import { useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import { ATIVIDADES, PRODUTOS } from "../lib/consulta";
import { buscarPerguntas } from "../lib/perguntas";
import type { PerguntaRevisada } from "../lib/perguntas";

export function PerguntasRevisadas({
  selecionar,
  relacionada,
}: {
  selecionar: (guia: PerguntaRevisada) => void;
  relacionada?: { pergunta: string; produto: string; atividade: string };
}) {
  const [guias, setGuias] = useState<PerguntaRevisada[]>([]);
  const [busca, setBusca] = useState("");
  const [atividade, setAtividade] = useState("todos");
  const [estado, setEstado] = useState("Carregando perguntas revisadas…");
  useEffect(() => {
    let ativo = true;
    if (!supabase) {
      setEstado("Perguntas revisadas indisponíveis no momento.");
      return;
    }
    supabase
      .from("orientacoes_empresariais")
      .select("id,titulo,pergunta_modelo,produto,atividade,revisado_em")
      .eq("estado", "publicada")
      .order("titulo")
      .limit(100)
      .then(({ data, error }) => {
        if (!ativo) return;
        setGuias(data || []);
        setEstado(
          error ? "Não foi possível carregar as perguntas revisadas." : "",
        );
      });
    return () => {
      ativo = false;
    };
  }, []);
  const filtrados = buscarPerguntas(
    guias,
    relacionada?.pergunta ?? busca,
    relacionada?.atividade ?? atividade,
    relacionada?.produto ?? "todos",
    !!relacionada,
  );
  if (relacionada && !estado && !filtrados.length) return null;
  const rotulo = (lista: readonly (readonly [string, string])[], v: string) =>
    lista.find((o) => o[0] === v)?.[1] || v;
  return (
    <section className="library reviewed-questions">
      <span>ORIENTAÇÕES CADASTRADAS</span>
      <h2>
        {relacionada
          ? "Perguntas revisadas relacionadas"
          : "Perguntas com orientação revisada"}
      </h2>
      <p>
        {relacionada
          ? "Estas perguntas compartilham termos com sua dúvida. Confira o escopo antes de escolher; a orientação pode abordar outra situação. A seleção prepara uma nova consulta."
          : "Busque por palavras em qualquer ordem, como ‘munições registros’ ou ‘renovar CR’. Escolha uma pergunta para conferir seus fundamentos no acervo atual."}
      </p>
      {!relacionada && (
        <>
          <label>
            Buscar pergunta revisada
            <input
              type="search"
              value={busca}
              onChange={(e) => setBusca(e.target.value)}
            />
          </label>
          <label>
            Filtrar orientações por atividade
            <select
              value={atividade}
              onChange={(e) => setAtividade(e.target.value)}
            >
              <option value="todos">Todas as atividades</option>
              {ATIVIDADES.filter(([id]) => id !== "todos").map(
                ([id, texto]) => (
                  <option key={id} value={id}>
                    {texto}
                  </option>
                ),
              )}
            </select>
          </label>
        </>
      )}
      {estado ? (
        <p role="status">{estado}</p>
      ) : (
        <>
          <p role="status">{filtrados.length} pergunta(s) encontrada(s).</p>
          <div className="procedure-grid">
            {filtrados.map((g) => (
              <article className="source-card" key={g.id}>
                <h3>{g.titulo}</h3>
                <p>{g.pergunta_modelo}</p>
                <p className="muted">
                  {g.produto !== "todos"
                    ? rotulo(PRODUTOS, g.produto)
                    : "Produtos conforme a pergunta"}{" "}
                  ·{" "}
                  {g.atividade !== "todos"
                    ? rotulo(ATIVIDADES, g.atividade)
                    : "Atividade conforme a pergunta"}
                </p>
                <small>
                  Revisão cadastrada: {g.revisado_em || "não informada"}
                </small>
                <button onClick={() => selecionar(g)}>Preparar consulta</button>
              </article>
            ))}
          </div>
          {!filtrados.length && (
            <p>Tente outro termo ou escreva sua dúvida no campo de consulta.</p>
          )}
        </>
      )}
    </section>
  );
}
