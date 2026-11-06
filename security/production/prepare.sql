-- REVIEWED PROPOSAL ONLY. Not yet applied to production. Run with the matching reviewed frontend.
-- No patient, appointment, membership or other business rows are edited or deleted.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';


DO $amr_preflight$
DECLARE t text; invalid boolean;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.usuarios_clinica m JOIN auth.users u ON u.id=m.auth_user_id JOIN public.clinicas c ON c.id=m.clinica_id WHERE m.activo IS TRUE AND m.rol='admin' AND u.email_confirmed_at IS NOT NULL) THEN
  RAISE EXCEPTION 'No confirmed active administrator; abort before changing permissions';
 END IF;
 IF EXISTS(SELECT 1 FROM public.usuarios_clinica WHERE activo IS TRUE AND auth_user_id IS NOT NULL GROUP BY auth_user_id,clinica_id HAVING count(DISTINCT rol)>1) THEN RAISE EXCEPTION 'Conflicting membership roles; no changes applied';END IF;
 FOREACH t IN ARRAY ARRAY['pacientes','citas','historias_clinicas','consentimientos','firmas_sesiones','facturas'] LOOP
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I WHERE clinica_id IS NULL)',t) INTO invalid;
  IF invalid THEN RAISE EXCEPTION 'Null clinic IDs in %; no data will be reassigned',t;END IF;
 END LOOP;
END $amr_preflight$;
DO $amr_relations$
DECLARE t text; invalid boolean;
BEGIN
 FOREACH t IN ARRAY ARRAY['citas','historias_clinicas','consentimientos','firmas_sesiones','facturas'] LOOP
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I r LEFT JOIN public.pacientes p ON p.id=r.paciente_id WHERE r.paciente_id IS NULL OR p.id IS NULL OR r.clinica_id IS DISTINCT FROM p.clinica_id)',t) INTO invalid;
  IF invalid THEN RAISE EXCEPTION 'Invalid patient relationship in %; abort without changing data',t;END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.firmas_sesiones f LEFT JOIN public.citas c ON c.id=f.cita_id WHERE f.cita_id IS NOT NULL AND (c.id IS NULL OR f.clinica_id IS DISTINCT FROM c.clinica_id OR f.paciente_id IS DISTINCT FROM c.paciente_id)) THEN RAISE EXCEPTION 'Invalid appointment/signature relationship';END IF;
END $amr_relations$;

CREATE SCHEMA IF NOT EXISTS amr_private;
REVOKE ALL ON SCHEMA amr_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA amr_private TO authenticated;


CREATE OR REPLACE FUNCTION amr_private.member_identity_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ BEGIN
IF NEW.id IS DISTINCT FROM OLD.id OR NEW.clinica_id IS DISTINCT FROM OLD.clinica_id
OR NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id THEN
RAISE EXCEPTION 'La identidad y la clinica de una membresia no se pueden cambiar' USING ERRCODE='42501';
END IF; RETURN NEW; END $function$;


CREATE OR REPLACE FUNCTION amr_private.has_role(p_clinic bigint, p_roles text[])
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $function$
 SELECT auth.uid() IS NOT NULL AND COALESCE((
  SELECT count(DISTINCT m.rol)=1 AND bool_and(COALESCE(m.rol=ANY(p_roles),false))
  FROM public.usuarios_clinica m
  WHERE m.auth_user_id=auth.uid() AND m.clinica_id=p_clinic AND m.activo IS TRUE
 ),false);
$function$;


CREATE OR REPLACE FUNCTION amr_private.clinic_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ BEGIN IF NEW.clinica_id IS DISTINCT FROM OLD.clinica_id OR NEW.id IS DISTINCT FROM OLD.id
THEN RAISE EXCEPTION 'No se puede cambiar la identidad ni la clinica del registro' USING ERRCODE='42501'; END IF; RETURN NEW; END $function$;


