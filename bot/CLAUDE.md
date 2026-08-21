# INSTRUCCIÓN PARA CLAUDE CODE — Bot RADAR

> Pegá este archivo como `CLAUDE.md` en la raíz del repositorio vacío y arrancá
> la sesión con: **"Leé CLAUDE.md y ejecutá el Bloque 0. Pará al terminarlo y
> mostrame el resultado antes de seguir."**
>
> Trabajá bloque por bloque. No avances al siguiente sin que yo lo apruebe.

---

## 1. Qué estamos construyendo

Un bot de Telegram que funciona como **puerta de entrada y sistema de alerta**
de RADAR, el sistema de gestión de incidentes digitales de la Municipalidad de
San Miguel de Tucumán (Argentina).

Resuelve un problema concreto: hoy, cuando un agente municipal detecta una
agresión digital contra un compañero o una campaña de desinformación sobre un
servicio, lo manda por WhatsApp a alguien y se pierde. El bot convierte eso en
un incidente registrado, con hora, autor, evidencia sellada, responsable
asignado y un reloj de escalamiento que no se detiene hasta que alguien acusa
recibo de forma explícita.

**El valor del sistema está en el criterio y en la trazabilidad, no en el
volumen de datos.** Un MVP que ordene la decisión con carga manual ya resuelve
el problema central.

### Los tres flujos

1. **Agente/guardián → RADAR.** Reporte guiado en 4 pasos desde el chat privado.
2. **RADAR → Comité.** Alerta al grupo con botones; cadena de escalamiento por
   pasos si nadie acusa recibo.
3. **RADAR ↔ persona afectada.** Canal protegido: estado del caso en lenguaje
   llano, botón de asistencia inmediata, check-in de bienestar. **Nunca
   contenido agresivo.**

---

## 2. Reglas no negociables

Estas reglas vienen del documento rector del proyecto. **No son preferencias de
estilo: si una implementación las viola, está mal aunque funcione.** Cada una
tiene un test que debe existir y pasar.

| # | Regla | Test obligatorio |
|---|---|---|
| R1 | El reloj de escalamiento se detiene **solo con acuse explícito** (pulsar el botón), nunca con la lectura. | `test_acuse_detiene_reloj` |
| R2 | Ninguna notificación transporta contenido agresivo: ni en el cuerpo, ni en el título, ni en la vista previa. Las plantillas usan códigos, niveles y estados. | `test_plantillas_sin_contenido` |
| R3 | El hash SHA-256 y el sellado de tiempo de la evidencia se calculan **en la ingesta**, no al decidir denunciar. | `test_sellado_en_ingesta` |
| R4 | `registro_auditoria` es append-only **por trigger de base de datos**, no por lógica de aplicación. | `test_auditoria_no_editable` |
| R5 | Toda mutación sensible escribe auditoría en la **misma transacción**. Si falla la auditoría, falla la operación. | `test_auditoria_transaccional` |
| R6 | No existe ninguna columna cuyo nombre contenga `partid`, `ideolog`, `afinidad`, `biometr` o `geolocaliz`. No existe tabla `cuenta_vigilada` ni lista nominal de personas observadas. | `test_schema_sin_campos_prohibidos` |
| R7 | El bot **no acepta desconocidos**. El alta es por código de vinculación de un solo uso creado por un administrador. | `test_usuario_no_vinculado_rechazado` |
| R8 | **Ninguna acción con efecto externo se ejecuta automáticamente.** El bot alerta, registra y escala. No publica, no responde, no denuncia. | Revisión de código |
| R9 | Ante duda sobre riesgo personal, prevalece la interpretación protectora: la casilla "hay amenaza o datos personales" activa N3 de forma provisoria sin esperar confirmación. Falsos positivos aceptables, falsos negativos no. | `test_bandera_activa_n3` |
| R10 | La persona afectada nunca recibe métricas de volumen ni citas del contenido. Solo estado, acompañamiento y vías de contacto. | `test_modo_protegido` |
| R11 | Los envíos son idempotentes por `clave_idem`. Un reintento tras caída no duplica alertas. | `test_envio_idempotente` |
| R12 | Los datos del hilo con la persona afectada y los check-in están cifrados y **compartimentados**: solo el rol `proteccion_humana` y la propia persona. Ni la autoridad superior accede. | `test_compartimentacion` |

