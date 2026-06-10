-- AMR Clínicas PRO - Fase SaaS Multi-Clínica
create table if not exists clinicas (
  id bigint generated always as identity primary key,
  nombre text,
  logo text,
  color_principal text default '#14b8a6',
  direccion text,
  telefono text,
  email text,
  cif text,
  dominio text,
  created_at timestamptz default now()
);

create table if not exists usuarios_clinica (
  id bigint generated always as identity primary key,
  auth_user_id uuid,
  clinica_id bigint references clinicas(id) on delete cascade,
  rol text default 'fisio',
  nombre text,
  created_at timestamptz default now()
);

alter table pacientes add column if not exists clinica_id bigint references clinicas(id) on delete set null;
alter table citas add column if not exists clinica_id bigint references clinicas(id) on delete set null;
alter table historias_clinicas add column if not exists clinica_id bigint references clinicas(id) on delete set null;
alter table consentimientos add column if not exists clinica_id bigint references clinicas(id) on delete set null;
alter table firmas_sesiones add column if not exists clinica_id bigint references clinicas(id) on delete set null;
alter table facturas add column if not exists clinica_id bigint references clinicas(id) on delete set null;

insert into clinicas (nombre, telefono, email, direccion, cif, color_principal)
select 'AMR Clínicas de Fisioterapia','698344334','amrclinicasfisio@hotmail.com','Granada','74671815S','#14b8a6'
where not exists (select 1 from clinicas);

update pacientes set clinica_id=(select id from clinicas order by id limit 1) where clinica_id is null;
update citas set clinica_id=(select id from clinicas order by id limit 1) where clinica_id is null;
update historias_clinicas set clinica_id=(select id from clinicas order by id limit 1) where clinica_id is null;
update consentimientos set clinica_id=(select id from clinicas order by id limit 1) where clinica_id is null;
update firmas_sesiones set clinica_id=(select id from clinicas order by id limit 1) where clinica_id is null;
update facturas set clinica_id=(select id from clinicas order by id limit 1) where clinica_id is null;

alter table clinicas enable row level security;
alter table usuarios_clinica enable row level security;

drop policy if exists "permitir todo clinicas" on clinicas;
drop policy if exists "permitir todo usuarios clinica" on usuarios_clinica;

create policy "permitir todo clinicas" on clinicas for all using (true) with check (true);
create policy "permitir todo usuarios clinica" on usuarios_clinica for all using (true) with check (true);
