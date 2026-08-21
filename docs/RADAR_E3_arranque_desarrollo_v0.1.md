# RADAR — Especificación de arranque de desarrollo
## E3.0 · Arquitectura funcional, notificaciones, acciones coordinadas y capa de IA
### Versión 0.1 — borrador para revisión técnica

**Organismo:** Municipalidad de San Miguel de Tucumán
**Área responsable:** Subsecretaría de Prensa y Comunicación Institucional
**Documento padre:** `RADAR_documento_rector_v1.md` (v1.0)
**Naturaleza:** especificación técnica derivada. **No sustituye al documento rector.** Ante contradicción, prevalece el rector; toda excepción debe registrarse en su Anexo A.
**Lema operativo:** Detectar señales. Comprender riesgos. Actuar con criterio.

---

## 0. Cómo leer este documento

Este archivo es el punto de partida del desarrollo. Traduce el modelo conceptual de la Etapa 1 en decisiones implementables sobre cuatro ejes que el encargo señala como críticos:

1. **Notificación bidireccional** entre el Comité y las personas usuarias/afectadas.
2. **Acciones coordinadas** verificables, con responsables, plazos y autorizaciones.
3. **IA especializada** enrutada vía OpenRouter, con prompts de sistema propios del dominio.
4. **Seguridad real**, no declarativa: control de acceso, cifrado, auditoría inmutable, minimización.

Cada sección se organiza como: *qué se construye · por qué · restricciones · criterio de aceptación*. Lo que no tiene criterio de aceptación no está especificado y no debe programarse todavía.

**Convención de estado:** `[DECIDIDO]` · `[PROPUESTO]` · `[ABIERTO]` · `[BLOQUEADO]`.

---

## 1. Advertencia previa que condiciona todo el diseño

> **`[BLOQUEADO]` El enrutamiento de datos de incidentes a través de OpenRouter constituye una transferencia internacional de datos personales a un intermediario que, a su vez, deriva a proveedores de modelos de terceros.**

Esto no impide usar OpenRouter, pero obliga a resolver tres cosas **antes** de la primera llamada con datos reales:

| Problema | Por qué importa | Mitigación exigida en esta especificación |
|---|---|---|
| Transferencia internacional (Ley 25.326, arts. 11 y 12; criterios AAIP) | Datos de personas afectadas, evidencia y datos de salud son categorías sensibles. El municipio es responsable de tratamiento. | **Ningún dato de categoría sensible sale del perímetro.** Se envía únicamente texto público seudonimizado (§7.4). Datos de salud: prohibición absoluta de salida. |
| Retención por el proveedor y uso para entrenamiento | Un log del proveedor con evidencia de un caso judicializado es una filtración diferida. | Cabecera de *zero data retention* obligatoria; proveedores sin política verificable de no-entrenamiento quedan fuera del *allow-list* (§7.3). |
| Trazabilidad de la sugerencia | P8 y P11 del rector exigen saber qué modelo dijo qué, con qué datos y qué peso. | Registro local íntegro de *prompt*, *respuesta*, modelo, versión de prompt, costo y latencia (§7.8). |

**Criterio de aceptación:** la Asesoría Letrada emite dictamen escrito sobre el circuito de seudonimización antes del primer despliegue con datos reales. Hasta entonces, el entorno de desarrollo opera exclusivamente con los seis casos ficcionalizados del rector (§12.4).

---

## 2. Principios heredados con traducción a código

No se reescriben los quince principios del rector. Se fija cómo se verifican en la aplicación.

| Principio | Implementación verificable | Test automatizado |
|---|---|---|
| P1 Protección prioritaria | La transición de estado `EVALUADO → DECIDIDO` falla si `EvaluacionRiesgo` está incompleta. | `test_gate_irh_obligatorio` |
| P2 Libertad de expresión | Las categorías `A1–A4` no exponen las acciones `denunciar`, `reportar_contenido` ni `intimar` en la API. | `test_familia_a_sin_acciones_juridicas` |
| P3 Proporcionalidad | Escalar exige campo `fundamento` no vacío (≥ 140 caracteres). Desescalar, no. | `test_escalamiento_requiere_fundamento` |
| P4 Neutralidad | No existe columna de adscripción partidaria. Migración que la introduzca falla en CI. | `test_schema_sin_campos_prohibidos` |
| P5/P6 Privacidad y minimización | Todo campo PII se declara en un registro central con base legal y plazo. Campo sin declarar = error de arranque. | `test_registro_pii_completo` |
| P7 Seguridad | 2FA obligatorio; cifrado en reposo por columna para evidencia y salud. | `test_2fa_enforced`, `test_columnas_cifradas` |
| P8 Trazabilidad | Toda mutación sensible escribe en `registro_auditoria` dentro de la misma transacción. | `test_auditoria_transaccional` |
| P9 Evidencia | El *hash* y el sellado de tiempo se generan en la captura, no al decidir denunciar. | `test_sellado_en_ingesta` |
| P10 Revisión humana | Ningún *endpoint* con efecto externo es invocable por el servicio de IA. Separación por credencial. | `test_ia_sin_permisos_de_ejecucion` |
| P11 Explicabilidad | Toda salida de IA sin los campos `datos_considerados`, `faltantes` y `confianza` se descarta. | `test_schema_salida_ia` |
| P12 Limitación de finalidad | Consultas de exportación filtran por finalidad declarada; exportación sin finalidad, prohibida. | `test_export_requiere_finalidad` |
| P13 Eliminación | Job diario de retención con reporte de auditoría; su fallo es incidente de severidad alta. | `test_job_retencion` |
| P14 Separación institucional/partidario | Cuentas institucionales marcadas en el modelo; sin tabla de cuentas partidarias. | `test_schema_sin_campos_prohibidos` |
| P15 Auditoría | Tabla *append-only* por permisos de base de datos, no por lógica de aplicación. | `test_auditoria_no_editable` |

**Regla de oro del desarrollo:** un principio que no tiene un test que lo rompa cuando se viola es un principio decorativo.

---

## 3. Arquitectura general

### 3.1 Decisión de stack `[PROPUESTO]`

