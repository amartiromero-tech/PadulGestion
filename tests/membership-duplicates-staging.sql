-- Staging only. Temporarily remove uniqueness inside a transaction to reproduce production's historical duplicates.
BEGIN;
ALTER TABLE public.usuarios_clinica DROP CONSTRAINT "amr_member_unique";
CREATE TEMP TABLE amr_duplicate_probe(user_id uuid,clinic_id bigint);
DO $seed$ DECLARE u uuid:=gen_random_uuid();c bigint;BEGIN
 INSERT INTO public.clinicas(nombre) VALUES('CLINICA FICTICIA DUPLICADOS') RETURNING id INTO c;
 INSERT INTO amr_duplicate_probe VALUES(u,c);
 INSERT INTO public.usuarios_clinica(auth_user_id,clinica_id,rol,nombre,activo) VALUES(u,c,'admin','ADMIN FICTICIO DUPLICADO',true),(u,c,'admin','ADMIN FICTICIO DUPLICADO',true);
 INSERT INTO public.pacientes(clinica_id,nombre) VALUES(c,'PACIENTE FICTICIO DUPLICADOS');
END $seed$;
GRANT SELECT ON amr_duplicate_probe TO authenticated;
SET LOCAL ROLE authenticated;
DO $same_roles$ DECLARE d record;BEGIN
 SELECT * INTO d FROM amr_duplicate_probe;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',d.user_id,'role','authenticated')::text,true);
 IF NOT amr_private.has_role(d.clinic_id,ARRAY['admin']) OR NOT EXISTS(SELECT 1 FROM public.pacientes WHERE clinica_id=d.clinic_id) THEN RAISE EXCEPTION 'Identical duplicate admins lost access';END IF;
END $same_roles$;
RESET ROLE;
INSERT INTO public.usuarios_clinica(auth_user_id,clinica_id,rol,nombre,activo) SELECT user_id,clinic_id,'fisio','ROL CONTRADICTORIO FICTICIO',true FROM amr_duplicate_probe;
SET LOCAL ROLE authenticated;
DO $conflict$ DECLARE d record;BEGIN
 SELECT * INTO d FROM amr_duplicate_probe;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',d.user_id,'role','authenticated')::text,true);
 IF amr_private.has_role(d.clinic_id,ARRAY['admin','fisio','recepcion','supervisor']) OR EXISTS(SELECT 1 FROM public.pacientes WHERE clinica_id=d.clinic_id) THEN RAISE EXCEPTION 'Conflicting membership roles granted access';END IF;
END $conflict$;
RESET ROLE;
SELECT 'PASS: identical duplicate admins keep access; conflicting roles deny all clinic data' AS result;
ROLLBACK;
