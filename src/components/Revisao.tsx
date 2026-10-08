import { useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "../lib/supabase";
import { ATIVIDADES, PRODUTOS, urlSegura } from "../lib/consulta";
import type { Orientacao, SecaoOrientacao } from "../lib/consulta";
type Auditoria = {
  id: string;
  titulo: string;
  status: string;
  ultima_verificacao: string | null;
  fonte_oficial: string | null;
  produtos: string[];
  atividades: string[];
  trechos: number;
  vinculados: number;
  dispositivos: number;
  conferidos: number;
};
type Dispositivo = {
  id: string;
  referencia: string;
  texto_literal: string;
  status: string;
  conferido: boolean;
};
export function Revisao() {
  const [auditoria, setAuditoria] = useState<Auditoria[]>([]);
  const [sessao, setSessao] = useState<Session | null>(null);
  const [revisor, setRevisor] = useState(false);
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [erro, setErro] = useState("");
  const [aviso, setAviso] = useState("");
  const [ocupado, setOcupado] = useState(false);
  const [filtro, setFiltro] = useState("pendencias");
  const [guias, setGuias] = useState<Orientacao[]>([]);
  const [titulo, setTitulo] = useState("");
  const [pergunta, setPergunta] = useState("");
  const [produto, setProduto] = useState("todos");
  const [atividade, setAtividade] = useState("todos");
  const [secoes, setSecoes] = useState<SecaoOrientacao[]>([
    { titulo: "Resposta direta", texto: "", dispositivo_ids: [] },
  ]);
  const [editando, setEditando] = useState<string | null>(null);
  const [normaId, setNormaId] = useState("");
  const [dispositivos, setDispositivos] = useState<Dispositivo[]>([]);
  const [url, setUrl] = useState("");
  const [ultimaVerificacao, setUltimaVerificacao] = useState("");
  useEffect(() => {
    let ativo = true;
    if (!supabase) return;
    supabase
      .from("v_revisao_empresarial")
      .select("*")
      .order("titulo")
      .then(({ data, error }) => {
        if (!ativo) return;
        if (error) setErro("Não foi possível carregar o painel de revisão.");
        else setAuditoria(data || []);
      });
    supabase.auth.getSession().then(({ data }) => {
      if (ativo) setSessao(data.session);
    });
    const { data } = supabase.auth.onAuthStateChange((_evento, session) =>
      setSessao(session),
    );
    return () => {
      ativo = false;
      data.subscription.unsubscribe();
    };
  }, []);
  useEffect(() => {
    let ativo = true;
    setRevisor(false);
    setGuias([]);
    if (!supabase || !sessao) return;
    supabase
      .from("revisores_normativos")
      .select("user_id")
      .eq("user_id", sessao.user.id)
      .maybeSingle()
      .then(({ data }) => {
        if (!ativo) return;
        setRevisor(!!data);
        if (data)
          supabase!
            .from("orientacoes_empresariais")
            .select("*")
            .order("updated_at", { ascending: false })
            .then(({ data }) => {
              if (ativo) setGuias(data || []);
            });
      });
    return () => {
      ativo = false;
    };
  }, [sessao]);
  useEffect(() => {
    let ativo = true;
    setDispositivos([]);
    const norma = auditoria.find((n) => n.id === normaId);
    setUrl(norma?.fonte_oficial || "");
    setUltimaVerificacao(norma?.ultima_verificacao || "");
    if (!supabase || !normaId) return;
    supabase
      .from("dispositivos")
      .select("id,referencia,texto_literal,status,conferido")
      .eq("norma_id", normaId)
      .order("referencia")
      .then(({ data, error }) => {
        if (!ativo) return;
        if (error) setErro("Não foi possível carregar os dispositivos.");
        else setDispositivos(data || []);
      });
    return () => {
      ativo = false;
    };
  }, [normaId, auditoria]);
  async function login(e: React.FormEvent) {
    e.preventDefault();
    if (!supabase) return;
    setOcupado(true);
    setErro("");
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password: senha,
      });
      if (error) setErro("Não foi possível entrar com essas credenciais.");
      else setSenha("");
    } catch {
      setErro("Falha de conexão. Tente novamente.");
    } finally {
      setOcupado(false);
    }
  }
  async function salvar(publicar: boolean) {
    if (!supabase || !revisor) return;
    setOcupado(true);
    setErro("");
    setAviso("");
    try {
      const conteudo = {
        titulo,
        pergunta_modelo: pergunta,
        produto,
        atividade,
        secoes,
        estado: publicar ? "publicada" : "rascunho",
      };
      const { error } = editando
        ? await supabase
            .from("orientacoes_empresariais")
            .update(conteudo)
            .eq("id", editando)
        : await supabase.from("orientacoes_empresariais").insert(conteudo);
      if (error) {
        setErro(error.message);
        return;
      }
      setAviso(
        publicar
          ? "Orientação publicada com fundamentos validados."
          : "Rascunho salvo.",
      );
      setEditando(null);
      setTitulo("");
      setPergunta("");
      setSecoes([
        { titulo: "Resposta direta", texto: "", dispositivo_ids: [] },
      ]);
      const { data } = await supabase
        .from("orientacoes_empresariais")
        .select("*")
        .order("updated_at", { ascending: false });
      setGuias(data || []);
    } catch {
      setErro("Não foi possível salvar a orientação.");
    } finally {
      setOcupado(false);
    }
  }
  async function salvarFonte() {
    if (!supabase || !revisor || !normaId) return;
    setErro("");
    setAviso("");
    if (url && !urlSegura(url)) {
      setErro("Informe um link HTTPS válido.");
      return;
    }
    if (!ultimaVerificacao) {
      setErro("Informe a data da conferência.");
      return;
    }
    setOcupado(true);
    try {
      const { error } = await supabase
        .from("normas")
        .update({
          fonte_oficial: url || null,
          ultima_verificacao: ultimaVerificacao,
        })
        .eq("id", normaId);
      if (error) setErro("Não foi possível atualizar a fonte.");
      else {
        setAuditoria((a) =>
          a.map((n) =>
            n.id === normaId
              ? {
                  ...n,
                  fonte_oficial: url || null,
                  ultima_verificacao: ultimaVerificacao,
                }
              : n,
          ),
        );
        setAviso("Metadados da conferência atualizados.");
      }
    } catch {
      setErro("Não foi possível atualizar a fonte.");
    } finally {
      setOcupado(false);
    }
  }
  const linhas = auditoria.filter(
    (n) =>
      filtro === "todos" ||
      !n.fonte_oficial ||
      !n.ultima_verificacao ||
      n.vinculados < n.trechos ||
      n.conferidos < n.dispositivos,
  );
  return (
    <section className="library">
      <span className="eyebrow">QUALIDADE DO ACERVO</span>
      <h1>Revisão e rastreabilidade</h1>
      <p>
        Acompanhe as lacunas do corpus. Percentuais de vínculo não representam a
        totalidade dos artigos de uma norma.
      </p>
      <div className="base-stats">
        <div>
          <b>{auditoria.length}</b>
          <span>Normas monitoradas</span>
        </div>
        <div>
          <b>{auditoria.reduce((n, a) => n + a.vinculados, 0)}</b>
          <span>Trechos com referência exata</span>
        </div>
        <div>
          <b>{auditoria.filter((a) => !a.fonte_oficial).length}</b>
          <span>Fontes oficiais pendentes</span>
        </div>
        <div>
          <b>{auditoria.reduce((n, a) => n + a.trechos - a.vinculados, 0)}</b>
          <span>Trechos sem vínculo exato</span>
        </div>
      </div>
      {erro && (
        <p className="warning" role="alert">
          {erro}
        </p>
      )}
      {aviso && (
        <p className="global-notice" role="status">
          {aviso}
        </p>
      )}
      <label className="filter-label">
        Mostrar
        <select value={filtro} onChange={(e) => setFiltro(e.target.value)}>
          <option value="pendencias">Normas com pendências</option>
          <option value="todos">Todas as normas</option>
        </select>
      </label>
      <div className="audit-table">
        <table>
          <thead>
            <tr>
              <th>Norma</th>
              <th>Situação</th>
              <th>Trechos vinculados</th>
              <th>Dispositivos conferidos</th>
              <th>Origem</th>
            </tr>
          </thead>
          <tbody>
            {linhas.map((n) => (
              <tr key={n.id}>
                <td>
                  {n.titulo}
                  <small>
                    {n.ultima_verificacao || "Sem data de verificação"}
                  </small>
                </td>
                <td>{n.status.replaceAll("_", " ")}</td>
                <td>
                  {n.vinculados}/{n.trechos}
                </td>
                <td>
                  {n.conferidos}/{n.dispositivos}
                </td>
                <td>
                  {urlSegura(n.fonte_oficial) ? (
                    <a
                      href={urlSegura(n.fonte_oficial)!}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      Fonte
                    </a>
                  ) : (
                    "Link pendente"
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <section className="source-card reviewer">
        <h2>Área de curadoria</h2>
        <p>
          A publicação de orientações exige acesso de revisor autorizado. Cada
          seção publicada deve citar dispositivos conferidos e vigentes.
        </p>
        {!sessao ? (
          <form onSubmit={(e) => void login(e)} className="login-form">
            <label>
              E-mail
              <input
                type="email"
                autoComplete="username"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </label>
            <label>
              Senha
              <input
                type="password"
                autoComplete="current-password"
                required
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
              />
            </label>
            <button disabled={ocupado || !supabase} type="submit">
              Entrar
            </button>
            <small>
              Contas e permissões de revisor são provisionadas pelo
              administrador do projeto.
            </small>
          </form>
        ) : (
          <>
            <div className="toolbar">
              <span>
                {revisor
                  ? "Revisor autorizado"
                  : "Conta sem permissão de revisão"}
              </span>
              <button onClick={() => void supabase?.auth.signOut()}>
                Sair
              </button>
            </div>
            {!revisor && (
              <p>
                Solicite ao administrador a autorização de revisor para esta
                conta.
              </p>
            )}
          </>
        )}
        {revisor && (
          <>
            <div className="editor-grid">
              <label>
                Norma para conferir
                <select
                  value={normaId}
                  onChange={(e) => setNormaId(e.target.value)}
                >
                  <option value="">Selecione</option>
                  {auditoria.map((n) => (
                    <option key={n.id} value={n.id}>
                      {n.titulo}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Fonte oficial HTTPS
                <input
                  type="url"
                  value={url}
                  onChange={(e) => setUrl(e.target.value)}
                />
              </label>
              <label>
                Data da conferência
                <input
                  type="date"
                  value={ultimaVerificacao}
                  onChange={(e) => setUltimaVerificacao(e.target.value)}
                />
              </label>
              <button
                disabled={ocupado || !normaId}
                onClick={() => void salvarFonte()}
              >
                Salvar fonte e conferência
              </button>
            </div>
            {!!dispositivos.length && (
              <details>
                <summary>Dispositivos da norma (para citar nas seções)</summary>
                {dispositivos.map((d) => (
                  <article key={d.id} className="device-preview">
                    <b>
                      {d.referencia} · {d.status}
                    </b>
                    <code>{d.id}</code>
                    <p>{d.texto_literal}</p>
                  </article>
                ))}
              </details>
            )}
            <h3>
              {editando ? "Editar orientação" : "Nova orientação prática"}
            </h3>
            <div className="editor-grid">
              <label>
                Título
                <input
                  value={titulo}
                  onChange={(e) => setTitulo(e.target.value)}
                  maxLength={200}
                />
              </label>
              <label>
                Pergunta atendida
                <input
                  value={pergunta}
                  onChange={(e) => setPergunta(e.target.value)}
                  maxLength={1000}
                />
              </label>
              <label>
                Produto
                <select
                  value={produto}
                  onChange={(e) => setProduto(e.target.value)}
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
                  value={atividade}
                  onChange={(e) => setAtividade(e.target.value)}
                >
                  {ATIVIDADES.map(([v, t]) => (
                    <option key={v} value={v}>
                      {t}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            {secoes.map((s, i) => (
              <fieldset key={i}>
                <legend>Seção {i + 1}</legend>
                <label>
                  Título da seção
                  <input
                    value={s.titulo}
                    onChange={(e) =>
                      setSecoes((a) =>
                        a.map((x, j) =>
                          j === i ? { ...x, titulo: e.target.value } : x,
                        ),
                      )
                    }
                  />
                </label>
                <label>
                  Orientação
                  <textarea
                    value={s.texto}
                    onChange={(e) =>
                      setSecoes((a) =>
                        a.map((x, j) =>
                          j === i ? { ...x, texto: e.target.value } : x,
                        ),
                      )
                    }
                  />
                </label>
                <label>
                  IDs dos dispositivos, separados por vírgula
                  <input
                    value={s.dispositivo_ids.join(", ")}
                    onChange={(e) =>
                      setSecoes((a) =>
                        a.map((x, j) =>
                          j === i
                            ? {
                                ...x,
                                dispositivo_ids: e.target.value
                                  .split(",")
                                  .map((v) => v.trim())
                                  .filter(Boolean),
                              }
                            : x,
                        ),
                      )
                    }
                  />
                </label>
                <button
                  onClick={() => setSecoes((a) => a.filter((_, j) => j !== i))}
                >
                  Remover seção
                </button>
              </fieldset>
            ))}
            <div className="toolbar">
              <button
                onClick={() =>
                  setSecoes((a) => [
                    ...a,
                    {
                      titulo: "Condições e exceções",
                      texto: "",
                      dispositivo_ids: [],
                    },
                  ])
                }
              >
                Adicionar seção
              </button>
              <button disabled={ocupado} onClick={() => void salvar(false)}>
                Salvar rascunho
              </button>
              <button disabled={ocupado} onClick={() => void salvar(true)}>
                Publicar orientação
              </button>
            </div>
            <h3>Orientações cadastradas</h3>
            {guias.map((g) => (
              <div className="source-card" key={g.id}>
                <b>
                  {g.titulo} · {g.estado}
                </b>
                <p>{g.pergunta_modelo}</p>
                <button
                  onClick={() => {
                    setEditando(g.id);
                    setTitulo(g.titulo);
                    setPergunta(g.pergunta_modelo);
                    setProduto(g.produto);
                    setAtividade(g.atividade);
                    setSecoes(g.secoes);
                  }}
                >
                  Editar / retirar de publicação
                </button>
              </div>
            ))}
          </>
        )}
      </section>
    </section>
  );
}
