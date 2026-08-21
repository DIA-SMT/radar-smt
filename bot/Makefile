# RADAR · Bot — tareas de desarrollo
# Requiere Docker Desktop (o Colima) corriendo.

COMPOSE := docker compose
PSQL    := $(COMPOSE) exec -T db psql -U radar -d radar -v ON_ERROR_STOP=1

.PHONY: up migrate seed test run down logs

up:
	$(COMPOSE) up -d db
	@echo "Postgres 16 arriba. Siguiente: make migrate"

migrate:
	$(PSQL) < sql/001_schema.sql
	@echo "Esquema 001 aplicado."

seed:
	$(PSQL) < sql/002_seed_desarrollo.sql
	@echo "Seed de desarrollo aplicado."

test:
	python -m pytest tests/ -v

run:
	$(COMPOSE) up --build bot

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f bot
