/**
 * Taxonomía y constantes del Protocolo RADAR v1.0.
 * Fuente: docs/Protocolo_RADAR_v1.pdf y docs/RADAR_E3_arranque_desarrollo_v0.1.md
 * Toda modificación acá debe estar respaldada por el documento rector.
 */

export const CODIGOS_INCIDENTE = {
  A1: { familia: "A", nombre: "Reclamo ciudadano genuino", respuesta: "Resolver el problema. Respuesta personalizada con plazo." },
  A2: { familia: "A", nombre: "Crítica política legítima", respuesta: "No intervenir, o respuesta institucional según relevancia." },
  A3: { familia: "A", nombre: "Opinión negativa", respuesta: "No intervenir." },
  A4: { familia: "A", nombre: "Sátira o parodia", respuesta: "No intervenir. Nunca reportar." },
  B1: { familia: "B", nombre: "Error o dato inexacto", respuesta: "Corrección informativa. Contacto directo si el emisor es identificable." },
  B2: { familia: "B", nombre: "Rumor", respuesta: "Monitoreo. Información verificable si crece." },
  B3: { familia: "B", nombre: "Desinformación", respuesta: "Contranarrativa fáctica. Prebunking." },
  B4: { familia: "B", nombre: "Contenido manipulado", respuesta: "Documentación verificable + reporte a plataforma." },
  B5: { familia: "B", nombre: "Filtración de información", respuesta: "Verificar autenticidad. Evaluación legal y de seguridad." },
  C1: { familia: "C", nombre: "Ataque reputacional", respuesta: "Según relevancia + evaluación legal." },
  C2: { familia: "C", nombre: "Hostigamiento", respuesta: "Resguardo + documentación + evaluación legal." },
  C3: { familia: "C", nombre: "Violencia política digital", respuesta: "Resguardo + respaldo institucional público + vía jurídica." },
  C4: { familia: "C", nombre: "Violencia de género digital", respuesta: "Resguardo + circuito especializado y reservado." },
  C5: { familia: "C", nombre: "Amenaza", respuesta: "Activación inmediata. Seguridad física + denuncia penal." },
  C6: { familia: "C", nombre: "Exposición de datos personales", respuesta: "Activación inmediata. Contención + remoción + denuncia." },
  C7: { familia: "C", nombre: "Suplantación de identidad", respuesta: "Reporte a plataforma + aviso público + evaluación legal." },
  D1: { familia: "D", nombre: "Campaña coordinada", respuesta: "Documentar. Habitualmente no responder. Evaluar reporte a plataforma." },
  D2: { familia: "D", nombre: "Denuncia masiva coordinada", respuesta: "Contacto con plataforma. Resguardo de la cuenta institucional." },
  E1: { familia: "E", nombre: "Cuenta institucional comprometida", respuesta: "Contención técnica + CERT.ar + comunicación." },
  E2: { familia: "E", nombre: "Ataque a sistemas o servicios", respuesta: "Protocolo técnico + CERT.ar." },
  E3: { familia: "E", nombre: "Phishing dirigido", respuesta: "Alerta interna + refuerzo + reporte." },
} as const;

export type CodigoIncidente = keyof typeof CODIGOS_INCIDENTE;

export const FAMILIAS = {
  A: "Expresión legítima",
  B: "Información falsa o manipulada",
  C: "Ataques a personas",
  D: "Operaciones coordinadas",
  E: "Ataques técnicos",
} as const;

/** IRS — Índice de Relevancia Social. Determina si corresponde respuesta pública. */
export const DIMENSIONES_IRS = {
  R1: { nombre: "Alcance efectivo local", peso: 0.15 },
  R2: { nombre: "Autoridad del emisor y amplificadores", peso: 0.2 },
  R3: { nombre: "Velocidad y aceleración", peso: 0.15 },
  R4: { nombre: "Transversalidad", peso: 0.15 },
  R5: { nombre: "Persistencia", peso: 0.1 },
  R6: { nombre: "Materialidad temática", peso: 0.15 },
  R7: { nombre: "Adhesión orgánica", peso: 0.1 },
} as const;

