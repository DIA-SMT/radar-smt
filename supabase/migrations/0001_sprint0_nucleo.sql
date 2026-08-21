-- ============================================================
-- RADAR · Sprint 0 — Núcleo del esquema
-- Protocolo RADAR v1.0 · E3.0 §4, §8
-- Reglas estructurales (§4.3): sin columnas de adscripción política,
-- sin geolocalización de individuos, sin biometría, auditoría append-only.
-- ============================================================

create extension if not exists pgcrypto;

-- ── Enums ───────────────────────────────────────────────────
create type rol_radar as enum (
  'presidencia',
  'coordinacion_general',
  'analisis_digital',
  'prensa_despliegue',
  'asuntos_juridicos',
  'proteccion_personas',
  'ciberseguridad',
  'secretaria_actas',
  'auditor',
  'agente_municipal'
);

create type codigo_incidente as enum (
  'A1','A2','A3','A4',
  'B1','B2','B3','B4','B5',
  'C1','C2','C3','C4','C5','C6','C7',
  'D1','D2',
  'E1','E2','E3'
);

create type estado_incidente as enum (
  'registrado','clasificado','evaluado','decidido','en_accion','cerrado'
);

create type nivel_intervencion as enum ('N0','N1','N2','N3','N4','N5');

create type estado_nivel as enum ('activo','suspendido','cerrado');

create type nivel_evidencia as enum ('E1','E2','E3','E4','E5','E6');

create type banda_irs as enum ('baja','media','alta','critica');

create type tipo_evaluacion as enum ('IRS','IRH');

create type veredicto_ia as enum ('aceptada','modificada','rechazada');

create type estado_accion as enum (
  'borrador','pendiente_autorizacion','autorizada','en_ejecucion','completada','cancelada'
);

-- ── Perfiles (extiende auth.users) ──────────────────────────
create table perfil (
  id          uuid primary key references auth.users(id) on delete cascade,
  nombre      text not null,
  rol         rol_radar not null default 'agente_municipal',
  area        text,
  activo      boolean not null default true,
  creado_en   timestamptz not null default now()
);

-- ── Incidentes ──────────────────────────────────────────────
create table incidente (
  id                  uuid primary key default gen_random_uuid(),
  numero              bigint generated always as identity unique,
  titulo              text not null,
  descripcion         text not null,
  origen              text not null default 'manual', -- manual | formulario_abierto
  codigo_primario     codigo_incidente,
  codigos_secundarios codigo_incidente[] not null default '{}',
  estado              estado_incidente not null default 'registrado',
  riesgo_personal_provisorio boolean not null default false, -- casilla del formulario abierto (§5.5)
  reportado_por       uuid references perfil(id),
  creado_en           timestamptz not null default now(),
  actualizado_en      timestamptz not null default now(),
  constraint max_dos_secundarios check (cardinality(codigos_secundarios) <= 2)
);

-- Reclasificar siempre es posible y queda registrado con su motivo (§6.3 regla 4)
create table reclasificacion (
  id             uuid primary key default gen_random_uuid(),
  incidente_id   uuid not null references incidente(id) on delete cascade,
  codigo_anterior codigo_incidente,
  codigo_nuevo   codigo_incidente not null,
  motivo         text not null check (length(motivo) >= 20),
  realizada_por  uuid not null references perfil(id),
  creado_en      timestamptz not null default now()
);

-- ── Evaluaciones IRS / IRH ──────────────────────────────────
-- Vector jsonb: [{dim, valor 0-4, fundamento, nivel_evidencia, datos_considerados, faltantes}]
-- IRS e IRH son independientes. Nunca se promedian entre sí (§7 protocolo).
create table evaluacion (
  id            uuid primary key default gen_random_uuid(),
  incidente_id  uuid not null references incidente(id) on delete cascade,
  tipo          tipo_evaluacion not null,
  vector        jsonb not null,
  puntaje       numeric(5,2), -- solo IRS: 0-100 ponderado. IRH no se agrega.
  banda         banda_irs,    -- solo IRS
  reglas_duras_disparadas text[] not null default '{}',
  evaluada_por  uuid not null references perfil(id),
  version       smallint not null default 1,
  creado_en     timestamptz not null default now()
);

-- ── Decisión (grilla + 13 preguntas) ────────────────────────
create table decision (
  id                    uuid primary key default gen_random_uuid(),
  incidente_id          uuid not null references incidente(id) on delete cascade,
  decision_adoptada     text not null, -- incluida la decisión de no responder
  fundamento            text not null check (length(fundamento) >= 40),
  coincide_con_grilla   boolean not null,
  trece_preguntas       jsonb, -- obligatorias si habilita N2+; {n, pregunta, respuesta, propuesta_ia_sin_editar}
  decidida_por          uuid not null references perfil(id),
  creado_en             timestamptz not null default now()
);

