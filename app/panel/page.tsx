import Image from "next/image";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { SEVERIDAD, NIVELES } from "@/lib/radar/constants";
import { salir } from "@/app/ingreso/actions";

export default async function PanelPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/ingreso");

  const [{ data: perfil }, { count: totalIncidentes }, { count: nivelesActivos }] =
    await Promise.all([
      supabase.from("perfil").select("nombre, rol").eq("id", user.id).single(),
      supabase.from("incidente").select("*", { count: "exact", head: true }),
      supabase
        .from("nivel_activacion")
        .select("*", { count: "exact", head: true })
        .eq("estado", "activo"),
    ]);

  const { data: incidentes } = await supabase
    .from("incidente")
    .select("numero, titulo, codigo_primario, estado, creado_en")
    .order("creado_en", { ascending: false })
    .limit(8);

  return (
    <main className="min-h-screen bg-smt-niebla">
      {/* ── Barra superior ─────────────────────────────── */}
      <header className="border-b border-smt-borde bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <div className="flex items-center gap-3">
            <Image src="/logo-smt.png" alt="Ciudad San Miguel de Tucumán" width={36} height={36} className="h-9 w-auto" />
            <div>
              <p className="text-sm font-extrabold leading-tight text-smt-gris">RADAR</p>
              <p className="text-[11px] text-slate-500">Sala de situación</p>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <div className="text-right">
              <p className="text-xs font-semibold text-smt-gris">
                {perfil?.nombre ?? user.email}
              </p>
              <p className="text-[11px] uppercase tracking-wide text-slate-500">
                {perfil?.rol?.replaceAll("_", " ") ?? "sin rol asignado"}
              </p>
            </div>
            <form action={salir}>
              <button className="rounded-full border border-smt-borde px-4 py-1.5 text-xs font-semibold text-smt-gris transition hover:border-smt-azul hover:text-smt-azul">
                Salir
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-6xl px-6 py-8">
        {/* ── Indicadores ──────────────────────────────── */}
        <section className="grid gap-4 sm:grid-cols-3">
          {[
            { label: "Incidentes registrados", valor: totalIncidentes ?? 0 },
            { label: "Niveles activos", valor: nivelesActivos ?? 0 },
            { label: "Acuses pendientes", valor: 0 },
          ].map((s) => (
            <div key={s.label} className="rounded-2xl border border-smt-borde bg-white p-5">
              <p className="text-3xl font-extrabold text-smt-azul">{s.valor}</p>
              <p className="mt-1 text-xs font-medium text-slate-500">{s.label}</p>
            </div>
          ))}
        </section>

        {/* ── Casos ────────────────────────────────────── */}
        <section className="mt-6 rounded-2xl border border-smt-borde bg-white p-6">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold tracking-wide text-smt-azul">CASOS RECIENTES</h2>
            <span className="rounded-full bg-smt-niebla px-3 py-1 text-[11px] font-semibold text-slate-500">
              Solo casos ficcionalizados hasta el dictamen jurídico
            </span>
          </div>
          <div className="mt-3 h-0.75 w-16 bg-smt-amarillo" />

          {incidentes && incidentes.length > 0 ? (
            <div className="mt-4 overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-smt-borde text-[11px] uppercase tracking-wide text-slate-400">
                    <th className="py-2 pr-4 font-semibold">Nº</th>
                    <th className="py-2 pr-4 font-semibold">Título</th>
                    <th className="py-2 pr-4 font-semibold">Código</th>
                    <th className="py-2 font-semibold">Estado</th>
                  </tr>
                </thead>
                <tbody>
                  {incidentes.map((i) => (
                    <tr key={i.numero} className="border-b border-smt-borde/60">
                      <td className="py-2.5 pr-4 font-bold text-smt-azul">#{i.numero}</td>
                      <td className="py-2.5 pr-4 font-medium text-smt-gris">{i.titulo}</td>
                      <td className="py-2.5 pr-4 font-extrabold text-smt-celeste">
                        {i.codigo_primario ?? "—"}
                      </td>
                      <td className="py-2.5 text-xs font-semibold uppercase tracking-wide text-slate-500">
                        {i.estado}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="mt-6 rounded-xl border border-dashed border-smt-borde bg-smt-niebla/60 p-8 text-center">
              <p className="text-sm font-semibold text-smt-gris">Sin incidentes registrados</p>
              <p className="mx-auto mt-2 max-w-md text-xs leading-relaxed text-slate-500">
                El Sprint 1 habilita el alta de incidentes y el formulario
                abierto para agentes municipales. El entorno opera con los seis
                casos ficcionalizados del documento rector hasta el dictamen de
                la Asesoría Letrada.
              </p>
            </div>
          )}
        </section>

        {/* ── Referencias operativas ───────────────────── */}
        <section className="mt-6 grid gap-4 lg:grid-cols-2">
          <div className="rounded-2xl border border-smt-borde bg-white p-6">
            <h3 className="text-sm font-bold tracking-wide text-smt-azul">
              SEVERIDAD · DOBLE CODIFICACIÓN
            </h3>
            <div className="mt-3 h-0.75 w-16 bg-smt-amarillo" />
            <p className="mt-4 text-xs leading-relaxed text-slate-500">
              La escala de severidad usa paleta propia, nunca los colores de
              marca: color + ícono + texto, para no depender del color bajo
              presión.
            </p>
            <ul className="mt-4 flex flex-wrap gap-3">
              {Object.entries(SEVERIDAD).map(([k, s]) => (
                <li
                  key={k}
                  className="flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs font-bold"
                  style={{ borderColor: s.color, color: s.color }}
                >
                  <span aria-hidden="true">{s.icono}</span>
                  {s.etiqueta}
                </li>
              ))}
            </ul>
          </div>

          <div className="rounded-2xl border border-smt-borde bg-white p-6">
            <h3 className="text-sm font-bold tracking-wide text-smt-azul">
              NIVELES DE INTERVENCIÓN
            </h3>
            <div className="mt-3 h-0.75 w-16 bg-smt-amarillo" />
            <ul className="mt-4 space-y-2.5">
              {Object.entries(NIVELES).map(([k, v]) => (
                <li key={k} className="flex items-baseline gap-3 text-xs">
                  <span className="w-7 shrink-0 font-extrabold text-smt-celeste">{k}</span>
                  <span className="font-semibold text-smt-gris">{v.nombre}</span>
                  <span className="ml-auto text-slate-400">{v.conduce}</span>
                </li>
              ))}
            </ul>
          </div>
        </section>
      </div>
    </main>
  );
}
