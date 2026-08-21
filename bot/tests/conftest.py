"""Fixtures compartidas: conexión a la base de desarrollo.

Los tests estructurales corren contra la base que indique RADAR_DSN
(por defecto, el Postgres de docker-compose). Si no hay base accesible,
se saltean con un mensaje claro en lugar de fallar en falso.
"""

from __future__ import annotations

import os

import asyncpg
import pytest
import pytest_asyncio

DSN = os.environ.get("RADAR_DSN", "postgresql://radar:radar_dev@localhost:5432/radar")


@pytest_asyncio.fixture
async def conexion():
    try:
        con = await asyncpg.connect(DSN, timeout=5)
    except Exception as exc:  # noqa: BLE001 — cualquier fallo de conexión implica saltear
        pytest.skip(f"Base no accesible en RADAR_DSN ({exc}). Levantala con: make up && make migrate")
        return
    yield con
    await con.close()