---

## 3. Stack (decidido, no lo cambies)

- **Python 3.12**, tipado con anotaciones, `from __future__ import annotations`.
- **aiogram 3.x** para Telegram (async nativo, FSM incluida).
- **asyncpg** contra **PostgreSQL 16**. Sin ORM: SQL explícito y legible.
- **cryptography** (Fernet) para el hilo protegido.
- **pytest** + **pytest-asyncio** + **testcontainers** o Postgres de CI.
- **Docker Compose** para desarrollo local.
- Sin orquestadores externos (nada de n8n). El escalamiento es un worker propio.

**Todo componente debe ser autoalojable.** El municipio puede quedar obligado a
desplegar en infraestructura propia; no introduzcas dependencias SaaS en el
camino crítico.

Nombres de tablas, columnas, funciones y variables **en español**, consistentes
con la documentación del proyecto. Comentarios en español.

---

## 4. Estructura a crear

```
radar-bot/
├── CLAUDE.md
├── README.md
├── .env.example
├── .gitignore
├── requirements.txt
├── docker-compose.yml
├── Makefile
├── sql/
│   ├── 001_schema.sql
│   └── 002_seed_desarrollo.sql
├── radar/
│   ├── __init__.py
│   ├── config.py            # configuración por entorno
│   ├── db.py                # pool asyncpg, transacciones
│   ├── auditoria.py         # auditoría append-only, hash, cifrado
│   ├── textos.py            # plantillas de notificación
│   ├── teclados.py          # botones inline
│   ├── incidentes.py        # alta, clasificación provisoria, evidencia
│   ├── notificaciones.py    # encolado, envío, acuse
│   ├── escalamiento.py      # worker del reloj
│   ├── usuarios.py          # vinculación, roles, guardias
│   ├── handlers/
│   │   ├── __init__.py
│   │   ├── comunes.py       # /start, /vincular, /ayuda
│   │   ├── reportar.py      # FSM de reporte
│   │   ├── comite.py        # callbacks de acuse, escalar, asignar
│   │   └── persona.py       # SOS, check-in, estado
│   └── main.py              # arranque: bot + worker
└── tests/
    ├── conftest.py
    ├── test_reglas.py       # R1..R12
    ├── test_escalamiento.py
    └── test_flujos.py
```

---

## 5. Modelo de datos

El esquema está **decidido**. Está en `sql/001_schema.sql` del material adjunto;
si no lo tenés, generalo con exactamente estas entidades:

- `usuario` — con `roles rol_radar[]`, `telegram_id`, `codigo_vinculacion`
  de un solo uso, `modo_protegido boolean`.
- `guardia` — rol, usuario, titular/suplente, ventana `desde`/`hasta`.
- `incidente` — descripción, superficie, afectado, `bandera_riesgo`,
  `nivel nivel_intervencion` (N0..N5), estado, reportante, responsable.
- `evidencia` — `hash_sha256`, ruta, metadatos, `sellada_en`.
- `notificacion` — destinatario, plantilla, variables jsonb, prioridad,
  `requiere_acuse`, `paso`, `vence_en`, estado, `clave_idem UNIQUE`.
- `politica_escalamiento` — plantilla, paso, rol objetivo, espera en minutos.
- `mensaje_caso` — `cuerpo_cifrado bytea`, RLS por rol.
- `checkin` — estado de bienestar de la persona afectada.
- `registro_auditoria` — append-only por trigger.

**Enums:** `rol_radar`, `nivel_intervencion`, `prioridad_notif`,
`estado_notif`, `estado_incidente`.

### Cadenas de escalamiento (semilla obligatoria)

