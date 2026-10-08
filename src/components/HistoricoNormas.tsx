import type { HistoricoNormativo } from "../lib/consulta";
import { urlSegura } from "../lib/consulta";
import { normalizarStatus } from "../lib/normas";
export function HistoricoNormas({ normas }: { normas: HistoricoNormativo[] }) {
  return <div>
    {normas.map(n => <article className="source-card" key={n.norma_id}>
      <h3>{n.titulo}</h3>
      <p><b>Situação cadastrada: {normalizarStatus(n.status)}</b></p>
      {n.observacao && <p>{n.observacao}</p>}
      <p className="muted">Verificação informada: {n.ultima_verificacao || "não informada"}.</p>
      {urlSegura(n.fonte_oficial) && <a href={urlSegura(n.fonte_oficial)!}
        target="_blank" rel="noopener noreferrer">Conferir fonte oficial</a>}
      <h4>Alterações cadastradas</h4>
      {n.eventos.length ? <ol className="timeline">{n.eventos.map((e,i) => <li key={i}>
        <b>{e.norma_alteradora}</b>
        <span>{e.norma_base} · {e.dispositivo} · {e.data || "data não informada"}</span>
        {e.resumo && <p>{e.resumo}</p>}
        {e.observacoes && <p>{e.observacoes}</p>}
      </li>)}</ol> : <p>Não há alteração detalhada cadastrada. Isso não comprova ausência de alterações.</p>}
      {!!n.mapa.length && <details open>
        <summary>Vigência por dispositivo</summary>
        {n.mapa.map((m,i) => <p key={i}><b>{m.dispositivo}: {m.status.replaceAll("_"," ")}</b>
          {m.data && " · " + m.data}{m.responsavel && " · " + m.responsavel}
          {m.observacoes && " — " + m.observacoes}</p>)}
      </details>}
    </article>)}
  </div>;
}