| Capa | Elección | Fundamento |
|---|---|---|
| Base de datos | PostgreSQL 16 (Supabase o instancia gestionada bajo control municipal) | RLS nativo para compartimentación; `pgcrypto`; auditoría por *trigger*; JSONB para vectores versionados. |
| Backend | Node.js + TypeScript (Fastify) o Python + FastAPI | Indistinto; se decide por el perfil real del equipo de sistemas municipal. `[ABIERTO]` |
| Frontend | React + TypeScript, diseño responsivo, PWA | La PWA habilita *push* en escritorio y móvil sin app nativa (excluida de v1 en el rector §14.2). |
| Cola de trabajos | Postgres + worker (pg-boss / Celery) | Evita infraestructura adicional. Notificaciones, escalamientos, retención y llamadas de IA son diferidos. |
| Almacenamiento de evidencia | Object storage cifrado, *bucket* privado, URLs firmadas de vida corta | La evidencia nunca se sirve por URL pública. |
| Autenticación | OIDC contra el directorio municipal si existe; si no, local con 2FA TOTP | `[ABIERTO]` según relevamiento §15.3 del rector. |
| Observabilidad | Logs estructurados sin PII + métricas de plazos por nivel | Un plazo N3 incumplido debe ser visible antes de que alguien pregunte. |

**Restricción de alojamiento:** conforme DA 641/2021 y el supuesto §15.2 del rector. Si el alojamiento en nube extranjera no supera la revisión jurídica, la arquitectura debe poder desplegarse en infraestructura propia. **Todo componente elegido debe ser autoalojable.** Esto excluye servicios SaaS propietarios en el camino crítico —salvo la capa de IA, que es explícitamente externa y por eso está encapsulada tras una única interfaz (§7.2).

### 3.2 Módulos y límites

```
┌───────────────────────────────────────────────────────────────────┐
│                         RADAR · núcleo                            │
│                                                                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │ Incidentes │→ │ Evaluación │→ │  Decisión  │→ │   Acción   │   │
│  │ y menciones│  │ IRS / IRH  │  │ + 13 preg. │  │ coordinada │   │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘   │
│        │               │               │               │          │
│  ┌─────▼───────────────▼───────────────▼───────────────▼──────┐   │
│  │        Bus de eventos internos (event log append-only)     │   │
│  └─────┬───────────────┬───────────────┬───────────────┬──────┘   │
│        │               │               │               │          │
│  ┌─────▼──────┐ ┌──────▼─────┐ ┌───────▼────┐ ┌────────▼──────┐  │
│  │Notificación│ │ Protección │ │  Evidencia │ │   Auditoría   │  │
│  │ bidireccion│ │   Humana   │ │  y custodia│ │  (inmutable)  │  │
│  │            │ │(comparti-  │ │            │ │               │  │
│  │            │ │ mentado)   │ │            │ │               │  │
│  └────────────┘ └────────────┘ └────────────┘ └───────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  Gateway de IA (única salida al exterior) → OpenRouter    │    │
│  │  seudonimiza · valida esquema · registra · nunca ejecuta   │    │
│  └──────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────┘
```

**Invariante arquitectónico:** el *Gateway de IA* es el único componente con egreso a Internet hacia proveedores de modelos, y **no posee credenciales de escritura sobre el núcleo**. Devuelve sugerencias que una persona acepta, modifica o rechaza. Esto no es una preferencia de estilo: es la implementación de P10.

---

## 4. Modelo de datos: extensiones sobre el rector §10

Se conservan las dieciocho entidades núcleo. Se agregan las necesarias para notificación bidireccional, acciones coordinadas y trazabilidad de IA.

### 4.1 Entidades nuevas

| Entidad | Descripción | Notas de privacidad |
|---|---|---|
| `CanalContacto` | Medio verificado de una persona: push, email, WhatsApp, Telegram, SMS. | PII. Cifrado en reposo. Verificación con doble opt-in. Baja inmediata a pedido. |
| `Notificacion` | Instancia enviada: destinatario, plantilla, canal, prioridad, estado, acuse. | **Sin contenido agresivo en el cuerpo.** Solo estado y llamada a la acción. |
| `AcuseRecibo` | Confirmación explícita de lectura o de acción, con marca temporal. | Base del reloj de escalamiento. |
| `PoliticaEscalamiento` | Cadena: a quién, en qué orden, tras cuánto silencio, por qué canal. | Configurable por nivel de intervención. |
| `Guardia` | Rotación de turnos por rol, con titular y suplente, cobertura 24/7 para N3/N5. | Sin datos personales más allá del vínculo usuario–turno. |
| `MensajeCaso` | Hilo bidireccional persona afectada ↔ referente de contención. | Cifrado. Acceso: la persona y Protección Humana. Nunca en exportaciones generales. |
| `CheckIn` | Registro de estado de la persona afectada ("estoy bien", "necesito hablar", "prefiero no responder"). | Dato de bienestar. Compartimentado. |
| `AporteVoluntario` | Material aportado por la persona sin obligación de revisarlo. | Ingresa a la cadena de custodia; la persona no clasifica. |
| `AccionCoordinada` | Conjunto de tareas paralelas con objetivo declarado, ventana y responsable único. | Núcleo del módulo de coordinación (§6). |
| `SolicitudIA` | Registro íntegro de cada llamada al gateway. | Prompt seudonimizado, respuesta, modelo, versión, costo, latencia, veredicto humano. |
| `VersionPrompt` | Prompts de sistema versionados con *hash*. | Reproducibilidad: toda sugerencia dice bajo qué prompt nació. |
| `Consentimiento` | Consentimientos de la persona afectada: canales, acompañamiento, tratamiento de salud. | Revocable. Registro de versión de texto aceptado. |

### 4.2 Esqueleto SQL de las piezas nuevas `[PROPUESTO]`

