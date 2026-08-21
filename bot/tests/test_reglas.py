"""Tests de las reglas no negociables (CLAUDE.md §2).

Bloque 0: R4 (auditoría append-only por trigger) y R6 (sin campos
prohibidos en el esquema). Los demás llegan con sus bloques.
"""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio

COLUMNAS_PROHIBIDAS = """
    SELECT table_name, column_name
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND (column_name ILIKE '%partid%'
         OR column_name ILIKE '%ideolog%'
         OR column_name ILIKE '%afinidad%'
         OR column_name ILIKE '%biometr%'
         OR column_name ILIKE '%geolocaliz%')
"""


async def test_schema_sin_campos_prohibidos(conexion):
    """R6: el esquema hace estructuralmente imposible el perfilado político."""
    filas = await conexion.fetch(COLUMNAS_PROHIBIDAS)
    assert filas == [], f"Columnas prohibidas presentes: {filas}"

    vigiladas = await conexion.fetchval(
        "SELECT count(*) FROM information_schema.tables "
        "WHERE table_schema = 'public' AND table_name = 'cuenta_vigilada'"
    )
    assert vigiladas == 0, "Existe la tabla cuenta_vigilada: la vigilancia nominal está prohibida"


async def test_auditoria_no_editable(conexion):
    """R4: la inmutabilidad la impone la base, no la aplicación."""
    await conexion.execute(
        "INSERT INTO registro_auditoria (accion, entidad, detalle) "
        "VALUES ('TEST', 'test', '{}'::jsonb)"
    )
    with pytest.raises(Exception, match="append-only"):
        await conexion.execute("UPDATE registro_auditoria SET accion = 'ALTERADO' WHERE accion = 'TEST'")
    with pytest.raises(Exception, match="append-only"):
        await conexion.execute("DELETE FROM registro_auditoria WHERE accion = 'TEST'")
