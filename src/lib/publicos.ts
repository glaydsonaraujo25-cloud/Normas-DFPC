export const PUBLICOS = [
  ["automatico", "Identificar pela pergunta"], ["empresa", "Empresas"],
  ["cac", "CAC"], ["militar", "Militares do Exército"],
  ["policial", "Policiais militares / bombeiros militares"], ["todos", "Todos os públicos"],
] as const;
export type Publico = (typeof PUBLICOS)[number][0];
export function identificarPublico(pergunta: string): Publico {
  const q = pergunta.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  const candidatos = [
    ["policial", /policial|policiais|policias militares|bombeiro|\bpm\b/],
    ["militar", /militar|militares|soldado|sargento|subtenente|oficial do exercito/],
    ["cac", /\bcac\b|atirador|colecionador|cacador/],
    ["empresa", /empresa|sicoex|explosivo|cnae|atividade economica|sicovab/],
  ] as const;
  const encontrados = candidatos.filter(([, r]) => r.test(q)).map(([p]) => p);
  // Policial militar não é classificado como militar do Exército.
  const distintos = encontrados.filter((p) => !(p === "militar" && encontrados.includes("policial")));
  return distintos.length === 1 ? distintos[0] : "todos";
}
export function ehHistoricoNormativo(pergunta: string): boolean {
  const q = pergunta.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  return /\b(decreto|portaria|lei|ita)\b/.test(q) &&
    /vigente|vigencia|revog|alter|mudou|redacao|ainda.*usad|vale hoje/.test(q) &&
    !/\bart(?:igo)?[. ]*\d/.test(q);
}
