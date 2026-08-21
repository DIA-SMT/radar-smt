# RADAR · Runbook de credenciales + instrucción del agente

**Parte A** — lo que tenés que hacer vos, con enlaces y pasos exactos.
**Parte B** — la instrucción para Claude Code, que hace todo lo demás.

> **Advertencia de vigencia.** Los enlaces y precios son al corte de mi
> información (mayo 2026). Este mercado se mueve rápido: los portales de
> desarrollador de Meta, TikTok y X cambian de nombre y de requisitos varias
> veces por año. Verificá cada URL al abrirla y, si algo no coincide, buscá el
> portal de desarrolladores oficial de esa plataforma antes de asumir que el
> servicio desapareció.

---

# Parte A — Lo que no puede hacer un agente

Conviene decirlo de entrada para que no pierdas tiempo: **ningún agente puede
crear cuentas, aceptar términos de servicio, hacer verificación de identidad,
cargar una tarjeta ni firmar un acuerdo de datos en tu nombre.** No es una
limitación técnica que se pueda saltar: esos trámites requieren una persona
jurídicamente responsable, y en este caso esa persona representa a un municipio.

Lo que sí hace el agente, y es la mayor parte del trabajo: escribir los
conectores, verificar que cada credencial funcione, normalizar los datos a la
tabla `incidente`, manejar reintentos y límites de tasa, y dejar los tests.

Tu parte son unas dos horas de trámites, más los tiempos de aprobación de
terceros.

---

## A.1 Orden recomendado

Lo primero desbloquea el bot; lo último puede tardar semanas y no conviene
esperarlo.

| # | Servicio | Tiempo tuyo | Espera de aprobación | Costo |
|---|---|---|---|---|
| 1 | Telegram BotFather | 5 min | ninguna | 0 |
| 2 | PostgreSQL | 15 min | ninguna | 0–25 USD/mes |
| 3 | Google Alerts + Talkwalker Alerts | 20 min | ninguna | 0 |
| 4 | Perspective API | 20 min | 1–3 días | 0 |
| 5 | Apify | 15 min | ninguna | ~50 USD/mes |
| 6 | OpenRouter | 10 min | ninguna | según uso |
| 7 | TikTok Research API | 40 min | 2–8 semanas | 0 |
| 8 | Meta Content Library | 40 min | 4–12 semanas | 0 |
| 9 | Business Manager municipal | reunión interna | interna | 0 |
| 10 | Escucha licenciada (Brand24/Awario) | demo + compra | días | 79–399 USD/mes |
| 11 | Sellado de tiempo con validez legal | consulta jurídica | variable | variable |

Los pasos 1 a 6 se hacen en una tarde y ya te dan un sistema funcionando.

---

## A.2 Telegram — BotFather

**Dónde:** abrí Telegram y buscá `@BotFather`, o entrá a https://t.me/BotFather

```
/newbot
→ nombre visible:  RADAR SMT
→ usuario:         radar_smt_bot     (debe terminar en "bot")
```

Te devuelve un token con forma `7123456789:AAH...`. **Ese token es una
credencial de producción**: quien lo tenga controla el bot. No lo pegues en un
chat ni en el repositorio.

Configuración adicional recomendada, en el mismo BotFather:

```
/setprivacy   → Disable   (para que el bot lea comandos en el grupo del Comité)
/setcommands  → pegar:
```

```
start - Iniciar
vincular - Vincular tu cuenta con el código recibido
reportar - Reportar un incidente
estado - Ver el estado de tus casos
guardia - Ver quién está de turno
sos - Pedir asistencia inmediata
ayuda - Ver comandos disponibles
```

**Después:** creá el grupo privado del Comité, agregá el bot como
administrador, y obtené el `chat_id` reenviando cualquier mensaje del grupo a
`@userinfobot`. Es un número negativo que empieza con `-100`.

```env
RADAR_BOT_TOKEN=7123456789:AAH...
RADAR_CHAT_COMITE=-1001234567890
```

