-- EMERGENCY RESTORATION ONLY: restores the previous OPEN pilot permissions.
-- Prefer reverting only the frontend while keeping restrictive database policies.
-- Review the current schema and obtain authorization before using this script.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

DO $amr_policy$ DECLARE p record; BEGIN FOR p IN SELECT policyname,tablename FROM pg_policies WHERE schemaname='public' AND tablename=ANY(ARRAY['pacientes','citas','facturas','firmas_sesiones','consentimientos','historias_clinicas','usuarios_clinica','clinicas','logs_sistema']) LOOP EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,p.tablename);END LOOP;END $amr_policy$;

DROP TRIGGER IF EXISTS "amr_member_identity" ON public."usuarios_clinica";

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."pacientes";

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."citas";

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."historias_clinicas";

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."consentimientos";

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."firmas_sesiones";

DROP TRIGGER IF EXISTS "amr_clinic_immutable" ON public."facturas";

ALTER TABLE public."citas" DROP CONSTRAINT IF EXISTS "amr_patient_same_clinic";

ALTER TABLE public."historias_clinicas" DROP CONSTRAINT IF EXISTS "amr_patient_same_clinic";

ALTER TABLE public."consentimientos" DROP CONSTRAINT IF EXISTS "amr_patient_same_clinic";

ALTER TABLE public."firmas_sesiones" DROP CONSTRAINT IF EXISTS "amr_patient_same_clinic";

ALTER TABLE public."facturas" DROP CONSTRAINT IF EXISTS "amr_patient_same_clinic";

ALTER TABLE public."firmas_sesiones" DROP CONSTRAINT IF EXISTS "amr_signature_same_appointment";

ALTER TABLE public."citas" DROP CONSTRAINT IF EXISTS "amr_appointment_clinic_patient_unique";

ALTER TABLE public."pacientes" DROP CONSTRAINT IF EXISTS "amr_patient_clinic_unique";

ALTER TABLE public."usuarios_clinica" DROP CONSTRAINT IF EXISTS "amr_member_role";

CREATE POLICY "permitir borrar pacientes" ON public."pacientes" AS PERMISSIVE FOR DELETE TO PUBLIC USING (true);

CREATE POLICY "permitir actualizar pacientes" ON public."pacientes" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (true);

CREATE POLICY "permitir insertar pacientes" ON public."pacientes" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);

CREATE POLICY "permitir lectura pacientes" ON public."pacientes" AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

CREATE POLICY "permitir borrar citas" ON public."citas" AS PERMISSIVE FOR DELETE TO PUBLIC USING (true);

CREATE POLICY "permitir actualizar citas" ON public."citas" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (true);

CREATE POLICY "permitir insertar citas" ON public."citas" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);

CREATE POLICY "permitir lectura citas" ON public."citas" AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

CREATE POLICY "permitir borrar facturas" ON public."facturas" AS PERMISSIVE FOR DELETE TO PUBLIC USING (true);

CREATE POLICY "permitir actualizar facturas" ON public."facturas" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (true);

CREATE POLICY "permitir insertar facturas" ON public."facturas" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);

CREATE POLICY "permitir lectura facturas" ON public."facturas" AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

CREATE POLICY "permitir borrar firmas sesiones" ON public."firmas_sesiones" AS PERMISSIVE FOR DELETE TO PUBLIC USING (true);

CREATE POLICY "permitir actualizar firmas sesiones" ON public."firmas_sesiones" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (true);

CREATE POLICY "permitir insertar firmas sesiones" ON public."firmas_sesiones" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);

CREATE POLICY "permitir lectura firmas sesiones" ON public."firmas_sesiones" AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

CREATE POLICY "permitir borrar consentimientos" ON public."consentimientos" AS PERMISSIVE FOR DELETE TO PUBLIC USING (true);

CREATE POLICY "permitir actualizar consentimientos" ON public."consentimientos" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (true);

CREATE POLICY "permitir insertar consentimientos" ON public."consentimientos" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);

CREATE POLICY "permitir lectura consentimientos" ON public."consentimientos" AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

CREATE POLICY "permitir borrar historias" ON public."historias_clinicas" AS PERMISSIVE FOR DELETE TO PUBLIC USING (true);

