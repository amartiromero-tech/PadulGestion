-- STAGING ONLY: synthetic fixtures; every row is rolled back. Identity sequences may advance.
begin;
create temp table amr_test_fixture as select gen_random_uuid() admin_uid,gen_random_uuid() fisio_uid,gen_random_uuid() reception_uid,gen_random_uuid() supervisor_uid,gen_random_uuid() inactive_uid,gen_random_uuid() outsider_uid,null::bigint clinic_a,null::bigint clinic_b,null::bigint patient_a,null::bigint patient_b;
do $$ declare ca bigint; cb bigint; pa bigint; pb bigint; begin
insert into public.clinicas(nombre) values('PRUEBA SEGURIDAD A') returning id into ca;
insert into public.clinicas(nombre) values('PRUEBA SEGURIDAD B') returning id into cb;
insert into public.pacientes(clinica_id,nombre,notas) values(ca,'PACIENTE FICTICIO A','NOTA CLINICA FICTICIA') returning id into pa;
insert into public.pacientes(clinica_id,nombre,notas) values(cb,'PACIENTE FICTICIO B','NOTA PRIVADA FICTICIA') returning id into pb;
update amr_test_fixture set clinic_a=ca,clinic_b=cb,patient_a=pa,patient_b=pb;
end $$;
insert into public.usuarios_clinica(auth_user_id,clinica_id,rol,nombre,activo)
select admin_uid,clinic_a,'admin','ADMIN FICTICIO',true from amr_test_fixture union all
select fisio_uid,clinic_a,'fisio','FISIO FICTICIO',true from amr_test_fixture union all
select reception_uid,clinic_a,'recepcion','RECEPCION FICTICIA',true from amr_test_fixture union all
select supervisor_uid,clinic_a,'supervisor','SUPERVISOR FICTICIO',true from amr_test_fixture union all
select inactive_uid,clinic_a,'admin','INACTIVO FICTICIO',false from amr_test_fixture union all
select outsider_uid,clinic_b,'admin','OTRA CLINICA FICTICIA',true from amr_test_fixture;
create temp table amr_test_results(test text);
grant select on amr_test_fixture to authenticated,anon;
grant insert on amr_test_results to authenticated,anon;
set local role anon;
do $$ declare t text; begin
foreach t in array array['pacientes','citas','historias_clinicas','consentimientos','firmas_sesiones','facturas','usuarios_clinica','clinicas','logs_sistema'] loop
begin execute format('select 1 from public.%I limit 0',t); raise exception 'Anon has access to %',t;
exception when insufficient_privilege then null; end;
end loop;
insert into amr_test_results values('anon: all 9 tables denied');
end $$;
reset role;
set local role authenticated;
do $$ declare f record; n int; begin select * into f from amr_test_fixture;
perform set_config('request.jwt.claims',json_build_object('sub',f.admin_uid,'role','authenticated')::text,true);
if not exists(select 1 from public.pacientes where id=f.patient_a) then raise exception 'Admin locked out'; end if;
if exists(select 1 from public.pacientes where id=f.patient_b) then raise exception 'Cross clinic read'; end if;
insert into public.citas(clinica_id,paciente_id,fecha,hora) values(f.clinic_a,f.patient_a,current_date,'09:00');
update public.pacientes set telefono='000000000' where id=f.patient_a;
get diagnostics n=row_count; if n<>1 then raise exception 'Admin update failed';end if;
begin insert into public.citas(clinica_id,paciente_id,fecha,hora) values(f.clinic_b,f.patient_b,current_date,'09:00');raise exception 'Cross clinic insert';exception when insufficient_privilege then null;end;
begin insert into public.citas(clinica_id,paciente_id,fecha,hora) values(f.clinic_a,f.patient_b,current_date,'09:00');raise exception 'Foreign patient insert';exception when foreign_key_violation then null;end;
begin update public.pacientes set clinica_id=f.clinic_b where id=f.patient_a;raise exception 'Moved patient clinic';exception when insufficient_privilege then null;end;
update public.usuarios_clinica set activo=false where auth_user_id=f.admin_uid;
get diagnostics n=row_count; if n<>0 then raise exception 'Self admin disabled'; end if;
if not exists(select 1 from public.logs_sistema where clinica_id=f.clinic_a and tabla='pacientes') then raise exception 'Audit missing';end if;
begin update public.logs_sistema set detalle='forged' where clinica_id=f.clinic_a;raise exception 'Audit writable';exception when insufficient_privilege then null;end;
begin delete from public.logs_sistema where clinica_id=f.clinic_a;raise exception 'Audit deletable';exception when insufficient_privilege then null;end;
insert into amr_test_results values('admin: own clinic read/create/update, cross clinic denied, identity immutable, self protection, audit read-only');
end $$;
do $$ declare f record; result jsonb; begin select * into f from amr_test_fixture;
perform set_config('request.jwt.claims',json_build_object('sub',f.reception_uid,'role','authenticated')::text,true);
if exists(select 1 from public.pacientes where id=f.patient_a) then raise exception 'Reception sees clinical notes directly';end if;
if exists(select 1 from public.historias_clinicas where clinica_id=f.clinic_a) then raise exception 'Reception reads history';end if;
result=public.amr_recepcion_pacientes(f.clinic_a,'listar');
if jsonb_array_length(result)<>1 or result->0 ? 'notas' then raise exception 'Reception patient projection';end if;
result=public.amr_recepcion_citas(f.clinic_a,'listar');
if jsonb_array_length(result)<>1 or result->0 ? 'motivo' then raise exception 'Reception appointment projection';end if;
result=public.amr_recepcion_pacientes(f.clinic_a,'crear',jsonb_build_object('nombre','ALTA FICTICIA','telefono','000'));
if result ? 'notas' or not result ? 'id' then raise exception 'Reception creation';end if;
begin perform public.amr_recepcion_pacientes(f.clinic_a,'crear','{"nombre":"FAKE","notas":"forbidden"}');raise exception 'Reception can write notes';exception when insufficient_privilege then null;end;
begin perform public.amr_recepcion_pacientes(f.clinic_b,'listar');raise exception 'Reception other clinic RPC';exception when insufficient_privilege then null;end;
begin insert into public.usuarios_clinica(auth_user_id,clinica_id,rol) values(gen_random_uuid(),f.clinic_a,'admin');raise exception 'Reception admin escalation';exception when insufficient_privilege then null;end;
insert into amr_test_results values('reception: limited RPC read/create, clinical fields denied, foreign clinic denied, cannot self-promote');
end $$;
do $$ declare f record; n int; begin select * into f from amr_test_fixture;
perform set_config('request.jwt.claims',json_build_object('sub',f.fisio_uid,'role','authenticated')::text,true);
if not exists(select 1 from public.pacientes where id=f.patient_a) then raise exception 'Fisio patient denied';end if;
insert into public.historias_clinicas(clinica_id,paciente_id,motivo) values(f.clinic_a,f.patient_a,'HISTORIA FICTICIA');
if exists(select 1 from public.facturas where clinica_id=f.clinic_a) then raise exception 'Fisio finance access';end if;
delete from public.citas where clinica_id=f.clinic_a;
get diagnostics n=row_count; if n<>0 then raise exception 'Fisio delete allowed';end if;
insert into amr_test_results values('fisio: clinical write permitted, appointment deletion denied');
perform set_config('request.jwt.claims',json_build_object('sub',f.supervisor_uid,'role','authenticated')::text,true);
if not exists(select 1 from public.pacientes where id=f.patient_a) then raise exception 'Supervisor read denied';end if;
update public.pacientes set nombre='FORGED' where id=f.patient_a;get diagnostics n=row_count;if n<>0 then raise exception 'Supervisor write';end if;
insert into amr_test_results values('supervisor: read permitted, patient update denied');
perform set_config('request.jwt.claims',json_build_object('sub',f.inactive_uid,'role','authenticated')::text,true);
if exists(select 1 from public.pacientes where id=f.patient_a) then raise exception 'Inactive user access';end if;
insert into amr_test_results values('inactive: no patient access');
perform set_config('request.jwt.claims',json_build_object('sub',f.outsider_uid,'role','authenticated')::text,true);
if exists(select 1 from public.pacientes where id=f.patient_a) then raise exception 'Foreign admin access';end if;
if not exists(select 1 from public.pacientes where id=f.patient_b) then raise exception 'Foreign admin own clinic denied';end if;
insert into amr_test_results values('second clinic admin: isolation verified');
perform set_config('request.jwt.claims',json_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
if exists(select 1 from public.pacientes where id=f.patient_a) then raise exception 'Unassigned user access';end if;
insert into amr_test_results values('authenticated without membership: denied');
end $$;
reset role;
select jsonb_agg(test) as passed from amr_test_results;
rollback;