```sql
-- ── Canales de contacto verificados ────────────────────────────────
CREATE TYPE tipo_canal AS ENUM ('push','email','whatsapp','telegram','sms','llamada');

CREATE TABLE canal_contacto (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id      uuid NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
  tipo            tipo_canal NOT NULL,
  destino_cifrado bytea NOT NULL,              -- pgp_sym_encrypt del identificador
  verificado_en   timestamptz,
  prioridad       smallint NOT NULL DEFAULT 5, -- 1 = primero en la cadena
  admite_urgente  boolean NOT NULL DEFAULT true, -- ignora horario de descanso
  activo          boolean NOT NULL DEFAULT true,
  creado_en       timestamptz NOT NULL DEFAULT now()
);

-- ── Notificaciones ─────────────────────────────────────────────────
CREATE TYPE prioridad_notif AS ENUM ('informativa','operativa','urgente','critica');
CREATE TYPE estado_notif    AS ENUM ('encolada','enviada','entregada','leida','acusada','fallida','vencida');

CREATE TABLE notificacion (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id   uuid REFERENCES incidente(id),
  destinatario   uuid NOT NULL REFERENCES usuario(id),
  plantilla      text NOT NULL REFERENCES plantilla_notificacion(codigo),
  variables      jsonb NOT NULL DEFAULT '{}'::jsonb,  -- jamás contenido agresivo
  prioridad      prioridad_notif NOT NULL,
  canal          tipo_canal NOT NULL,
  requiere_acuse boolean NOT NULL DEFAULT false,
  vence_en       timestamptz,                          -- dispara escalamiento
  estado         estado_notif NOT NULL DEFAULT 'encolada',
  intento        smallint NOT NULL DEFAULT 0,
  enviada_en     timestamptz,
  acusada_en     timestamptz,
  CONSTRAINT acuse_coherente CHECK (NOT requiere_acuse OR vence_en IS NOT NULL)
);

-- ── Escalamiento ───────────────────────────────────────────────────
CREATE TABLE politica_escalamiento (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nivel          text NOT NULL,             -- N0..N5
  paso           smallint NOT NULL,
  rol_objetivo   text NOT NULL,
  espera_minutos smallint NOT NULL,
  canal_forzado  tipo_canal,
  UNIQUE (nivel, paso)
);

-- ── Hilo protegido con la persona afectada ─────────────────────────
CREATE TABLE mensaje_caso (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id      uuid NOT NULL REFERENCES incidente(id),
  persona_id        uuid NOT NULL REFERENCES persona_afectada(id),
  autor_usuario_id  uuid REFERENCES usuario(id),    -- null = la propia persona
  cuerpo_cifrado    bytea NOT NULL,
  contiene_evidencia boolean NOT NULL DEFAULT false, -- fuerza colapso en UI
  creado_en         timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE mensaje_caso ENABLE ROW LEVEL SECURITY;
-- Política: acceso solo a la persona afectada y al rol proteccion_humana.

-- ── Acciones coordinadas ───────────────────────────────────────────
CREATE TABLE accion_coordinada (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id      uuid NOT NULL REFERENCES incidente(id),
  objetivo          text NOT NULL,          -- obligatorio, en lenguaje llano
  publico_destino   text NOT NULL,
  indicador_exito   text NOT NULL,
  ventana_inicio    timestamptz NOT NULL,
  ventana_fin       timestamptz NOT NULL,
  responsable_unico uuid NOT NULL REFERENCES usuario(id),
  autorizacion_id   uuid REFERENCES autorizacion(id),
  estado            text NOT NULL DEFAULT 'borrador',
  CONSTRAINT objetivo_no_trivial CHECK (length(objetivo) >= 40)
);

-- ── Trazabilidad de IA ─────────────────────────────────────────────
CREATE TABLE solicitud_ia (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id      uuid REFERENCES incidente(id),
  agente            text NOT NULL,          -- clasificador | evaluador | ...
  prompt_version    text NOT NULL REFERENCES version_prompt(hash),
  payload_enviado   jsonb NOT NULL,         -- ya seudonimizado
  respuesta_cruda   jsonb,
  modelo_efectivo   text,                   -- lo que OpenRouter usó realmente
  tokens_in         integer,
  tokens_out        integer,
  costo_usd         numeric(10,5),
  latencia_ms       integer,
  veredicto_humano  text,                   -- aceptada | modificada | rechazada
  motivo_rechazo    text,
  creado_en         timestamptz NOT NULL DEFAULT now()
);
```

### 4.3 Restricciones estructurales que el esquema debe hacer imposibles

Estas son negativas y se verifican en CI contra el esquema real:

- No existe columna cuyo nombre coincida con `%partid%`, `%ideolog%`, `%afinidad%`, `%orientacion_politica%`.
- No existe tabla que vincule `actor` con `padron`, `contribuyente` o `legajo`.
- No existe columna de geolocalización de individuos.
- No existe columna de datos biométricos.
- `registro_auditoria` no tiene `UPDATE` ni `DELETE` concedidos a ningún rol de aplicación.

---

## 5. Sistema de notificación bidireccional

Este es el corazón operativo. Un protocolo con ventana de quince minutos que depende de que alguien mire una pantalla no es un protocolo: es una intención.

### 5.1 Las dos direcciones

**Comité → personas.** Alertas de activación, asignación de tarea, vencimiento de plazo, solicitud de autorización, convocatoria de comité, aviso de estado a la persona afectada.

**Personas → Comité.** Reporte de incidente por cualquier agente municipal, botón de asistencia inmediata de la persona afectada, acuse de recibo, aporte voluntario de material, *check-in* de bienestar, respuesta a una consulta del referente de contención.

La segunda dirección se subestima siempre. Es la que convierte a RADAR en un sistema del municipio y no en un tablero de la Subsecretaría.

### 5.2 Catálogo de eventos notificables `[PROPUESTO]`

| Código | Disparador | Destinatario | Prioridad | Acuse | Vence | Escalamiento |
|---|---|---|---|---|---|---|
| `INC.NUEVO` | Alta de incidente | Coordinador de guardia | operativa | no | 60 min | Coordinador de crisis |
| `INC.REPORTE_AGENTE` | Reporte desde el formulario abierto municipal | Coordinador de guardia | operativa | sí | 30 min | Coordinador de crisis |
| `RIESGO.C5_C6` | Clasificación C5 (amenaza) o C6 (doxxing) confirmada | Protección Humana + Jurídico + Coordinador de crisis | **crítica** | sí | **5 min** | Cadena completa hasta Intendencia |
| `RIESGO.H1_ALTO` | `H1 ≥ 3` | ídem | **crítica** | sí | **5 min** | ídem |
| `PROT.N3_ACTIVO` | Activación de N3 | Referente de Protección Humana de guardia | **crítica** | sí | **5 min** | Suplente → titular del área → Secretaría |
| `PERSONA.SOS` | Botón de asistencia de la persona afectada | Protección Humana de guardia + coordinador | **crítica** | sí | **3 min** | Cadena completa, sin horario de descanso |
| `PERSONA.CHECKIN` | Respuesta de bienestar | Protección Humana | informativa | no | — | — |
| `PERSONA.SIN_RESPUESTA` | Sin *check-in* en la ventana pactada | Protección Humana | urgente | sí | 30 min | Titular del área |
| `CIBER.E1_E2` | Compromiso de cuenta o de sistemas | Referente de ciberseguridad + coordinador | **crítica** | sí | 10 min | Comité |
| `LEGAL.N4` | Activación de nivel jurídico | Asesoría Letrada de guardia | urgente | sí | 60 min | Director General |
| `AUTORIZACION.PEND` | Acción N2+ esperando aprobación | Rol autorizante | urgente | sí | 50 % del plazo restante | Superior jerárquico |
| `TAREA.ASIGNADA` | Tarea nueva | Responsable | operativa | sí | 25 % del plazo | Responsable del plan |
| `TAREA.VENCE` | 80 % del plazo consumido | Responsable + responsable del plan | urgente | sí | plazo restante | Coordinador |
| `COMITE.CONVOCATORIA` | Activación N5 | Todos los miembros | **crítica** | sí | 10 min | Llamada telefónica manual |
| `CIERRE.PENDIENTE` | Caso con N3 activo sin conformidad de Protección Humana | Protección Humana | operativa | sí | 24 h | Coordinador |
| `RETENCION.EJECUTADA` | Job diario de eliminación | Auditor | informativa | no | — | — |
| `RETENCION.FALLIDA` | Fallo del job | Auditor + ciberseguridad | urgente | sí | 4 h | Coordinador |