CREATE POLICY "permitir actualizar historias" ON public."historias_clinicas" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (true);

CREATE POLICY "permitir insertar historias" ON public."historias_clinicas" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);

CREATE POLICY "permitir lectura historias" ON public."historias_clinicas" AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

CREATE POLICY "usuarios clinica borrar piloto" ON public."usuarios_clinica" AS PERMISSIVE FOR DELETE TO PUBLIC USING (true);

CREATE POLICY "usuarios clinica actualizar piloto" ON public."usuarios_clinica" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (true);

CREATE POLICY "usuarios clinica insertar piloto" ON public."usuarios_clinica" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);

CREATE POLICY "usuarios clinica lectura piloto" ON public."usuarios_clinica" AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

CREATE POLICY "permitir todo usuarios clinica" ON public."usuarios_clinica" AS PERMISSIVE FOR ALL TO PUBLIC USING (true) WITH CHECK (true);

CREATE POLICY "permitir todo clinicas" ON public."clinicas" AS PERMISSIVE FOR ALL TO PUBLIC USING (true) WITH CHECK (true);

CREATE POLICY "logs borrar piloto" ON public."logs_sistema" AS PERMISSIVE FOR DELETE TO PUBLIC USING (true);

CREATE POLICY "logs actualizar piloto" ON public."logs_sistema" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (true);

CREATE POLICY "logs insertar piloto" ON public."logs_sistema" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);

CREATE POLICY "logs lectura piloto" ON public."logs_sistema" AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

REVOKE ALL ON TABLE public."pacientes" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE public."citas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE public."facturas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE public."firmas_sesiones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE public."consentimientos" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE public."historias_clinicas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE public."usuarios_clinica" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE public."clinicas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE public."logs_sistema" FROM PUBLIC,anon,authenticated;

GRANT INSERT ON TABLE public."pacientes" TO "anon";

GRANT SELECT ON TABLE public."pacientes" TO "anon";

GRANT UPDATE ON TABLE public."pacientes" TO "anon";

GRANT DELETE ON TABLE public."pacientes" TO "anon";

GRANT TRUNCATE ON TABLE public."pacientes" TO "anon";

GRANT REFERENCES ON TABLE public."pacientes" TO "anon";

GRANT TRIGGER ON TABLE public."pacientes" TO "anon";

GRANT INSERT ON TABLE public."pacientes" TO "authenticated";

GRANT SELECT ON TABLE public."pacientes" TO "authenticated";

GRANT UPDATE ON TABLE public."pacientes" TO "authenticated";

GRANT DELETE ON TABLE public."pacientes" TO "authenticated";

GRANT TRUNCATE ON TABLE public."pacientes" TO "authenticated";

GRANT REFERENCES ON TABLE public."pacientes" TO "authenticated";

GRANT TRIGGER ON TABLE public."pacientes" TO "authenticated";

GRANT INSERT ON TABLE public."citas" TO "anon";

GRANT SELECT ON TABLE public."citas" TO "anon";

GRANT UPDATE ON TABLE public."citas" TO "anon";

GRANT DELETE ON TABLE public."citas" TO "anon";

GRANT TRUNCATE ON TABLE public."citas" TO "anon";

GRANT REFERENCES ON TABLE public."citas" TO "anon";

GRANT TRIGGER ON TABLE public."citas" TO "anon";

GRANT INSERT ON TABLE public."citas" TO "authenticated";

GRANT SELECT ON TABLE public."citas" TO "authenticated";

GRANT UPDATE ON TABLE public."citas" TO "authenticated";

GRANT DELETE ON TABLE public."citas" TO "authenticated";

GRANT TRUNCATE ON TABLE public."citas" TO "authenticated";

GRANT REFERENCES ON TABLE public."citas" TO "authenticated";

GRANT TRIGGER ON TABLE public."citas" TO "authenticated";

GRANT INSERT ON TABLE public."facturas" TO "anon";

GRANT SELECT ON TABLE public."facturas" TO "anon";

GRANT UPDATE ON TABLE public."facturas" TO "anon";