/** IRH — Índice de Riesgo Humano e Institucional. Determina protección y acción jurídica. */
export const DIMENSIONES_IRH = {
  H1: { nombre: "Integridad física" },
  H2: { nombre: "Privacidad" },
  H3: { nombre: "Capacidad de ejercicio de la función" },
  H4: { nombre: "Continuidad de servicios" },
  H5: { nombre: "Integridad de sistemas y cuentas" },
  H6: { nombre: "Confianza institucional" },
  H7: { nombre: "Contra-riesgo de la respuesta (alto = desaconseja responder)" },
} as const;

export const BANDAS_IRS = [
  { banda: "baja", rango: [0, 24] },
  { banda: "media", rango: [25, 49] },
  { banda: "alta", rango: [50, 74] },
  { banda: "critica", rango: [75, 100] },
] as const;

/** Niveles de intervención. NO son secuenciales: se activan en paralelo. */
export const NIVELES = {
  N0: { nombre: "Observación", conduce: "Análisis Digital", plazo: "24 h" },
  N1: { nombre: "Informativo", conduce: "Community management / área técnica", plazo: "4 h" },
  N2: { nombre: "Comunicacional", conduce: "Coordinación General", plazo: "24 h" },
  N3: { nombre: "Resguardo de personas", conduce: "Protección de Personas", plazo: "15 minutos" },
  N4: { nombre: "Jurídico", conduce: "Asuntos Jurídicos", plazo: "6 h" },
  N5: { nombre: "Crisis", conduce: "Comité pleno + Intendencia", plazo: "Inmediato" },
} as const;

export type Nivel = keyof typeof NIVELES;

/** Niveles de evidencia. Nada por debajo de E1/E2 funda una denuncia. */
export const NIVELES_EVIDENCIA = {
  E1: "Hecho comprobado, verificable de forma independiente",
  E2: "Vínculo público documentado, declarado por la propia persona u organización",
  E3: "Indicio: dato objetivo que sugiere sin probar",
  E4: "Inferencia derivada del análisis",
  E5: "Hipótesis a confirmar",
  E6: "No verificado. No funda ninguna decisión",
} as const;

/** Las trece preguntas previas a habilitar respuesta pública (N2+). */
export const TRECE_PREGUNTAS = [
  "¿Cuál es el objetivo concreto de responder?",
  "¿A quién está dirigida realmente la respuesta?",
  "¿Se busca convencer, informar, detener un daño, llevar tranquilidad o preservar una posición?",
  "¿El público relevante ya vio el contenido?",
  "¿La respuesta puede hacer que más personas lo conozcan?",
  "¿El emisor merece una respuesta directa?",
  "¿Es mejor responder a la narrativa sin mencionar la publicación?",
  "¿Existe información verificable disponible?",
  "¿Quién tiene mayor credibilidad para responder?",
  "¿Cuál es el momento adecuado?",
  "¿Qué tono corresponde?",
  "¿Qué canal debe utilizarse?",
  "¿Cómo sabremos si la intervención funcionó?",
] as const;

/**
 * Severidad operativa: paleta PROPIA, neutra respecto de la marca.
 * Doble codificación (color + ícono + texto): nunca depender solo del color.
 * El amarillo de marca (#f4dc00) NO se usa como alerta.
 */
export const SEVERIDAD = {
  baja: { etiqueta: "Baja", color: "#64748b", icono: "●" },
  media: { etiqueta: "Media", color: "#7c5bd1", icono: "◆" },
  alta: { etiqueta: "Alta", color: "#c2410c", icono: "▲" },
  critica: { etiqueta: "Crítica", color: "#b3123e", icono: "■" },
} as const;

export const LEMA = "Detectar señales. Comprender riesgos. Actuar con criterio.";
