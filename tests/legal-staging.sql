-- STAGING ONLY: synthetic documents and signatures; rollback all rows.
BEGIN;
CREATE TEMP TABLE amr_legal_probe AS SELECT gen_random_uuid() admin_uid,gen_random_uuid() fisio_uid,gen_random_uuid() reception_uid,gen_random_uuid() supervisor_uid,NULL::bigint clinic_id,NULL::bigint patient_id;
DO $$ DECLARE c bigint;p bigint;f record;BEGIN
 INSERT INTO public.clinicas(nombre) VALUES('CLINICA FICTICIA FIRMAS') RETURNING id INTO c;
 INSERT INTO public.pacientes(clinica_id,nombre) VALUES(c,'PACIENTE FICTICIO FIRMAS') RETURNING id INTO p;
 UPDATE amr_legal_probe SET clinic_id=c,patient_id=p;
 SELECT * INTO f FROM amr_legal_probe;
 INSERT INTO public.usuarios_clinica(auth_user_id,clinica_id,rol,activo) VALUES(f.admin_uid,c,'admin',true),(f.fisio_uid,c,'fisio',true),(f.reception_uid,c,'recepcion',true),(f.supervisor_uid,c,'supervisor',true);
END $$;
GRANT SELECT ON amr_legal_probe TO authenticated;
SET LOCAL ROLE authenticated;
DO $$ DECLARE f record;u uuid;d public.consentimientos%ROWTYPE;s public.firmas_sesiones%ROWTYPE;BEGIN
 SELECT * INTO f FROM amr_legal_probe;
 FOREACH u IN ARRAY ARRAY[f.admin_uid,f.fisio_uid] LOOP
  PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
  INSERT INTO public.consentimientos(clinica_id,paciente_id,tipo,profesional,centro,notas,firma,aceptado,fecha) VALUES(f.clinic_id,f.patient_id,'rgpd','PROFESIONAL FICTICIO','CENTRO FICTICIO','NOTAS FICTICIAS','data:image/png;base64,FICTICIA',true,now()) RETURNING * INTO d;
  IF d.id IS NULL OR d.firma<>'data:image/png;base64,FICTICIA' OR NOT d.aceptado THEN RAISE EXCEPTION 'Consent confirmation mismatch';END IF;
  IF NOT EXISTS(SELECT 1 FROM public.consentimientos WHERE id=d.id AND clinica_id=f.clinic_id) THEN RAISE EXCEPTION 'Consent not persisted';END IF;
  INSERT INTO public.firmas_sesiones(clinica_id,paciente_id,fecha,hora,motivo,importe,notas,firma,confirmado) VALUES(f.clinic_id,f.patient_id,current_date,'','Firma ficticia',0,'NOTAS FICTICIAS','data:image/png;base64,FICTICIA',true) RETURNING * INTO s;
  IF s.id IS NULL OR s.firma<>'data:image/png;base64,FICTICIA' OR NOT s.confirmado THEN RAISE EXCEPTION 'Session confirmation mismatch';END IF;
  IF NOT EXISTS(SELECT 1 FROM public.firmas_sesiones WHERE id=s.id AND clinica_id=f.clinic_id) THEN RAISE EXCEPTION 'Session not persisted';END IF;
 END LOOP;
 FOREACH u IN ARRAY ARRAY[f.reception_uid,f.supervisor_uid] LOOP
  PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
  BEGIN INSERT INTO public.consentimientos(clinica_id,paciente_id,tipo) VALUES(f.clinic_id,f.patient_id,'rgpd');RAISE EXCEPTION 'Read-only role wrote consent';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
  BEGIN INSERT INTO public.firmas_sesiones(clinica_id,paciente_id,fecha) VALUES(f.clinic_id,f.patient_id,current_date);RAISE EXCEPTION 'Read-only role wrote signature';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 END LOOP;
END $$;
RESET ROLE;
SELECT 'PASS: admin/fisio consent and session INSERT RETURNING and persisted signatures; reception/supervisor writes denied' AS result;
ROLLBACK;