### 5.3 Reglas de contenido de las notificaciones

Derivan directamente del *modo protegido* (rector §9.3) y son vinculantes:

1. **Ninguna notificación transporta contenido agresivo.** Ni en el cuerpo, ni en el título, ni en la vista previa del sistema operativo. Una notificación *push* que muestre una amenaza en la pantalla de bloqueo de la persona amenazada es un daño causado por el sistema.
2. Las notificaciones dirigidas a la persona afectada informan **estado y acompañamiento**, nunca métricas de volumen ni citas: *"Tu caso pasó a seguimiento jurídico. El equipo se ocupa. ¿Querés hablar con alguien ahora?"*
3. Las notificaciones al equipo usan **códigos y niveles**, con el detalle detrás de autenticación: *"Incidente #482 · N3 activo · riesgo personal alto · acuse requerido en 5 min"*.
4. Canales de terceros (WhatsApp, Telegram, SMS) reciben **solo el aviso mínimo y el enlace**. El contenido vive en la aplicación. Un canal que no controlamos no transporta información del caso.
5. Prioridad `critica` ignora el horario de descanso; el resto lo respeta. La configuración de descanso no puede suprimir `PERSONA.SOS`.

### 5.4 Escalamiento y guardias

El reloj de escalamiento arranca con el **envío**, no con la lectura, y solo se detiene con **acuse explícito**. Un acuse es una acción deliberada, nunca la apertura pasiva.

```
PROT.N3_ACTIVO
  t+0     → Protección Humana de guardia (push + WhatsApp + SMS en paralelo)
  t+5min  → sin acuse: suplente de guardia + coordinador de crisis
  t+10min → sin acuse: titular del área + Subsecretaría (todos los canales)
  t+15min → sin acuse: INCIDENTE DE PROTOCOLO. Se registra el incumplimiento,
            se notifica a Auditoría y el caso queda marcado para post-mortem.
```

El paso final importa: el sistema **no puede garantizar** que alguien responda, pero sí puede garantizar que el incumplimiento quede registrado y sea revisado. El supuesto §15.2 del rector —disponibilidad efectiva de RRHH en quince minutos, fines de semana incluidos— se valida o se refuta con estos datos, no con opiniones.

**Criterio de aceptación:** en la prueba de carga del sprint 4, el 100 % de los eventos `critica` genera cadena completa de escalamiento con marcas temporales verificables, y ningún evento se pierde ante caída del *worker* (reintento idempotente desde la cola).

### 5.5 Canal de ingreso abierto para agentes municipales

Formulario mínimo, accesible sin credenciales de RADAR, con autenticación municipal básica o código de área. Cuatro campos: qué pasó, dónde lo viste, a quién afecta, cómo te contactamos. Y una casilla: **"Esto involucra una amenaza o la publicación de datos personales"**, que dispara `RIESGO.C5_C6` de forma provisoria hasta la confirmación humana.

Falsos positivos en esa casilla son aceptables. Falsos negativos, no. La regla 2 de clasificación del rector —ante duda sobre riesgo personal, prevalece la interpretación protectora— se implementa aquí.

### 5.6 Modo protegido en la práctica de notificación

- La persona afectada elige al alta: *"solo estado"* (por defecto) o *"estado y resumen agregado"*. Nunca *"contenido"*: esa opción no existe en la interfaz de notificación.
- *Check-in* configurable: cada 6, 12 o 24 h durante la fase aguda, con opción de *"no me consulten, yo escribo si necesito"*, decisión que también se registra y se respeta.
- Vía directa siempre visible al referente de contención, con indicador de disponibilidad real —no un botón que escribe a un buzón vacío el domingo.

---

## 6. Acciones coordinadas

Un plan que no se puede ejecutar en paralelo con responsables únicos por acción termina siendo una lista de buenas intenciones en un grupo de WhatsApp.

### 6.1 Anatomía de una acción coordinada

Toda `AccionCoordinada` exige, antes de pasar de borrador:

| Campo | Obligatorio | Validación |
|---|---|---|
| Objetivo concreto | sí | ≥ 40 caracteres, en lenguaje llano. "Comunicar" no es un objetivo. |
| Público destinatario | sí | De un catálogo cerrado: vecinos afectados, ciudadanía general, personal municipal, medios, plataforma, sede judicial. |
| Indicador de éxito | sí | Debe ser observable en la ventana definida. |
| Ventana temporal | sí | Coherente con el plazo máximo del nivel activo. |
| Responsable único | sí | Una persona. No un área. Las áreas no acusan recibo. |
| Autorización | según nivel | N2+ requiere `Autorizacion` registrada previa a la ejecución. |
| Acciones prohibidas del nivel | automático | Se listan en la interfaz junto a las habilitadas. |

### 6.2 Ejecución en paralelo

Los niveles N0–N5 no son secuenciales (rector §7). El tablero de acción refleja eso con carriles simultáneos:

