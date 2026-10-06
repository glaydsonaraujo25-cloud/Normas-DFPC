import { useEffect, useMemo, useState } from 'react';
import { BookOpen, FileSearch, Scale, Search, ShieldCheck } from 'lucide-react';
import { normas as normasLocais } from './data/normas';
import { supabase } from './lib/supabase';
import { normalizarStatus, ordenarPorSeguranca, podeFundamentar, statusSlug } from './lib/normas';
import type { Norma } from './types';

type ResultadoConsulta = {
  id?: string;
  trecho_id?: number;
  aspecto?: string;
  titulo: string;
  dispositivo?: string;
  pagina?: number;
  conteudo: string;
  status?: string;
  relevancia?: number;
  relacoes?: Array<{ tipo: string; norma_relacionada: string; dispositivo?: string; observacoes?: string }>;
  normas?: { titulo: string; status: string };
};

type ResultadoStatusNorma = {
  norma_id: string;
  titulo: string;
  tipo: string;
  numero: string;
  ano: number;
  status: string;
  status_detalhado?: string;
  usar_como_fundamento: boolean;
  observacao_vigencia?: string;
  ultima_verificacao?: string;
  relevancia?: number;
  relacoes?: Array<{ tipo: string; norma_relacionada: string; dispositivo?: string; observacoes?: string }>;
};

type RelacaoBanco = {
  norma_origem_id: string;
  norma_destino_id: string;
  tipo: string;
  dispositivo?: string | null;
  observacoes?: string | null;
};

type TemaId = 'todos' | 'armas' | 'municoes' | 'cac' | 'explosivos' | 'blindagem' | 'comercio_exterior' | 'sisfpc' | 'seguranca_privada';

type QualidadeAderencia = {
  rotulo: 'Alta aderência' | 'Aderência moderada' | 'Aderência baixa';
  slug: 'alta' | 'moderada' | 'baixa';
  conclusiva: boolean;
};

const TEMAS: Array<{ id: TemaId; rotulo: string; contexto: string }> = [
  { id: 'todos', rotulo: 'Todos', contexto: '' },
  { id: 'armas', rotulo: 'Armas', contexto: 'arma de fogo armas calibre registro aquisição porte' },
  { id: 'municoes', rotulo: 'Munições', contexto: 'munição munições marcação rastreabilidade aquisição recarga' },
  { id: 'cac', rotulo: 'CAC', contexto: 'CAC colecionador atirador caçador tiro desportivo guia de tráfego CR' },
  { id: 'explosivos', rotulo: 'Explosivos', contexto: 'explosivos detonação nitrato de amônio SICOEX armazenamento transporte' },
  { id: 'blindagem', rotulo: 'Blindagem', contexto: 'blindagem proteção balística EPBI SICOVAB veículo blindado colete balístico' },
  { id: 'comercio_exterior', rotulo: 'Importação / Exportação', contexto: 'importação exportação comércio exterior PCE LPCO DUIMP Siscomex' },
  { id: 'sisfpc', rotulo: 'SisFPC', contexto: 'SisFPC registro fiscalização autorização DFPC SFPC PCE' },
  { id: 'seguranca_privada', rotulo: 'Segurança Privada', contexto: 'segurança privada Polícia Federal PCE menor potencial ofensivo vigilância' },
];

const chaveNorma = (titulo: string) => titulo.trim().toLowerCase();
const perguntaSobreVigencia = (texto: string) => /\b(vigent|vig[eê]ncia|revogad|revogou|revoga[cç][aã]o|alterad|situa[cç][aã]o normativa|ainda vale|est[aá] valendo)\w*/i.test(texto);
const perguntaCompostaOuComparativa = (texto: string) => {
  const t = texto.toLowerCase();
  if (/(diferen[cç]a|comparar|compare|comparativo|versus|\bvs\b|o que muda)/i.test(t)) return true;
  const sinais = [
    /(adquir|aquisi[cç][aã]o|comprar|compra)/i,
    /(transport|tr[aá]fego|\bgt\b|\bgte\b)/i,
    /(registr|cadastr|craf|sigma|sinarm)/i,
    /(transfer)/i,
    /(muni[cç][aã]o|muni[cç][oõ]es|cartuchos?|recarga|insumos)/i,
    /(^|[^a-z])porte([^a-z]|$)|portar arma/i,
    /(requisito|documento|exig[eê]ncia|necess[aá]rio|deve apresentar)/i,
    /(procedimento|como fazer|como obter|como solicitar|requerer|pedido)/i,
  ];
  return sinais.filter((r) => r.test(t)).length >= 2;
};

