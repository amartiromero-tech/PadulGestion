BEGIN;
CREATE TEMP TABLE amr_history_probe AS SELECT gen_random_uuid() uid,NULL::bigint clinic_id,NULL::bigint patient_id,NULL::bigint history_id;
DO $seed$ DECLARE c bigint;p bigint;h bigint;u uuid;BEGIN
 SELECT uid INTO u FROM amr_history_probe;
 INSERT INTO public.clinicas(nombre) VALUES('CLINICA FICTICIA PRUEBA EVOLUCIONES') RETURNING id INTO c;
 INSERT INTO public.usuarios_clinica(auth_user_id,clinica_id,rol,activo,nombre) VALUES(u,c,'fisio',true,'FISIO FICTICIO');
 INSERT INTO public.pacientes(clinica_id,nombre) VALUES(c,'PACIENTE FICTICIO EVOLUCIONES') RETURNING id INTO p;
 INSERT INTO public.historias_clinicas(clinica_id,paciente_id,motivo,evoluciones,updated_at) VALUES(c,p,'Motivo ficticio','[{"fecha":"2026-11-01","texto":"Anterior ficticia"}]','2026-11-01T10:00:00Z') RETURNING id INTO h;
 UPDATE amr_history_probe SET clinic_id=c,patient_id=p,history_id=h;
END $seed$;
GRANT SELECT ON amr_history_probe TO authenticated;
SET LOCAL ROLE authenticated;
DO $test$ DECLARE f record;previous public.historias_clinicas%ROWTYPE;n integer;BEGIN
 SELECT * INTO f FROM amr_history_probe;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',f.uid,'role','authenticated')::text,true);
 SELECT * INTO previous FROM public.historias_clinicas WHERE clinica_id=f.clinic_id AND paciente_id=f.patient_id;
 IF previous.id IS NULL THEN RAISE EXCEPTION 'Fisio cannot read own history';END IF;
 UPDATE public.historias_clinicas SET evoluciones='[{"fecha":"2026-11-02","texto":"Nueva ficticia"}]'::jsonb||previous.evoluciones,updated_at='2026-11-02T10:00:00Z'
 WHERE id=previous.id AND clinica_id=f.clinic_id AND paciente_id=f.patient_id AND updated_at=previous.updated_at;
 GET DIAGNOSTICS n=ROW_COUNT;IF n<>1 THEN RAISE EXCEPTION 'Confirmed append did not update one row';END IF;
 UPDATE public.historias_clinicas SET evoluciones='[]'::jsonb WHERE id=previous.id AND clinica_id=f.clinic_id AND updated_at=previous.updated_at;
 GET DIAGNOSTICS n=ROW_COUNT;IF n<>0 THEN RAISE EXCEPTION 'Stale timestamp overwrote history';END IF;
 UPDATE public.historias_clinicas SET motivo='Cambio ficticio de ficha',updated_at='2026-11-03T10:00:00Z' WHERE id=previous.id AND clinica_id=f.clinic_id;
 IF (SELECT jsonb_array_length(evoluciones) FROM public.historias_clinicas WHERE id=previous.id)<>2 THEN RAISE EXCEPTION 'Clinical form save erased evolutions';END IF;
END $test$;
RESET ROLE;
SELECT 'PASS: fisio append confirmed, stale write rejected, clinical fields preserve evolutions' AS result;
ROLLBACK;