GRANT DELETE ON TABLE public."facturas" TO "anon";

GRANT TRUNCATE ON TABLE public."facturas" TO "anon";

GRANT REFERENCES ON TABLE public."facturas" TO "anon";

GRANT TRIGGER ON TABLE public."facturas" TO "anon";

GRANT INSERT ON TABLE public."facturas" TO "authenticated";

GRANT SELECT ON TABLE public."facturas" TO "authenticated";

GRANT UPDATE ON TABLE public."facturas" TO "authenticated";

GRANT DELETE ON TABLE public."facturas" TO "authenticated";

GRANT TRUNCATE ON TABLE public."facturas" TO "authenticated";

GRANT REFERENCES ON TABLE public."facturas" TO "authenticated";

GRANT TRIGGER ON TABLE public."facturas" TO "authenticated";

GRANT INSERT ON TABLE public."firmas_sesiones" TO "anon";

GRANT SELECT ON TABLE public."firmas_sesiones" TO "anon";

GRANT UPDATE ON TABLE public."firmas_sesiones" TO "anon";

GRANT DELETE ON TABLE public."firmas_sesiones" TO "anon";

GRANT TRUNCATE ON TABLE public."firmas_sesiones" TO "anon";

GRANT REFERENCES ON TABLE public."firmas_sesiones" TO "anon";

GRANT TRIGGER ON TABLE public."firmas_sesiones" TO "anon";

GRANT INSERT ON TABLE public."firmas_sesiones" TO "authenticated";

GRANT SELECT ON TABLE public."firmas_sesiones" TO "authenticated";

GRANT UPDATE ON TABLE public."firmas_sesiones" TO "authenticated";

GRANT DELETE ON TABLE public."firmas_sesiones" TO "authenticated";

GRANT TRUNCATE ON TABLE public."firmas_sesiones" TO "authenticated";

GRANT REFERENCES ON TABLE public."firmas_sesiones" TO "authenticated";

GRANT TRIGGER ON TABLE public."firmas_sesiones" TO "authenticated";

GRANT INSERT ON TABLE public."consentimientos" TO "anon";

GRANT SELECT ON TABLE public."consentimientos" TO "anon";

GRANT UPDATE ON TABLE public."consentimientos" TO "anon";

GRANT DELETE ON TABLE public."consentimientos" TO "anon";

GRANT TRUNCATE ON TABLE public."consentimientos" TO "anon";

GRANT REFERENCES ON TABLE public."consentimientos" TO "anon";

GRANT TRIGGER ON TABLE public."consentimientos" TO "anon";

GRANT INSERT ON TABLE public."consentimientos" TO "authenticated";

GRANT SELECT ON TABLE public."consentimientos" TO "authenticated";

GRANT UPDATE ON TABLE public."consentimientos" TO "authenticated";

GRANT DELETE ON TABLE public."consentimientos" TO "authenticated";

GRANT TRUNCATE ON TABLE public."consentimientos" TO "authenticated";

GRANT REFERENCES ON TABLE public."consentimientos" TO "authenticated";

GRANT TRIGGER ON TABLE public."consentimientos" TO "authenticated";

GRANT INSERT ON TABLE public."historias_clinicas" TO "anon";

GRANT SELECT ON TABLE public."historias_clinicas" TO "anon";

GRANT UPDATE ON TABLE public."historias_clinicas" TO "anon";

GRANT DELETE ON TABLE public."historias_clinicas" TO "anon";

GRANT TRUNCATE ON TABLE public."historias_clinicas" TO "anon";

GRANT REFERENCES ON TABLE public."historias_clinicas" TO "anon";

GRANT TRIGGER ON TABLE public."historias_clinicas" TO "anon";

GRANT INSERT ON TABLE public."historias_clinicas" TO "authenticated";

GRANT SELECT ON TABLE public."historias_clinicas" TO "authenticated";

GRANT UPDATE ON TABLE public."historias_clinicas" TO "authenticated";

GRANT DELETE ON TABLE public."historias_clinicas" TO "authenticated";

GRANT TRUNCATE ON TABLE public."historias_clinicas" TO "authenticated";

GRANT REFERENCES ON TABLE public."historias_clinicas" TO "authenticated";