-- ── Niveles de intervención: carriles paralelos ─────────────
create table nivel_activacion (
  id            uuid primary key default gen_random_uuid(),
  incidente_id  uuid not null references incidente(id) on delete cascade,
  nivel         nivel_intervencion not null,
  estado        estado_nivel not null default 'activo',
  motivo_suspension text, -- el carril suspendido con motivo visible vale tanto como los activos (§6.2)
  conduce       uuid references perfil(id),
  activado_en   timestamptz not null default now(),
  vence_en      timestamptz,
  cerrado_en    timestamptz,
  unique (incidente_id, nivel),
  constraint suspension_con_motivo check (estado <> 'suspendido' or motivo_suspension is not null)
);

-- ── Acciones coordinadas (§6.1) ─────────────────────────────
create table accion_coordinada (
  id                uuid primary key default gen_random_uuid(),
  incidente_id      uuid not null references incidente(id) on delete cascade,
  nivel             nivel_intervencion not null,
  objetivo          text not null constraint objetivo_no_trivial check (length(objetivo) >= 40),
  publico_destino   text not null, -- catálogo cerrado validado en aplicación
  indicador_exito   text not null,
  ventana_inicio    timestamptz not null,
  ventana_fin       timestamptz not null,
  responsable_unico uuid not null references perfil(id), -- una persona, no un área
  autorizada_por    uuid references perfil(id),
  autorizada_en     timestamptz,
  estado            estado_accion not null default 'borrador',
  creado_en         timestamptz not null default now(),
  constraint ventana_coherente check (ventana_fin > ventana_inicio)
);

-- ── Evidencia: hash y sellado en la ingesta, no al denunciar (P9) ──
create table evidencia (
  id              uuid primary key default gen_random_uuid(),
  incidente_id    uuid not null references incidente(id) on delete cascade,
  descripcion     text not null,
  url_origen      text,
  hash_sha256     text not null,
  nivel           nivel_evidencia not null,
  storage_path    text, -- bucket privado; URLs firmadas de vida corta
  metadatos       jsonb not null default '{}'::jsonb,
  capturada_por   uuid not null references perfil(id),
  capturada_en    timestamptz not null default now()
);

-- ── Trazabilidad de IA (§7.8) ───────────────────────────────
create table version_prompt (
  hash        text primary key,
  agente      text not null, -- clasificador | evaluador | estratega | redactor | auditor
  contenido   text not null,
  vigente     boolean not null default true,
  creado_en   timestamptz not null default now()
);

create table solicitud_ia (
  id                uuid primary key default gen_random_uuid(),
  incidente_id      uuid references incidente(id),
  agente            text not null,
  prompt_version    text not null references version_prompt(hash),
  payload_enviado   jsonb not null, -- ya seudonimizado; verificado sin PII
  respuesta_cruda   jsonb,
  modelo_efectivo   text,
  tokens_in         integer,
  tokens_out        integer,
  costo_usd         numeric(10,5),
  latencia_ms       integer,
  veredicto_humano  veredicto_ia,
  motivo_rechazo    text,
  creado_en         timestamptz not null default now()
);

-- ── Auditoría inmutable (P8, P15) ───────────────────────────
create table registro_auditoria (
  id          bigint generated always as identity primary key,
  actor       uuid,
  accion      text not null,     -- INSERT | UPDATE | DELETE
  tabla       text not null,
  registro_id text,
  detalle     jsonb,
  creado_en   timestamptz not null default now()
);

-- Append-only por permisos y por trigger: falla aun con credencial de aplicación.
revoke update, delete on registro_auditoria from anon, authenticated;

create or replace function fn_auditoria_inmutable()
returns trigger language plpgsql as $$
begin
  raise exception 'registro_auditoria es append-only (P15)';
end $$;

create trigger trg_auditoria_inmutable
  before update or delete on registro_auditoria
  for each row execute function fn_auditoria_inmutable();

-- Toda mutación sensible escribe auditoría en la misma transacción (P8).
create or replace function fn_auditar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into registro_auditoria (actor, accion, tabla, registro_id, detalle)
  values (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    coalesce((to_jsonb(coalesce(NEW, OLD)) ->> 'id'), ''),
    case when TG_OP = 'DELETE' then to_jsonb(OLD) else to_jsonb(NEW) end
  );
  return coalesce(NEW, OLD);
end $$;

