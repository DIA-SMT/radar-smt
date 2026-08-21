# RADAR — Defensa institucional en el entorno digital

Sistema de apoyo a la decisión de la Subsecretaría de Prensa y Comunicación
Institucional, Municipalidad de San Miguel de Tucumán.

Lema: **Detectar señales. Comprender riesgos. Actuar con criterio.**

## Documentos rectores (leer antes de tocar dominio)

- `docs/Protocolo_RADAR_v1.pdf` — protocolo operativo v1.0 (taxonomía A–E, IRS/IRH, niveles N0–N5, evidencia E1–E6).
- `docs/RADAR_E3_arranque_desarrollo_v0.1.md` — especificación técnica de arranque (modelo de datos, notificaciones, IA, seguridad).
- `docs/marca/Manual Marca SMT .pdf` — identidad visual.

Ante contradicción, prevalece el documento rector. Lo que no tiene criterio
de aceptación no está especificado y no debe programarse todavía.

## Stack

- Next.js (App Router, TS, Tailwind v4) en Vercel.
- Supabase (proyecto `pjreaomfrrsnnsjcmcjr`): Postgres + RLS + Auth. Migraciones en `supabase/migrations/`, se aplican vía Management API.
- Taxonomía y constantes de dominio en `lib/radar/constants.ts`.
- IA (futura, sprint 6): OpenRouter tras un gateway único, con seudonimización obligatoria. La IA sugiere; **jamás ejecuta**.

## Reglas innegociables (fallar el build antes que violarlas)

1. **Ninguna acción automática con efecto externo, jamás.** Propiedad permanente del sistema, no una limitación del MVP.
2. **Sin columnas ni datos de adscripción política, ideología, geolocalización de individuos o biometría.** Tampoco cruces con padrones/legajos.
3. `registro_auditoria` es **append-only** (trigger + revoke). Toda mutación sensible audita en la misma transacción.
4. IRS e IRH son independientes: **nunca se promedian**. El riesgo tiene precedencia sobre la relevancia.
5. Las familias A1–A4 (expresión legítima) **nunca** exponen acciones jurídicas ni reporte de contenido.
6. Ninguna notificación transporta contenido agresivo (ni cuerpo, ni título, ni preview).
7. Datos de salud y `mensaje_caso`: compartimentados (solo Protección de Personas y la persona). Nunca salen a proveedores de IA.
8. Secretos fuera del repo (`.env.local`, env vars de Vercel). Service role key: solo servidor.
9. Marca: colores institucionales **no** se usan como semáforo de riesgo. Severidad = paleta propia + doble codificación (color + ícono + texto). Tipografía Poppins.
10. Español rioplatense institucional en UI y comunicación: sobrio, sin ironía, sin adjetivación política.

## Estado actual

- Sprint 0 en curso: esquema núcleo aplicado (11 tablas, RLS, auditoría inmutable).
- Pendiente Sprint 0: tests de restricciones estructurales en CI, seed de los seis casos ficcionalizados (requiere `RADAR_documento_rector_v1.md`, aún no está en el repo).
- Desarrollo solo con casos ficcionalizados hasta dictamen escrito de la Asesoría Letrada (transferencia internacional de datos, Ley 25.326).