```
Incidente #482 — Doxxing de trabajadora municipal · alcance bajo · riesgo máximo

 N3 PROTECCIÓN  ██████████░░  Protección Humana   · vence 14:22 · 2/5 tareas
 N4 JURÍDICO    ████░░░░░░░░  Asesoría Letrada    · vence 19:07 · 1/4 tareas
 N2 COMUNIC.    ░░░░░░░░░░░░  SUSPENDIDO — regla de no amplificación aplicada
 N0 OBSERVACIÓN ████████████  Analista            · monitoreo activo
```

El carril suspendido con su motivo visible vale tanto como los activos. Es la diferencia entre "nadie hizo nada" y "se decidió no responder públicamente, con fundamento registrado, y esa decisión es auditable".

### 6.3 Compuerta de las 13 preguntas

Antes de habilitar cualquier acción de nivel N2 o superior, pantalla obligatoria con las trece preguntas del rector §12.3. Reglas de implementación:

- Las respuestas se guardan como parte de la `Decision`, no como un trámite descartable.
- La IA puede **proponer** borradores de respuesta a cada pregunta con su fundamento; la persona las edita o las reemplaza. Una pregunta cuya respuesta quedó tal cual la propuso la IA se marca visualmente. No lo prohíbe: lo hace visible.
- Las preguntas 5 y 7 —*¿la respuesta puede hacer que más personas lo conozcan?* y *¿es mejor responder a la narrativa sin mencionar la publicación?*— alimentan la evaluación de contra-riesgo H7. Si el resultado dispara la regla de no amplificación (rector §6.5), la interfaz muestra la recomendación de no responder **antes** de mostrar el editor de contenido. El orden de la pantalla es una decisión de diseño con consecuencias.

### 6.4 Autorizaciones

Cadena mínima `[PROPUESTO]`:

| Acción | Autoriza | Suplente | Plazo de autorización |
|---|---|---|---|
| Respuesta N1 informativa | Coordinador de guardia | Coordinador de crisis | 2 h |
| Comunicación N2 | Coordinador de crisis | Subsecretaría | 6 h |
| Presentación judicial | Referente jurídico | Director General de Asuntos Jurídicos | 6 h |
| Reporte a plataforma | Coordinador de crisis + visto jurídico | — | 6 h |
| Declaración de crisis N5 | Autoridad superior | — | inmediato |
| Medida de resguardo personal | Protección Humana | Titular del área | **sin autorización previa** |

La última fila es deliberada. La protección de una persona no espera una firma. Se ejecuta y se informa.

---

## 7. Capa de IA especializada

### 7.1 Qué se le pide a la IA y qué no

Recorte estricto sobre el rector §11: la IA **agrupa, resume, detecta patrones, sugiere clasificación, señala factores de riesgo, propone preguntas faltantes, redacta borradores y explica alternativas**. No decide, no califica jurídicamente, no publica, no afirma pertenencias, no accede a datos privados.

### 7.2 Los cinco agentes

| Agente | Función | Modelo objetivo | Fallback | Temperatura |
|---|---|---|---|---|
| `CLASIFICADOR` | Sugiere categoría primaria y hasta dos secundarias sobre la taxonomía A–E. | Modelo de razonamiento de gama alta | Gama media | 0.1 |
| `EVALUADOR` | Propone vectores IRS (R1–R7) e IRH (H1–H7) con justificación por dimensión y datos faltantes. | Gama alta | Gama alta alternativa | 0.1 |
| `ESTRATEGA` | Responde las 13 preguntas, propone 2–3 cursos de acción con riesgos comparados, incluida siempre la opción de no responder. | Gama alta | Gama alta alternativa | 0.3 |
| `REDACTOR` | Borradores de comunicados, respuestas, respaldo institucional y contranarrativa fáctica, según matriz de tono y canal. | Gama alta con buen registro en español rioplatense | Gama media | 0.5 |
| `AUDITOR` | *Red team* interno: revisa la salida de los otros y el plan humano buscando violaciones de principios, riesgo de amplificación, sesgo partidario y afirmaciones sin nivel de evidencia. | Gama alta, **proveedor distinto** al del agente auditado | — | 0.2 |

El `AUDITOR` corriendo sobre otro proveedor no es capricho: la correlación de errores entre instancias del mismo modelo es alta, y un auditor que comparte los sesgos del auditado no audita nada.

### 7.3 Enrutamiento en OpenRouter `[PROPUESTO]`

```jsonc
{
  "route_policy": {
    "provider": {
      "allow_fallbacks": true,
      "data_collection": "deny",        // excluye proveedores que retienen datos
      "require_parameters": true,
      "order": ["<proveedor_A>", "<proveedor_B>"],
      "ignore": ["<proveedores_sin_politica_verificable>"]
    },
    "headers": {
      "X-Title": "RADAR-SMT",
      "HTTP-Referer": "https://radar.interno.smt.gob.ar"
    },
    "max_tokens": 4096,
    "response_format": { "type": "json_schema", "strict": true }
  }
}
```

Decisiones vinculantes de enrutamiento:

- `data_collection: "deny"` es **obligatorio**. Sin esa política, no se envía nada.
- Los modelos concretos no se fijan en este documento: rotan más rápido de lo que se actualiza una especificación. Se define un **archivo de configuración de modelos** versionado, con revisión trimestral y registro del cambio.
- Presupuesto por incidente con corte duro. Un caso que consume más de lo previsto genera alerta, no una factura sorpresa.
- Latencia máxima aceptable: 20 s para `CLASIFICADOR` y `EVALUADOR`. Superado el umbral, la interfaz sigue sin la sugerencia. **La IA nunca bloquea el flujo humano.** Si el proveedor cae, RADAR funciona con carga manual, que es exactamente el MVP del rector §14.

### 7.4 Seudonimización obligatoria antes del egreso

Pipeline no evitable en el gateway:

1. **Sustitución de identidades.** Personas afectadas → `PERSONA_A`, `PERSONA_B`. Agentes municipales → `AGENTE_1`. Cuentas → `CUENTA_1`. Mapa reversible guardado solo en local.
2. **Supresión total.** Datos de salud, domicilios, teléfonos, documentos, datos de menores, contenido de `MensajeCaso` y de `CheckIn`: **nunca salen**. No se seudonimizan, se eliminan del payload.
3. **Normalización de contenido citado.** Para clasificar una amenaza no hace falta enviar el texto íntegro con nombres y direcciones: se envía la estructura del mensaje con marcadores (`[DOMICILIO_MENCIONADO]`, `[FAMILIAR_MENCIONADO]`). El agente clasifica igual de bien y el dato no viaja.
4. **Verificación de salida.** Detector de patrones PII sobre el payload final. Coincidencia = llamada abortada y evento de auditoría.

