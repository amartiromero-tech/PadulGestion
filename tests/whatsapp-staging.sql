-- STAGING ONLY. Synthetic fixtures, no message provider; rollback all data.
BEGIN;
CREATE TEMP TABLE amr_wa_probe AS SELECT gen_random_uuid() admin_uid,gen_random_uuid() reception_uid,gen_random_uuid() supervisor_uid,NULL::bigint clinic_id,NULL::bigint other_clinic,NULL::bigint patient_id,NULL::bigint cita_id;
DO $$ DECLARE c bigint;b bigint;p bigint;ci bigint;t timestamp;f record;BEGIN
 INSERT INTO public.clinicas(nombre) VALUES('CLINICA FICTICIA WHATSAPP') RETURNING id INTO c;
 INSERT INTO public.clinicas(nombre) VALUES('OTRA CLINICA FICTICIA') RETURNING id INTO b;
 INSERT INTO public.pacientes(clinica_id,nombre,telefono,notas) VALUES(c,'PACIENTE FICTICIO','600000001','NOTA CLINICA QUE NO DEBE COPIARSE') RETURNING id INTO p;
 t:=(now()+interval '4 hours') AT TIME ZONE 'Europe/Madrid';
 INSERT INTO public.citas(clinica_id,paciente_id,fecha,hora,estado,motivo) VALUES(c,p,t::date,to_char(t,'HH24:MI'),'Confirmada','MOTIVO CLINICO QUE NO DEBE COPIARSE') RETURNING id INTO ci;
 INSERT INTO public.citas(clinica_id,paciente_id,fecha,hora,estado) VALUES(c,p,t::date,'INVALIDA','Confirmada'),(c,p,t::date,to_char(t,'HH24:MI'),'Cancelada'),(c,p,current_date-2,'10:00','Confirmada');
 UPDATE amr_wa_probe SET clinic_id=c,other_clinic=b,patient_id=p,cita_id=ci;
 SELECT * INTO f FROM amr_wa_probe;
 INSERT INTO public.usuarios_clinica(auth_user_id,clinica_id,rol,activo) VALUES(f.admin_uid,c,'admin',true),(f.reception_uid,c,'recepcion',true),(f.supervisor_uid,c,'supervisor',true);
END $$;
GRANT SELECT ON amr_wa_probe TO authenticated,anon;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM 1 FROM public.whatsapp_permisos;RAISE EXCEPTION 'Anon read allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.amr_whatsapp_simular(1);RAISE EXCEPTION 'Anon simulate allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
DO $$ DECLARE f record;a public.whatsapp_permisos;n integer;BEGIN
 SELECT * INTO f FROM amr_wa_probe;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',f.admin_uid,'role','authenticated')::text,true);
 IF public.amr_whatsapp_simular(f.clinic_id)<>0 THEN RAISE EXCEPTION 'No opt-in must produce zero reminders';END IF;
 SELECT * INTO a FROM public.amr_whatsapp_permiso(f.clinic_id,f.patient_id,true,'AUTORIZACION FICTICIA');
 IF NOT a.permitido OR a.telefono<>'34600000001' OR a.registrado_por<>f.admin_uid THEN RAISE EXCEPTION 'Permission capture failed';END IF;
 IF public.amr_whatsapp_simular(f.clinic_id)<>1 THEN RAISE EXCEPTION 'Eligible reminder missing';END IF;
 IF public.amr_whatsapp_simular(f.clinic_id)<>0 THEN RAISE EXCEPTION 'Duplicate simulation';END IF;
 IF EXISTS(SELECT 1 FROM public.whatsapp_recordatorios WHERE clinica_id=f.clinic_id AND (mensaje LIKE '%CLINICO%' OR estado<>'simulado' OR inicio-programado_para<>interval '24 hours')) THEN RAISE EXCEPTION 'Sensitive content or invalid reminder timing';END IF;
 PERFORM public.amr_whatsapp_permiso(f.clinic_id,f.patient_id,false,'RETIRADA FICTICIA');
 IF EXISTS(SELECT 1 FROM public.whatsapp_recordatorios WHERE clinica_id=f.clinic_id AND estado<>'cancelado') THEN RAISE EXCEPTION 'Withdrawal did not cancel';END IF;
 BEGIN PERFORM public.amr_whatsapp_simular(f.other_clinic);RAISE EXCEPTION 'Cross clinic simulation';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN INSERT INTO public.whatsapp_recordatorios(clinica_id,cita_id,paciente_id,inicio,programado_para,telefono,mensaje) VALUES(f.clinic_id,f.cita_id,f.patient_id,now(),now(),'34600000001','FORGED');RAISE EXCEPTION 'Direct write allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',f.reception_uid,'role','authenticated')::text,true);
 PERFORM public.amr_whatsapp_permiso(f.clinic_id,f.patient_id,true,'RECEPCION FICTICIA');
 BEGIN PERFORM public.amr_whatsapp_simular(f.clinic_id);RAISE EXCEPTION 'Reception simulation allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',f.supervisor_uid,'role','authenticated')::text,true);
 BEGIN PERFORM public.amr_whatsapp_permiso(f.clinic_id,f.patient_id,true,'FORGED');RAISE EXCEPTION 'Supervisor write allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;
UPDATE public.pacientes SET telefono='600000002' WHERE id=(SELECT patient_id FROM amr_wa_probe);
SET LOCAL ROLE authenticated;
DO $$ DECLARE f record;BEGIN
 SELECT * INTO f FROM amr_wa_probe;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',f.admin_uid,'role','authenticated')::text,true);
 IF public.amr_whatsapp_simular(f.clinic_id)<>0 THEN RAISE EXCEPTION 'New phone reused old opt-in';END IF;
 PERFORM public.amr_whatsapp_permiso(f.clinic_id,f.patient_id,true,'NUEVO TELEFONO FICTICIO');
 IF public.amr_whatsapp_simular(f.clinic_id)<>1 THEN RAISE EXCEPTION 'Reauthorized phone missing';END IF;
 IF (SELECT count(*) FROM public.whatsapp_recordatorios WHERE clinica_id=f.clinic_id)<>1 THEN RAISE EXCEPTION 'Reauthorization duplicated reminder';END IF;
END $$;
RESET ROLE;
UPDATE public.citas SET hora='INVALIDA' WHERE id=(SELECT cita_id FROM amr_wa_probe);
SET LOCAL ROLE authenticated;
DO $$ DECLARE f record;BEGIN
 SELECT * INTO f FROM amr_wa_probe;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',f.admin_uid,'role','authenticated')::text,true);
 PERFORM public.amr_whatsapp_simular(f.clinic_id);
 IF EXISTS(SELECT 1 FROM public.whatsapp_recordatorios WHERE clinica_id=f.clinic_id AND estado<>'cancelado') THEN RAISE EXCEPTION 'Invalid time did not invalidate reminder';END IF;
END $$;
RESET ROLE;
SELECT 'PASS: opt-in, phone binding, roles, isolation, no duplicates, cancellation, invalid times, no clinical content, no delivery' AS result;
ROLLBACK;