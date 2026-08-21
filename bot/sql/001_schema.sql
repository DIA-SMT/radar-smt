-- ═══════════════════════════════════════════════════════════════════
-- RADAR · Bot de reporte, alerta y escalamiento
-- Esquema 001 — subconjunto operativo del modelo del documento rector
-- ═══════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Tipos ──────────────────────────────────────────────────────────

CREATE TYPE rol_radar AS ENUM (
  'agente',                 -- cualquier trabajador municipal que reporta
  'guardian',               -- observador asignado a superficies/temas
  'analista',
  'coordinador_guardia',
  'coordinador_crisis',
  'juridico',
  'proteccion_humana',
  'ciberseguridad',
  'autoridad_superior',
  'auditor',
  'persona_afectada'
);

CREATE TYPE nivel_intervencion AS ENUM ('N0','N1','N2','N3','N4','N5');

CREATE TYPE prioridad_notif AS ENUM ('informativa','operativa','urgente','critica');

CREATE TYPE estado_notif AS ENUM (
  'encolada','enviada','acusada','vencida','fallida'
);

CREATE TYPE estado_incidente AS ENUM (
  'registrado','en_evaluacion','en_accion','en_seguimiento','cerrado'
);

-- ── Usuarios y vinculación con Telegram ────────────────────────────
-- No hay alta abierta: un administrador crea el usuario con un código
-- de vinculación de un solo uso. El bot nunca acepta desconocidos.