GRANT TRIGGER ON TABLE public."historias_clinicas" TO "authenticated";

GRANT INSERT ON TABLE public."usuarios_clinica" TO "anon";

GRANT SELECT ON TABLE public."usuarios_clinica" TO "anon";

GRANT UPDATE ON TABLE public."usuarios_clinica" TO "anon";

GRANT DELETE ON TABLE public."usuarios_clinica" TO "anon";

GRANT TRUNCATE ON TABLE public."usuarios_clinica" TO "anon";

GRANT REFERENCES ON TABLE public."usuarios_clinica" TO "anon";

GRANT TRIGGER ON TABLE public."usuarios_clinica" TO "anon";

GRANT INSERT ON TABLE public."usuarios_clinica" TO "authenticated";

GRANT SELECT ON TABLE public."usuarios_clinica" TO "authenticated";

GRANT UPDATE ON TABLE public."usuarios_clinica" TO "authenticated";

GRANT DELETE ON TABLE public."usuarios_clinica" TO "authenticated";

GRANT TRUNCATE ON TABLE public."usuarios_clinica" TO "authenticated";

GRANT REFERENCES ON TABLE public."usuarios_clinica" TO "authenticated";

GRANT TRIGGER ON TABLE public."usuarios_clinica" TO "authenticated";

GRANT INSERT ON TABLE public."clinicas" TO "anon";

GRANT SELECT ON TABLE public."clinicas" TO "anon";

GRANT UPDATE ON TABLE public."clinicas" TO "anon";

GRANT DELETE ON TABLE public."clinicas" TO "anon";

GRANT TRUNCATE ON TABLE public."clinicas" TO "anon";

GRANT REFERENCES ON TABLE public."clinicas" TO "anon";

GRANT TRIGGER ON TABLE public."clinicas" TO "anon";

GRANT INSERT ON TABLE public."clinicas" TO "authenticated";

GRANT SELECT ON TABLE public."clinicas" TO "authenticated";

GRANT UPDATE ON TABLE public."clinicas" TO "authenticated";

GRANT DELETE ON TABLE public."clinicas" TO "authenticated";

GRANT TRUNCATE ON TABLE public."clinicas" TO "authenticated";

GRANT REFERENCES ON TABLE public."clinicas" TO "authenticated";

GRANT TRIGGER ON TABLE public."clinicas" TO "authenticated";

GRANT INSERT ON TABLE public."logs_sistema" TO "anon";

GRANT SELECT ON TABLE public."logs_sistema" TO "anon";

GRANT UPDATE ON TABLE public."logs_sistema" TO "anon";

GRANT DELETE ON TABLE public."logs_sistema" TO "anon";

GRANT TRUNCATE ON TABLE public."logs_sistema" TO "anon";

GRANT REFERENCES ON TABLE public."logs_sistema" TO "anon";

GRANT TRIGGER ON TABLE public."logs_sistema" TO "anon";

GRANT INSERT ON TABLE public."logs_sistema" TO "authenticated";

GRANT SELECT ON TABLE public."logs_sistema" TO "authenticated";

GRANT UPDATE ON TABLE public."logs_sistema" TO "authenticated";

GRANT DELETE ON TABLE public."logs_sistema" TO "authenticated";

GRANT TRUNCATE ON TABLE public."logs_sistema" TO "authenticated";

GRANT REFERENCES ON TABLE public."logs_sistema" TO "authenticated";

GRANT TRIGGER ON TABLE public."logs_sistema" TO "authenticated";

ALTER TABLE public."pacientes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."pacientes" NO FORCE ROW LEVEL SECURITY;

ALTER TABLE public."citas" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."citas" NO FORCE ROW LEVEL SECURITY;

ALTER TABLE public."facturas" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."facturas" NO FORCE ROW LEVEL SECURITY;

ALTER TABLE public."firmas_sesiones" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."firmas_sesiones" NO FORCE ROW LEVEL SECURITY;

ALTER TABLE public."consentimientos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."consentimientos" NO FORCE ROW LEVEL SECURITY;

ALTER TABLE public."historias_clinicas" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."historias_clinicas" NO FORCE ROW LEVEL SECURITY;

