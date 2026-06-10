-- AMR Clínicas PRO - Usuarios y roles SaaS
-- Ejecutar después de supabase_multiclinica_saas.sql

alter table usuarios_clinica
add column if not exists activo boolean default true;

-- Para hacerte admin:
-- 1) Supabase > Authentication > Users
-- 2) Copia tu UUID
-- 3) Sustituye PEGAR_UUID_AQUI y ejecuta el INSERT

-- insert into usuarios_clinica (auth_user_id, clinica_id, rol, nombre, activo)
-- values ('PEGAR_UUID_AQUI', (select id from clinicas order by id limit 1), 'admin', 'Antonio Javier Martí Romero', true);

alter table usuarios_clinica enable row level security;

drop policy if exists "usuarios clinica lectura piloto" on usuarios_clinica;
drop policy if exists "usuarios clinica insertar piloto" on usuarios_clinica;
drop policy if exists "usuarios clinica actualizar piloto" on usuarios_clinica;
drop policy if exists "usuarios clinica borrar piloto" on usuarios_clinica;

create policy "usuarios clinica lectura piloto" on usuarios_clinica for select using (true);
create policy "usuarios clinica insertar piloto" on usuarios_clinica for insert with check (true);
create policy "usuarios clinica actualizar piloto" on usuarios_clinica for update using (true);
create policy "usuarios clinica borrar piloto" on usuarios_clinica for delete using (true);

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

create policy "logs lectura piloto" on logs_sistema for select using (true);
create policy "logs insertar piloto" on logs_sistema for insert with check (true);