---

## A.3 PostgreSQL

Dos caminos según lo que decida Sistemas.

**Autoalojado** (recomendado si el municipio tiene infraestructura): el
`docker-compose.yml` del proyecto ya lo levanta. Sin trámite.

**Gestionado:** https://supabase.com/dashboard o Neon (https://neon.tech).
Plan gratuito suficiente para el piloto.

Advertencia que ya está en la E3.0: si el alojamiento en nube extranjera no
supera la revisión jurídica, hay que poder desplegar en infraestructura propia.
Por eso todo el stack es autoalojable.

```env
RADAR_DSN=postgresql://radar:clave@localhost:5432/radar
```

Y la clave de cifrado del hilo protegido:

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

```env
RADAR_CLAVE_MENSAJES=...
```

---

## A.4 Google Alerts y Talkwalker Alerts — gratis, RSS

**Google Alerts:** https://www.google.com/alerts
**Talkwalker Alerts:** https://www.talkwalker.com/alerts

Creá una alerta por término y elegí **entrega por RSS** (Google Alerts lo
ofrece en "Opciones → Entregar a → Fuente RSS"). Copiá cada URL de feed.

Términos iniciales sugeridos para SMT:

```
"San Miguel de Tucumán" municipalidad
"Municipalidad de San Miguel de Tucumán"
intendenta Tucumán
"SMT" municipio Tucumán
```

Más los nombres de funcionarios cuya exposición pública el municipio decida
monitorear. Criterio: cargos con vocería, no la plantilla completa.

```env
RADAR_FEEDS_RSS=https://www.google.com/alerts/feeds/...,https://...
```

Esto cubre medios y web indexada, que es donde se mide la permeabilidad (R4 del
IRS). No cubre redes sociales.

---

## A.5 Perspective API — clasificación de toxicidad, gratis

**Documentación:** https://developers.perspectiveapi.com/s/docs-get-started
**Formulario de acceso:** https://developers.perspectiveapi.com/s/request-access

Pasos:

1. Creá o usá un proyecto en https://console.cloud.google.com
2. Completá el formulario de acceso (uso institucional, moderación de
   comentarios en cuentas oficiales de un municipio). Suele aprobarse en días.
3. Aprobado: **APIs y servicios → Credenciales → Crear credenciales → Clave de
   API**, y restringila a Perspective Comment Analyzer API.

Atributos a pedir en español: `TOXICITY`, `SEVERE_TOXICITY`, `INSULT`,
`THREAT`, `IDENTITY_ATTACK`, con `languages: ["es"]`.

```env
RADAR_PERSPECTIVE_KEY=AIza...
```

**Cómo usarlo, que importa más que la clave:** el puntaje es un **indicio
(nivel E3)**, no un hecho. Nunca funda una decisión por sí solo, y `THREAT`
alto crea un incidente para revisión humana, no una acción. Los clasificadores
en español rioplatense fallan con ironía, modismos y agresión indirecta en las
dos direcciones.

---

## A.6 Apify — recolección de contenido público

**Registro:** https://console.apify.com/sign-up
**Docs de la API:** https://docs.apify.com/api/v2
**Tienda de actores:** https://apify.com/store

Sacá el token en **Settings → Integrations → Personal API tokens**.

Actores útiles (buscalos en la tienda; los IDs cambian de dueño, así que
verificá reputación y última actualización antes de usar uno):

- Twitter/X Scraper — búsqueda por término
- Instagram Scraper — perfiles y publicaciones públicas
- TikTok Scraper — por hashtag o término
- Facebook Posts Scraper — páginas públicas

Presupuesto: plan de ~49 USD/mes más consumo. Poné un **límite de gasto
mensual** en la cuenta antes de la primera corrida; un actor mal configurado en
loop se come el presupuesto en una noche.

```env
RADAR_APIFY_TOKEN=apify_api_...
RADAR_APIFY_ACTOR_X=...
```