ALTER TABLE public."usuarios_clinica" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."usuarios_clinica" NO FORCE ROW LEVEL SECURITY;

ALTER TABLE public."clinicas" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."clinicas" NO FORCE ROW LEVEL SECURITY;

ALTER TABLE public."logs_sistema" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."logs_sistema" NO FORCE ROW LEVEL SECURITY;

REVOKE ALL ON SEQUENCE public.pacientes_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.pacientes_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.pacientes_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.pacientes_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.pacientes_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.pacientes_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.pacientes_id_seq TO "authenticated";

REVOKE ALL ON SEQUENCE public.citas_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.citas_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.citas_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.citas_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.citas_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.citas_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.citas_id_seq TO "authenticated";

REVOKE ALL ON SEQUENCE public.facturas_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.facturas_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.facturas_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.facturas_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.facturas_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.facturas_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.facturas_id_seq TO "authenticated";

REVOKE ALL ON SEQUENCE public.firmas_sesiones_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.firmas_sesiones_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.firmas_sesiones_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.firmas_sesiones_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.firmas_sesiones_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.firmas_sesiones_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.firmas_sesiones_id_seq TO "authenticated";

REVOKE ALL ON SEQUENCE public.consentimientos_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.consentimientos_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.consentimientos_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.consentimientos_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.consentimientos_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.consentimientos_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.consentimientos_id_seq TO "authenticated";

REVOKE ALL ON SEQUENCE public.historias_clinicas_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.historias_clinicas_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.historias_clinicas_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.historias_clinicas_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.historias_clinicas_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.historias_clinicas_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.historias_clinicas_id_seq TO "authenticated";

REVOKE ALL ON SEQUENCE public.usuarios_clinica_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.usuarios_clinica_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.usuarios_clinica_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.usuarios_clinica_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.usuarios_clinica_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.usuarios_clinica_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.usuarios_clinica_id_seq TO "authenticated";

REVOKE ALL ON SEQUENCE public.clinicas_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.clinicas_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.clinicas_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.clinicas_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.clinicas_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.clinicas_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.clinicas_id_seq TO "authenticated";

REVOKE ALL ON SEQUENCE public.logs_sistema_id_seq FROM PUBLIC,anon,authenticated;

GRANT SELECT ON SEQUENCE public.logs_sistema_id_seq TO "anon";

GRANT UPDATE ON SEQUENCE public.logs_sistema_id_seq TO "anon";

GRANT USAGE ON SEQUENCE public.logs_sistema_id_seq TO "anon";

GRANT SELECT ON SEQUENCE public.logs_sistema_id_seq TO "authenticated";

GRANT UPDATE ON SEQUENCE public.logs_sistema_id_seq TO "authenticated";

GRANT USAGE ON SEQUENCE public.logs_sistema_id_seq TO "authenticated";

REVOKE ALL ON FUNCTION "public"."amr_auditar_pacientes"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."amr_auditar_pacientes"() TO PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."amr_auditar_pacientes"() TO "anon";

GRANT EXECUTE ON FUNCTION "public"."amr_auditar_pacientes"() TO "authenticated";

DROP FUNCTION IF EXISTS "public"."amr_recepcion_pacientes"(p_clinica_id bigint, p_accion text, p_datos jsonb);

DROP FUNCTION IF EXISTS "public"."amr_recepcion_citas"(p_clinica_id bigint, p_accion text, p_datos jsonb);

DROP FUNCTION IF EXISTS "amr_private"."member_identity_immutable"();

DROP FUNCTION IF EXISTS "amr_private"."clinic_immutable"();

DROP FUNCTION IF EXISTS "amr_private"."reception_pacientes"(p_clinica_id bigint, p_accion text, p_datos jsonb);

DROP FUNCTION IF EXISTS "amr_private"."reception_citas"(p_clinica_id bigint, p_accion text, p_datos jsonb);

DROP FUNCTION IF EXISTS "amr_private"."has_role"(p_clinic bigint, p_roles text[]);

DROP SCHEMA IF EXISTS amr_private;

NOTIFY pgrst, 'reload schema';
COMMIT;