CREATE OR REPLACE FUNCTION amr_private.reception_pacientes(p_clinica_id bigint, p_accion text, p_datos jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r public.pacientes%ROWTYPE; result jsonb; BEGIN
IF NOT amr_private.has_role(p_clinica_id,ARRAY['admin','recepcion']) THEN
RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
IF p_accion='listar' THEN
SELECT coalesce(jsonb_agg(jsonb_build_object('id',src.id,'nombre',src.nombre,'telefono',src.telefono,'nif',src.nif,'direccion',src.direccion,'created_at',src.created_at,'clinica_id',src.clinica_id) ORDER BY src.id),'[]'::jsonb) INTO result FROM public.pacientes src WHERE src.clinica_id=p_clinica_id;
RETURN result; END IF;
IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_datos) k WHERE k<>ALL(ARRAY['id','nombre','telefono','nif','direccion'])) THEN
RAISE EXCEPTION 'Campos no permitidos' USING ERRCODE='42501'; END IF;
IF p_accion='crear' THEN
INSERT INTO public.pacientes(clinica_id,nombre,telefono,nif,direccion) VALUES(p_clinica_id,p_datos->>'nombre',p_datos->>'telefono',p_datos->>'nif',p_datos->>'direccion') RETURNING * INTO r;
ELSIF p_accion='modificar' THEN
UPDATE public.pacientes SET nombre=p_datos->>'nombre',telefono=p_datos->>'telefono',nif=p_datos->>'nif',direccion=p_datos->>'direccion' WHERE id=(p_datos->>'id')::bigint AND clinica_id=p_clinica_id RETURNING * INTO r;
IF NOT FOUND THEN RAISE EXCEPTION 'Registro no disponible' USING ERRCODE='42501'; END IF;
ELSE RAISE EXCEPTION 'Operacion no permitida' USING ERRCODE='42501'; END IF;
RETURN jsonb_build_object('id',r.id,'nombre',r.nombre,'telefono',r.telefono,'nif',r.nif,'direccion',r.direccion,'created_at',r.created_at,'clinica_id',r.clinica_id);
END $function$;


