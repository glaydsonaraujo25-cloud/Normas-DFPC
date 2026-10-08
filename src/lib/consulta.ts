export type ContextoEmpresa = {
  publico: "empresa" | "todos";
  produto: string;
  atividade: string;
  registro: string;
  detalhes: string;
  data: string;
};
export const hoje = () =>
  new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
export const contextoInicial = (): ContextoEmpresa => ({
  publico: "empresa",
  produto: "todos",
  atividade: "todos",
  registro: "nao_informado",
  detalhes: "",
  data: hoje(),
});
export const PRODUTOS = [
  ["todos", "Identificar pela pergunta"],
  ["armas", "Armas de fogo"],
  ["municoes", "Munições"],
  ["explosivos", "Explosivos"],
  ["quimicos", "Produtos químicos"],
  ["pirotecnicos", "Pirotécnicos"],
  ["blindagem", "Blindagem e proteção balística"],
  ["menos_letais", "Menor potencial ofensivo"],
  ["outros", "Outros produtos"],
] as const;
export const ATIVIDADES = [
  ["todos", "Identificar pela pergunta"],
  ["registro", "Registro / apostilamento"],
  ["fabricacao", "Fabricação"],
  ["comercio", "Comércio"],
  ["aquisicao", "Aquisição"],
  ["transporte", "Transporte"],
  ["armazenagem", "Armazenagem"],
  ["utilizacao", "Utilização / prestação de serviço"],
  ["importacao", "Importação"],
  ["exportacao", "Exportação"],
  ["fiscalizacao", "Fiscalização / processo administrativo"],
] as const;
export type Fonte = {
  trecho_id: number | string;
  norma_id: string;
  titulo: string;
  dispositivo: string;
  conteudo: string;
  pagina: number | null;
  relevancia: number;
  status: string;
  ultima_verificacao: string | null;
  dispositivo_id: string | null;
  texto_literal: string | null;
  status_dispositivo: string | null;
  literal_conferido: boolean;
  vigencia_inicio: string | null;
  vigencia_fim: string | null;
  fonte_oficial: string | null;
  nome_arquivo: string | null;
  sha256: string | null;
  tipo_conteudo: string;
  relacoes: Array<{
    tipo: string;
    norma_relacionada: string;
    dispositivo?: string;
    observacoes?: string;
  }>;
};
export type SecaoOrientacao = {
  titulo: string;
  texto: string;
  dispositivo_ids: string[];
};
export type Orientacao = {
  id: string;
  titulo: string;
  produto: string;
  atividade: string;
  pergunta_modelo: string;
  secoes: SecaoOrientacao[];
  estado: "rascunho" | "publicada";
  revisado_em: string | null;
};
export type Consulta = {
  fontes: Fonte[];
  orientacoes: Orientacao[];
  data_referencia: string;
  versao: string;
  fontes_excluidas: number;
};
const normalizar = (t: string) =>
  t
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
export function faltantes(pergunta: string, c: ContextoEmpresa): string[] {
  const q = normalizar(pergunta);
  if (
    c.publico !== "empresa" ||
    !/(precis|obrig|dispens|isent|posso|pode|devo|document|como.*(registr|obter|solicit))/.test(
      q,
    )
  )
    return [];
  const itens: string[] = [];
  if (
    c.produto === "todos" &&
    !/(arma|munic|explosiv|quimic|pirotec|fogos|blind|colete|balistic|menos.letal|menor potencial ofensivo|nitrato|espargidor|dardos)/.test(
      q,
    )
  )
    itens.push("Informe o produto ou a família de PCE envolvida.");
  if (
    c.atividade === "todos" &&
    !/(fabric|comerci|vend|compr|adquir|aquis|transport|trafeg|armazen|utiliz|empreg|detona|import|export|registr|apostil|fiscaliz)/.test(
      q,
    )
  )
    itens.push(
      "Informe a atividade da empresa: fabricar, comercializar, transportar, armazenar, importar ou utilizar, por exemplo.",
    );
  if (
    /(este|esse|desse|deste|tal) produto|produto.*(controlado|pce)|concentracao|composicao/.test(
      q,
    ) &&
    !c.detalhes.trim() &&
    c.produto === "quimicos"
  )
    itens.push(
      "Descreva o produto químico, sua composição/concentração e finalidade.",
    );
  return itens;
}
export function fonteAtual(f: Fonte, data: string): boolean {
  return Boolean(
    f.dispositivo_id &&
      f.literal_conferido &&
      f.texto_literal &&
      ["vigente", "alterado"].includes(f.status_dispositivo || "") &&
      ["vigente", "vigente_com_alteracoes", "parcialmente_vigente"].includes(
        f.status,
      ) &&
      (!f.vigencia_inicio || f.vigencia_inicio <= data) &&
      (!f.vigencia_fim || f.vigencia_fim >= data),
  );
}
export function secoesExtraidas(fontes: Fonte[]) {
  const grupos = [
    {
      titulo: "Requisitos e documentos encontrados",
      padrao:
        /document|requisit|comprov|certid|laudo|requerimento|autoriz|registro/i,
    },
    {
      titulo: "Condições e exceções encontradas",
      padrao:
        /salvo|exceto|dispens|isent|condicion|desde que|somente|vedad|proibid|ressalv|limite/i,
    },
    {
      titulo: "Prazos e validade encontrados",
      padrao:
        /\b(prazos?|validade|dias?|meses|anos?|vigência|vencimento|transitóri\w*)\b/i,
    },
  ];
  return grupos.map((g) => ({
    titulo: g.titulo,
    itens: fontes.filter((f) => g.padrao.test(f.conteudo)).slice(0, 3),
  }));
}
export function urlSegura(valor: string | null | undefined): string | null {
  if (!valor) return null;
  try {
    const u = new URL(valor);
    return u.protocol === "https:" ? u.href : null;
  } catch {
    return null;
  }
}
export type RegistroConsulta = {
  id: string;
  pergunta: string;
  contexto: ContextoEmpresa;
  consulta: Consulta;
  criadoEm: string;
  favorito: boolean;
};
const CHAVE = "normas-dfpc-consultas-v1";
export function lerHistorico(): RegistroConsulta[] {
  try {
    const valor: unknown = JSON.parse(localStorage.getItem(CHAVE) || "[]");
    if (!Array.isArray(valor)) return [];
    return valor
      .filter(
        (x): x is RegistroConsulta =>
          !!x &&
          typeof x.id === "string" &&
          typeof x.pergunta === "string" &&
          typeof x.criadoEm === "string" &&
          !!x.contexto &&
          !!x.consulta &&
          Array.isArray(x.consulta.fontes) &&
          Array.isArray(x.consulta.orientacoes),
      )
      .slice(0, 30);
  } catch {
    return [];
  }
}
export function salvarHistorico(itens: RegistroConsulta[]) {
  try {
    localStorage.setItem(CHAVE, JSON.stringify(itens.slice(0, 30)));
    return true;
  } catch {
    return false;
  }
}
export function exportarConsulta(r: RegistroConsulta) {
  const linhas = [
    "# Consulta Normas DFPC",
    "",
    r.pergunta,
    "",
    `Consulta realizada: ${r.criadoEm}`,
    `Data de referência: ${r.contexto.data}`,
    `Versão: ${r.consulta.versao}`,
    `Produto: ${r.contexto.produto} | Atividade: ${r.contexto.atividade}`,
    `Situação de registro informada: ${r.contexto.registro}`,
    r.contexto.detalhes ? `Detalhes: ${r.contexto.detalhes}` : "",
    "",
    ...r.consulta.orientacoes.flatMap((o) => [
      `## ${o.titulo}`,
      ...o.secoes.flatMap((s) => [
        `### ${s.titulo}`,
        s.texto,
        `Dispositivos: ${s.dispositivo_ids.join(", ")}`,
        "",
      ]),
    ]),
    ...r.consulta.fontes.flatMap((f, i) => [
      `## [${i + 1}] ${f.titulo}`,
      f.dispositivo,
      `Situação: ${f.status} | Dispositivo: ${f.status_dispositivo || "não vinculado"}`,
      `Última verificação cadastrada: ${f.ultima_verificacao || "não informada"}`,
      `Fonte: ${f.nome_arquivo || "não informada"}`,
      urlSegura(f.fonte_oficial) || "",
      `SHA-256: ${f.sha256 || "não informado"}`,
      "",
      f.conteudo,
      "",
      "Texto cadastrado:",
      f.texto_literal || "Sem vínculo literal exato.",
      "",
    ]),
  ];
  const url = URL.createObjectURL(
    new Blob([linhas.join("\n")], { type: "text/markdown;charset=utf-8" }),
  );
  const a = document.createElement("a");
  a.href = url;
  a.download = `consulta-pce-${r.contexto.data}.md`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