const qualidadeDaAderencia = (relevancia?: number): QualidadeAderencia => {
  const valor = Number(relevancia || 0);
  if (valor >= 3) return { rotulo: 'Alta aderência', slug: 'alta', conclusiva: true };
  if (valor >= 1.2) return { rotulo: 'Aderência moderada', slug: 'moderada', conclusiva: true };
  return { rotulo: 'Aderência baixa', slug: 'baixa', conclusiva: false };
};

const rotuloRelacao = (tipo: string) => {
  const mapa: Record<string, string> = {
    altera: 'Altera', alterada_por: 'Alterada por', revoga: 'Revoga', revogada_por: 'Revogada por',
    complementa: 'Complementa', regulamenta: 'Regulamenta', substitui: 'Substitui', consolida: 'Consolida', cita: 'Cita',
  };
  return mapa[tipo] || tipo.replaceAll('_', ' ');
};

export default function App() {
  const [tab, setTab] = useState<'consulta' | 'base'>('consulta');
  const [q, setQ] = useState('');
  const [pergunta, setPergunta] = useState('');
  const [tema, setTema] = useState<TemaId>('todos');
  const [resposta, setResposta] = useState<ResultadoConsulta[] | null>(null);
  const [statusNormas, setStatusNormas] = useState<ResultadoStatusNorma[] | null>(null);
  const [consultando, setConsultando] = useState(false);
  const [buscaRealizada, setBuscaRealizada] = useState(false);
  const [erroConsulta, setErroConsulta] = useState('');
  const [normas, setNormas] = useState<Norma[]>(normasLocais);

  useEffect(() => {
    if (!supabase) return;
    Promise.all([
      supabase.from('normas').select('id,tipo,numero,ano,titulo,orgao,data_norma,assunto,status,status_detalhado,norma_principal,usar_como_fundamento,vigencia_inicio,vigencia_fim,ultima_verificacao,observacao_vigencia,palavras_chave').order('ano', { ascending: false }),
      supabase.from('relacoes_normativas').select('norma_origem_id,norma_destino_id,tipo,dispositivo,observacoes'),
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
        const local = catalogo.get(chaveNorma(n.titulo));
        catalogo.set(chaveNorma(n.titulo), {
          ...local, id: n.id, tipo: n.tipo, numero: n.numero, ano: n.ano, titulo: n.titulo, assunto: n.assunto,
          orgao: n.orgao || undefined, dataPublicacao: n.data_norma || undefined, vigenciaInicio: n.vigencia_inicio || undefined,
          vigenciaFim: n.vigencia_fim || null, status: normalizarStatus(n.status), statusDetalhado: n.status_detalhado || undefined,
          normaPrincipal: n.norma_principal ?? undefined, usarComoFundamento: n.usar_como_fundamento ?? undefined,
          ultimaVerificacao: n.ultima_verificacao || undefined, observacaoVigencia: n.observacao_vigencia || undefined,
          palavrasChave: n.palavras_chave || [], relacoes: relacoesPorNorma.get(n.id) || local?.relacoes || [],
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
    setResposta(null);
    setStatusNormas(null);

    if (!supabase) {
      setErroConsulta('A conexão com a base normativa não está disponível.');
      setConsultando(false);
      return;
    }

    if (perguntaSobreVigencia(pergunta)) {
      const { data, error } = await supabase.rpc('consultar_status_norma', { consulta: pergunta.trim(), limite: 6 });
      if (error) setErroConsulta('Não foi possível consultar a situação normativa agora.');
      else setStatusNormas((data || []) as ResultadoStatusNorma[]);
      setConsultando(false);
      return;
    }

    const temaSelecionado = TEMAS.find((item) => item.id === tema);
    const consultaEfetiva = [pergunta.trim(), temaSelecionado?.contexto].filter(Boolean).join(' ');
    const consultaComposta = perguntaCompostaOuComparativa(pergunta);
    const rpc = consultaComposta ? 'consultar_base_normativa_composta' : 'consultar_base_normativa';
    const { data: achados, error } = await supabase.rpc(rpc, { consulta: consultaEfetiva, limite: consultaComposta ? 10 : 12 });

    if (error) {
      setErroConsulta('Não foi possível consultar a base normativa agora.');
      setResposta([]);
      setConsultando(false);
      return;
    }

    const seguros = ordenarPorSeguranca((achados || []) as ResultadoConsulta[]).filter((item) => {
      const status = normalizarStatus(item.status);
      return !['Revogada', 'Superada materialmente', 'Vigência a confirmar', 'Ato alterador', 'Parcialmente vigente'].includes(status);
    });
    const melhorRelevancia = Math.max(...seguros.map((item) => Number(item.relevancia || 0)), 0);
    const corteDinamico = consultaComposta ? 0.35 : Math.max(0.35, melhorRelevancia * 0.22);
    const aderentes = seguros.filter((item) => Number(item.relevancia || 0) >= corteDinamico).slice(0, consultaComposta ? 10 : 8);
    setResposta(aderentes.map((x) => ({ ...x, normas: { titulo: x.titulo, status: normalizarStatus(x.status) } })));
    setConsultando(false);
  }

  const filtered = useMemo(() => {
    const termo = q.toLowerCase();
    return normas.filter((n) => [n.titulo, n.assunto, n.status, n.statusDetalhado, n.orgao, ...(n.palavrasChave || [])].filter(Boolean).join(' ').toLowerCase().includes(termo));
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
    const qualidade = qualidadeDaAderencia(principal.relevancia);
    const metadadosPrincipal = normas.find((n) => chaveNorma(n.titulo) === chaveNorma(principal.titulo));
    const fundamentos = resposta.slice(0, 6);
    const normasUnicas = [...new Set(fundamentos.map((r) => r.titulo))];
    const statusEncontrados = [...new Set(fundamentos.map((r) => normalizarStatus(r.status)))];
    const aspectos = [...new Set(fundamentos.map((r) => r.aspecto).filter(Boolean))] as string[];
    const observacoes: string[] = [];
    if (statusEncontrados.some((s) => s !== 'Vigente')) observacoes.push('Há fundamento vigente com alterações; considere a redação consolidada e a cadeia normativa.');
    if (metadadosPrincipal?.observacaoVigencia) observacoes.push(metadadosPrincipal.observacaoVigencia);
    if (normasUnicas.length > 1) observacoes.push(`A consulta foi sustentada por ${normasUnicas.length} normas relacionadas ao tema.`);
    if (aspectos.length > 1) observacoes.push(`A pergunta contém ${aspectos.length} aspectos normativos e foi analisada separadamente por assunto.`);
    if (!qualidade.conclusiva) observacoes.push('A aderência é baixa; o primeiro resultado não é apresentado como conclusão automática.');
    return { principal, qualidade, metadadosPrincipal, fundamentos, aspectos, observacoes };
  }, [resposta, normas]);

  const possuiAlerta = resposta?.some((r) => normalizarStatus(r.status) !== 'Vigente');
  const temaAtual = TEMAS.find((item) => item.id === tema)?.rotulo || 'Todos';

  return (
    <>
      <header>
        <div className="brand"><div className="seal"><ShieldCheck /></div><div><b>NORMAS DFPC</b><span>Base normativa de Produtos Controlados pelo Exército</span></div></div>
        <nav><button className={tab === 'consulta' ? 'active' : ''} onClick={() => setTab('consulta')}>Consulta</button><button className={tab === 'base' ? 'active' : ''} onClick={() => setTab('base')}>Base normativa</button></nav>
      </header>

      <main>
        {tab === 'consulta' ? (
          <>
            <section className="hero">
              <div className="eyebrow"><Scale size={16} /> CONSULTA NORMATIVA PCE</div>
              <h1>Encontre respostas fundamentadas<br />nas normas da DFPC.</h1>
              <p>Consulte conteúdo e também a situação de vigência de uma norma, sem usar atos revogados ou incertos como fundamento material.</p>

              <div className="topic-filters" aria-label="Filtro por tema">
                {TEMAS.map((item) => <button key={item.id} className={`topic-chip ${tema === item.id ? 'active' : ''}`} onClick={() => { setTema(item.id); setResposta(null); setStatusNormas(null); setBuscaRealizada(false); }}>{item.rotulo}</button>)}
              </div>

              <div className="ask"><Search /><input value={pergunta} onChange={(e) => setPergunta(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && consultar()} placeholder="Ex.: O que é PCE? A Portaria 42/2020 está vigente?" /><button onClick={consultar} disabled={consultando || !pergunta.trim()}>{consultando ? 'Buscando...' : 'Consultar'}</button></div>
              <small>Tema: <b>{temaAtual}</b>. Perguntas de vigência consultam o catálogo completo; perguntas materiais usam somente fundamentos seguros.</small>

              {erroConsulta && <div className="answer empty"><h3>Falha na consulta</h3><p>{erroConsulta}</p></div>}

              {statusNormas && statusNormas.length > 0 && (
                <section className="structured-answer">
                  <div className="structured-head"><div><span>VERIFICAÇÃO DE VIGÊNCIA</span><h2>{pergunta}</h2></div><i className={`badge ${statusSlug(normalizarStatus(statusNormas[0].status))}`}>{normalizarStatus(statusNormas[0].status)}</i></div>
                  <div className="answer-block primary-block"><h3>Resultado principal</h3><p><b>{statusNormas[0].titulo}</b></p><p>{statusNormas[0].status_detalhado || normalizarStatus(statusNormas[0].status)}</p>{statusNormas[0].observacao_vigencia && <p>{statusNormas[0].observacao_vigencia}</p>}<p><b>Uso como fundamento automático:</b> {statusNormas[0].usar_como_fundamento ? 'permitido' : 'bloqueado'}</p>{statusNormas[0].ultima_verificacao && <p><b>Última verificação:</b> {statusNormas[0].ultima_verificacao.split('-').reverse().join('/')}</p>}</div>
                  {statusNormas[0].relacoes?.length ? <div className="norm-chain"><strong>Cadeia normativa</strong>{statusNormas[0].relacoes.map((r, i) => <span key={`${r.tipo}-${i}`}>{rotuloRelacao(r.tipo)}: {r.norma_relacionada}{r.dispositivo ? ` — ${r.dispositivo}` : ''}</span>)}</div> : null}
                  {statusNormas.length > 1 && <div className="answer-block observations-block"><h3>Outras correspondências</h3>{statusNormas.slice(1, 4).map((n) => <p key={n.norma_id}>{n.titulo} — <b>{normalizarStatus(n.status)}</b></p>)}</div>}
                  <div className="answer-block observations-block"><small>Esta consulta informa a situação cadastrada da norma. Norma revogada, superada, alteradora ou com vigência não confirmada não é usada automaticamente como fundamento material.</small></div>
                </section>
              )}

              {statusNormas && statusNormas.length === 0 && !consultando && <div className="answer empty"><h3>Norma não localizada</h3><p>Não encontrei correspondência suficiente no catálogo. Informe, de preferência, tipo, número e ano da norma.</p></div>}

              {sintese && !sintese.qualidade.conclusiva && <div className="answer confidence-warning"><div className="answer-head"><div><h3>Resultado insuficiente para conclusão</h3><p>Foram encontrados trechos relacionados, mas a aderência ainda é baixa.</p></div><span className={`quality-badge ${sintese.qualidade.slug}`}>{sintese.qualidade.rotulo}</span></div><p>Refine a pergunta ou selecione um tema específico.</p></div>}

              {sintese && sintese.qualidade.conclusiva && (
                <section className="structured-answer">
                  <div className="structured-head"><div><span>{sintese.aspectos.length > 1 ? 'RESPOSTA COMPOSTA FUNDAMENTADA' : 'RESPOSTA FUNDAMENTADA'}</span><h2>{pergunta}</h2></div><div className="structured-badges"><span className={`quality-badge ${sintese.qualidade.slug}`}>{sintese.qualidade.rotulo}</span><i className={`badge ${statusSlug(normalizarStatus(sintese.principal.status))}`}>{normalizarStatus(sintese.principal.status)}</i></div></div>
                  {sintese.aspectos.length > 1 && <div className="answer-block aspects-block"><h3>Aspectos identificados</h3><div className="aspect-list">{sintese.aspectos.map((aspecto) => <span className="aspect-badge" key={aspecto}>{aspecto}</span>)}</div></div>}
                  <div className="answer-block primary-block"><h3>{sintese.aspectos.length > 1 ? 'Primeiro fundamento' : 'Resposta'}</h3><p>{sintese.principal.conteudo}</p></div>
                  {sintese.aspectos.length > 1 && <div className="answer-block"><h3>Fundamentos por aspecto</h3>{sintese.aspectos.map((aspecto) => { const f = sintese.fundamentos.find((item) => item.aspecto === aspecto); return f ? <div className="foundation-line" key={aspecto}><b>{aspecto}</b><span>{f.titulo} — {f.dispositivo || 'Dispositivo não informado'}</span><p>{f.conteudo}</p></div> : null; })}</div>}
                  <div className="answer-grid"><div className="answer-block"><h3>Fundamentação</h3>{sintese.fundamentos.map((f, i) => <div className="foundation-line" key={`${f.trecho_id || f.id}-${i}`}><b>{f.aspecto ? `${f.aspecto}: ` : ''}{f.titulo}</b><span>{f.dispositivo || 'Dispositivo não informado'}{f.pagina ? ` • pág. ${f.pagina}` : ''}</span></div>)}</div><div className="answer-block"><h3>Situação normativa</h3><p><b>Aderência:</b> {sintese.qualidade.rotulo}</p><p><b>Fundamento:</b> {normalizarStatus(sintese.principal.status)}</p>{sintese.metadadosPrincipal?.statusDetalhado && <p>{sintese.metadadosPrincipal.statusDetalhado}</p>}{sintese.metadadosPrincipal?.ultimaVerificacao && <p><b>Última verificação:</b> {sintese.metadadosPrincipal.ultimaVerificacao.split('-').reverse().join('/')}</p>}</div></div>
                  <div className="answer-block observations-block"><h3>Observações</h3>{sintese.observacoes.length ? sintese.observacoes.map((o, i) => <p key={`${o}-${i}`}>• {o}</p>) : <p>Não foi identificado alerta adicional de vigência.</p>}<small>Síntese baseada somente nos trechos recuperados do banco.</small></div>
                </section>
              )}

              {Array.isArray(resposta) && resposta.length > 0 && (
                <div className="answer detailed-sources"><div className="answer-head"><div><h3>Fontes e trechos utilizados</h3><p>{resposta.length} fundamento{resposta.length > 1 ? 's' : ''} seguro{resposta.length > 1 ? 's' : ''}.</p></div>{possuiAlerta && <span className="attention">Atenção à vigência</span>}</div>
                  {resposta.map((r, idx) => {
                    const status = normalizarStatus(r.status);
                    const metadados = normas.find((n) => chaveNorma(n.titulo) === chaveNorma(r.titulo));
                    const relacoes = r.relacoes?.length ? r.relacoes.map((x) => `${rotuloRelacao(x.tipo)}: ${x.norma_relacionada}${x.dispositivo ? ` — ${x.dispositivo}` : ''}`) : metadados?.relacoes || [];
                    const qualidade = qualidadeDaAderencia(r.relevancia);
                    return <article key={`${r.trecho_id || r.id || idx}`}><div className="result-title"><b>{r.titulo}</b><div className="result-badges">{r.aspecto && <span className="aspect-badge">{r.aspecto}</span>}<span className={`quality-badge ${qualidade.slug}`}>{qualidade.rotulo}</span><i className={`badge ${statusSlug(status)}`}>{status}</i></div></div><span>{r.dispositivo || 'Dispositivo não informado'}{r.pagina ? ` • pág. ${r.pagina}` : ''}</span><p>{r.conteudo}</p><div className="source-meta"><strong>Fundamento:</strong> {r.titulo}{r.dispositivo ? ` — ${r.dispositivo}` : ''}{r.aspecto && <><br /><strong>Aspecto:</strong> {r.aspecto}</>}<br /><strong>Aderência:</strong> {qualidade.rotulo}{typeof r.relevancia === 'number' ? ` • índice ${r.relevancia.toFixed(2)}` : ''}<br /><strong>Situação:</strong> {metadados?.statusDetalhado || status}{metadados?.observacaoVigencia && <><br /><strong>Observação:</strong> {metadados.observacaoVigencia}</>}</div>{relacoes.length > 0 && <div className="norm-chain"><strong>Cadeia normativa</strong>{relacoes.map((relacao, i) => <span key={`${relacao}-${i}`}>{relacao}</span>)}</div>}</article>;
                  })}
                </div>
              )}

              {buscaRealizada && !erroConsulta && Array.isArray(resposta) && resposta.length === 0 && !consultando && <div className="answer empty"><h3>Nenhum fundamento seguro localizado</h3><p>A base não encontrou trecho em norma apta a fundamentar automaticamente a resposta.</p></div>}
            </section>

            <section className="features"><article><BookOpen /><h3>Resposta fundamentada</h3><p>Entrega conteúdo, fundamento, vigência, aderência e observações.</p></article><article><ShieldCheck /><h3>Consulta de vigência</h3><p>Consulta também atos alteradores, revogados, superados ou pendentes sem usá-los como fundamento material.</p></article><article><FileSearch /><h3>Aderência e cadeia normativa</h3><p>Mostra relações de alteração, revogação, substituição e complementação.</p></article></section>
          </>
        ) : (
          <section className="library">
            <div className="title"><div><span>BASE DOCUMENTAL</span><h1>Normas cadastradas</h1><p>Catálogo estruturado com status de vigência, relações normativas e política de uso como fundamento.</p></div><div className="search"><Search /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Pesquisar norma ou assunto" /></div></div>
            <div className="base-stats"><div><b>{resumoBase.total}</b><span>Normas cadastradas</span></div><div><b>{resumoBase.aptas}</b><span>Aptas a fundamentar</span></div><div><b>{resumoBase.atencao}</b><span>Exigem atenção</span></div><div><b>{resumoBase.revogadas}</b><span>Revogadas</span></div></div>
            <div className="table"><div className="tr head"><span>Norma</span><span>Assunto e cadeia normativa</span><span>Situação</span></div>{filtered.map((n) => <div className="tr" key={n.id}><span><b>{n.titulo}</b><small>{n.tipo} • {n.ano}{n.orgao ? ` • ${n.orgao}` : ''}</small><small>{n.normaPrincipal === false ? 'Ato de relacionamento normativo' : n.usarComoFundamento === false ? 'Bloqueada para fundamento automático' : 'Pode ser usada como fundamento'}</small></span><span>{n.assunto}{n.statusDetalhado && <small>{n.statusDetalhado}</small>}{n.relacoes?.map((r) => <small className="relation-line" key={r}>{r}</small>)}{n.observacaoVigencia && <small>{n.observacaoVigencia}</small>}</span><span><i className={`badge ${statusSlug(n.status)}`}>{n.status}</i>{n.vigenciaInicio && <small>Vigência: {n.vigenciaInicio.split('-').reverse().join('/')}</small>}{n.ultimaVerificacao && <small>Verificado em {n.ultimaVerificacao.split('-').reverse().join('/')}</small>}</span></div>)}</div>
          </section>
        )}
      </main>
      <footer>Projeto Normas DFPC • Base para consulta técnica de PCE</footer>
    </>
  );
}