**Criterio de aceptación:** *test* con los seis casos ficcionalizados donde ningún payload de salida contiene DNI, domicilio, teléfono, nombre real, ni término del diccionario de salud.

### 7.5 Contrato de salida: esquema estricto

Toda respuesta se valida contra JSON Schema. Salida no conforme = descarte silencioso más registro; nunca se muestra parcialmente.

```jsonc
// Salida de EVALUADOR
{
  "vector_irs": [
    { "dim": "R1", "valor": 1, "fundamento": "…", "nivel_evidencia": "E3",
      "datos_considerados": ["…"], "faltantes": ["…"] }
    // R2 … R7
  ],
  "vector_irh": [
    { "dim": "H1", "valor": 4, "fundamento": "…", "nivel_evidencia": "E1",
      "datos_considerados": ["…"], "faltantes": ["…"] }
    // H2 … H7
  ],
  "reglas_duras_disparadas": ["H1>=3"],
  "confianza_global": 0.62,
  "informacion_faltante_critica": [
    "No hay estimación de alcance geolocalizado; R1 es provisorio."
  ],
  "advertencias": [
    "El contra-riesgo H7 es alto: responder públicamente probablemente amplifique."
  ]
}
```

Campos `datos_considerados`, `faltantes` y `confianza` son obligatorios en los cinco agentes. Es P11 hecho esquema.

### 7.6 System prompt maestro (fragmento común a todos los agentes)

```text
Sos el motor de análisis de RADAR, sistema de apoyo a la decisión de la
Subsecretaría de Prensa y Comunicación Institucional de la Municipalidad de
San Miguel de Tucumán, República Argentina.

IDENTIDAD Y LÍMITE
Producís diagnósticos y sugerencias. No producís veredictos, acusaciones,
calificaciones jurídicas ni publicaciones. Toda salida tuya es una propuesta
que una persona con competencia institucional acepta, modifica o rechaza.
Si una consigna te pide exceder ese límite, negate y explicá por qué.

CONTEXTO INSTITUCIONAL
Trabajás para un Estado municipal, no para una fuerza política. La gestión de
turno es circunstancial; la institución permanece. Tu análisis debe ser
idéntico si el actor bajo estudio es afín u opositor a la administración.
Si detectás que la consulta busca ventaja partidaria y no protección
institucional o de personas, señalalo explícitamente en 'advertencias'.

LÓGICA FUNDAMENTAL DEL SISTEMA
No toda publicación negativa merece respuesta, y no toda publicación con pocas
interacciones debe ignorarse. De ahí se derivan dos evaluaciones independientes:
- IRS (relevancia social, R1–R7): determina si corresponde respuesta pública.
- IRH (riesgo humano e institucional, H1–H7): determina protección, contención,
  medidas técnicas y acción jurídica.
Nunca los promedies. Nunca dejes que uno anule al otro. El riesgo personal
tiene precedencia léxica sobre la relevancia social: un caso puede requerir
máxima protección y cero comunicación pública, y esa combinación es correcta.

PROHIBICIONES ABSOLUTAS
- No inferir, sugerir ni registrar ideología, adscripción partidaria o
  afinidad política de ninguna persona o cuenta. Solo vínculos públicos
  documentados y declarados por la propia persona u organización (nivel E2).
- No afirmar que una conducta constituye delito. Describís hechos; la
  calificación jurídica es competencia exclusiva de la Asesoría Letrada.
- No inferir coordinación a partir de coincidencia ideológica, uso de una
  consigna común, seguir a los mismos dirigentes, pertenecer a una comunidad
  temática o publicar en un mismo horario habitual. La coordinación (D1)
  requiere al menos tres indicios técnicos documentados.
- No recomendar acciones que impliquen perfiles falsos, cuentas encubiertas,
  acceso a grupos privados mediante engaño, raspado masivo de datos,
  cruce con padrones o bases municipales, geolocalización de individuos ni
  contratación de 'inteligencia' de origen no acreditado.
- No proponer responder a crítica política legítima, opinión negativa,
  sátira o parodia con acción jurídica ni con reporte de contenido. Nunca.

NIVELES DE EVIDENCIA (obligatorio etiquetar toda afirmación)
E1 hecho comprobado · E2 vínculo público documentado · E3 indicio ·
E4 inferencia · E5 hipótesis · E6 no verificado.
Nada por debajo de E1/E2 puede fundar una denuncia. E3–E6 son de uso interno
y deben ir marcados. Si no podés etiquetar una afirmación, no la hagas.

SESGOS QUE DEBÉS RESISTIR ACTIVAMENTE
1. Sesgo de volumen: muchas menciones no equivalen a relevancia social.
   Novecientas cuentas inauténticas sin permeabilidad pueden no merecer
   ninguna respuesta pública.
2. Sesgo de invisibilidad: pocas interacciones no equivalen a bajo riesgo.
   Una amenaza dirigida a una trabajadora municipal enviada a cuarenta
   personas es prioridad máxima.
3. Sesgo de acción: la recomendación de no intervenir es un resultado
   legítimo y frecuente. Ofrecela siempre como opción explícita evaluada,
   nunca como omisión.
4. Sesgo de defensa institucional: si el reclamo ciudadano es correcto, decilo.
   Corregir el problema real es mejor comunicación que cualquier contranarrativa.
5. Efecto Streisand: evaluá siempre si tu propia recomendación puede difundir
   un contenido que hoy casi nadie vio.

FORMA DE RESPUESTA
Español rioplatense institucional. Sobrio, preciso, sin adjetivación política,
sin ironía, sin chicanas. Salida exclusivamente en el JSON del esquema provisto,
sin texto adicional, sin markdown, sin preámbulo.
Declará siempre: qué datos usaste, qué peso les diste, qué falta para una
conclusión más firme y tu nivel de confianza. Ante información insuficiente,
decilo y pedila; no completes con supuestos.
```

### 7.7 Prompts específicos por agente (extractos operativos)

**`ESTRATEGA` — bloque distintivo**

