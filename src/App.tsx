import { lazy, Suspense, useEffect, useRef, useState } from "react";
import {
  Building2,
  ShieldCheck,
  Search,
  BookOpen,
  ClipboardList,
  History,
  Star,
  Download,
  Printer,
  ArrowRight,
} from "lucide-react";
import { normas as normasLocais } from "./data/normas";
import { supabase } from "./lib/supabase";
import { normalizarStatus, podeFundamentar, statusSlug } from "./lib/normas";
import {
  ATIVIDADES,
  PRODUTOS,
  contextoInicial,
  faltantes,
  conflitosContexto,
  fonteAtual,
  secoesExtraidas,
  coberturaConsulta,
  lerHistorico,
  salvarHistorico,
  exportarConsulta,
  hoje,
  urlSegura,
  validarConsulta,
  limitarHistorico,
  filtrarHistorico,
  temReferenciaNormativa,
} from "./lib/consulta";
import type {
  Consulta,
  ContextoEmpresa,
  RegistroConsulta,
  Esclarecimento,
} from "./lib/consulta";
import type { Norma } from "./types";
import { FonteNormativa, LinhaNormativa } from "./components/FonteNormativa";
import { PerguntasRevisadas } from "./components/PerguntasRevisadas";
import { PUBLICOS, identificarPublico, ehHistoricoNormativo } from "./lib/publicos";
import { perguntasExemplo } from "./data/perguntas-exemplo";
import { HistoricoNormas } from "./components/HistoricoNormas";
const Revisao = lazy(() =>
  import("./components/Revisao").then((m) => ({ default: m.Revisao })),
);

type Tab = "consulta" | "base" | "roteiros" | "historico" | "revisao";
type StatusResultado = {
  norma_id: string;
  titulo: string;
  status: string;
  status_detalhado?: string;
  observacao_vigencia?: string;
  ultima_verificacao?: string;
  usar_como_fundamento: boolean;
};
const exemplos = [
  "Minha empresa precisa de registro para comercializar produtos químicos?",
  "Quais requisitos se aplicam à importação de PCE?",
  "Como funciona o apostilamento de atividade no registro da empresa?",
  "Empresa de segurança privada pode adquirir PCE de menor potencial ofensivo?",
];
const label = (opcoes: readonly (readonly [string, string])[], id: string) =>
  opcoes.find((x) => x[0] === id)?.[1] || id;

