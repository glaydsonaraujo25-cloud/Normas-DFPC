import { useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import { ATIVIDADES, PRODUTOS } from "../lib/consulta";
import type { Orientacao } from "../lib/consulta";

type Pergunta = Pick<
  Orientacao,
  "id" | "titulo" | "pergunta_modelo" | "produto" | "atividade" | "revisado_em"
>;
export function PerguntasRevisadas({
  selecionar,
}: {
  selecionar: (guia: Pergunta) => void;
}) {
  const [guias, setGuias] = useState<Pergunta[]>([]);
  const [busca, setBusca] = useState("");
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
  const normalizar = (s: string) =>
    s
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase();
  const filtrados = guias.filter((g) =>
    normalizar(`${g.titulo} ${g.pergunta_modelo}`).includes(normalizar(busca)),
  );
  const rotulo = (lista: readonly (readonly [string, string])[], v: string) =>
    lista.find((o) => o[0] === v)?.[1] || v;
  return (
    <section className="library reviewed-questions">
      <span>ORIENTAÇÕES CADASTRADAS</span>
      <h2>Perguntas com orientação revisada</h2>
      <p>
        Escolha uma pergunta para preencher a consulta. Ao consultar, a
        aplicação verifica se os fundamentos continuam aplicáveis na data atual.
      </p>
      <label>
        Buscar pergunta revisada
        <input
          type="search"
          value={busca}
          onChange={(e) => setBusca(e.target.value)}
        />
      </label>
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
