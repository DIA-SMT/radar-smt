import Image from "next/image";
import Link from "next/link";
import { FAMILIAS, LEMA, NIVELES } from "@/lib/radar/constants";

function RadarMotif() {
  return (
    <svg
      viewBox="0 0 400 400"
      className="w-full max-w-105 select-none"
      aria-hidden="true"
    >
      {[60, 110, 160].map((r) => (
        <circle
          key={r}
          cx="200"
          cy="200"
          r={r}
          fill="none"
          stroke="rgba(255,255,255,0.22)"
          strokeWidth="1"
        />
      ))}
      <circle cx="200" cy="200" r="185" fill="none" stroke="rgba(255,255,255,0.35)" strokeWidth="1.5" />
      <line x1="15" y1="200" x2="385" y2="200" stroke="rgba(255,255,255,0.12)" strokeWidth="1" />
      <line x1="200" y1="15" x2="200" y2="385" stroke="rgba(255,255,255,0.12)" strokeWidth="1" />
      <g className="radar-sweep">
        <path
          d="M 200 200 L 200 15 A 185 185 0 0 1 328 60 Z"
          fill="url(#sweep)"
        />
      </g>
      <defs>
        <linearGradient id="sweep" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="rgba(46,177,255,0.55)" />
          <stop offset="100%" stopColor="rgba(46,177,255,0)" />
        </linearGradient>
      </defs>
      <circle cx="264" cy="128" r="5" fill="#f4dc00" className="radar-blip" />
      <circle cx="150" cy="252" r="4" fill="#ffffff" className="radar-blip" style={{ animationDelay: "1.2s" }} />
      <circle cx="236" cy="286" r="3.5" fill="#2eb1ff" className="radar-blip" style={{ animationDelay: "2.1s" }} />
      <circle cx="200" cy="200" r="6" fill="#ffffff" />
    </svg>
  );
}

const QUE_NO_ES = [
  "No es un sistema de vigilancia de opositores ni de ciudadanos.",
  "No registra ni infiere ideología política de nadie.",
  "No habilita cuentas encubiertas ni recolección masiva de datos.",
  "No es una herramienta de campaña ni de comunicación partidaria.",
  "No obliga a responder: en la mayoría de los casos indica lo contrario.",
];

