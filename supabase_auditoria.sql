-- AMR Clínicas PRO - Auditoría
-- Ejecutar después de supabase_usuarios_roles.sql

alter table usuarios_clinica add column if not exists activo boolean default true;

create table if not exists logs_sistema (
  id bigint generated always as identity primary key,
  clinica_id bigint references clinicas(id) on delete set null,
  usuario uuid,
  accion text,
  tabla text,
  registro_id text,
  detalle text,
  created_at timestamptz default now()
);

alter table logs_sistema enable row level security;

drop policy if exists "logs lectura piloto" on logs_sistema;
drop policy if exists "logs insertar piloto" on logs_sistema;
drop policy if exists "logs actualizar piloto" on logs_sistema;
drop policy if exists "logs borrar piloto" on logs_sistema;

create policy "logs lectura piloto" on logs_sistema for select using (true);
create policy "logs insertar piloto" on logs_sistema for insert with check (true);
create policy "logs actualizar piloto" on logs_sistema for update using (true);
create policy "logs borrar piloto" on logs_sistema for delete using (true);
