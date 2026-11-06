-- Read-only access checks; no business records are modified.
BEGIN;
CREATE TEMP TABLE amr_rollout_admin AS SELECT DISTINCT m.auth_user_id,m.clinica_id FROM public.usuarios_clinica m JOIN auth.users u ON u.id=m.auth_user_id WHERE m.activo IS TRUE AND m.rol='admin' AND u.email_confirmed_at IS NOT NULL;
DO $check_admin$ BEGIN IF NOT EXISTS(SELECT 1 FROM amr_rollout_admin) THEN RAISE EXCEPTION 'No confirmed active admin';END IF;END $check_admin$;
GRANT SELECT ON amr_rollout_admin TO authenticated;
SET LOCAL ROLE anon;
DO $check_anon$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['pacientes','citas','historias_clinicas','consentimientos','firmas_sesiones','facturas','usuarios_clinica','clinicas','logs_sistema'] LOOP
 IF has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE') THEN RAISE EXCEPTION 'Anonymous access still granted on %',t;END IF;
END LOOP;END $check_anon$;
RESET ROLE;
SET LOCAL ROLE authenticated;
DO $check_access$ DECLARE a record; BEGIN FOR a IN SELECT * FROM amr_rollout_admin LOOP
 PERFORM set_config('request.jwt.claims',json_build_object('sub',a.auth_user_id,'role','authenticated')::text,true);
 IF NOT amr_private.has_role(a.clinica_id,ARRAY['admin']) THEN RAISE EXCEPTION 'Administrator role is unavailable';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.clinicas WHERE id=a.clinica_id) THEN RAISE EXCEPTION 'Admin clinic lookup denied';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios_clinica WHERE auth_user_id=a.auth_user_id AND clinica_id=a.clinica_id AND activo IS TRUE AND rol='admin') THEN RAISE EXCEPTION 'Admin membership lookup denied';END IF;
 PERFORM 1 FROM public.pacientes WHERE clinica_id=a.clinica_id LIMIT 1;
 PERFORM 1 FROM public.citas WHERE clinica_id=a.clinica_id LIMIT 1;
 PERFORM 1 FROM public.logs_sistema WHERE clinica_id=a.clinica_id LIMIT 1;
END LOOP;END $check_access$;
RESET ROLE;
SELECT 'PASS: anonymous permissions closed and every confirmed active admin retains their clinic lookup and table access' AS result;
ROLLBACK;