CREATE OR REPLACE FUNCTION public.amr_recepcion_pacientes(p_clinica_id bigint, p_accion text, p_datos jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT amr_private.reception_pacientes(p_clinica_id,p_accion,p_datos) $function$;


CREATE OR REPLACE FUNCTION public.amr_recepcion_citas(p_clinica_id bigint, p_accion text, p_datos jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT amr_private.reception_citas(p_clinica_id,p_accion,p_datos) $function$;


CREATE OR REPLACE FUNCTION amr_private.reception_citas(p_clinica_id bigint, p_accion text, p_datos jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r public.citas%ROWTYPE; result jsonb; BEGIN
IF NOT amr_private.has_role(p_clinica_id,ARRAY['admin','recepcion']) THEN
RAISE EXCEPTION 'Acceso denegado' USING ERRCODE='42501'; END IF;
IF p_accion='listar' THEN
SELECT coalesce(jsonb_agg(jsonb_build_object('id',src.id,'paciente_id',src.paciente_id,'fecha',src.fecha,'hora',src.hora,'precio',src.precio,'estado',src.estado,'created_at',src.created_at,'clinica_id',src.clinica_id) ORDER BY src.id),'[]'::jsonb) INTO result FROM public.citas src WHERE src.clinica_id=p_clinica_id;
RETURN result; END IF;
IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_datos) k WHERE k<>ALL(ARRAY['id','paciente_id','fecha','hora','precio','estado'])) THEN
RAISE EXCEPTION 'Campos no permitidos' USING ERRCODE='42501'; END IF;
IF p_accion='crear' THEN
INSERT INTO public.citas(clinica_id,paciente_id,fecha,hora,precio,estado) VALUES(p_clinica_id,(p_datos->>'paciente_id')::bigint,(p_datos->>'fecha')::date,p_datos->>'hora',(p_datos->>'precio')::numeric,p_datos->>'estado') RETURNING * INTO r;
ELSIF p_accion='modificar' THEN
UPDATE public.citas SET paciente_id=(p_datos->>'paciente_id')::bigint,fecha=(p_datos->>'fecha')::date,hora=p_datos->>'hora',precio=(p_datos->>'precio')::numeric,estado=p_datos->>'estado' WHERE id=(p_datos->>'id')::bigint AND clinica_id=p_clinica_id RETURNING * INTO r;
IF NOT FOUND THEN RAISE EXCEPTION 'Registro no disponible' USING ERRCODE='42501'; END IF;
ELSE RAISE EXCEPTION 'Operacion no permitida' USING ERRCODE='42501'; END IF;
RETURN jsonb_build_object('id',r.id,'paciente_id',r.paciente_id,'fecha',r.fecha,'hora',r.hora,'precio',r.precio,'estado',r.estado,'created_at',r.created_at,'clinica_id',r.clinica_id);
END $function$;


REVOKE ALL ON FUNCTION "amr_private"."member_identity_immutable"() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "amr_private"."has_role"(p_clinic bigint, p_roles text[]) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "amr_private"."clinic_immutable"() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "amr_private"."reception_pacientes"(p_clinica_id bigint, p_accion text, p_datos jsonb) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."amr_recepcion_pacientes"(p_clinica_id bigint, p_accion text, p_datos jsonb) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."amr_recepcion_citas"(p_clinica_id bigint, p_accion text, p_datos jsonb) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "amr_private"."reception_citas"(p_clinica_id bigint, p_accion text, p_datos jsonb) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "amr_private"."has_role"(p_clinic bigint, p_roles text[]) TO authenticated;

GRANT EXECUTE ON FUNCTION "amr_private"."reception_pacientes"(p_clinica_id bigint, p_accion text, p_datos jsonb) TO authenticated;

GRANT EXECUTE ON FUNCTION "public"."amr_recepcion_pacientes"(p_clinica_id bigint, p_accion text, p_datos jsonb) TO authenticated;

GRANT EXECUTE ON FUNCTION "public"."amr_recepcion_citas"(p_clinica_id bigint, p_accion text, p_datos jsonb) TO authenticated;

GRANT EXECUTE ON FUNCTION "amr_private"."reception_citas"(p_clinica_id bigint, p_accion text, p_datos jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public.amr_auditar_pacientes() FROM PUBLIC, anon, authenticated;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.citas'::regclass AND conname='amr_appointment_clinic_patient_unique') THEN ALTER TABLE public."citas" ADD CONSTRAINT "amr_appointment_clinic_patient_unique" UNIQUE (clinica_id, paciente_id, id); END IF; END $amr_constraint$;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.pacientes'::regclass AND conname='amr_patient_clinic_unique') THEN ALTER TABLE public."pacientes" ADD CONSTRAINT "amr_patient_clinic_unique" UNIQUE (clinica_id, id); END IF; END $amr_constraint$;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.usuarios_clinica'::regclass AND conname='amr_member_role') THEN ALTER TABLE public."usuarios_clinica" ADD CONSTRAINT "amr_member_role" CHECK ((rol = ANY (ARRAY['admin'::text, 'fisio'::text, 'recepcion'::text, 'supervisor'::text]))); END IF; END $amr_constraint$;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.citas'::regclass AND conname='amr_patient_same_clinic') THEN ALTER TABLE public."citas" ADD CONSTRAINT "amr_patient_same_clinic" FOREIGN KEY (clinica_id, paciente_id) REFERENCES pacientes(clinica_id, id); END IF; END $amr_constraint$;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.historias_clinicas'::regclass AND conname='amr_patient_same_clinic') THEN ALTER TABLE public."historias_clinicas" ADD CONSTRAINT "amr_patient_same_clinic" FOREIGN KEY (clinica_id, paciente_id) REFERENCES pacientes(clinica_id, id); END IF; END $amr_constraint$;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.consentimientos'::regclass AND conname='amr_patient_same_clinic') THEN ALTER TABLE public."consentimientos" ADD CONSTRAINT "amr_patient_same_clinic" FOREIGN KEY (clinica_id, paciente_id) REFERENCES pacientes(clinica_id, id); END IF; END $amr_constraint$;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.firmas_sesiones'::regclass AND conname='amr_patient_same_clinic') THEN ALTER TABLE public."firmas_sesiones" ADD CONSTRAINT "amr_patient_same_clinic" FOREIGN KEY (clinica_id, paciente_id) REFERENCES pacientes(clinica_id, id); END IF; END $amr_constraint$;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.facturas'::regclass AND conname='amr_patient_same_clinic') THEN ALTER TABLE public."facturas" ADD CONSTRAINT "amr_patient_same_clinic" FOREIGN KEY (clinica_id, paciente_id) REFERENCES pacientes(clinica_id, id); END IF; END $amr_constraint$;

DO $amr_constraint$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.firmas_sesiones'::regclass AND conname='amr_signature_same_appointment') THEN ALTER TABLE public."firmas_sesiones" ADD CONSTRAINT "amr_signature_same_appointment" FOREIGN KEY (clinica_id, paciente_id, cita_id) REFERENCES citas(clinica_id, paciente_id, id); END IF; END $amr_constraint$;

