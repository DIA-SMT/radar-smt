# RADAR

**Defensa institucional en el entorno digital** — Municipalidad de San Miguel de Tucumán.

Identificación, diagnóstico y respuesta coordinada ante desinformación,
campañas coordinadas y hostigamiento digital contra la gestión municipal.

> Detectar señales. Comprender riesgos. Actuar con criterio.

## Stack

| Capa | Tecnología |
|---|---|
| Frontend | Next.js (App Router) + TypeScript + Tailwind CSS v4 |
| Base de datos / Auth | Supabase (Postgres 17, RLS, auditoría append-only) |
| Hosting | Vercel |
| IA (sprint 6) | OpenRouter tras gateway único con seudonimización |

## Desarrollo

```bash
cp .env.example .env.local   # completar claves de Supabase
npm install
npm run dev
```

Migraciones en `supabase/migrations/`. Documentos rectores en `docs/`.

## Principio operativo

La IA sugiere. Una persona con competencia institucional decide.
Ninguna acción automática con efecto externo, jamás.
