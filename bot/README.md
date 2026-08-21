# RADAR · Bot de Telegram

Puerta de entrada y sistema de alerta de RADAR: convierte un reporte
informal en un incidente registrado, con evidencia sellada, responsable
asignado y un reloj de escalamiento que solo se detiene con acuse explícito.

Documentos de trabajo:
- `CLAUDE.md` — instrucción por bloques y reglas no negociables R1–R12.
- `CLAUDE_E3.2.md` — módulo de ingesta automática (fuentes → tabla `incidente`).

## Desarrollo

Requiere **Docker** (Desktop o Colima) y Python 3.12.

```bash
cp .env.example .env    # completar RADAR_BOT_TOKEN, RADAR_CHAT_COMITE, RADAR_CLAVE_MENSAJES
make up                 # Postgres 16
make migrate            # sql/001_schema.sql
make seed               # datos ficticios de desarrollo
make test               # reglas estructurales
make run                # bot + worker (bloques 1+)
```

## Estado

**Bloque 0 completado**: esqueleto, compose, esquema, seed y tests
estructurales. Los bloques 1–7 se ejecutan uno por vez, con aprobación
entre bloques (ver CLAUDE.md §7).