DROP TRIGGER IF EXISTS "amr_member_identity" ON public."usuarios_clinica";
CREATE TRIGGER amr_member_identity BEFORE UPDATE ON public.usuarios_clinica FOR EACH ROW EXECUTE FUNCTION amr_private.member_identity_immutable();

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."pacientes";
CREATE TRIGGER amr_clinic_immutable BEFORE UPDATE ON public.pacientes FOR EACH ROW EXECUTE FUNCTION amr_private.clinic_immutable();

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."citas";
CREATE TRIGGER amr_clinic_immutable BEFORE UPDATE ON public.citas FOR EACH ROW EXECUTE FUNCTION amr_private.clinic_immutable();

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."historias_clinicas";
CREATE TRIGGER amr_clinic_immutable BEFORE UPDATE ON public.historias_clinicas FOR EACH ROW EXECUTE FUNCTION amr_private.clinic_immutable();

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."consentimientos";
CREATE TRIGGER amr_clinic_immutable BEFORE UPDATE ON public.consentimientos FOR EACH ROW EXECUTE FUNCTION amr_private.clinic_immutable();

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."firmas_sesiones";
CREATE TRIGGER amr_clinic_immutable BEFORE UPDATE ON public.firmas_sesiones FOR EACH ROW EXECUTE FUNCTION amr_private.clinic_immutable();

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."facturas";
CREATE TRIGGER amr_clinic_immutable BEFORE UPDATE ON public.facturas FOR EACH ROW EXECUTE FUNCTION amr_private.clinic_immutable();

ALTER TABLE public."pacientes" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."pacientes" FROM PUBLIC,anon,authenticated;

ALTER TABLE public."citas" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."citas" FROM PUBLIC,anon,authenticated;

ALTER TABLE public."facturas" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."facturas" FROM PUBLIC,anon,authenticated;

ALTER TABLE public."firmas_sesiones" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."firmas_sesiones" FROM PUBLIC,anon,authenticated;

ALTER TABLE public."consentimientos" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."consentimientos" FROM PUBLIC,anon,authenticated;

ALTER TABLE public."historias_clinicas" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."historias_clinicas" FROM PUBLIC,anon,authenticated;

ALTER TABLE public."usuarios_clinica" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."usuarios_clinica" FROM PUBLIC,anon,authenticated;

ALTER TABLE public."clinicas" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."clinicas" FROM PUBLIC,anon,authenticated;

ALTER TABLE public."logs_sistema" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public."logs_sistema" FROM PUBLIC,anon,authenticated;

DO $amr_policy$ DECLARE p record; BEGIN FOR p IN SELECT policyname,tablename FROM pg_policies WHERE schemaname='public' AND tablename=ANY(ARRAY['pacientes','citas','facturas','firmas_sesiones','consentimientos','historias_clinicas','usuarios_clinica','clinicas','logs_sistema']) LOOP EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,p.tablename);END LOOP;END $amr_policy$;

CREATE POLICY "amr_member_read" ON public."usuarios_clinica" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((((auth_user_id = ( SELECT auth.uid() AS uid)) AND (activo IS TRUE)) OR amr_private.has_role(clinica_id, ARRAY['admin'::text])));

CREATE POLICY "amr_member_insert" ON public."usuarios_clinica" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((amr_private.has_role(clinica_id, ARRAY['admin'::text]) AND (auth_user_id <> ( SELECT auth.uid() AS uid)) AND (rol = ANY (ARRAY['fisio'::text, 'recepcion'::text, 'supervisor'::text]))));

CREATE POLICY "amr_member_update" ON public."usuarios_clinica" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((amr_private.has_role(clinica_id, ARRAY['admin'::text]) AND (auth_user_id <> ( SELECT auth.uid() AS uid)) AND (rol <> 'admin'::text))) WITH CHECK ((amr_private.has_role(clinica_id, ARRAY['admin'::text]) AND (auth_user_id <> ( SELECT auth.uid() AS uid)) AND (rol = ANY (ARRAY['fisio'::text, 'recepcion'::text, 'supervisor'::text]))));

CREATE POLICY "amr_select" ON public."pacientes" AS PERMISSIVE FOR SELECT TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text, 'supervisor'::text]));

CREATE POLICY "amr_insert" ON public."pacientes" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_update" ON public."pacientes" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text])) WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_select" ON public."citas" AS PERMISSIVE FOR SELECT TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text, 'supervisor'::text]));

CREATE POLICY "amr_insert" ON public."citas" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_update" ON public."citas" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text])) WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_delete" ON public."citas" AS PERMISSIVE FOR DELETE TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text]));

CREATE POLICY "amr_select" ON public."historias_clinicas" AS PERMISSIVE FOR SELECT TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text, 'supervisor'::text]));