| Plantilla | Paso 0 | Paso 1 | Paso 2 |
|---|---|---|---|
| `RIESGO.C5_C6` | protección humana · 5 min | coord. crisis · 5 min | autoridad superior · 5 min |
| `PERSONA.SOS` | protección humana · 3 min | coord. crisis · 3 min | autoridad superior · 3 min |
| `INC.REPORTE_AGENTE` | coord. guardia · 30 min | coord. crisis · 30 min | — |
| `CIBER.E1_E2` | ciberseguridad · 10 min | coord. crisis · 10 min | — |

Agotada la cadena sin acuse: la notificación pasa a `vencida`, se emite
`INCUMPLIMIENTO` al rol `auditor` y queda marcada para el post-mortem.

---

## 6. Comportamiento del bot

### 6.1 Comandos

| Comando | Quién | Qué hace |
|---|---|---|
| `/start` | cualquiera | Saludo. Si no está vinculado, pide el código. |
| `/vincular <codigo>` | cualquiera | Asocia `telegram_id` al usuario. Código de un solo uso. |
| `/reportar` | agente, guardián | FSM de 4 pasos. |
| `/estado` | todos | Sus incidentes; la persona afectada ve el suyo en modo protegido. |
| `/guardia` | equipo | Quién está de turno ahora, por rol. |
| `/sos` | persona afectada | Alerta crítica, acuse en 3 min. |
| `/estoybien` `/necesitohablar` | persona afectada | Check-in. |
| `/ayuda` | todos | Comandos disponibles según rol. |

### 6.2 FSM de `/reportar`

```
1. ¿Qué viste?                    → texto libre
2. ¿Dónde?                        → botones: Instagram · Facebook · X · TikTok
                                     WhatsApp · Portal/medio · Otro
3. ¿A quién afecta?               → botones: una persona del municipio ·
                                     un servicio · la gestión en general ·
                                     no estoy seguro
4. ⚠️ ¿Involucra una amenaza o la publicación de datos personales
   (domicilio, teléfono, familia, rutinas)?  → Sí / No
5. (opcional) Adjuntar captura    → foto o documento; hash + sellado inmediato
```

Al confirmar: se crea el `incidente`, se sella la evidencia, se registra
auditoría y se dispara la notificación **en una sola transacción**.

- Casilla del paso 4 en **Sí** → categoría sugerida `C5/C6`, nivel `N3`,
  plantilla `RIESGO.C5_C6`, prioridad crítica.
- Casilla en **No** → nivel `N0`, plantilla `INC.REPORTE_AGENTE`.

En ambos casos la clasificación es **sugerida y provisoria**; una persona la
confirma o corrige después. El bot nunca clasifica en firme.

### 6.3 Alerta al Comité

Mensaje al grupo (`RADAR_CHAT_COMITE`) con teclado inline:

```
🔴 Incidente #482 · RIESGO PERSONAL
Se reportó amenaza o exposición de datos personales.
Nivel: N3 protección + N4 jurídico
Reportado por: A. Gómez (Dir. Com. Digital)

Acuse requerido en 5 minutos.

[✅ Acuso recibo]  [⏫ Escalar ahora]
[👤 Asignarme]     [📄 Ver caso]
```

Callbacks: `acuse:<notif_id>`, `escalar:<inc_id>`, `asignar:<inc_id>`,
`ver:<inc_id>`. Todos validan que quien pulsa esté vinculado y tenga rol.

Al acusar: se edita el mensaje agregando quién y a qué hora, se cancelan las
notificaciones hermanas pendientes del mismo paso y se detiene el reloj.

### 6.4 Worker de escalamiento

Loop cada 20 s (holgadamente menor que el escalón más corto de 3 min):

```
SELECT ... FROM notificacion
 WHERE requiere_acuse AND estado = 'enviada' AND vence_en < now()
 FOR UPDATE SKIP LOCKED
```

