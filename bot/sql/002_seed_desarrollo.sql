-- ═══════════════════════════════════════════════════════════════════
-- RADAR · Bot — Seed de desarrollo
-- Personas ficticias (ninguna real), una guardia activa y el caso de
-- práctica del proyecto: doxxing de una trabajadora municipal tras una
-- medida administrativa impopular. Alcance bajo, riesgo máximo.
-- ═══════════════════════════════════════════════════════════════════

INSERT INTO usuario (nombre, area, roles, codigo_vinculacion, modo_protegido) VALUES
  ('Agente de Prueba',        'Dirección de Tránsito',              '{agente}',              'VINC-AGENTE-001',  false),
  ('Guardiana de Prueba',     'Comunicación Digital',               '{guardian,analista}',   'VINC-GUARDIA-001', false),
  ('Coordinación de Guardia', 'Subsecretaría de Prensa',            '{coordinador_guardia}', 'VINC-COORDG-001',  false),
  ('Coordinación de Crisis',  'Subsecretaría de Prensa',            '{coordinador_crisis}',  'VINC-CRISIS-001',  false),
  ('Referente Jurídico',      'Asuntos Jurídicos',                  '{juridico}',            'VINC-JURID-001',   false),
  ('Protección Humana',       'RRHH / Salud Ocupacional',           '{proteccion_humana}',   'VINC-PROT-001',    false),
  ('Ciberseguridad',          'Sistemas',                           '{ciberseguridad}',      'VINC-CIBER-001',   false),
  ('Autoridad Superior',      'Intendencia',                        '{autoridad_superior}',  'VINC-AUTOR-001',   false),
  ('Auditoría',               'Auditoría Interna',                  '{auditor}',             'VINC-AUDIT-001',   false),
  ('Trabajadora Afectada',    'Dirección de Habilitaciones',        '{persona_afectada}',    'VINC-PERSONA-001', true);

-- Guardia activa 24/7 esta semana: protección humana y coordinación.
INSERT INTO guardia (rol, usuario_id, es_suplente, desde, hasta)
SELECT 'proteccion_humana', id, false, now() - interval '1 day', now() + interval '6 days'
  FROM usuario WHERE codigo_vinculacion = 'VINC-PROT-001';
INSERT INTO guardia (rol, usuario_id, es_suplente, desde, hasta)
SELECT 'coordinador_guardia', id, false, now() - interval '1 day', now() + interval '6 days'
  FROM usuario WHERE codigo_vinculacion = 'VINC-COORDG-001';
INSERT INTO guardia (rol, usuario_id, es_suplente, desde, hasta)
SELECT 'coordinador_crisis', id, true, now() - interval '1 day', now() + interval '6 days'
  FROM usuario WHERE codigo_vinculacion = 'VINC-CRISIS-001';

-- Caso de práctica: volumen mínimo, prioridad absoluta.
INSERT INTO incidente
  (titulo, descripcion, superficie, afectado_texto, persona_afectada_id,
   categoria_sugerida, bandera_riesgo, nivel, estado, reportado_por, origen)
SELECT
  'Exposición de datos de trabajadora municipal',
  'Tras la clausura de un local, una cuenta publicó el nombre completo, la '
  'foto y referencias al domicilio de la inspectora actuante, con mensajes '
  'que sugieren "ir a buscarla". Interacciones bajas hasta ahora.',
  'facebook',
  'Una persona del municipio',
  (SELECT id FROM usuario WHERE codigo_vinculacion = 'VINC-PERSONA-001'),
  'C6',
  true,
  'N3',
  'registrado',
  (SELECT id FROM usuario WHERE codigo_vinculacion = 'VINC-AGENTE-001'),
  'telegram';

-- La evidencia del caso: hash ficticio sellado en la ingesta.
INSERT INTO evidencia (incidente_id, tipo, hash_sha256, url_origen, metadatos, aportada_por)
SELECT
  i.id, 'captura',
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  'https://ejemplo.invalido/publicacion-ficticia',
  '{"nota": "caso ficcionalizado de desarrollo"}'::jsonb,
  (SELECT id FROM usuario WHERE codigo_vinculacion = 'VINC-AGENTE-001')
FROM incidente i
ORDER BY i.creado_en DESC LIMIT 1;
