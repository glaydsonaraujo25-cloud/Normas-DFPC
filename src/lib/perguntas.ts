import type { Orientacao } from "./consulta.ts";
export type PerguntaRevisada = Pick<
  Orientacao,
  "id" | "titulo" | "pergunta_modelo" | "produto" | "atividade" | "revisado_em"
>;
const normalizar = (s: string) =>
  s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
const ignorados = new Set(
  "a o as os de da do das dos e em no na nos nas um uma para por com se que qual quais como minha meu empresa empresarial pce preciso precisa posso pode devo sao ser".split(
    " ",
  ),
);
function termo(s: string): string {
  if (/^(renov|revalid)/.test(s)) return "revalidacao";
  if (/^(vender|venda|comerc|comercial)/.test(s)) return "comercio";
  if (/^(compr|adquir|aquis)/.test(s)) return "aquisicao";
  if (/^(guardar|guarda|armazen|estocar)/.test(s)) return "armazenagem";
  if (/^(incluir|adicionar|apostil)/.test(s)) return "apostilamento";
  if (/^munic/.test(s)) return "municao";
  if (/^quimic/.test(s)) return "quimico";
  if (/^document/.test(s)) return "documento";
  if (/^registr/.test(s) || s === "cr") return "registro";
  return s.replace(/s$/, "");
}
function termos(s: string): Set<string> {
  return new Set(
    normalizar(s)
      .split(/[^a-z0-9]+/)
      .filter((s) => s.length > 1 && !ignorados.has(s))
      .map(termo),
  );
}
export function buscarPerguntas(
  guias: PerguntaRevisada[],
  busca: string,
  atividade = "todos",
  produto = "todos",
  relacionadas = false,
): PerguntaRevisada[] {
  const palavras = termos(busca);
  if (relacionadas && !palavras.size) return [];
  return guias
    .filter(
      (g) =>
        (atividade === "todos" ||
          g.atividade === "todos" ||
          g.atividade === atividade) &&
        (produto === "todos" || g.produto === "todos" || g.produto === produto),
    )
    .map((g) => {
      const texto = termos(`${g.titulo} ${g.pergunta_modelo}`);
      const pontos = [...palavras].filter((p) => texto.has(p)).length;
      return { g, pontos };
    })
    .filter(({ pontos }) =>
      relacionadas
        ? pontos >= Math.min(2, palavras.size)
        : pontos === palavras.size,
    )
    .sort(
      (a, b) =>
        b.pontos - a.pontos || a.g.titulo.localeCompare(b.g.titulo, "pt-BR"),
    )
    .slice(0, relacionadas ? 3 : 100)
    .map(({ g }) => g);
}