CREATE POLICY "amr_insert" ON public."historias_clinicas" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_update" ON public."historias_clinicas" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text])) WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_select" ON public."consentimientos" AS PERMISSIVE FOR SELECT TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text, 'supervisor'::text]));

CREATE POLICY "amr_insert" ON public."consentimientos" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_update" ON public."consentimientos" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text])) WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_select" ON public."firmas_sesiones" AS PERMISSIVE FOR SELECT TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text, 'supervisor'::text]));

CREATE POLICY "amr_insert" ON public."firmas_sesiones" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_update" ON public."firmas_sesiones" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text])) WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'fisio'::text]));

CREATE POLICY "amr_select" ON public."facturas" AS PERMISSIVE FOR SELECT TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'recepcion'::text, 'supervisor'::text]));

CREATE POLICY "amr_insert" ON public."facturas" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'recepcion'::text]));

CREATE POLICY "amr_update" ON public."facturas" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'recepcion'::text])) WITH CHECK (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'recepcion'::text]));

CREATE POLICY "amr_select" ON public."logs_sistema" AS PERMISSIVE FOR SELECT TO "authenticated" USING (amr_private.has_role(clinica_id, ARRAY['admin'::text, 'supervisor'::text]));

CREATE POLICY "amr_select" ON public."clinicas" AS PERMISSIVE FOR SELECT TO "authenticated" USING (amr_private.has_role(id, ARRAY['admin'::text, 'fisio'::text, 'recepcion'::text, 'supervisor'::text]));

CREATE POLICY "amr_update" ON public."clinicas" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (amr_private.has_role(id, ARRAY['admin'::text])) WITH CHECK (amr_private.has_role(id, ARRAY['admin'::text]));

GRANT INSERT ON TABLE public."usuarios_clinica" TO authenticated;

GRANT SELECT ON TABLE public."usuarios_clinica" TO authenticated;

GRANT UPDATE ON TABLE public."usuarios_clinica" TO authenticated;

GRANT INSERT ON TABLE public."pacientes" TO authenticated;

GRANT SELECT ON TABLE public."pacientes" TO authenticated;

GRANT UPDATE ON TABLE public."pacientes" TO authenticated;

GRANT INSERT ON TABLE public."citas" TO authenticated;

GRANT SELECT ON TABLE public."citas" TO authenticated;

GRANT UPDATE ON TABLE public."citas" TO authenticated;

GRANT DELETE ON TABLE public."citas" TO authenticated;

GRANT SELECT ON TABLE public."logs_sistema" TO authenticated;

GRANT SELECT ON TABLE public."clinicas" TO authenticated;

GRANT INSERT ON TABLE public."historias_clinicas" TO authenticated;

GRANT SELECT ON TABLE public."historias_clinicas" TO authenticated;

GRANT UPDATE ON TABLE public."historias_clinicas" TO authenticated;

GRANT INSERT ON TABLE public."consentimientos" TO authenticated;

GRANT SELECT ON TABLE public."consentimientos" TO authenticated;

GRANT UPDATE ON TABLE public."consentimientos" TO authenticated;

GRANT INSERT ON TABLE public."firmas_sesiones" TO authenticated;

GRANT SELECT ON TABLE public."firmas_sesiones" TO authenticated;

GRANT UPDATE ON TABLE public."firmas_sesiones" TO authenticated;

GRANT INSERT ON TABLE public."facturas" TO authenticated;

GRANT SELECT ON TABLE public."facturas" TO authenticated;

GRANT UPDATE ON TABLE public."facturas" TO authenticated;

DO $amr_sequence$ DECLARE t text; s text; BEGIN FOREACH t IN ARRAY ARRAY['pacientes','citas','facturas','firmas_sesiones','consentimientos','historias_clinicas','usuarios_clinica','clinicas','logs_sistema'] LOOP s=pg_get_serial_sequence(format('public.%I',t),'id');IF s IS NOT NULL THEN EXECUTE format('REVOKE ALL ON SEQUENCE %s FROM PUBLIC,anon,authenticated',s);IF t=ANY(ARRAY['usuarios_clinica','pacientes','citas','historias_clinicas','consentimientos','firmas_sesiones','facturas']) THEN EXECUTE format('GRANT USAGE ON SEQUENCE %s TO authenticated',s);END IF;END IF;END LOOP;END $amr_sequence$;

NOTIFY pgrst, 'reload schema';
COMMIT;