---

## A.7 OpenRouter — capa de IA

**Claves:** https://openrouter.ai/keys
**Docs:** https://openrouter.ai/docs
**Modelos y precios:** https://openrouter.ai/models

Configurá:

- Límite de gasto por clave, en el panel.
- En cada llamada, la política de proveedor con `data_collection: "deny"`.

```env
RADAR_OPENROUTER_KEY=sk-or-v1-...
```

**Bloqueo vigente de la E3.0 §1:** esto no se conecta con datos reales hasta que
la Asesoría Letrada dictamine sobre el circuito de seudonimización. Hasta
entonces, solo los seis casos ficcionalizados. El agente puede construir todo el
gateway igual; simplemente no se le apunta a datos productivos.

---

## A.8 TikTok Research API — gratis, con aprobación

**Producto:** https://developers.tiktok.com/products/research-api/
**Portal:** https://developers.tiktok.com

Requiere solicitud institucional. Históricamente estuvo restringida a
investigadores académicos de ciertas regiones y fue ampliándose; verificá los
requisitos vigentes antes de invertir tiempo en la solicitud.

En la justificación, describí el objeto real: gestión de incidentes de
desinformación y protección de personal municipal. **No la presentes como
monitoreo de ciudadanos** — además de ser inexacto respecto de lo que diseñamos,
es motivo directo de rechazo.

---

## A.9 Meta Content Library — gratis, aprobación lenta

**Info:** https://transparency.meta.com/researchtools/meta-content-library
**Docs:** https://developers.facebook.com/docs/content-library-and-api/

Da acceso a contenido público de páginas y cuentas públicas de Facebook e
Instagram. La aprobación es lenta y ha estado orientada a instituciones
académicas; para un municipio conviene evaluar una solicitud conjunta con una
universidad local. **Iniciala igual y seguí sin ella**: si sale, suma; si no,
el sistema funciona.

---

## A.10 Business Manager municipal — el que más rinde

No es un trámite externo. Es pedirle a la Subsecretaría que te agregue como
usuario en el Business Manager que **ya existe** si el municipio publica en
Facebook e Instagram.

**Dónde:** https://business.facebook.com → Configuración → Usuarios
**Rol:** analista, solo lectura. No pidas administrador.

**Después:** creás una app en https://developers.facebook.com/apps para obtener
tokens de acceso a los comentarios y menciones de las cuentas propias.

Esto te da lo que ninguna herramienta externa cubre bien: **los comentarios en
las publicaciones del propio municipio**, que es donde aterriza la mayor parte
del hostigamiento real. Es una reunión, no un desarrollo, y rinde más que
cualquier suscripción.

```env
RADAR_META_APP_ID=...
RADAR_META_APP_SECRET=...
RADAR_META_PAGE_TOKEN=...
```

---

## A.11 Escucha licenciada

**Brand24:** https://brand24.com · 79–399 USD/mes
**Awario:** https://awario.com · 29–399 USD/mes
**Determ:** https://determ.com · 100–400 USD/mes

Todas tienen prueba gratuita y API en los planes intermedios. Pedí demo con tus
términos reales de SMT antes de comprar: la diferencia de cobertura en español
regional entre proveedores es grande y no se ve en la web comercial.

Mi sugerencia: **dos semanas de prueba con Awario y Brand24 en paralelo**, con
los mismos términos, y comprás el que más menciones locales reales devuelva.

---

## A.12 Sellado de tiempo con validez legal

Para desarrollo alcanza un TSA RFC 3161 público como https://freetsa.org

Para producción es una **decisión jurídica, no técnica**: qué autoridad de
sellado tiene reconocimiento ante la justicia de Tucumán. Está listado como
decisión abierta #5 en la E3.0 y bloquea el sprint 3. Preguntale a la Asesoría
Letrada antes de elegir proveedor; rehacer la cadena de custodia después es
caro y puede comprometer casos ya documentados.

