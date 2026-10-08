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
  pergunta_interpretada?: string | null;
  complementares?: number;
};
const normalizar = (t: string) =>
  t
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
export function faltantes(pergunta: string, c: ContextoEmpresa): string[] {
  const q = normalizar(pergunta);
  if (/(como verificar|procedimento)/.test(q) && /(mistura|solucao)/.test(q))
    return [];
  if (
    /(como|o que|significa)/.test(q) &&
    (/apostil/.test(q) ||
      (/incluir|adicionar/.test(q) &&
        /atividade/.test(q) &&
        /registro|\bcr\b/.test(q)))
  )
    return [];
  if (
    c.publico !== "empresa" ||
    !/(precis|obrig|dispens|isent|posso|pode|devo|document|como.*(registr|obter|solicit)|\bcr\b|(?:mistura|solucao).*(?:pce|controlad))/.test(
      q,
    )
  )
    return [];
  const itens: string[] = [];
  if (
    c.produto === "todos" &&
    !/(arma|munic|explosiv|quimic|pirotec|fogos|blind|colete|balistic|menos.letal|menor potencial ofensivo|nitrato|espargidor|dardos|mistura|solucao)/.test(
      q,
    )
  )
    itens.push("Informe o produto ou a família de PCE envolvida.");
  if (
    c.atividade === "todos" &&
    !/(mistura|solucao).*(pce|controlad)/.test(q) &&
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
  if (
    /(mistura|solucao)/.test(q) &&
    /(controlad|pce|enquadr|dispens|isent)/.test(q) &&
    !/[0-9]|composicao:|como verificar|procedimento/.test(q)
  )
    itens.push(
      "Para pesquisar o enquadramento da mistura/solução, inclua na pergunta os componentes, as concentrações e a finalidade. Informações só no campo de detalhes não participam da busca.",
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
const objeto = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);
const textoOuNulo = (v: unknown) => v === null || typeof v === "string";
function validarFonte(v: unknown): v is Fonte {
  if (!objeto(v)) return false;
  return (
    [
      "norma_id",
      "titulo",
      "dispositivo",
      "conteudo",
      "status",
      "tipo_conteudo",
    ].every((k) => typeof v[k] === "string") &&
    [
      "dispositivo_id",
      "texto_literal",
      "status_dispositivo",
      "ultima_verificacao",
      "vigencia_inicio",
      "vigencia_fim",
      "fonte_oficial",
      "nome_arquivo",
      "sha256",
    ].every((k) => textoOuNulo(v[k])) &&
    typeof v.literal_conferido === "boolean" &&
    (v.pagina === null || typeof v.pagina === "number") &&
    typeof v.relevancia === "number" &&
    ["number", "string"].includes(typeof v.trecho_id) &&
    Array.isArray(v.relacoes) &&
    v.relacoes.every(
      (r) =>
        objeto(r) &&
        typeof r.tipo === "string" &&
        typeof r.norma_relacionada === "string" &&
        (r.dispositivo == null || typeof r.dispositivo === "string") &&
        (r.observacoes == null || typeof r.observacoes === "string"),
    )
  );
}
export function validarConsulta(v: unknown): v is Consulta {
  if (!objeto(v)) return false;
  return (
    typeof v.data_referencia === "string" &&
    typeof v.versao === "string" &&
    typeof v.fontes_excluidas === "number" &&
    Array.isArray(v.fontes) &&
    v.fontes.every(validarFonte) &&
    Array.isArray(v.orientacoes) &&
    v.orientacoes.every(
      (o) =>
        objeto(o) &&
        ["id", "titulo", "produto", "atividade", "pergunta_modelo"].every(
          (k) => typeof o[k] === "string",
        ) &&
        textoOuNulo(o.revisado_em) &&
        ["rascunho", "publicada"].includes(String(o.estado)) &&
        Array.isArray(o.secoes) &&
        o.secoes.every(
          (sec) =>
            objeto(sec) &&
            typeof sec.titulo === "string" &&
            typeof sec.texto === "string" &&
            Array.isArray(sec.dispositivo_ids) &&
            sec.dispositivo_ids.every((id) => typeof id === "string"),
        ),
    )
  );
}
export function limitarHistorico(
  itens: RegistroConsulta[],
): RegistroConsulta[] {
  // Protege favoritos antigos quando consultas novas ultrapassam o limite.
  if (!itens.length) return [];
  const recentes = itens.slice(1);
  const favoritos = recentes.filter((r) => r.favorito).slice(0, 29);
  const comuns = recentes
    .filter((r) => !r.favorito)
    .slice(0, 29 - favoritos.length);
  const ids = new Set([itens[0], ...favoritos, ...comuns].map((r) => r.id));
  return itens.filter((r) => ids.has(r.id)).slice(0, 30);
}
export function filtrarHistorico(
  itens: RegistroConsulta[],
  busca: string,
  favoritos: boolean,
) {
  const q = normalizar(busca.trim());
  return itens
    .filter(
      (r) =>
        (!favoritos || r.favorito) &&
        normalizar(
          [
            r.pergunta,
            r.contexto.produto,
            r.contexto.atividade,
            ...r.consulta.fontes.map((f) => f.titulo),
          ].join(" "),
        ).includes(q),
    )
    .sort(
      (a, b) =>
        Number(b.favorito) - Number(a.favorito) ||
        b.criadoEm.localeCompare(a.criadoEm),
    );
}
export function lerHistorico(): RegistroConsulta[] {
  try {
    const valor: unknown = JSON.parse(localStorage.getItem(CHAVE) || "[]");
    if (!Array.isArray(valor)) return [];
    return limitarHistorico(
      valor.filter(
        (x): x is RegistroConsulta =>
          objeto(x) &&
          typeof x.id === "string" &&
          typeof x.pergunta === "string" &&
          typeof x.criadoEm === "string" &&
          !Number.isNaN(Date.parse(x.criadoEm)) &&
          typeof x.favorito === "boolean" &&
          objeto(x.contexto) &&
          ["produto", "atividade", "registro", "detalhes", "data"].every(
            (k) =>
              typeof (x.contexto as Record<string, unknown>)[k] === "string",
          ) &&
          ["empresa", "todos"].includes(String(x.contexto.publico)) &&
          validarConsulta(x.consulta),
      ),
    );
  } catch {
    return [];
  }
}
export function salvarHistorico(itens: RegistroConsulta[]) {
  try {
    localStorage.setItem(CHAVE, JSON.stringify(limitarHistorico(itens)));
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
    r.consulta.pergunta_interpretada
      ? `Tema reconhecido: ${r.consulta.pergunta_interpretada}`
      : "",
    "A consulta usa o acervo cadastrado; a ausência de resultado não comprova dispensa de controle.",
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