export default function Home() {
  return (
    <main className="min-h-screen bg-white">
      {/* ── Barra superior ─────────────────────────────── */}
      <header className="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
        <div className="flex items-center gap-3">
          <Image src="/logo-smt.png" alt="Ciudad San Miguel de Tucumán" width={40} height={40} className="h-10 w-auto" />
          <span className="hidden text-sm font-semibold tracking-wide text-smt-gris sm:block">
            RADAR
          </span>
        </div>
        <Link
          href="/ingreso"
          className="rounded-full bg-smt-azul px-5 py-2 text-sm font-semibold text-white transition hover:bg-smt-azul-profundo"
        >
          Ingresar
        </Link>
      </header>

      {/* ── Hero: banner azul como el protocolo ────────── */}
      <section className="mx-auto max-w-6xl px-6">
        <div className="relative overflow-hidden rounded-3xl bg-smt-azul text-white">
          <div className="grid items-center gap-8 p-8 sm:p-12 lg:grid-cols-[1.2fr_1fr] lg:p-16">
            <div className="rise-in">
              <p className="text-xs font-bold tracking-[0.25em] text-smt-celeste">
                PROTOCOLO OPERATIVO · MUNICIPALIDAD DE SAN MIGUEL DE TUCUMÁN
              </p>
              <h1 className="mt-4 text-5xl font-extrabold leading-none sm:text-7xl">
                RADAR
              </h1>
              <p className="mt-3 max-w-xl text-xl font-semibold leading-snug text-white sm:text-2xl">
                Defensa institucional en el entorno digital
              </p>
              <div className="mt-5 h-1 w-24 bg-smt-amarillo" />
              <p className="mt-6 max-w-xl text-sm leading-relaxed text-blue-100 sm:text-base">
                Identificación, diagnóstico y respuesta coordinada ante
                desinformación, campañas coordinadas y hostigamiento digital
                contra la gestión municipal.
              </p>
              <p className="mt-6 text-sm font-semibold italic text-smt-amarillo">
                {LEMA}
              </p>
            </div>
            <div className="hidden justify-center lg:flex">
              <RadarMotif />
            </div>
          </div>
        </div>
      </section>

      {/* ── El método en tres verbos ───────────────────── */}
      <section className="mx-auto max-w-6xl px-6 py-16">
        <div className="grid gap-6 md:grid-cols-3">
          {[
            {
              n: "01",
              t: "Detectar señales",
              d: "Todo evento recibe un código A–E antes de discutirse. La clasificación puede sugerirla una herramienta; la confirma siempre una persona.",
            },
            {
              n: "02",
              t: "Comprender riesgos",
              d: "Dos índices independientes que nunca se promedian: IRS mide cuánto importa la conversación; IRH mide qué riesgo genera el hecho.",
            },
            {
              n: "03",
              t: "Actuar con criterio",
              d: "Niveles N0–N5 en paralelo, con responsables únicos, plazos y fundamento registrado. No responder también es una decisión, y queda auditada.",
            },
          ].map((c, i) => (
            <div
              key={c.n}
              className="rise-in rounded-2xl border border-smt-borde bg-smt-niebla p-7"
              style={{ animationDelay: `${i * 0.12}s` }}
            >
              <p className="text-sm font-extrabold text-smt-celeste">{c.n}</p>
              <h2 className="mt-2 text-lg font-bold text-smt-gris">{c.t}</h2>
              <p className="mt-3 text-sm leading-relaxed text-slate-600">{c.d}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── Taxonomía y niveles ────────────────────────── */}
      <section className="mx-auto max-w-6xl px-6 pb-16">
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="rounded-2xl border border-smt-borde p-7">
            <h3 className="text-sm font-bold tracking-wide text-smt-azul">
              CINCO FAMILIAS DE INCIDENTE
            </h3>
            <div className="mt-4 h-0.75 w-16 bg-smt-amarillo" />
            <ul className="mt-5 space-y-3">
              {Object.entries(FAMILIAS).map(([k, v]) => (
                <li key={k} className="flex items-baseline gap-3 text-sm">
                  <span className="w-6 shrink-0 font-extrabold text-smt-celeste">{k}</span>
                  <span className="font-medium text-smt-gris">{v}</span>
                </li>
              ))}
            </ul>
            <p className="mt-5 text-xs leading-relaxed text-slate-500">
              La crítica política, la opinión negativa, el reclamo vecinal y la
              sátira son legítimos. Nunca habilitan acción jurídica ni pedido de
              baja de contenido.
            </p>
          </div>
          <div className="rounded-2xl border border-smt-borde p-7">
            <h3 className="text-sm font-bold tracking-wide text-smt-azul">
              NIVELES DE INTERVENCIÓN · NO SECUENCIALES
            </h3>
            <div className="mt-4 h-0.75 w-16 bg-smt-amarillo" />
            <ul className="mt-5 space-y-3">
              {Object.entries(NIVELES).map(([k, v]) => (
                <li key={k} className="flex items-baseline gap-3 text-sm">
                  <span className="w-8 shrink-0 font-extrabold text-smt-celeste">{k}</span>
                  <span className="font-medium text-smt-gris">{v.nombre}</span>
                  <span className="ml-auto shrink-0 text-xs text-slate-500">{v.plazo}</span>
                </li>
              ))}
            </ul>
            <p className="mt-5 text-xs leading-relaxed text-slate-500">
              Un caso puede exigir máxima protección y cero comunicación
              pública. Esa combinación es correcta: el riesgo tiene precedencia
              sobre la relevancia.
            </p>
          </div>
        </div>
      </section>

      {/* ── Qué no es ──────────────────────────────────── */}
      <section className="bg-smt-tinta py-14 text-white">
        <div className="mx-auto max-w-6xl px-6">
          <h3 className="text-sm font-bold tracking-[0.2em] text-smt-amarillo">
            QUÉ NO ES RADAR
          </h3>
          <ul className="mt-6 grid gap-x-10 gap-y-3 text-sm leading-relaxed text-blue-100 md:grid-cols-2">
            {QUE_NO_ES.map((q) => (
              <li key={q} className="flex gap-3">
                <span className="mt-0.5 shrink-0 font-bold text-smt-celeste">—</span>
                {q}
              </li>
            ))}
          </ul>
          <p className="mt-8 border-l-4 border-smt-amarillo pl-4 text-sm font-semibold">
            Ante duda sobre si hay riesgo para una persona: se actúa como si lo
            hubiera. Ante duda entre agresión y crítica legítima: se trata como
            crítica legítima.
          </p>
        </div>
      </section>

      {/* ── Pie ────────────────────────────────────────── */}
      <footer className="mx-auto flex max-w-6xl flex-col items-center gap-4 px-6 py-10 sm:flex-row sm:justify-between">
        <div className="flex items-center gap-3">
          <Image src="/logo-smt.png" alt="" width={32} height={32} className="h-8 w-auto" />
          <p className="text-xs text-slate-500">
            Subsecretaría de Prensa y Comunicación Institucional ·
            Municipalidad de San Miguel de Tucumán
          </p>
        </div>
        <p className="text-xs text-slate-400">Protocolo RADAR v1.0</p>
      </footer>
    </main>
  );
}
