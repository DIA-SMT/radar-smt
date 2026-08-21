"use client";

import Image from "next/image";
import Link from "next/link";
import { useActionState } from "react";
import { ingresar } from "./actions";

export default function IngresoPage() {
  const [state, action, pending] = useActionState(ingresar, { error: null });

  return (
    <main className="flex min-h-screen items-center justify-center bg-smt-niebla px-6">
      <div className="w-full max-w-md">
        <div className="rise-in rounded-3xl border border-smt-borde bg-white p-8 shadow-[0_20px_60px_-30px_rgba(0,71,179,0.35)] sm:p-10">
          <div className="flex items-center gap-3">
            <Image src="/logo-smt.png" alt="Ciudad San Miguel de Tucumán" width={44} height={44} className="h-11 w-auto" />
            <div>
              <p className="text-lg font-extrabold leading-tight text-smt-gris">RADAR</p>
              <p className="text-xs text-slate-500">Acceso del equipo</p>
            </div>
          </div>

          <div className="mt-6 h-0.75 w-16 bg-smt-amarillo" />

          <form action={action} className="mt-6 space-y-4">
            <div>
              <label htmlFor="email" className="text-xs font-semibold text-smt-gris">
                Correo institucional
              </label>
              <input
                id="email"
                name="email"
                type="email"
                required
                autoComplete="email"
                className="mt-1.5 w-full rounded-xl border border-smt-borde bg-white px-4 py-2.5 text-sm outline-none transition focus:border-smt-azul focus:ring-2 focus:ring-smt-celeste/30"
              />
            </div>
            <div>
              <label htmlFor="password" className="text-xs font-semibold text-smt-gris">
                Contraseña
              </label>
              <input
                id="password"
                name="password"
                type="password"
                required
                autoComplete="current-password"
                className="mt-1.5 w-full rounded-xl border border-smt-borde bg-white px-4 py-2.5 text-sm outline-none transition focus:border-smt-azul focus:ring-2 focus:ring-smt-celeste/30"
              />
            </div>

            {state.error && (
              <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-xs font-medium text-red-700">
                {state.error}
              </p>
            )}

            <button
              type="submit"
              disabled={pending}
              className="w-full rounded-xl bg-smt-azul py-3 text-sm font-bold text-white transition hover:bg-smt-azul-profundo disabled:opacity-60"
            >
              {pending ? "Verificando…" : "Ingresar"}
            </button>
          </form>

          <p className="mt-6 text-center text-xs leading-relaxed text-slate-500">
            Acceso restringido al Comité RADAR y personal autorizado.
            <br />
            El 2FA obligatorio se habilita antes de producción (P7).
          </p>
        </div>

        <p className="mt-6 text-center text-xs text-slate-400">
          <Link href="/" className="hover:text-smt-azul">
            ← Volver al inicio
          </Link>
        </p>
      </div>
    </main>
  );
}