export default function App() {
  const [tab, setTab] = useState<Tab>("consulta");
  const [pergunta, setPergunta] = useState("");
  const [contexto, setContexto] = useState<ContextoEmpresa>(contextoInicial);
  const [consulta, setConsulta] = useState<RegistroConsulta | null>(null);
  const [status, setStatus] = useState<StatusResultado[] | null>(null);
  const [carregando, setCarregando] = useState(false);
  const [erro, setErro] = useState("");
  const [pendencias, setPendencias] = useState<string[]>([]);
  const [alternativas, setAlternativas] = useState<Esclarecimento[]>([]);
  const [historico, setHistorico] = useState<RegistroConsulta[]>(lerHistorico);
  const [buscaHistorico, setBuscaHistorico] = useState("");
  const [soFavoritos, setSoFavoritos] = useState(false);
  const [excluidos, setExcluidos] = useState<RegistroConsulta[]>([]);
  const [normas, setNormas] = useState<Norma[]>(normasLocais);
  const [busca, setBusca] = useState("");
  const [avisoBase, setAvisoBase] = useState("");
  const [mensagem, setMensagem] = useState("");
  const requestId = useRef(0);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    let ativo = true;
    if (!supabase) {
      setAvisoBase(
        "Conexão indisponível. O catálogo abaixo é uma referência local, sem confirmação do estado atual.",
      );
      return;
    }
    supabase
      .from("normas")
      .select(
        "id,tipo,numero,ano,titulo,orgao,assunto,status,status_detalhado,usar_como_fundamento,ultima_verificacao,observacao_vigencia,fonte_oficial,vigencia_inicio,vigencia_fim,palavras_chave",
      )
      .order("ano", { ascending: false })
      .then(({ data, error }) => {
        if (!ativo) return;
        if (error || !data?.length) {
          setAvisoBase(
            "Não foi possível atualizar o catálogo. Exibindo referência local.",
          );
          return;
        }
        setNormas(
          data.map((n) => ({
            id: n.id,
            tipo: n.tipo,
            numero: n.numero,
            ano: n.ano,
            titulo: n.titulo,
            orgao: n.orgao,
            assunto: n.assunto,
            status: normalizarStatus(n.status),
            statusDetalhado: n.status_detalhado,
            usarComoFundamento: n.usar_como_fundamento,
            ultimaVerificacao: n.ultima_verificacao,
            observacaoVigencia: n.observacao_vigencia,
            fonteOficial: n.fonte_oficial,
            vigenciaInicio: n.vigencia_inicio,
            vigenciaFim: n.vigencia_fim,
            palavrasChave: n.palavras_chave || [],
          })),
        );
      });
    return () => {
      ativo = false;
    };
  }, []);
  function atualizarContexto<K extends keyof ContextoEmpresa>(
    campo: K,
    valor: ContextoEmpresa[K],
  ) {
    setContexto((c) => ({ ...c, [campo]: valor }));
    invalidar();
  }
  function invalidar() {
    requestId.current++;
    setConsulta(null);
    setStatus(null);
    setPendencias([]);
    setAlternativas([]);
    setErro("");
    setCarregando(false);
  }
  function guardar(itens: RegistroConsulta[]) {
    const limitados = limitarHistorico(itens);
    setHistorico(limitados);
    if (!salvarHistorico(limitados))
      setMensagem(
        "Seu navegador não permitiu salvar o histórico. Você ainda pode exportar a consulta.",
      );
  }
  async function consultar() {
    if (!pergunta.trim() || carregando) return;
    const rid = ++requestId.current;
    setConsulta(null);
    setStatus(null);
    setErro("");
    setPendencias([]);
    setAlternativas([]);
    setMensagem("");
    if (!supabase) {
      setErro("Conexão com a base normativa indisponível.");
      return;
    }
    if (!contexto.data || contexto.data > hoje()) {
      setPendencias([
        "Selecione a data atual ou uma data anterior. Regras futuras não serão tratadas como obrigações atuais.",
      ]);
      return;
    }
    if (contexto.data < hoje()) {
      setPendencias([
        "A base ainda não possui todas as redações históricas. Para esta versão, consulte na data atual.",
      ]);
      return;
    }
    const referenciaExplicita = temReferenciaNormativa(pergunta);
    const vigencia = !referenciaExplicita && ehHistoricoNormativo(pergunta);
    const publico = contexto.publico === "automatico" ? identificarPublico(pergunta) : contexto.publico;
    const contextoConsulta = { ...contexto, publico };
    const faltam =
      vigencia || referenciaExplicita
        ? []
        : [
            ...conflitosContexto(pergunta, contextoConsulta),
            ...faltantes(pergunta, contextoConsulta),
          ];
    if (faltam.length) {
      setPendencias(faltam);
      inputRef.current?.focus();
      return;
    }
    setCarregando(true);
    try {
      const { data, error } = await supabase.rpc("consultar_publico_pce", {
        p_pergunta: pergunta.trim(),
        p_produto: contexto.produto,
        p_atividade: contexto.atividade,
        p_publico: publico,
        p_data: contexto.data,
        p_limite: 10,
      });
      if (rid !== requestId.current) return;
      if (error) throw error;
      if (!validarConsulta(data)) throw new Error("Resposta inválida");
      const resposta = data as Consulta;
      if (resposta.esclarecimentos?.length) {
        setPendencias([
          resposta.aviso_referencia || "Escolha a seção da norma.",
        ]);
        setAlternativas(resposta.esclarecimentos);
        return;
      }
      resposta.fontes = resposta.fontes.filter((f) =>
        fonteAtual(f, contexto.data),
      );
      const ids = new Set(resposta.fontes.map((f) => f.dispositivo_id));
      resposta.orientacoes = resposta.orientacoes.filter(
        (o) =>
          o.secoes.length > 0 &&
          o.secoes.every(
            (s) =>
              s.dispositivo_ids.length > 0 &&
              s.dispositivo_ids.every((id) => ids.has(id)),
          ),
      );
      const registro: RegistroConsulta = {
        id: crypto.randomUUID(),
        pergunta: pergunta.trim(),
        contexto: contextoConsulta,
        consulta: resposta,
        criadoEm: new Date().toISOString(),
        favorito: false,
      };
      setConsulta(registro);
      // Os detalhes ficam no dispositivo do usuário, sem serem enviados ao banco.
      guardar([registro, ...historico]);
    } catch {
      if (rid === requestId.current)
        setErro("Não foi possível concluir a consulta. Tente novamente.");
    } finally {
      if (rid === requestId.current) setCarregando(false);
    }
  }
  function abrirRegistro(r: RegistroConsulta) {
    invalidar();
    setContexto(r.contexto);
    setPergunta(r.pergunta);
    setConsulta(r);
    setTab("consulta");
  }
  function prepararPergunta(g: {
    pergunta_modelo: string;
    produto: string;
    atividade: string;
    publico?: ContextoEmpresa["publico"];
  }) {
    invalidar();
    setPergunta(g.pergunta_modelo);
    setContexto({
      ...contextoInicial(),
      produto: g.produto,
      atividade: g.atividade,
      publico: g.publico ?? "automatico",
    });
    inputRef.current?.focus();
    inputRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
  }
  function sugerir(q: string, atividade = "todos") {
    invalidar();
    setPergunta(q);
    setContexto((c) => ({ ...c, atividade }));
    setTab("consulta");
    setTimeout(() => inputRef.current?.focus(), 0);
  }
  const fontes = consulta?.consulta.fontes || [];
  const extracoes = secoesExtraidas(fontes);
  const catalogo = normas.filter((n) =>
    [n.titulo, n.assunto, n.status, ...(n.palavrasChave || [])]
      .join(" ")
      .toLocaleLowerCase("pt-BR")
      .includes(busca.toLocaleLowerCase("pt-BR")),
  );
  const favorito =
    consulta && historico.find((h) => h.id === consulta.id)?.favorito;

  return (
    <>
      <header>
        <div className="brand">
          <div className="seal">
            <ShieldCheck />
          </div>
          <div>
            <b>NORMAS DFPC</b>
            <span>Orientação normativa para atividades com PCE</span>
          </div>
        </div>
        <nav aria-label="Navegação principal">
          {(
            [
              ["consulta", "Consulta"],
              ["base", "Normas"],
              ["roteiros", "Procedimentos"],
              ["historico", "Histórico"],
              ["revisao", "Revisão"],
            ] as const
          ).map(([id, t]) => (
            <button
              key={id}
              className={tab === id ? "active" : ""}
              onClick={() => setTab(id)}
              aria-current={tab === id ? "page" : undefined}
            >
              {t}
            </button>
          ))}
        </nav>
      </header>
      {mensagem && (
        <div className="global-notice" role="status">
          {mensagem}
          <button onClick={() => setMensagem("")} aria-label="Fechar aviso">
            ×
          </button>
        </div>
      )}
      <main>
        {tab === "consulta" && (
          <>
            <section className="hero">
              <div className="eyebrow">
                <Building2 size={17} /> CONSULTA NORMATIVA PCE
              </div>
              <h1>
                Entenda a norma.
                <br />
                Encontre o próximo passo.
              </h1>
              <p>
                Consulte requisitos, procedimentos e vigência com fundamentos
                rastreáveis para empresas, CAC, militares e policiais.
              </p>
              <form
                className="consult-form"
                onSubmit={(e) => {
                  e.preventDefault();
                  void consultar();
                }}
              >
                <div className="context-grid">
                  <label>
                    Público
                    <select
                      value={contexto.publico}
                      onChange={(e) =>
                        atualizarContexto(
                          "publico",
                          e.target.value as ContextoEmpresa["publico"],
                        )
                      }
                    >
                      {PUBLICOS.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
                    </select>
                  </label>
                  <label>
                    Produto
                    <select
                      value={contexto.produto}
                      onChange={(e) =>
                        atualizarContexto("produto", e.target.value)
                      }
                    >
                      {PRODUTOS.map(([v, t]) => (
                        <option key={v} value={v}>
                          {t}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label>
                    Atividade
                    <select
                      value={contexto.atividade}
                      onChange={(e) =>
                        atualizarContexto("atividade", e.target.value)
                      }
                    >
                      {ATIVIDADES.map(([v, t]) => (
                        <option key={v} value={v}>
                          {t}
                        </option>
                      ))}
                    </select>
                  </label>
                </div>
                <label className="question-label" htmlFor="pergunta">
                  Qual é a dúvida?
                </label>
                <div className="ask">
                  <Search aria-hidden="true" />
                  <textarea
                    id="pergunta"
                    ref={inputRef}
                    value={pergunta}
                    onChange={(e) => {
                      setPergunta(e.target.value);
                      invalidar();
                    }}
                    placeholder="Descreva a dúvida, o público e a situação…"
                    maxLength={2000}
                    rows={3}
                  />
                  <button
                    type="submit"
                    disabled={carregando || !pergunta.trim()}
                  >
                    {carregando ? "Consultando…" : "Consultar"}
                    <ArrowRight size={16} />
                  </button>
                </div>
                <details className="context-details">
                  <summary>Detalhes do caso e data da consulta</summary>
                  <div className="context-grid">
                    <label>
                      Situação de registro informada
                      <select
                        value={contexto.registro}
                        onChange={(e) =>
                          atualizarContexto("registro", e.target.value)
                        }
                      >
                        <option value="nao_informado">Não informado</option>
                        <option value="sem_registro">
                          Empresa sem registro
                        </option>
                        <option value="registrada">Empresa com registro</option>
                        <option value="em_renovacao">
                          Registro em renovação
                        </option>
                      </select>
                    </label>
                    <label>
                      Data de referência
                      <input
                        type="date"
                        value={contexto.data}
                        max={hoje()}
                        required
                        onChange={(e) =>
                          atualizarContexto("data", e.target.value)
                        }
                      />
                    </label>
                  </div>
                  <label>
                    Características do produto e finalidade
                    <textarea
                      value={contexto.detalhes}
                      onChange={(e) =>
                        atualizarContexto("detalhes", e.target.value)
                      }
                      maxLength={1000}
                      placeholder="Ex.: composição e concentração, tipo de produto, finalidade da operação."
                    />
                  </label>
                  <small>
                    Estes detalhes ficam no histórico deste navegador. A busca
                    usa a pergunta e os filtros de produto e atividade; o
                    registro informado não comprova autorização da empresa.
                  </small>
                </details>
              </form>
              {!consulta && !status && !carregando && (
                <div className="examples" aria-label="Exemplos de perguntas">
                  {exemplos.map((q) => (
                    <button key={q} onClick={() => sugerir(q)}>
                      {q}
                    </button>
                  ))}
                </div>
              )}
            </section>
            {!consulta && !status && !carregando && (
              <section className="library">
                <details>
                  <summary>Explorar 46 perguntas por tema</summary>
                  {perguntasExemplo.map(g => (
                    <details key={g.grupo}>
                      <summary>{g.grupo} · {g.perguntas.length} perguntas</summary>
                      <div className="examples">
                        {g.perguntas.map(q => <button key={q} onClick={() => {
                          invalidar(); setPergunta(q); setContexto(contextoInicial());
                          inputRef.current?.focus();
                        }}>{q}</button>)}
                      </div>
                    </details>
                  ))}
                </details>
              </section>
            )}
            <div className="results" aria-live="polite" aria-busy={carregando}>
              {carregando && (
                <div className="answer">
                  <p>Consultando os fundamentos cadastrados…</p>
                </div>
              )}
              {erro && (
                <div className="answer warning" role="alert">
                  <h2>Consulta indisponível</h2>
                  <p>{erro}</p>
                </div>
              )}
              {!!pendencias.length && (
                <div className="answer warning">
                  <h2>Precisamos identificar o caso</h2>
                  <ul>
                    {pendencias.map((p) => (
                      <li key={p}>{p}</li>
                    ))}
                  </ul>
                  {!!alternativas.length && (
                    <div className="toolbar">
                      {alternativas.map((a) => (
                        <button
                          key={a.rotulo}
                          onClick={() => sugerir(a.pergunta)}
                        >
                          {a.rotulo}
                        </button>
                      ))}
                    </div>
                  )}
                  <p>
                    {alternativas.length
                      ? "Escolha uma seção acima e clique em Consultar."
                      : "Complete os filtros ou inclua essas informações na pergunta."}
                  </p>
                </div>
              )}
              {status && (
                <section className="structured-answer">
                  <h2>Situação normativa cadastrada</h2>
                  {!status.length ? (
                    <p>Não localizei a norma. Informe tipo, número e ano.</p>
                  ) : (
                    status.map((s, i) => (
                      <article key={s.norma_id} className="source-card">
                        <h3>{s.titulo}</h3>
                        <span
                          className={`badge ${statusSlug(normalizarStatus(s.status))}`}
                        >
                          {normalizarStatus(s.status)}
                        </span>
                        <p>{s.status_detalhado}</p>
                        <p>{s.observacao_vigencia}</p>
                        <p className="muted">
                          Última verificação cadastrada:{" "}
                          {s.ultima_verificacao || "não informada"}. O uso de
                          norma parcialmente vigente depende do dispositivo
                          específico.
                        </p>
                        {i === 0 && <LinhaNormativa titulo={s.titulo} />}
                      </article>
                    ))
                  )}
                </section>
              )}
              {consulta && (
                <section className="structured-answer">
                  <div className="structured-head">
                    <div>
                      <span>
                        {consulta.criadoEm !== historico[0]?.criadoEm
                          ? "CONSULTA SALVA"
                          : "RESULTADO DA CONSULTA"}
                      </span>
                      <h2>{consulta.pergunta}</h2>
                    </div>
                    <span className="badge">
                      {consulta.consulta.historico_normativo !== undefined ? "Histórico normativo" : consulta.consulta.metodologia ? "Vigência e redação" : `${fontes.length} fundamento${fontes.length !== 1 ? "s" : ""}`}
                    </span>
                  </div>
                  <div className="case-meta">
                    <span>{label(PRODUTOS, consulta.contexto.produto)}</span>
                    <span>
                      {label(ATIVIDADES, consulta.contexto.atividade)}
                    </span>
                    <span>Referência: {consulta.contexto.data}</span>
                  </div>
                  <div className="toolbar">
                    <button
                      onClick={() => {
                        const itens = historico.map((h) =>
                          h.id === consulta.id
                            ? { ...h, favorito: !h.favorito }
                            : h,
                        );
                        guardar(itens);
                      }}
                    >
                      <Star
                        size={16}
                        fill={favorito ? "currentColor" : "none"}
                      />
                      {favorito ? "Favoritada" : "Favoritar"}
                    </button>
                    <button onClick={() => exportarConsulta(consulta)}>
                      <Download size={16} />
                      Exportar consulta
                    </button>
                    <button onClick={() => window.print()}>
                      <Printer size={16} />
                      Imprimir / PDF
                    </button>
                    <button onClick={() => void consultar()}>
                      Consultar novamente
                    </button>
                  </div>
                  <p className="muted">
                    Realizada em{" "}
                    {new Date(consulta.criadoEm).toLocaleString("pt-BR")}.
                    Consultas salvas preservam os fundamentos daquela consulta;
                    use “Consultar novamente” para verificar atualizações.
                  </p>
                  {!consulta.consulta.metodologia && consulta.consulta.historico_normativo === undefined &&
                    <CoberturaResposta consulta={consulta.consulta} />}
                  {consulta.consulta.pergunta_interpretada && (
                    <p className="answer-block">
                      Tema reconhecido:{" "}
                      <b>{consulta.consulta.pergunta_interpretada}</b> A
                      orientação aborda a regra geral deste tema; confira abaixo
                      sua aplicação e eventuais condições.
                    </p>
                  )}
                  {!!consulta.consulta.complementares && (
                    <p className="muted">
                      {consulta.consulta.complementares === 1
                        ? "Incluído 1 dispositivo complementar"
                        : `Incluídos ${consulta.consulta.complementares} dispositivos complementares`}{" "}
                      do mesmo artigo para conferir condições e exceções.
                    </p>
                  )}
                  {consulta.consulta.aviso_referencia && (
                    <p className="answer-block">
                      {consulta.consulta.aviso_referencia}
                    </p>
                  )}
                  {consulta.consulta.historico_normativo !== undefined ? (
                    <HistoricoNormas normas={consulta.consulta.historico_normativo} />
                  ) : consulta.consulta.metodologia ? (
                    <div className="answer-block primary-block">
                      <h3>{consulta.consulta.metodologia.titulo}</h3>
                      <p>{consulta.consulta.metodologia.texto}</p>
                      <p>{consulta.consulta.metodologia.referencia}</p>
                      <a href={urlSegura(consulta.consulta.metodologia.fonte_oficial)!}
                        target="_blank" rel="noopener noreferrer">Conferir fonte oficial</a>
                    </div>
                  ) : !fontes.length ? (
                    <div className="answer-block warning">
                      <h3>Fundamento insuficiente para responder</h3>
                      <p>
                        {consulta.consulta.referencia_exata
                          ? "A referência solicitada não possui texto individual conferido e aplicável no acervo."
                          : "Não localizei um dispositivo conferido e aplicável aos filtros escolhidos. Isso não significa que a atividade é dispensada de controle."}
                      </p>
                      <p>
                        {consulta.consulta.referencia_exata
                          ? "Confira o número, o ano, o artigo e a seção da norma. Pode ser necessário complementar ou conferir o acervo."
                          : "Especifique o produto e a atividade ou revise os filtros. A base pode precisar de complementação."}
                      </p>
                    </div>
                  ) : (
                    <>
                      {!!consulta.consulta.orientacoes.length ? (
                        consulta.consulta.orientacoes.map((o) => (
                          <div
                            key={o.id}
                            className="answer-block primary-block"
                          >
                            <h3>{o.titulo}</h3>
                            {o.secoes.map((s, i) => (
                              <section key={i}>
                                <h4>{s.titulo}</h4>
                                <p>{s.texto}</p>
                                <p className="muted">
                                  Fundamentos:{" "}
                                  {s.dispositivo_ids.map((id) => {
                                    const idx = fontes.findIndex(
                                      (f) => f.dispositivo_id === id,
                                    );
                                    return idx >= 0 ? (
                                      <a key={id} href={`#fonte-${idx + 1}`}>
                                        [{idx + 1}]{" "}
                                      </a>
                                    ) : null;
                                  })}
                                </p>
                                {!!s.fontes_complementares?.length && (
                                  <ul className="complementary-links">
                                    {s.fontes_complementares.map((f) => (
                                      <li key={f.url}>
                                        <a
                                          href={urlSegura(f.url)!}
                                          target="_blank"
                                          rel="noopener noreferrer"
                                        >
                                          {f.titulo}
                                        </a>
                                        <small>
                                          Fonte complementar verificada em{" "}
                                          {f.verificado_em}.
                                        </small>
                                      </li>
                                    ))}
                                  </ul>
                                )}
                              </section>
                            ))}
                            <small>
                              Orientação revisada em {o.revisado_em}.
                            </small>
                          </div>
                        ))
                      ) : (
                        <div className="answer-block primary-block">
                          <h3>
                            {consulta.consulta.referencia_exata
                              ? "Trechos da referência solicitada"
                              : "O que a base permite consultar"}
                          </h3>
                          <p>
                            {consulta.consulta.referencia_exata
                              ? "Os trechos abaixo podem abranger apenas partes do artigo. Confira a indicação de caput, parágrafo e inciso em cada referência."
                              : "Foram localizados dispositivos sobre o tema. Ainda não há uma orientação prática revisada para esta pergunta específica; confira os requisitos e as exceções nos fundamentos abaixo."}
                          </p>
                        </div>
                      )}
                      <div className="answer-sections">
                        {extracoes
                          .filter((g) => g.itens.length)
                          .map((g) => (
                            <div className="answer-block" key={g.titulo}>
                              <h3>{g.titulo}</h3>
                              <p className="muted">
                                Índice por palavras do texto cadastrado. Leia o
                                trecho completo para conferir sua aplicação.
                              </p>
                              {g.itens.map((f) => {
                                const i = fontes.indexOf(f) + 1;
                                return (
                                  <p key={f.trecho_id}>
                                    {f.titulo} · {f.dispositivo}{" "}
                                    <a
                                      href={`#fonte-${i}`}
                                      aria-label={`Ver fundamento ${i}`}
                                    >
                                      [{i}]
                                    </a>
                                  </p>
                                );
                              })}
                            </div>
                          ))}
                      </div>
                      <div className="answer-block observations-block">
                        <h3>
                          {consulta.consulta.referencia_exata
                            ? "Conferência da referência"
                            : "Aplicação ao caso"}
                        </h3>
                        <p>
                          {consulta.consulta.referencia_exata
                            ? "A situação exibida corresponde ao cadastro desses dispositivos. Para aplicar a norma a uma operação empresarial, consulte também os demais requisitos e condições pertinentes."
                            : "Confirme que o produto, a atividade e as condições descritas nos dispositivos correspondem ao público e ao caso informado. A busca textual identifica fundamentos; a classificação de relevância não comprova autorização ou dispensa."}
                        </p>
                        {consulta.consulta.fontes_excluidas > 0 && (
                          <p>
                            {consulta.consulta.fontes_excluidas} trecho(s)
                            candidato(s) ficaram fora por falta de vínculo exato
                            ou validação de vigência.
                          </p>
                        )}
                      </div>
                      <h3 className="sources-title">
                        Fundamentos e texto cadastrado
                      </h3>
                      {fontes.map((f, i) => (
                        <FonteNormativa
                          key={f.trecho_id}
                          fonte={f}
                          indice={i + 1}
                        />
                      ))}
                    </>
                  )}
                </section>
              )}
            </div>
            {!status &&
              (!consulta ||
                (!consulta.consulta.orientacoes.length &&
                  !consulta.consulta.metodologia &&
                  consulta.consulta.historico_normativo === undefined &&
                  !consulta.consulta.referencia_exata)) && (
                <PerguntasRevisadas
                  key={consulta?.id || "catalogo"}
                  selecionar={prepararPergunta}
                  relacionada={
                    consulta
                      ? {
                          pergunta: consulta.pergunta,
                          produto: consulta.contexto.produto,
                          atividade: consulta.contexto.atividade,
                        }
                      : undefined
                  }
                />
              )}
            {!consulta && !status && (
              <section className="features">
                <article>
                  <Building2 />
                  <h3>Produto e atividade</h3>
                  <p>
                    Filtros por público, produto e atividade; esclarecimento quando
                    faltam dados.
                  </p>
                </article>
                <article>
                  <BookOpen />
                  <h3>Fundamento exato</h3>
                  <p>
                    Dispositivo vinculado ao trecho, com texto e origem
                    disponíveis para conferência.
                  </p>
                </article>
                <article>
                  <ShieldCheck />
                  <h3>Vigência e rastreabilidade</h3>
                  <p>
                    Controle de redações, alterações e data de referência da
                    consulta.
                  </p>
                </article>
              </section>
            )}
          </>
        )}
        {tab === "base" && (
          <section className="library">
            <div className="title">
              <div>
                <span>ACERVO NORMATIVO</span>
                <h1>Normas e situação cadastrada</h1>
                <p>
                  Consulte a vigência, as alterações e a origem dos fundamentos.
                </p>
              </div>
              <label className="search">
                <Search size={18} />
                <input
                  aria-label="Buscar norma"
                  value={busca}
                  onChange={(e) => setBusca(e.target.value)}
                  placeholder="Norma, assunto ou situação"
                />
              </label>
            </div>
            {avisoBase && <p className="warning">{avisoBase}</p>}
            <div className="source-card">
              <h2>Conferir publicações oficiais</h2>
              <p>
                A consulta usa o acervo cadastrado. Consulte a DFPC e os
                documentos oficiais para conferir publicações e alterações ainda
                não incorporadas.
              </p>
              <div className="toolbar">
                <a
                  href="https://www.dfpc.eb.mil.br/index.php/informacoes/legislacao"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Legislação da DFPC
                </a>
                <a
                  href="https://www.gov.br/siscomex/pt-br/servicos/aprendendo-a-exportar/legislacao/dfpc/"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Referências do Exército no Siscomex
                </a>
              </div>
            </div>
            <div className="base-stats">
              <div>
                <b>{normas.length}</b>
                <span>Normas no catálogo</span>
              </div>
              <div>
                <b>{normas.filter(podeFundamentar).length}</b>
                <span>Normas aptas; dispositivos exigem conferência</span>
              </div>
              <div>
                <b>
                  {
                    normas.filter((n) => n.status === "Parcialmente vigente")
                      .length
                  }
                </b>
                <span>Com validação por dispositivo</span>
              </div>
              <div>
                <b>{normas.filter((n) => !n.fonteOficial).length}</b>
                <span>Links oficiais pendentes</span>
              </div>
            </div>
            {!catalogo.length && <p>Nenhuma norma corresponde à busca.</p>}
            <div className="norm-list">
              {catalogo.map((n) => (
                <article key={n.id} className="source-card">
                  <div className="source-heading">
                    <h3>{n.titulo}</h3>
                    <span className={`badge ${statusSlug(n.status)}`}>
                      {n.status}
                    </span>
                  </div>
                  <p>{n.assunto}</p>
                  <p className="muted">
                    Última verificação: {n.ultimaVerificacao || "não informada"}
                  </p>
                  {n.observacaoVigencia && <p>{n.observacaoVigencia}</p>}
                  <div className="toolbar">
                    <button
                      onClick={() => sugerir(`${n.titulo} está vigente?`)}
                    >
                      Consultar vigência
                    </button>
                    {urlSegura(n.fonteOficial) && (
                      <a
                        href={urlSegura(n.fonteOficial)!}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        Fonte oficial
                      </a>
                    )}
                  </div>
                  <details>
                    <summary>Ver cadeia normativa</summary>
                    <LinhaNormativa titulo={n.titulo} />
                  </details>
                </article>
              ))}
            </div>
          </section>
        )}
        {tab === "roteiros" && (
          <section className="library">
            <div className="eyebrow">
              <ClipboardList size={16} /> PROCEDIMENTOS EMPRESARIAIS
            </div>
            <h1>Encontre os requisitos da sua operação</h1>
            <p>
              Escolha o procedimento, identifique o produto e consulte os
              fundamentos. Documentos e etapas dependem das condições da norma e
              do caso.
            </p>
            <div className="procedure-grid">
              {ATIVIDADES.filter(([v]) => v !== "todos").map(([v, t]) => (
                <article className="source-card" key={v}>
                  <h2>{t}</h2>
                  <ol>
                    <li>Identifique o produto e suas características.</li>
                    <li>Informe a atividade e a dúvida específica.</li>
                    <li>
                      Confira requisitos, exceções e prazos nos dispositivos.
                    </li>
                    <li>
                      Use os documentos e procedimentos que se aplicam ao caso.
                    </li>
                  </ol>
                  <button
                    onClick={() =>
                      sugerir(
                        `Quais requisitos e documentos se aplicam à atividade de ${t.toLowerCase()} de PCE por uma empresa?`,
                        v,
                      )
                    }
                  >
                    Consultar este procedimento <ArrowRight size={16} />
                  </button>
                </article>
              ))}
            </div>
          </section>
        )}
        {tab === "historico" && (
          <section className="library">
            <div className="title">
              <div>
                <span>CONSULTAS NESTE NAVEGADOR</span>
                <h1>Histórico e favoritos</h1>
                <p>
                  Até 30 consultas são guardadas neste dispositivo, com a versão
                  dos fundamentos utilizados.
                </p>
              </div>
              {!!historico.length && (
                <button
                  onClick={() => {
                    setExcluidos(historico);
                    guardar([]);
                    setConsulta(null);
                    setMensagem("Histórico removido deste navegador.");
                  }}
                >
                  Limpar histórico
                </button>
              )}
            </div>
            <div className="toolbar history-filters">
              <label>
                Buscar no histórico
                <input
                  type="search"
                  value={buscaHistorico}
                  onChange={(e) => setBuscaHistorico(e.target.value)}
                />
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={soFavoritos}
                  onChange={(e) => setSoFavoritos(e.target.checked)}
                />{" "}
                Somente favoritos
              </label>
            </div>
            {!!excluidos.length && (
              <div className="global-notice" role="status">
                {excluidos.length} consulta(s) excluída(s).
                <button
                  onClick={() => {
                    const ids = new Set(historico.map((r) => r.id));
                    guardar(
                      [
                        ...historico,
                        ...excluidos.filter((r) => !ids.has(r.id)),
                      ].sort((a, b) => b.criadoEm.localeCompare(a.criadoEm)),
                    );
                    setExcluidos([]);
                    setMensagem("Exclusão desfeita.");
                  }}
                >
                  Desfazer exclusão
                </button>
                <small>Disponível até sair ou recarregar a página.</small>
              </div>
            )}
            {!historico.length ? (
              <div className="answer empty">
                <History />
                <p>Suas consultas aparecerão aqui.</p>
              </div>
            ) : (
              <div className="history-list">
                {!filtrarHistorico(historico, buscaHistorico, soFavoritos)
                  .length && <p>Nenhuma consulta corresponde aos filtros.</p>}
                {filtrarHistorico(historico, buscaHistorico, soFavoritos).map(
                  (r) => (
                    <article className="source-card" key={r.id}>
                      <h3>{r.pergunta}</h3>
                      <p className="muted">
                        {new Date(r.criadoEm).toLocaleString("pt-BR")} ·{" "}
                        {r.consulta.fontes.length} fundamentos ·{" "}
                        {r.contexto.data}
                      </p>
                      <div className="toolbar">
                        <button onClick={() => abrirRegistro(r)}>
                          Abrir consulta
                        </button>
                        <button
                          aria-label={
                            r.favorito ? "Remover favorito" : "Favoritar"
                          }
                          onClick={() =>
                            guardar(
                              historico.map((h) =>
                                h.id === r.id
                                  ? { ...h, favorito: !h.favorito }
                                  : h,
                              ),
                            )
                          }
                        >
                          <Star
                            size={16}
                            fill={r.favorito ? "currentColor" : "none"}
                          />
                        </button>
                        <button onClick={() => exportarConsulta(r)}>
                          Exportar
                        </button>
                        <button
                          onClick={() => {
                            setExcluidos([r]);
                            guardar(historico.filter((h) => h.id !== r.id));
                            if (consulta?.id === r.id) setConsulta(null);
                          }}
                        >
                          Excluir
                        </button>
                      </div>
                    </article>
                  ),
                )}
              </div>
            )}
          </section>
        )}
        {tab === "revisao" && (
          <Suspense
            fallback={<p role="status">Carregando painel de revisão…</p>}
          >
            <Revisao />
          </Suspense>
        )}
      </main>
      <footer>
        Normas DFPC · Consulta fundamentada em conteúdo cadastrado · Sem
        serviços externos de geração de respostas
      </footer>
    </>
  );
}

function CoberturaResposta({ consulta }: { consulta: Consulta }) {
  const cobertura = coberturaConsulta(consulta);
  return (
    <aside
      className="answer-block coverage-block"
      aria-label="Alcance da resposta"
    >
      <h3>{cobertura.titulo}</h3>
      <p>
        A resposta usa o acervo cadastrado. A consulta não verifica
        automaticamente novas publicações na DFPC.
      </p>
      {!!consulta.fontes.length && (
        <p>
          Fontes com link oficial: {consulta.fontes.length - cobertura.semLink}{" "}
          de {consulta.fontes.length}.
          {cobertura.semLink > 0 && " Há links oficiais pendentes de cadastro."}
          {cobertura.semData > 0 &&
            ` ${cobertura.semData} fonte(s) sem data de verificação informada.`}
        </p>
      )}
      {!!consulta.fontes.length && (
        <p>
          Textos com reconferência documentada: {cobertura.textosReconferidos}{" "}
          de {consulta.fontes.length}. A reconferência do texto é distinta da
          análise de vigência.
        </p>
      )}
      {cobertura.fundamentosAusentes > 0 && (
        <p role="status">
          A orientação cita {cobertura.fundamentosAusentes} dispositivo(s) que
          não aparecem nos fundamentos desta consulta. Confira essas referências
          antes de aplicar a orientação.
        </p>
      )}
      <p className="muted">
        A data de verificação de cada dispositivo está disponível em “Ver origem
        e verificação”.
      </p>
    </aside>
  );
}
