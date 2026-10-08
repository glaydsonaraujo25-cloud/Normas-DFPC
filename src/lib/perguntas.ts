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
  if (/\d/.test(s)) return s;
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
// Uma edição em palavras longas; siglas e referências numéricas permanecem exatas.
function proximo(a: string, b: string): boolean {
  if (a === b) return true;
  if (Math.min(a.length, b.length) < 5 || /\d/.test(a + b)) return false;
  if (Math.abs(a.length - b.length) > 1) return false;
  if (a.length === b.length) {
    const diferentes = [...a].flatMap((letra, i) => letra !== b[i] ? [i] : []);
    return diferentes.length === 1 ||
      (diferentes.length === 2 && diferentes[1] === diferentes[0] + 1 &&
        a[diferentes[0]] === b[diferentes[1]] && a[diferentes[1]] === b[diferentes[0]]);
  }
  const menor = a.length < b.length ? a : b;
  const maior = a.length < b.length ? b : a;
  let i = 0;
  while (i < menor.length && menor[i] === maior[i]) i++;
  return menor.slice(i) === maior.slice(i + 1);
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
      const exatos = [...palavras].filter((p) => texto.has(p)).length;
      const pontos = [...palavras].filter((p) =>
        [...texto].some((t) => proximo(p, t)),
      ).length;
      return { g, pontos, exatos };
    })
    .filter(({ pontos }) =>
      relacionadas
        ? pontos >= Math.min(2, palavras.size)
        : pontos === palavras.size,
    )
    .sort(
      (a, b) =>
        b.pontos - a.pontos || b.exatos - a.exatos ||
        a.g.titulo.localeCompare(b.g.titulo, "pt-BR"),
    )
    .slice(0, relacionadas ? 3 : 100)
    .map(({ g }) => g);
}