Para cada vencida: busca el paso siguiente en `politica_escalamiento`, resuelve
destinatarios por **guardia activa** (si no hay guardia, todos los usuarios con
ese rol), crea la nueva notificación y marca la anterior como `vencida`.
Si no hay paso siguiente: emite `INCUMPLIMIENTO`.

`FOR UPDATE SKIP LOCKED` es obligatorio: debe poder correr más de una instancia
sin duplicar alertas.

---

## 7. Orden de trabajo

Un bloque por vez. Al terminar cada uno: correr tests, hacer commit con mensaje
descriptivo en español, y **parar** a esperar mi aprobación.

| Bloque | Contenido | Criterio de aceptación |
|---|---|---|
| **0** | Esqueleto, `docker-compose`, `requirements.txt`, `.env.example`, `Makefile`, esquema SQL, migración aplicada. | `make up && make migrate` deja la base creada. `test_schema_sin_campos_prohibidos` y `test_auditoria_no_editable` en verde. |
| **1** | `config.py`, `db.py`, `auditoria.py`, `usuarios.py`. Vinculación por código. | Un usuario semilla se vincula; un desconocido es rechazado. R7 en verde. |
| **2** | `textos.py`, `teclados.py`, `notificaciones.py`. Encolado y envío con idempotencia. | R2 y R11 en verde. |
| **3** | `incidentes.py` + FSM `/reportar` con evidencia sellada. | Reporte completo crea incidente + evidencia con hash. R3, R5, R9 en verde. |
| **4** | `comite.py`: alerta con botones, acuse, asignación. | R1 en verde. |
| **5** | `escalamiento.py`: worker, cadena completa, incumplimiento. | Test de 3 escalones con reloj acelerado. Dos instancias del worker no duplican. |
| **6** | `persona.py`: SOS, check-in, estado, cifrado, compartimentación. | R10 y R12 en verde. |
| **7** | `README.md` de despliegue, script de alta de usuarios, prueba de caos (matar el worker a mitad de cadena). | Ninguna alerta perdida ni duplicada. |

---

## 8. Convenciones

- **Nada de secretos en el repo.** Todo por entorno, con `.env.example`
  documentado. `.gitignore` cubre `.env`, `evidencia/`, `__pycache__`.
- **Logs estructurados sin PII.** Nunca loguees el cuerpo de un reporte, el
  contenido de un mensaje protegido ni un identificador de Telegram junto a un
  nombre real.
- **SQL explícito**, parametrizado siempre. Prohibida la interpolación de
  cadenas en consultas.
- **Errores de Telegram no rompen el sistema:** si falla un envío, la
  notificación queda `fallida` y el worker reintenta. Una caída de la API de
  Telegram no puede perder un incidente ya registrado.
- Toda función pública con docstring breve en español explicando **por qué**,
  no qué. El qué se lee en el código.
- Si encontrás una contradicción entre esta instrucción y una regla de la
  sección 2, **para y preguntame**. No resuelvas por tu cuenta.

---

## 9. Lo que NO hay que construir

Aunque parezca natural agregarlo, queda explícitamente fuera:

- Scraping de redes sociales dentro del bot. La ingesta automatizada es otro
  módulo (E3.2) y se conecta después escribiendo en la misma tabla `incidente`.
- Clasificación automática en firme. El bot **sugiere**; una persona confirma.
- Cualquier respuesta, publicación o reporte automático hacia afuera.
- Listas nominales de cuentas a vigilar. La observación es por superficie y
  tema, no por persona.
- Panel web, app móvil, métricas de alcance. Fuera del alcance de esta pieza.

---

## 10. Datos de prueba

`sql/002_seed_desarrollo.sql` debe crear usuarios ficticios para cada rol, una
guardia activa y un incidente de ejemplo. Para las pruebas de flujo usá el caso
de práctica del proyecto: **doxxing de una trabajadora municipal tras una medida
administrativa impopular, alcance bajo, riesgo máximo.** Es el caso que mejor
expone si el sistema funciona: volumen mínimo, prioridad absoluta.

Ningún dato de prueba puede ser una persona real.
