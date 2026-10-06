import { useEffect, useMemo, useState } from 'react';
import { BookOpen, FileSearch, Scale, Search, ShieldCheck } from 'lucide-react';
import { normas as normasLocais } from './data/normas';
import { supabase } from './lib/supabase';
import { normalizarStatus, ordenarPorSeguranca, statusSlug } from './lib/normas';
import type { Norma } from './types';

type ResultadoConsulta = {
  id: string;
  titulo: string;
  dispositivo?: string;
  pagina?: number;
  conteudo: string;
  status?: string;
  relevancia?: number;
  relacoes?: Array<{ tipo: string; norma_relacionada: string; dispositivo?: string }>;
  normas?: { titulo: string; status: string };
};

export default function App() {
  const [tab, setTab] = useState<'consulta' | 'base'>('consulta');
  const [q, setQ] = useState('');
  const [pergunta, setPergunta] = useState('');
  const [resposta, setResposta] = useState<ResultadoConsulta[] | null>(null);
  const [consultando, setConsultando] = useState(false);
  const [buscaRealizada, setBuscaRealizada] = useState(false);
  const [erroConsulta, setErroConsulta] = useState('');
  const [normas, setNormas] = useState<Norma[]>(normasLocais);

  useEffect(() => {
    if (!supabase) return;

    supabase
      .from('normas')
      .select('id,tipo,numero,ano,titulo,assunto,status')
      .order('ano', { ascending: false })
      .then(({ data }) => {
        if (!data?.length) return;

        const normasRemotas = data.map((n: any) => ({
          ...n,
          status: normalizarStatus(n.status),
        })) as Norma[];

        setNormas(normasRemotas);
      });
  }, []);

  async function consultar() {
    if (!pergunta.trim()) return;

    setErroConsulta('');
    setBuscaRealizada(true);
    setConsultando(true);

    if (!supabase) {
      setResposta([]);
      setConsultando(false);
      return;
    }

    const { data: achados, error } = await supabase.rpc('consultar_base_normativa', {
      consulta: pergunta,
      limite: 8,
    });

    if (error) {
      setErroConsulta('Não foi possível consultar a base normativa agora.');
      setResposta([]);
      setConsultando(false);
      return;
    }

    if (!achados?.length) {
      setResposta([]);
      setConsultando(false);
      return;
    }

    const seguros = ordenarPorSeguranca(achados as ResultadoConsulta[]).filter((item) => {
      const status = normalizarStatus(item.status);
      return !['Revogada', 'Superada materialmente', 'Vigência a confirmar', 'Ato alterador'].includes(status);
    });

    setResposta(
      seguros.map((x: any) => ({
        ...x,
        normas: { titulo: x.titulo, status: normalizarStatus(x.status) },
      })),
    );
    setConsultando(false);
  }

  const filtered = useMemo(() => {
    const termo = q.toLowerCase();
    return normas.filter((n) =>
      [n.titulo, n.assunto, n.status, n.statusDetalhado, ...(n.palavrasChave || [])]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
        .includes(termo),
    );
  }, [q, normas]);

  const possuiAlerta = resposta?.some((r) => normalizarStatus(r.status) !== 'Vigente');

  return (
    <>
      <header>
        <div className="brand">
          <div className="seal"><ShieldCheck /></div>
          <div>
            <b>NORMAS DFPC</b>
            <span>Base normativa de Produtos Controlados pelo Exército</span>
          </div>
        </div>
        <nav>
          <button className={tab === 'consulta' ? 'active' : ''} onClick={() => setTab('consulta')}>Consulta</button>
          <button className={tab === 'base' ? 'active' : ''} onClick={() => setTab('base')}>Base normativa</button>
        </nav>
      </header>

      <main>
        {tab === 'consulta' ? (
          <>
            <section className="hero">
              <div className="eyebrow"><Scale size={16} /> CONSULTA NORMATIVA PCE</div>
              <h1>Encontre respostas fundamentadas<br />nas normas da DFPC.</h1>
              <p>Consulte a base normativa com controle de vigência, alterações, revogações e rastreabilidade.</p>

              <div className="ask">
                <Search />
                <input
                  value={pergunta}
                  onChange={(e) => setPergunta(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && consultar()}
                  placeholder="Ex.: O que é PCE? Qual norma trata da Guia de Tráfego?"
                />
                <button onClick={consultar} disabled={consultando || !pergunta.trim()}>
                  {consultando ? 'Buscando...' : 'Consultar'}
                </button>
              </div>

              <small>A consulta não usa normas revogadas, materialmente superadas, atos meramente alteradores ou normas com vigência não confirmada como fundamento automático.</small>

              {erroConsulta && (
                <div className="answer empty">
                  <h3>Falha na consulta</h3>
                  <p>{erroConsulta}</p>
                </div>
              )}

              {Array.isArray(resposta) && resposta.length > 0 && (
                <div className="answer">
                  <div className="answer-head">
                    <div>
                      <h3>Fundamentos encontrados</h3>
                      <p>{resposta.length} fonte{resposta.length > 1 ? 's' : ''} localizada{resposta.length > 1 ? 's' : ''}. Resultados priorizam normas vigentes e consolidadas.</p>
                    </div>
                    {possuiAlerta && <span className="attention">Atenção à vigência</span>}
                  </div>

                  {resposta.map((r) => {
                    const status = normalizarStatus(r.status);
                    return (
                      <article key={r.id}>
                        <b>{r.normas?.titulo || r.titulo}</b>
                        <span>{r.dispositivo}{r.pagina ? ` • pág. ${r.pagina}` : ''}</span>
                        <p>{r.conteudo}</p>
                        <div className="source-meta">
                          <strong>Fonte:</strong> {r.titulo}{r.dispositivo ? ` — ${r.dispositivo}` : ''}{r.pagina ? ` — pág. ${r.pagina}` : ''}<br />
                          <strong>Situação:</strong> <i className={`badge ${statusSlug(status)}`}>{status}</i>
                          {Array.isArray(r.relacoes) && r.relacoes.length > 0 && (
                            <>
                              <br /><strong>Relações normativas:</strong>
                              {r.relacoes.map((x, i) => (
                                <span key={`${x.tipo}-${x.norma_relacionada}-${i}`}> {x.tipo} — {x.norma_relacionada}{x.dispositivo ? ` (${x.dispositivo})` : ''}{i < r.relacoes!.length - 1 ? ';' : ''}</span>
                              ))}
                            </>
                          )}
                        </div>
                      </article>
                    );
                  })}
                </div>
              )}

              {buscaRealizada && !erroConsulta && Array.isArray(resposta) && resposta.length === 0 && !consultando && (
                <div className="answer empty">
                  <h3>Nenhum fundamento seguro localizado</h3>
                  <p>A base não encontrou trecho em norma apta a fundamentar automaticamente a resposta. Nenhuma conclusão foi gerada sem fonte vigente.</p>
                </div>
              )}
            </section>

            <section className="features">
              <article><BookOpen /><h3>Resposta fundamentada</h3><p>Exibe norma, dispositivo e trecho utilizado na resposta.</p></article>
              <article><ShieldCheck /><h3>Controle de vigência</h3><p>Distingue normas vigentes, parcialmente vigentes, alteradoras, revogadas e pendentes.</p></article>
              <article><FileSearch /><h3>Relações normativas</h3><p>Registra atos que alteram, revogam, substituem ou complementam outras normas.</p></article>
            </section>
          </>
        ) : (
          <section className="library">
            <div className="title">
              <div>
                <span>BASE DOCUMENTAL</span>
                <h1>Normas cadastradas</h1>
                <p>Catálogo estruturado com status de vigência e política de uso como fundamento.</p>
              </div>
              <div className="search"><Search /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Pesquisar norma ou assunto" /></div>
            </div>

            <div className="table">
              <div className="tr head"><span>Norma</span><span>Assunto</span><span>Situação</span></div>
              {filtered.map((n) => (
                <div className="tr" key={n.id}>
                  <span>
                    <b>{n.titulo}</b>
                    <small>{n.tipo} • {n.ano}{n.normaPrincipal === false ? ' • ato de relacionamento' : ''}</small>
                  </span>
                  <span>
                    {n.assunto}
                    {n.statusDetalhado && <small>{n.statusDetalhado}</small>}
                    {n.relacoes?.map((r) => <small key={r}>{r}</small>)}
                    {n.observacaoVigencia && <small>{n.observacaoVigencia}</small>}
                  </span>
                  <span>
                    <i className={`badge ${statusSlug(n.status)}`}>{n.status}</i>
                    {n.ultimaVerificacao && <small>Verificado em {n.ultimaVerificacao.split('-').reverse().join('/')}</small>}
                  </span>
                </div>
              ))}
            </div>
          </section>
        )}
      </main>

      <footer>Projeto Normas DFPC • Base para consulta técnica de PCE</footer>
    </>
  );
}