```text
Producís entre dos y tres cursos de acción. Uno de ellos es SIEMPRE
"no responder públicamente", con su fundamento y sus riesgos, aunque
parezca inadecuado: el equipo necesita ver el costo de cada opción.

Para cada curso declará: objetivo concreto, público real destinatario,
canal, vocería sugerida por rol —nunca por nombre—, momento, tono,
indicador de éxito observable, riesgo de amplificación y qué haría falta
saber para descartarlo.

Respondé las trece preguntas previas. Si la respuesta a la pregunta 8
—¿existe información verificable disponible?— es negativa, ninguna
recomendación tuya puede incluir respuesta pública sobre el fondo del
asunto. Responder sin datos verificados debilita la posición institucional
y abre flancos.

Distinguí siempre entre responder al emisor y responder a la narrativa
ante terceros. Suele ser preferible lo segundo, sin mencionar la
publicación original ni al autor.

La contranarrativa es fáctica, no adjetiva: documentos, resoluciones,
datos técnicos, plazos. Nunca refutación adjetivo por adjetivo.
```

**`REDACTOR` — bloque distintivo**

```text
Escribís borradores institucionales para un municipio argentino.

Matriz de tono según categoría:
- Reclamo ciudadano genuino (A1): empático, resolutivo, con plazo concreto
  y responsable. Sin defensiva.
- Desinformación operativa (B3): pedagógico, con dato verificable y enlace
  al portal oficial. Sin mencionar al emisor.
- Hostigamiento o amenaza a personal (C2, C3, C5): respaldo humano explícito,
  tajante contra la violencia, sobrio en lo jurídico. Nunca reproduce ni cita
  el contenido agresivo. Nunca expone más datos de la persona afectada.
- Suplantación (C7): informativo y verificable, con indicación de las cuentas
  oficiales auténticas.

Prohibiciones de redacción:
- No nombrar a la persona afectada sin autorización expresa registrada.
- No citar, parafrasear ni describir el contenido agresivo.
- No usar la palabra 'campaña', 'operación' ni atribuir intencionalidad a
  actores identificados si el nivel de evidencia disponible es inferior a E1.
- No lenguaje bélico, no victimismo institucional, no ataque a periodistas.
- No adjetivar al adversario. La institución informa; no discute.

Toda pieza incluye enlace al portal oficial como repositorio de respaldo.
Entregá el borrador y, por separado, tres razones por las que podría ser
mala idea publicarlo.
```

**`AUDITOR` — bloque distintivo**

```text
Revisás la sugerencia de otro agente o el plan cargado por una persona.
Tu tarea es encontrar el problema, no validar.

Verificá, uno por uno:
1. ¿Alguna afirmación carece de nivel de evidencia o lo tiene sobreestimado?
2. ¿Se infiere ideología, pertenencia partidaria o coordinación sin los tres
   indicios técnicos exigidos?
3. ¿Se propone acción jurídica o reporte de contenido sobre expresión
   legítima (A1–A4)?
4. ¿La respuesta puede amplificar un contenido de bajo alcance?
5. ¿Se expone a la persona afectada más de lo que ya estaba expuesta?
6. ¿El plan trata como equivalentes a actores afines y opositores?
7. ¿La recomendación excede el mínimo suficiente (proporcionalidad)?
8. ¿Hay salida de datos personales que no debería producirse?
9. ¿La decisión se apoya en un número agregado en lugar del vector completo?
10. ¿Se omitió la opción de no responder?

Devolvé hallazgos con severidad (bloqueante / advertencia / observación) y
la corrección concreta. Si no encontrás nada, decilo sin adornos: no
inventes hallazgos para parecer útil.
```

### 7.8 Registro y aprendizaje

Cada `SolicitudIA` guarda el veredicto humano. Con eso se construye el único indicador que importa sobre la IA: **tasa de aceptación sin modificación, por agente y por dimensión**. Si el `EVALUADOR` acierta el 90 % en R1 pero el 30 % en H3, eso se corrige en el prompt, no se tolera. El rechazo humano es insumo de mejora, no ruido.

---

## 8. Seguridad

| Control | Especificación | Criterio de aceptación |
|---|---|---|
| Autenticación | OIDC municipal o local; **2FA TOTP obligatorio para todos los roles**, sin excepción jerárquica. | Login sin 2FA imposible en producción. |
| Autorización | RBAC + RLS en base de datos. La aplicación no es la única barrera. | Consulta directa a la base con credencial de rol A no devuelve filas del ámbito B. |
| Compartimentación | Datos de salud y `MensajeCaso`: solo Protección Humana y la persona. Ni la Intendencia accede. | Test explícito con rol `autoridad_superior`. |
| Cifrado | TLS en tránsito; cifrado por columna para PII, evidencia y salud; claves fuera de la base. | Volcado de base sin claves no revela PII. |
| Evidencia | Hash SHA-256 y sellado de tiempo en la ingesta; almacenamiento inmutable; descarga con URL firmada de 5 min y registro de acceso. | Alteración de un archivo rompe la verificación de integridad. |
| Auditoría | *Append-only* por permisos de base de datos; escritura en la misma transacción que la mutación. | `UPDATE`/`DELETE` sobre auditoría fallan aun con credencial de administrador de aplicación. |
| Retención | Job diario según tabla §10.1 del rector; reporte al rol Auditor; fallo = alerta. | Dato vencido inexistente en la base al día siguiente. |
| Acceso a caso ajeno | Permitido con motivo obligatorio y registro; reporte semanal al Auditor. | Sin motivo, la consulta se rechaza. |
| Secretos | Fuera del repositorio; rotación documentada. La clave de OpenRouter solo la conoce el gateway. | Escaneo de secretos en CI. |
| Reporte CERT.ar | Tarea precargada automática en incidentes E1/E2/E3 con plazo y responsable. | Alta de incidente E1 crea la tarea sin intervención. |

**Ejercicio obligatorio previo a producción:** intento deliberado de usar RADAR para vigilancia política, ejecutado por una persona ajena al equipo de desarrollo. Si lo logra, no se despliega. El riesgo "uso desviado hacia vigilancia política" está calificado como crítico en el rector §15.4 y merece una prueba, no una promesa.

---

## 9. Interfaz

### 9.1 Regla de los diez segundos

El encabezado fijo del caso responde las nueve preguntas del rector §13.3 sin desplazamiento. Jerarquía visual: **riesgo personal arriba de alcance**, siempre. Vectores IRS/IRH como barras comparables de siete segmentos; el puntaje agregado, si aparece, va en cuerpo menor y nunca solo.

### 9.2 Identidad visual

Conforme al Manual de Marca de la Ciudad de San Miguel de Tucumán (junio 2025), tipografía Poppins.

