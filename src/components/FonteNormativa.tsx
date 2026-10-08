import { useEffect, useState } from "react";
import type { Fonte } from "../lib/consulta";
import { urlSegura } from "../lib/consulta";
import { supabase } from "../lib/supabase";
export function FonteNormativa({
  fonte,
  indice,
}: {
  fonte: Fonte;
  indice: number;
}) {
  const url = urlSegura(fonte.fonte_oficial);
  return (
    <article className="source-card" id={`fonte-${indice}`}>
      <div className="source-heading">
        <b>
          [{indice}] {fonte.titulo}
        </b>
        <span className="badge">
          {fonte.status_dispositivo === "alterado"
            ? "Redação alterada"
            : "Dispositivo vigente"}
        </span>
      </div>
      <p className="muted">
        {fonte.dispositivo}
        {fonte.pagina ? ` · página ${fonte.pagina}` : ""}
      </p>
      {fonte.tipo_conteudo === "dispositivo_complementar" && (
        <p className="muted">
          Complemento do mesmo artigo: confira as condições junto da regra
          principal.
        </p>
      )}
      <p>{fonte.conteudo}</p>
      <details>
        <summary>Ver origem e verificação</summary>
        {fonte.texto_literal &&
          fonte.texto_literal.trim() !== fonte.conteudo.trim() && (
            <>
              <p>Texto vinculado ao dispositivo:</p>
              <blockquote>{fonte.texto_literal}</blockquote>
            </>
          )}
        <dl>
          <dt>Documento</dt>
          <dd>{fonte.nome_arquivo || "Documento de origem não vinculado"}</dd>
          <dt>Última verificação de vigência cadastrada</dt>
          <dd>{fonte.ultima_verificacao || "Não informada"}</dd>
          <dt>Identificador do dispositivo</dt>
          <dd>{fonte.dispositivo_id}</dd>
          {fonte.vigencia_inicio && (
            <>
              <dt>Início de vigência cadastrado</dt>
              <dd>{fonte.vigencia_inicio}</dd>
            </>
          )}
          {fonte.sha256 && (
            <>
              <dt>SHA-256 do documento</dt>
              <dd className="hash">{fonte.sha256}</dd>
            </>
          )}
        </dl>
        {url ? (
          <a href={url} target="_blank" rel="noopener noreferrer">
            Abrir fonte oficial
          </a>
        ) : (
          <p className="muted">Link oficial pendente de cadastro.</p>
        )}
      </details>
      {!!fonte.relacoes?.length && (
        <details>
          <summary>Relações normativas</summary>
          {fonte.relacoes.map((r, i) => (
            <p key={i}>
              {r.tipo.replaceAll("_", " ")}: {r.norma_relacionada}
              {r.dispositivo ? ` — ${r.dispositivo}` : ""}
              {r.observacoes ? ` · ${r.observacoes}` : ""}
            </p>
          ))}
        </details>
      )}
    </article>
  );
}
type Evento = {
  norma_alteradora: string;
  dispositivo_base: string;
  tipo_alteracao: string;
  vigencia_inicio: string | null;
  observacoes: string | null;
};
type Vigencia = {
  dispositivo: string;
  status_dispositivo: string;
  data_efeito: string | null;
  observacoes: string | null;
};
export function LinhaNormativa({ titulo }: { titulo: string }) {
  const [eventos, setEventos] = useState<Evento[]>([]);
  const [mapa, setMapa] = useState<Vigencia[]>([]);
  const [erro, setErro] = useState("");
  useEffect(() => {
    let ativo = true;
    setEventos([]);
    setMapa([]);
    setErro("");
    if (!supabase) return;
    Promise.all([
      supabase
        .from("v_linha_tempo_normativa")
        .select(
          "norma_alteradora,dispositivo_base,tipo_alteracao,vigencia_inicio,observacoes",
        )
        .eq("norma_base", titulo)
        .eq("conferido", true)
        .order("vigencia_inicio"),
      supabase
        .from("v_mapa_vigencia_normativa")
        .select("dispositivo,status_dispositivo,data_efeito,observacoes")
        .eq("titulo", titulo)
        .eq("conferido", true),
    ]).then(([a, b]) => {
      if (!ativo) return;
      if (a.error || b.error)
        setErro("Não foi possível carregar o mapa de alterações.");
      setEventos(a.data || []);
      setMapa(b.data || []);
    });
    return () => {
      ativo = false;
    };
  }, [titulo]);
  if (!eventos.length && !mapa.length && !erro) return null;
  return (
    <div className="norm-chain">
      {erro && <p role="status">{erro}</p>}
      {!!eventos.length && (
        <>
          <h3>Alterações cadastradas</h3>
          <ol className="timeline">
            {eventos.map((e, i) => (
              <li key={i}>
                <b>{e.norma_alteradora}</b>
                <span>
                  {e.vigencia_inicio || "Data não informada"} ·{" "}
                  {e.dispositivo_base} · {e.tipo_alteracao.replaceAll("_", " ")}
                </span>
                {e.observacoes && <p>{e.observacoes}</p>}
              </li>
            ))}
          </ol>
        </>
      )}
      {!!mapa.length && (
        <details>
          <summary>Vigência por dispositivo</summary>
          {mapa.map((m, i) => (
            <p key={i}>
              <b>{m.dispositivo}</b>:{" "}
              {m.status_dispositivo.replaceAll("_", " ")}
              {m.data_efeito ? ` · ${m.data_efeito}` : ""}
              {m.observacoes ? ` — ${m.observacoes}` : ""}
            </p>
          ))}
        </details>
      )}
    </div>
  );
}
