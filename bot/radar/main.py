"""Punto de arranque: bot + worker de escalamiento.

Esqueleto del Bloque 0. La lógica llega con los bloques 1–5; este módulo
solo verifica que el entorno mínimo esté configurado y lo dice claro.
"""

from __future__ import annotations

import os
import sys

REQUERIDAS = ("RADAR_BOT_TOKEN", "RADAR_CHAT_COMITE", "RADAR_DSN", "RADAR_CLAVE_MENSAJES")


def main() -> int:
    faltantes = [v for v in REQUERIDAS if not os.environ.get(v)]
    if faltantes:
        print(f"Configuración incompleta. Faltan: {', '.join(faltantes)}")
        return 1
    print("RADAR bot · Bloque 0: entorno verificado. La lógica del bot llega con el Bloque 1.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