```css
--smt-azul:     #0066ff;  /* institucional primario */
--smt-celeste:  #2eb1ff;  /* secundario */
--smt-amarillo: #f4dc00;  /* acento */
--smt-gris:     #333333;  /* texto */
```

**Advertencia de diseño:** los colores institucionales no deben usarse como semáforo de riesgo. El amarillo de marca compitiendo con un amarillo de "alerta media" produce lecturas erróneas bajo presión. La escala de severidad usa una paleta propia, neutra respecto de la identidad, con **doble codificación** —color más ícono más texto— para no depender del color. En una pantalla que decide sobre la seguridad de una persona, la accesibilidad no es un extra.

### 9.3 Vista protegida de la persona afectada

Interfaz separada, no un permiso reducido de la interfaz del equipo. Contiene: estado del caso en lenguaje llano, quién se está ocupando, próximo contacto previsto, vía directa al referente, botón de asistencia inmediata, y un espacio para aportar material que se sube sin previsualización. Evidencia agresiva: colapsada, desenfocada, con apertura de dos pasos y advertencia previa.

---

## 10. API (superficie inicial)

```
POST   /incidentes                       alta manual o desde formulario abierto
GET    /incidentes/:id                   ficha completa según rol
POST   /incidentes/:id/clasificacion     confirma o corrige sugerencia de IA
POST   /incidentes/:id/evaluacion/irs
POST   /incidentes/:id/evaluacion/irh
POST   /incidentes/:id/decision          exige IRS+IRH completos y 13 preguntas
POST   /incidentes/:id/acciones          crea acción coordinada
POST   /acciones/:id/autorizacion
POST   /acciones/:id/ejecutar            exige autorización vigente
POST   /incidentes/:id/evidencia         hash + sellado en ingesta
GET    /incidentes/:id/linea-tiempo

POST   /notificaciones/:id/acuse         detiene el reloj de escalamiento
POST   /personas/:id/sos                 prioridad crítica, sin horario de descanso
POST   /personas/:id/checkin
POST   /personas/:id/mensajes            hilo protegido
POST   /personas/:id/aporte

POST   /ia/sugerir                       único acceso al gateway; solo lectura
GET    /auditoria                        rol auditor exclusivamente
```

Reglas transversales: idempotencia por clave en todos los `POST` de acción; sin PII en parámetros de consulta ni en logs; *rate limiting* por rol; toda mutación sensible escribe auditoría en la misma transacción.

---

## 11. Plan de sprints `[PROPUESTO]`

| Sprint | Foco | Entregable verificable |
|---|---|---|
| 0 | Esquema, RBAC/RLS, auditoría inmutable, seed de los seis casos ficcionalizados. | Tests de restricciones estructurales en verde. |
| 1 | Alta de incidentes, taxonomía completa, formulario abierto para agentes. | Un agente reporta y el coordinador ve el caso en menos de 60 s. |
| 2 | Vectores IRS/IRH con justificación por dimensión; grilla de decisión; 13 preguntas. | Los seis casos del rector se evalúan y el resultado coincide con el esperado, incluido el caso 4 (autocontrol). |
| 3 | Evidencia con hash y sellado; niveles E1–E6; reglas de exportación. | Alteración detectada; exportación con E3+ marcada. |
| 4 | **Notificaciones bidireccionales, guardias, escalamiento, SOS, check-in.** | Cadena completa de `PROT.N3_ACTIVO` con marcas temporales en prueba de caos. |
| 5 | Acciones coordinadas, autorizaciones, carriles paralelos, cierre con conformidad. | Caso 3 gestionado íntegro con N3+N4 activos y N2 suspendido con fundamento. |
| 6 | **Gateway de IA**: seudonimización, esquemas, cinco agentes, registro. | Ningún payload con PII en los seis casos; auditor detecta violaciones plantadas. |
| 7 | Retención automática, panel de auditoría, informes. | Dato vencido eliminado y reportado. |
| 8 | Endurecimiento, prueba de uso desviado, revisión jurídica y de privacidad. | Dictamen escrito favorable. |

Los sprints 4 y 6 son los que el encargo pide con más énfasis, pero dependen de 0–3. Construir notificaciones sobre un modelo de datos sin compartimentación produce un sistema que avisa rápido y filtra igual de rápido.

---

## 12. Decisiones abiertas que bloquean el arranque

| # | Decisión | Quién decide | Bloquea |
|---|---|---|---|
| 1 | Alojamiento: infraestructura propia o nube. | Sistemas + Asesoría Letrada | Sprint 0 |
| 2 | Lenguaje de backend según perfil real del equipo. | Sistemas | Sprint 0 |
| 3 | Dictamen sobre transferencia internacional a proveedores de IA. | Asesoría Letrada | Sprint 6 |
| 4 | Existencia y cobertura real de guardias 24/7 para N3. | RRHH / Salud Ocupacional | Sprint 4 |
| 5 | Proveedor de sellado de tiempo con validez ante la justicia local. | Asesoría Letrada | Sprint 3 |
| 6 | Canal de mensajería institucional: WhatsApp Business API vs. Telegram. | Subsecretaría + Sistemas | Sprint 4 |
| 7 | Umbrales calibrados: **requiere los 30 días de línea de base.** Es la dependencia más lenta del proyecto y debería iniciarse hoy, en paralelo al desarrollo. | Comunicación Digital | Calibración post-MVP |

---

## 13. Qué NO se construye en esta versión

Reafirmación del rector §14.2, porque la presión por agregarlo aparecerá: sin escucha automatizada a gran escala, sin detección automática de coordinación, sin grafos de actores, sin integración de reporte a plataformas, sin app nativa, sin panel público.

Y un agregado propio de esta etapa: **sin ninguna acción automática con efecto externo, jamás, en ninguna versión futura.** No es una limitación del MVP. Es una propiedad permanente del sistema. Un municipio que responde automáticamente a un ataque digital ya perdió el control de su vocería.

---

## 14. Próximo entregable

**E3.1 — Especificación funcional detallada por módulo**, con historias de usuario, criterios de aceptación por pantalla, y el catálogo definitivo de plantillas de notificación con su texto exacto revisado por Protección Humana. El texto de una notificación dirigida a una persona amenazada no es una tarea de redacción técnica.

---

*RADAR · E3.0 v0.1 — borrador. Toda modificación requiere versionado y, si altera una regla del documento rector, registro en su Anexo A.*