create trigger trg_auditar_incidente        after insert or update or delete on incidente         for each row execute function fn_auditar();
create trigger trg_auditar_evaluacion       after insert or update or delete on evaluacion        for each row execute function fn_auditar();
create trigger trg_auditar_decision         after insert or update or delete on decision          for each row execute function fn_auditar();
create trigger trg_auditar_nivel            after insert or update or delete on nivel_activacion  for each row execute function fn_auditar();
create trigger trg_auditar_accion           after insert or update or delete on accion_coordinada for each row execute function fn_auditar();
create trigger trg_auditar_evidencia        after insert or update or delete on evidencia         for each row execute function fn_auditar();
create trigger trg_auditar_reclasificacion  after insert on reclasificacion                       for each row execute function fn_auditar();
create trigger trg_auditar_solicitud_ia     after insert or update on solicitud_ia                for each row execute function fn_auditar();

-- ── RLS ─────────────────────────────────────────────────────
alter table perfil             enable row level security;
alter table incidente          enable row level security;
alter table reclasificacion    enable row level security;
alter table evaluacion         enable row level security;
alter table decision           enable row level security;
alter table nivel_activacion   enable row level security;
alter table accion_coordinada  enable row level security;
alter table evidencia          enable row level security;
alter table version_prompt     enable row level security;
alter table solicitud_ia       enable row level security;
alter table registro_auditoria enable row level security;

create or replace function fn_rol_actual()
returns rol_radar
language sql stable security definer
set search_path = public
as $$
  select rol from perfil where id = auth.uid() and activo
$$;

-- Perfil: cada quien ve el suyo; los roles del comité ven todos.
create policy perfil_select_propio on perfil for select
  using (id = auth.uid() or fn_rol_actual() is distinct from 'agente_municipal');

create policy perfil_update_propio on perfil for update
  using (id = auth.uid()) with check (id = auth.uid() and rol = (select rol from perfil p where p.id = auth.uid()));

-- Incidentes: el comité opera; el agente municipal solo reporta y ve lo propio.
create policy incidente_select_comite on incidente for select
  using (fn_rol_actual() is distinct from 'agente_municipal' or reportado_por = auth.uid());

create policy incidente_insert_autenticado on incidente for insert
  with check (auth.uid() is not null);

create policy incidente_update_comite on incidente for update
  using (fn_rol_actual() in ('coordinacion_general','analisis_digital','asuntos_juridicos','proteccion_personas','ciberseguridad','presidencia'));

-- Tablas operativas: solo roles del comité.
create policy op_select on reclasificacion for select using (fn_rol_actual() is distinct from 'agente_municipal');
create policy op_insert on reclasificacion for insert with check (fn_rol_actual() is distinct from 'agente_municipal');

create policy eval_select on evaluacion for select using (fn_rol_actual() is distinct from 'agente_municipal');
create policy eval_insert on evaluacion for insert with check (fn_rol_actual() is distinct from 'agente_municipal');

create policy dec_select on decision for select using (fn_rol_actual() is distinct from 'agente_municipal');
create policy dec_insert on decision for insert with check (fn_rol_actual() in ('coordinacion_general','presidencia','analisis_digital'));

create policy niv_select on nivel_activacion for select using (fn_rol_actual() is distinct from 'agente_municipal');
create policy niv_all on nivel_activacion for all using (fn_rol_actual() in ('coordinacion_general','presidencia','proteccion_personas','asuntos_juridicos','ciberseguridad','analisis_digital'));

create policy acc_select on accion_coordinada for select using (fn_rol_actual() is distinct from 'agente_municipal');
create policy acc_all on accion_coordinada for all using (fn_rol_actual() in ('coordinacion_general','presidencia','proteccion_personas','asuntos_juridicos','ciberseguridad','analisis_digital','prensa_despliegue'));

create policy evid_select on evidencia for select using (fn_rol_actual() in ('analisis_digital','asuntos_juridicos','coordinacion_general','presidencia','auditor'));
create policy evid_insert on evidencia for insert with check (fn_rol_actual() in ('analisis_digital','asuntos_juridicos'));

create policy prompt_select on version_prompt for select using (auth.uid() is not null);

create policy ia_select on solicitud_ia for select using (fn_rol_actual() is distinct from 'agente_municipal');

-- Auditoría: lectura exclusiva del rol auditor (§10 API).
create policy audit_select_auditor on registro_auditoria for select
  using (fn_rol_actual() = 'auditor');

-- ── Índices ─────────────────────────────────────────────────
create index idx_incidente_estado   on incidente (estado);
create index idx_incidente_codigo   on incidente (codigo_primario);
create index idx_evaluacion_inc     on evaluacion (incidente_id, tipo);
create index idx_nivel_inc          on nivel_activacion (incidente_id);
create index idx_accion_inc         on accion_coordinada (incidente_id);
create index idx_evidencia_inc      on evidencia (incidente_id);
create index idx_auditoria_tabla    on registro_auditoria (tabla, creado_en);
create index idx_solicitud_ia_inc   on solicitud_ia (incidente_id);