---

## A.13 `.env` consolidado

```env
# ── Núcleo (bloquea todo) ──────────────────────────────────
RADAR_BOT_TOKEN=
RADAR_CHAT_COMITE=
RADAR_DSN=postgresql://radar:clave@localhost:5432/radar
RADAR_CLAVE_MENSAJES=
RADAR_ENTORNO=desarrollo

# ── Ingesta ────────────────────────────────────────────────
RADAR_FEEDS_RSS=
RADAR_PERSPECTIVE_KEY=
RADAR_APIFY_TOKEN=
RADAR_APIFY_ACTOR_X=

# ── Meta (si se consigue el Business Manager) ──────────────
RADAR_META_APP_ID=
RADAR_META_APP_SECRET=
RADAR_META_PAGE_TOKEN=

# ── IA (bloqueada hasta dictamen jurídico) ─────────────────
RADAR_OPENROUTER_KEY=
RADAR_IA_HABILITADA=false

# ── Evidencia ──────────────────────────────────────────────
RADAR_DIR_EVIDENCIA=./evidencia
RADAR_TSA_URL=https://freetsa.org/tsr
```

---

# Parte B — Instrucción para Claude Code

> Guardá esto como `CLAUDE_E3.2.md` en la raíz del repo, junto al `CLAUDE.md`
> del bot. Arrancá con: **"Leé CLAUDE.md y CLAUDE_E3.2.md. Ejecutá el Bloque I
> del E3.2 y pará."**

## B.1 Contexto

El bot RADAR (ver `CLAUDE.md`) ya registra incidentes reportados por personas.
Este módulo agrega **fuentes automáticas** que escriben en la misma tabla
`incidente`. El bot no cambia: sigue siendo el que alerta y escala.

**Todas las reglas de `CLAUDE.md` §2 siguen vigentes.** Especialmente R8
(ninguna acción automática con efecto externo) y R6 (sin listas nominales de
personas vigiladas).

## B.2 Reglas propias de la ingesta

| # | Regla | Test |
|---|---|---|
| I1 | **Ninguna credencial se pide interactivamente ni se escribe en el repo.** Todo desde entorno. Si falta una variable, el conector se desactiva con un log claro y el resto del sistema sigue andando. | `test_conector_sin_credencial_se_desactiva` |
| I2 | Cada conector normaliza a un dataclass `MencionCruda` común antes de tocar la base. Nada de lógica específica de plataforma más allá del conector. | `test_normalizacion_uniforme` |
| I3 | **Deduplicación obligatoria** por hash de contenido + URL. Cinco fuentes van a traer la misma mención. | `test_deduplicacion_entre_fuentes` |
| I4 | Toda mención se sella (hash SHA-256 + timestamp) en la ingesta, antes de cualquier procesamiento. | `test_sellado_en_ingesta` |
| I5 | El puntaje de toxicidad se guarda con **nivel de evidencia E3** y nunca dispara una acción por sí solo: crea un incidente en estado `registrado` para revisión humana. | `test_toxicidad_no_decide` |
| I6 | **Búsqueda por término y superficie, nunca por lista de cuentas.** El módulo no acepta una configuración de "cuentas a seguir". | `test_sin_configuracion_por_cuenta` |
| I7 | Límite de gasto y de tasa por conector, con corte duro. Un conector que supera el presupuesto se desactiva y notifica. | `test_corte_por_presupuesto` |
| I8 | Umbral de creación de incidente configurable y **conservador por defecto**. Un grupo del Comité que suena 100 veces por día se silencia en una semana. | `test_umbral_configurable` |

## B.3 Estructura a agregar

