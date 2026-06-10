create table if not exists historias_clinicas (
  id bigint generated always as identity primary key,
  paciente_id bigint references pacientes(id) on delete cascade,
  motivo text,
  exploracion text,
  diagnostico text,
  objetivos text,
  ejercicios text,
  evoluciones jsonb default '[]'::jsonb,
  updated_at timestamp with time zone default now(),
  created_at timestamp with time zone default now()
);

alter table historias_clinicas enable row level security;

drop policy if exists "permitir lectura historias" on historias_clinicas;
drop policy if exists "permitir insertar historias" on historias_clinicas;
drop policy if exists "permitir actualizar historias" on historias_clinicas;
drop policy if exists "permitir borrar historias" on historias_clinicas;

create policy "permitir lectura historias" on historias_clinicas for select using (true);
create policy "permitir insertar historias" on historias_clinicas for insert with check (true);
create policy "permitir actualizar historias" on historias_clinicas for update using (true);
create policy "permitir borrar historias" on historias_clinicas for delete using (true);