CREATE TABLE usuario (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre            text NOT NULL,
  area              text,
  roles             rol_radar[] NOT NULL DEFAULT '{agente}',
  telegram_id       bigint UNIQUE,
  telegram_chat_id  bigint,
  codigo_vinculacion text UNIQUE,
  vinculado_en      timestamptz,
  activo            boolean NOT NULL DEFAULT true,
  -- Modo protegido: si es true, jamás recibe contenido, solo estado.
  modo_protegido    boolean NOT NULL DEFAULT false,
  creado_en         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_usuario_roles ON usuario USING gin (roles);

-- ── Guardias ───────────────────────────────────────────────────────

CREATE TABLE guardia (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rol          rol_radar NOT NULL,
  usuario_id   uuid NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  es_suplente  boolean NOT NULL DEFAULT false,
  desde        timestamptz NOT NULL,
  hasta        timestamptz NOT NULL,
  CONSTRAINT ventana_valida CHECK (hasta > desde)
);

CREATE INDEX idx_guardia_activa ON guardia (rol, desde, hasta);

-- ── Incidentes ─────────────────────────────────────────────────────

CREATE TABLE incidente (
  id                 bigserial PRIMARY KEY,
  titulo             text NOT NULL,
  descripcion        text NOT NULL,
  superficie         text,                       -- dónde se observó
  afectado_texto     text,                       -- a quién afecta (texto libre)
  persona_afectada_id uuid REFERENCES usuario(id),
  categoria          text,                       -- A1..E3, confirmada por persona
  categoria_sugerida text,                       -- propuesta automática/IA
  bandera_riesgo     boolean NOT NULL DEFAULT false, -- casilla amenaza/datos
  nivel              nivel_intervencion NOT NULL DEFAULT 'N0',
  estado             estado_incidente NOT NULL DEFAULT 'registrado',
  reportado_por      uuid REFERENCES usuario(id),
  responsable_id     uuid REFERENCES usuario(id),
  origen             text NOT NULL DEFAULT 'telegram',
  creado_en          timestamptz NOT NULL DEFAULT now(),
  actualizado_en     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_incidente_estado ON incidente (estado, nivel);

-- ── Evidencia ──────────────────────────────────────────────────────
-- Hash y sellado en la INGESTA, no al decidir denunciar (P9).

CREATE TABLE evidencia (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id   bigint NOT NULL REFERENCES incidente(id) ON DELETE CASCADE,
  tipo           text NOT NULL,                  -- captura | enlace | texto
  hash_sha256    text NOT NULL,
  ruta_archivo   text,
  url_origen     text,
  metadatos      jsonb NOT NULL DEFAULT '{}'::jsonb,
  aportada_por   uuid REFERENCES usuario(id),
  sellada_en     timestamptz NOT NULL DEFAULT now()
);

-- ── Notificaciones ─────────────────────────────────────────────────
-- El cuerpo se arma desde plantilla; jamás transporta contenido agresivo.

CREATE TABLE notificacion (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id    bigint REFERENCES incidente(id) ON DELETE CASCADE,
  destinatario_id uuid NOT NULL REFERENCES usuario(id),
  plantilla       text NOT NULL,
  variables       jsonb NOT NULL DEFAULT '{}'::jsonb,
  prioridad       prioridad_notif NOT NULL,
  requiere_acuse  boolean NOT NULL DEFAULT false,
  paso            smallint NOT NULL DEFAULT 0,   -- escalón de la cadena
  vence_en        timestamptz,
  estado          estado_notif NOT NULL DEFAULT 'encolada',
  telegram_msg_id bigint,
  clave_idem      text UNIQUE,                   -- idempotencia de envío
  enviada_en      timestamptz,
  acusada_en      timestamptz,
  acusada_por     uuid REFERENCES usuario(id),
  creada_en       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT acuse_coherente
    CHECK (NOT requiere_acuse OR vence_en IS NOT NULL)
);

CREATE INDEX idx_notif_pendientes
  ON notificacion (estado, vence_en)
  WHERE requiere_acuse;

-- ── Política de escalamiento ───────────────────────────────────────

CREATE TABLE politica_escalamiento (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plantilla      text NOT NULL,
  paso           smallint NOT NULL,
  rol_objetivo   rol_radar NOT NULL,
  espera_minutos smallint NOT NULL,
  UNIQUE (plantilla, paso)
);

-- ── Canal protegido con la persona afectada ────────────────────────

CREATE TABLE mensaje_caso (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id       bigint NOT NULL REFERENCES incidente(id) ON DELETE CASCADE,
  persona_id         uuid NOT NULL REFERENCES usuario(id),
  autor_id           uuid REFERENCES usuario(id),  -- NULL = la propia persona
  cuerpo_cifrado     bytea NOT NULL,
  contiene_evidencia boolean NOT NULL DEFAULT false,
  creado_en          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE checkin (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id bigint REFERENCES incidente(id) ON DELETE CASCADE,
  persona_id   uuid NOT NULL REFERENCES usuario(id),
  estado       text NOT NULL,   -- bien | necesito_hablar | prefiero_no_responder
  creado_en    timestamptz NOT NULL DEFAULT now()
);

-- ── Auditoría append-only ──────────────────────────────────────────

CREATE TABLE registro_auditoria (
  id           bigserial PRIMARY KEY,
  actor_id     uuid REFERENCES usuario(id),
  accion       text NOT NULL,
  entidad      text,
  entidad_id   text,
  detalle      jsonb NOT NULL DEFAULT '{}'::jsonb,
  creado_en    timestamptz NOT NULL DEFAULT now()
);

-- La inmutabilidad no se confía a la aplicación: se impone en la base.
CREATE OR REPLACE FUNCTION bloquear_mutacion_auditoria()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'registro_auditoria es append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_inmutable
  BEFORE UPDATE OR DELETE ON registro_auditoria
  FOR EACH ROW EXECUTE FUNCTION bloquear_mutacion_auditoria();

-- ═══════════════════════════════════════════════════════════════════
-- Cadenas de escalamiento (semilla)
-- ═══════════════════════════════════════════════════════════════════

INSERT INTO politica_escalamiento (plantilla, paso, rol_objetivo, espera_minutos) VALUES
  -- Amenaza o doxxing: 5 · 10 · 15 minutos, luego incumplimiento
  ('RIESGO.C5_C6', 0, 'proteccion_humana',   5),
  ('RIESGO.C5_C6', 1, 'coordinador_crisis',  5),
  ('RIESGO.C5_C6', 2, 'autoridad_superior',  5),
  -- Botón de asistencia de la persona afectada: 3 minutos por escalón
  ('PERSONA.SOS',  0, 'proteccion_humana',   3),
  ('PERSONA.SOS',  1, 'coordinador_crisis',  3),
  ('PERSONA.SOS',  2, 'autoridad_superior',  3),
  -- Reporte de agente: 30 minutos
  ('INC.REPORTE_AGENTE', 0, 'coordinador_guardia', 30),
  ('INC.REPORTE_AGENTE', 1, 'coordinador_crisis',  30),
  -- Compromiso de cuentas o sistemas
  ('CIBER.E1_E2', 0, 'ciberseguridad',      10),
  ('CIBER.E1_E2', 1, 'coordinador_crisis',  10);

-- ═══════════════════════════════════════════════════════════════════
-- Restricciones estructurales del documento rector (§4.3 de la E3.0)
-- Estas consultas deben devolver 0 filas. Se verifican en CI.
-- ═══════════════════════════════════════════════════════════════════
--
--   SELECT column_name FROM information_schema.columns
--    WHERE table_schema = 'public'
--      AND (column_name ILIKE '%partid%'
--        OR column_name ILIKE '%ideolog%'
--        OR column_name ILIKE '%afinidad%'
--        OR column_name ILIKE '%biometr%'
--        OR column_name ILIKE '%geolocaliz%');
--
-- No existe tabla `cuenta_vigilada`. La vigilancia es por superficie y
-- tema, no por lista nominal de personas.