```
radar/
├── ingesta/
│   ├── __init__.py
│   ├── base.py              # MencionCruda, ConectorBase, registro de conectores
│   ├── normalizador.py      # crudo → Mencion → (umbral) → Incidente
│   ├── deduplicador.py
│   ├── toxicidad.py         # Perspective API
│   ├── programador.py       # loop asyncio, por conector, con backoff
│   └── conectores/
│       ├── rss.py           # Google/Talkwalker Alerts
│       ├── apify.py         # X, IG, TikTok, FB público
│       ├── meta.py          # comentarios de cuentas propias
│       ├── tiktok_research.py
│       └── escucha.py       # Brand24/Awario, según lo contratado
├── ia/
│   ├── gateway.py           # única salida a OpenRouter
│   ├── seudonimizador.py    # PII fuera antes del egreso
│   └── esquemas.py          # JSON Schema de salida por agente
└── herramientas/
    └── verificar_credenciales.py   # ← ejecutable, ver B.5
```

## B.4 Contrato común

```python
@dataclass(frozen=True)
class MencionCruda:
    fuente: str              # rss | apify_x | meta | tiktok | escucha
    id_externo: str
    url: str | None
    texto: str
    autor_seudonimo: str     # NUNCA el handle real fuera de evidencia
    publicado_en: datetime
    metricas: dict[str, int] # alcance, interacciones, si están disponibles
    recolectado_en: datetime
    hash_contenido: str
```

```python
class ConectorBase(ABC):
    nombre: str
    intervalo_segundos: int

    @abstractmethod
    def disponible(self) -> bool:
        """False si falta credencial. No lanza excepción: se desactiva."""

    @abstractmethod
    async def recolectar(self, desde: datetime) -> AsyncIterator[MencionCruda]:
        ...
```

## B.5 Verificador de credenciales — construilo primero

`python -m radar.herramientas.verificar_credenciales` debe:

1. Leer el `.env`.
2. Por cada credencial presente, hacer **una llamada real mínima** de prueba.
3. Imprimir una tabla: servicio · configurado · responde · cuota/plan detectado.
4. Para lo que falta, imprimir la URL exacta donde obtenerlo.
5. Salir con código 0 aunque falten credenciales opcionales; **solo el núcleo
   (bot, base de datos, clave de cifrado) es bloqueante**.

Es lo primero que hay que construir: convierte el trámite en un checklist
verificable en lugar de una serie de suposiciones.

## B.6 Orden de bloques

| Bloque | Contenido | Aceptación |
|---|---|---|
| **I** | `base.py`, `normalizador.py`, `deduplicador.py`, verificador de credenciales. | Verificador corre y reporta correctamente con `.env` incompleto. I1, I2, I3 en verde. |
| **II** | Conector RSS. | Feed real produce menciones deduplicadas y selladas. |
| **III** | `toxicidad.py` + umbral de creación de incidente. | Comentario tóxico de prueba crea incidente; el bot alerta al Comité. I5, I8 en verde. |
| **IV** | Conector Apify con corte por presupuesto. | I7 en verde. Costo simulado supera el tope y desactiva el conector. |
| **V** | Conector Meta (solo si hay tokens) + `escucha.py` según proveedor contratado. | Conector inactivo sin credencial, sin romper el resto. |
| **VI** | `ia/`: seudonimizador, esquemas, gateway. **Con `RADAR_IA_HABILITADA=false` por defecto.** | Ningún payload de salida contiene DNI, domicilio, teléfono ni nombre real, verificado sobre los seis casos ficcionalizados. |
| **VII** | `programador.py`: loop de todos los conectores, backoff, observabilidad. | Caída de un conector no afecta a los demás. |

## B.7 Lo que no hay que construir

- Configuración de "cuentas a seguir". No existe esa pantalla ni esa tabla.
- Acceso a grupos cerrados, perfiles privados o contenido no público.
- Publicación, respuesta o reporte automático hacia plataformas.
- Clasificación en firme: todo es sugerencia con nivel de evidencia.
- Cruce de menciones con padrones, bases de contribuyentes o legajos.

Si una tarea que te pido parece requerir alguno de estos puntos, **para y
preguntame** antes de implementarla.
