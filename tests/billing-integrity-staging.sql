-- STAGING ONLY. Synthetic records; rollback all rows. Identity sequences may advance.
BEGIN;
CREATE TEMP TABLE amr_billing_probe AS SELECT gen_random_uuid() admin_uid,gen_random_uuid() reception_uid,gen_random_uuid() supervisor_uid,NULL::bigint clinic_a,NULL::bigint clinic_b,NULL::bigint patient_a,NULL::bigint patient_b;
DO $$ DECLARE ca bigint;cb bigint;pa bigint;pb bigint;f record;BEGIN
 INSERT INTO public.clinicas(nombre) VALUES('FACTURACION FICTICIA A') RETURNING id INTO ca;
 INSERT INTO public.clinicas(nombre) VALUES('FACTURACION FICTICIA B') RETURNING id INTO cb;
 INSERT INTO public.pacientes(clinica_id,nombre) VALUES(ca,'PACIENTE FACTURA FICTICIO A') RETURNING id INTO pa;
 INSERT INTO public.pacientes(clinica_id,nombre) VALUES(cb,'PACIENTE FACTURA FICTICIO B') RETURNING id INTO pb;
 UPDATE amr_billing_probe SET clinic_a=ca,clinic_b=cb,patient_a=pa,patient_b=pb;
 SELECT * INTO f FROM amr_billing_probe;
 INSERT INTO public.usuarios_clinica(auth_user_id,clinica_id,rol,activo) VALUES(f.admin_uid,ca,'admin',true),(f.reception_uid,ca,'recepcion',true),(f.supervisor_uid,ca,'supervisor',true);
END $$;
GRANT SELECT ON amr_billing_probe TO authenticated;
SET LOCAL ROLE authenticated;
DO $$ DECLARE f record;invoice public.facturas%ROWTYPE;u uuid;BEGIN
 SELECT * INTO f FROM amr_billing_probe;
 FOREACH u IN ARRAY ARRAY[f.admin_uid,f.reception_uid] LOOP
  PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
  INSERT INTO public.facturas(clinica_id,paciente_id,numero,fecha,concepto,cantidad,precio,total,datos_fiscales) VALUES(f.clinic_a,f.patient_a,'FICTICIA-'||u,'2026-11-06','Prueba ficticia',3,19.95,59.85,'{"receptor":{"nombre":"FORGED"}}'::jsonb) RETURNING * INTO invoice;
  IF invoice.datos_fiscales->'receptor'->>'nombre'<>'PACIENTE FACTURA FICTICIO A' OR invoice.datos_fiscales->'receptor' ? 'notas' THEN RAISE EXCEPTION 'Snapshot incorrect or contains clinical notes';END IF;
  BEGIN INSERT INTO public.facturas(clinica_id,paciente_id,numero) VALUES(f.clinic_a,f.patient_a,'  '||upper(invoice.numero)||'  ');RAISE EXCEPTION 'Duplicate number allowed';EXCEPTION WHEN unique_violation THEN NULL;END;
  BEGIN UPDATE public.facturas SET datos_fiscales='{}' WHERE id=invoice.id;RAISE EXCEPTION 'Fiscal snapshot mutable';EXCEPTION WHEN check_violation THEN NULL;END;
  BEGIN UPDATE public.facturas SET numero='CHANGED' WHERE id=invoice.id;RAISE EXCEPTION 'Saved invoice number mutable';EXCEPTION WHEN check_violation THEN NULL;END;
  BEGIN INSERT INTO public.facturas(clinica_id,paciente_id,numero) VALUES(f.clinic_a,f.patient_a,'  ');RAISE EXCEPTION 'Blank number allowed';EXCEPTION WHEN check_violation THEN NULL;END;
  IF invoice.id IS NULL OR invoice.total<>59.85 OR invoice.fecha<>'2026-11-06'::date THEN RAISE EXCEPTION 'Insert confirmation mismatch';END IF;
  IF NOT EXISTS(SELECT 1 FROM public.facturas WHERE id=invoice.id AND clinica_id=f.clinic_a AND numero='FICTICIA-'||u) THEN RAISE EXCEPTION 'Persisted invoice not found';END IF;
  BEGIN INSERT INTO public.facturas(clinica_id,paciente_id,numero) VALUES(f.clinic_b,f.patient_b,'FORBIDDEN');RAISE EXCEPTION 'Cross clinic write allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
  BEGIN INSERT INTO public.facturas(clinica_id,paciente_id,numero) VALUES(f.clinic_a,f.patient_b,'FORBIDDEN PATIENT');RAISE EXCEPTION 'Cross clinic patient allowed';EXCEPTION WHEN foreign_key_violation THEN NULL;END;
 END LOOP;
END $$;
RESET ROLE;
UPDATE public.pacientes SET nombre='CAMBIADO FICTICIO',nif='CAMBIADO',direccion='CAMBIADA' WHERE id=(SELECT patient_a FROM amr_billing_probe);
UPDATE public.clinicas SET nombre='EMISOR CAMBIADO',cif='CAMBIADO' WHERE id=(SELECT clinic_a FROM amr_billing_probe);
SET LOCAL ROLE authenticated;
DO $$ DECLARE f record;BEGIN
 SELECT * INTO f FROM amr_billing_probe;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',f.supervisor_uid,'role','authenticated')::text,true);
 IF EXISTS(SELECT 1 FROM public.facturas WHERE clinica_id=f.clinic_a AND (datos_fiscales->'receptor'->>'nombre'<>'PACIENTE FACTURA FICTICIO A' OR datos_fiscales->'emisor'->>'comercial'='EMISOR CAMBIADO')) THEN RAISE EXCEPTION 'Snapshot changed with patient or clinic';END IF;
 IF (SELECT count(*) FROM public.facturas WHERE clinica_id=f.clinic_a)<>2 THEN RAISE EXCEPTION 'Supervisor list unavailable';END IF;
 BEGIN INSERT INTO public.facturas(clinica_id,paciente_id,numero) VALUES(f.clinic_a,f.patient_a,'FORBIDDEN SUPERVISOR');RAISE EXCEPTION 'Supervisor wrote invoice';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;
SELECT 'PASS: admin/reception INSERT RETURNING and persisted read; supervisor read only; cross-clinic and foreign patient denied' AS result;
ROLLBACK;
