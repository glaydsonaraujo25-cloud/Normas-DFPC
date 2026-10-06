import { useEffect, useMemo, useState } from 'react';
import { BookOpen, FileSearch, Scale, Search, ShieldCheck } from 'lucide-react';
import { normas as normasLocais } from './data/normas';
import { supabase } from './lib/supabase';
import { normalizarStatus, ordenarPorSeguranca, podeFundamentar, statusSlug } from './lib/normas';
import type { Norma } from './types';

type ResultadoConsulta = {
  id: string;
  titulo: string;
  dispositivo?: string;
  pagina?: number;
  conteudo: string;
  status?: string;
  relevancia?: number;
  relacoes?: Array<{ tipo: string; norma_relacionada: string; dispositivo?: string; observacoes?: string }>;
  normas?: { titulo: string; status: string };
};

type RelacaoBanco = {
  norma_origem_id: string;
  norma_destino_id: string;
  tipo: string;
  dispositivo?: string | null;
  observacoes?: string | null;
};

const chaveNorma = (titulo: string) => titulo.trim().toLowerCase();

const rotuloRelacao = (tipo: string) => {
  const mapa: Record<string, string> = {
    altera: 'Altera',
    alterada_por: 'Alterada por',
    revoga: 'Revoga',
    revogada_por: 'Revogada por',
    complementa: 'Complementa',
    regulamenta: 'Regulamenta',
    substitui: 'Substitui',
    consolida: 'Consolida',
    cita: 'Cita',
  };
  return mapa[tipo] || tipo.replaceAll('_', ' ');
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

    Promise.all([
      supabase
        .from('normas')
        .select('id,tipo,numero,ano,titulo,orgao,data_norma,assunto,status,status_detalhado,norma_principal,usar_como_fundamento,vigencia_inicio,vigencia_fim,ultima_verificacao,observacao_vigencia,palavras_chave')
        .order('ano', { ascending: false }),
      supabase
        .from('relacoes_normativas')
        .select('norma_origem_id,norma_destino_id,tipo,dispositivo,observacoes'),
    ]).then(([normasRes, relacoesRes]) => {
      if (!normasRes.data?.length) return;

      const dados = normasRes.data as any[];
      const tituloPorId = new Map(dados.map((n) => [n.id, n.titulo]));
      const relacoesPorNorma = new Map<string, string[]>();

      ((relacoesRes.data || []) as RelacaoBanco[]).forEach((r) => {
        const destino = tituloPorId.get(r.norma_destino_id);
        if (!destino) return;
        const atual = relacoesPorNorma.get(r.norma_origem_id) || [];
        atual.push(`${rotuloRelacao(r.tipo)}: ${destino}${r.dispositivo ? ` — ${r.dispositivo}` : ''}`);
        relacoesPorNorma.set(r.norma_origem_id, atual);
      });

      const catalogo = new Map(normasLocais.map((n) => [chaveNorma(n.titulo), n]));

      dados.forEach((n) => {
        const chave = chaveNorma(n.titulo);
        const local = catalogo.get(chave);
        catalogo.set(chave, {
          ...local,
          id: n.id,
          tipo: n.tipo,
          numero: n.numero,
          ano: n.ano,
          titulo: n.titulo,
          assunto: n.assunto,
          orgao: n.orgao || undefined,
          dataPublicacao: n.data_norma || undefined,
          vigenciaInicio: n.vigencia_inicio || undefined,
          vigenciaFim: n.vigencia_fim || null,
          status: normalizarStatus(n.status),
          statusDetalhado: n.status_detalhado || undefined,
          normaPrincipal: n.norma_principal ?? undefined,
          usarComoFundamento: n.usar_como_fundamento ?? undefined,
          ultimaVerificacao: n.ultima_verificacao || undefined,
          observacaoVigencia: n.observacao_vigencia || undefined,
          palavrasChave: n.palavras_chave || [],
          relacoes: relacoesPorNorma.get(n.id) || local?.relacoes || [],
        } as Norma);
      });

      setNormas([...catalogo.values()].sort((a, b) => b.ano - a.ano || a.titulo.localeCompare(b.titulo)));
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
      [n.titulo, n.assunto, n.status, n.statusDetalhado, n.orgao, ...(n.palavrasChave || [])]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
        .includes(termo),
    );
  }, [q, normas]);

  const resumoBase = useMemo(() => ({
    total: normas.length,
    aptas: normas.filter(podeFundamentar).length,
    atencao: normas.filter((n) => ['Parcialmente vigente', 'Vigência a confirmar', 'Superada materialmente'].includes(n.status)).length,
    revogadas: normas.filter((n) => n.status === 'Revogada').length,
  }), [normas]);

  const sintese = useMemo(() => {
    if (!resposta?.length) return null;

    const principal = resposta[0];
    const metadadosPrincipal = normas.find((n) => chaveNorma(n.titulo) === chaveNorma(principal.titulo));
    const fundamentos = resposta.slice(0, 4);
    const normasUnicas = [...new Set(fundamentos.map((r) => r.titulo))];
    const statusEncontrados = [...new Set(fundamentos.map((r) => normalizarStatus(r.status)))];
    const observacoes: string[] = [];

    if (statusEncontrados.some((s) => s !== 'Vigente')) {
      observacoes.push('Há fundamento vigente com alterações; a leitura deve considerar a redação consolidada e a cadeia normativa exibida abaixo.');
    }
    if (metadadosPrincipal?.observacaoVigencia) {
      observacoes.push(metadadosPrincipal.observacaoVigencia);
    }
    if (normasUnicas.length > 1) {
      observacoes.push(`A consulta foi sustentada por ${normasUnicas.length} normas relacionadas ao tema.`);
    }

    return {
      principal,
      metadadosPrincipal,
      fundamentos,
      normasUnicas,
      statusEncontrados,
      observacoes,
    };
  }, [resposta, normas]);

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

              <small>A resposta é montada exclusivamente a partir de trechos da base considerados seguros para fundamentação automática.</small>

              {erroConsulta && (
                <div className="answer empty">
                  <h3>Falha na consulta</h3>
                  <p>{erroConsulta}</p>
                </div>
              )}

              {sintese && (
                <section className="structured-answer">
                  <div className="structured-head">
                    <div>
                      <span>RESPOSTA FUNDAMENTADA</span>
                      <h2>{pergunta}</h2>
                    </div>
                    <i className={`badge ${statusSlug(normalizarStatus(sintese.principal.status))}`}>
                      {normalizarStatus(sintese.principal.status)}
                    </i>
                  </div>

                  <div className="answer-block primary-block">
                    <h3>Resposta</h3>
                    <p>{sintese.principal.conteudo}</p>
                  </div>

                  <div className="answer-grid">
                    <div className="answer-block">
                      <h3>Fundamentação</h3>
                      {sintese.fundamentos.map((f, i) => (
                        <div className="foundation-line" key={`${f.id}-${i}`}>
                          <b>{f.titulo}</b>
                          <span>{f.dispositivo || 'Dispositivo não informado'}{f.pagina ? ` • pág. ${f.pagina}` : ''}</span>
                        </div>
                      ))}
                    </div>

                    <div className="answer-block">
                      <h3>Situação normativa</h3>
                      <p><b>Fundamento principal:</b> {normalizarStatus(sintese.principal.status)}</p>
                      {sintese.metadadosPrincipal?.statusDetalhado && <p>{sintese.metadadosPrincipal.statusDetalhado}</p>}
                      {sintese.metadadosPrincipal?.ultimaVerificacao && (
                        <p><b>Última verificação:</b> {sintese.metadadosPrincipal.ultimaVerificacao.split('-').reverse().join('/')}</p>
                      )}
                    </div>
                  </div>

                  <div className="answer-block observations-block">
                    <h3>Observações</h3>
                    {sintese.observacoes.length > 0 ? (
                      sintese.observacoes.map((o, i) => <p key={`${o}-${i}`}>• {o}</p>)
                    ) : (
                      <p>Não foi identificado alerta adicional de vigência nos fundamentos selecionados.</p>
                    )}
                    <small>Síntese automática baseada somente nos trechos recuperados. Para decisões administrativas ou jurídicas, confira o dispositivo integral e a versão oficial consolidada.</small>
                  </div>
                </section>
              )}

              {Array.isArray(resposta) && resposta.length > 0 && (
                <div className="answer detailed-sources">
                  <div className="answer-head">
                    <div>
                      <h3>Fontes e trechos utilizados</h3>
                      <p>{resposta.length} fundamento{resposta.length > 1 ? 's' : ''} seguro{resposta.length > 1 ? 's' : ''} localizado{resposta.length > 1 ? 's' : ''}.</p>
                    </div>
                    {possuiAlerta && <span className="attention">Atenção à vigência</span>}
                  </div>

                  {resposta.map((r) => {
                    const status = normalizarStatus(r.status);
                    const metadados = normas.find((n) => chaveNorma(n.titulo) === chaveNorma(r.titulo));
                    const relacoes = r.relacoes?.length
                      ? r.relacoes.map((x) => `${rotuloRelacao(x.tipo)}: ${x.norma_relacionada}${x.dispositivo ? ` — ${x.dispositivo}` : ''}`)
                      : metadados?.relacoes || [];

                    return (
                      <article key={r.id}>
                        <div className="result-title">
                          <b>{r.normas?.titulo || r.titulo}</b>
                          <i className={`badge ${statusSlug(status)}`}>{status}</i>
                        </div>
                        <span>{r.dispositivo || 'Dispositivo não informado'}{r.pagina ? ` • pág. ${r.pagina}` : ''}</span>
                        <p>{r.conteudo}</p>
                        <div className="source-meta">
                          <strong>Fundamento:</strong> {r.titulo}{r.dispositivo ? ` — ${r.dispositivo}` : ''}{r.pagina ? ` — pág. ${r.pagina}` : ''}<br />
                          <strong>Situação:</strong> {metadados?.statusDetalhado || status}
                          {metadados?.ultimaVerificacao && <><br /><strong>Última verificação:</strong> {metadados.ultimaVerificacao.split('-').reverse().join('/')}</>}
                          {metadados?.observacaoVigencia && <><br /><strong>Observação de vigência:</strong> {metadados.observacaoVigencia}</>}
                        </div>
                        {relacoes.length > 0 && (
                          <div className="norm-chain">
                            <strong>Cadeia normativa</strong>
                            {relacoes.map((relacao, i) => <span key={`${relacao}-${i}`}>{relacao}</span>)}
                          </div>
                        )}
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
              <article><BookOpen /><h3>Resposta fundamentada</h3><p>Entrega resposta, fundamento, vigência e observações em blocos separados.</p></article>
              <article><ShieldCheck /><h3>Controle de vigência</h3><p>Distingue normas vigentes, parcialmente vigentes, alteradoras, revogadas e pendentes.</p></article>
              <article><FileSearch /><h3>Cadeia normativa</h3><p>Mostra atos que alteram, revogam, substituem ou complementam o fundamento localizado.</p></article>
            </section>
          </>
        ) : (
          <section className="library">
            <div className="title">
              <div>
                <span>BASE DOCUMENTAL</span>
                <h1>Normas cadastradas</h1>
                <p>Catálogo estruturado com status de vigência, relações normativas e política de uso como fundamento.</p>
              </div>
              <div className="search"><Search /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Pesquisar norma ou assunto" /></div>
            </div>

            <div className="base-stats">
              <div><b>{resumoBase.total}</b><span>Normas cadastradas</span></div>
              <div><b>{resumoBase.aptas}</b><span>Aptas a fundamentar</span></div>
              <div><b>{resumoBase.atencao}</b><span>Exigem atenção</span></div>
              <div><b>{resumoBase.revogadas}</b><span>Revogadas</span></div>
            </div>

            <div className="table">
              <div className="tr head"><span>Norma</span><span>Assunto e cadeia normativa</span><span>Situação</span></div>
              {filtered.map((n) => (
                <div className="tr" key={n.id}>
                  <span>
                    <b>{n.titulo}</b>
                    <small>{n.tipo} • {n.ano}{n.orgao ? ` • ${n.orgao}` : ''}</small>
                    <small>{n.normaPrincipal === false ? 'Ato de relacionamento normativo' : n.usarComoFundamento === false ? 'Bloqueada para fundamento automático' : 'Pode ser usada como fundamento'}</small>
                  </span>
                  <span>
                    {n.assunto}
                    {n.statusDetalhado && <small>{n.statusDetalhado}</small>}
                    {n.relacoes?.map((r) => <small className="relation-line" key={r}>{r}</small>)}
                    {n.observacaoVigencia && <small>{n.observacaoVigencia}</small>}
                  </span>
                  <span>
                    <i className={`badge ${statusSlug(n.status)}`}>{n.status}</i>
                    {n.vigenciaInicio && <small>Vigência: {n.vigenciaInicio.split('-').reverse().join('/')}</small>}
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
