import assert from "node:assert/strict";
import { test } from "node:test";
import {
  coberturaConsulta,
  contextoInicial,
  faltantes,
  fonteAtual,
  urlSegura,
  lerHistorico,
  salvarHistorico,
  secoesExtraidas,
  validarConsulta,
  limitarHistorico,
  filtrarHistorico,
  temReferenciaNormativa,
} from "../src/lib/consulta.ts";
import type { Fonte } from "../src/lib/consulta.ts";
import type { RegistroConsulta } from "../src/lib/consulta.ts";
const fonte = {
  dispositivo_id: "id",
  literal_conferido: true,
  texto_literal: "texto",
  status: "vigente_com_alteracoes",
  status_dispositivo: "vigente",
  vigencia_inicio: "2026-01-01",
  vigencia_fim: null,
} as Fonte;
test("não trata redação futura ou revogada como aplicável", () => {
  assert.equal(fonteAtual(fonte, "2026-10-08"), true);
  assert.equal(
    fonteAtual({ ...fonte, vigencia_inicio: "2027-01-01" }, "2026-10-08"),
    false,
  );
  assert.equal(
    fonteAtual({ ...fonte, status_dispositivo: "revogado" }, "2026-10-08"),
    false,
  );
  assert.equal(
    fonteAtual({ ...fonte, status: "ato_alterador" }, "2026-10-08"),
    false,
  );
  assert.equal(
    fonteAtual({ ...fonte, literal_conferido: false }, "2026-10-08"),
    false,
  );
  assert.equal(
    fonteAtual({ ...fonte, dispositivo_id: null }, "2026-10-08"),
    false,
  );
  assert.equal(
    fonteAtual({ ...fonte, status: "parcialmente_vigente" }, "2026-10-08"),
    true,
  );
  assert.equal(
    fonteAtual({ ...fonte, vigencia_fim: "2026-10-01" }, "2026-10-08"),
    false,
  );
});
test("pede contexto quando produto e atividade estão ausentes", () => {
  const c = contextoInicial();
  assert.equal(faltantes("Minha empresa precisa de autorização?", c).length, 2);
  assert.equal(
    faltantes("Minha empresa precisa de autorização?", {
      ...c,
      produto: "explosivos",
      atividade: "transporte",
    }).length,
    0,
  );
  assert.equal(faltantes("O que é PCE?", c).length, 0);
});
test("bloqueia links executáveis e protocolos não seguros", () => {
  assert.equal(urlSegura("javascript:alert(1)"), null);
  assert.equal(urlSegura("http://example.com"), null);
  assert.equal(urlSegura("https://www.gov.br"), "https://www.gov.br/");
});
test("recupera histórico com armazenamento inválido ou indisponível", () => {
  let data = "invalid";
  Object.defineProperty(globalThis, "localStorage", {
    configurable: true,
    value: {
      getItem: () => data,
      setItem: (_k: string, v: string) => {
        data = v;
      },
    },
  });
  assert.deepEqual(lerHistorico(), []);
  data = '[{"id":"corrompido"}]';
  assert.deepEqual(lerHistorico(), []);
  assert.equal(salvarHistorico([]), true);
  assert.deepEqual(lerHistorico(), []);
  Object.defineProperty(globalThis, "localStorage", {
    configurable: true,
    get: () => {
      throw new Error("blocked");
    },
  });
  assert.equal(salvarHistorico([]), false);
  assert.deepEqual(lerHistorico(), []);
});

test("não confunde danos com prazos em anos", () => {
  const f = {
    ...fonte,
    conteudo: "Produto que possa causar danos às pessoas.",
  } as Fonte;
  assert.equal(
    secoesExtraidas([f]).find((g) => g.titulo.startsWith("Prazos"))?.itens
      .length,
    0,
  );
  assert.equal(
    secoesExtraidas([{ ...f, conteudo: "O prazo é de dois anos." }]).find((g) =>
      g.titulo.startsWith("Prazos"),
    )?.itens.length,
    1,
  );
});
test("reconhece a família de menor potencial ofensivo", () => {
  assert.equal(
    faltantes(
      "Empresa de segurança privada pode adquirir PCE de menor potencial ofensivo?",
      contextoInicial(),
    ).length,
    0,
  );
});

test("distingue perguntas de procedimento de enquadramento de caso específico", () => {
  assert.deepEqual(
    faltantes("Como incluir nova atividade no CR?", contextoInicial()),
    [],
  );
  assert.deepEqual(
    faltantes(
      "Como verificar se uma mistura ou solução química é PCE?",
      contextoInicial(),
    ),
    [],
  );
  assert.ok(
    faltantes("Minha mistura é PCE?", contextoInicial()).some((p) =>
      p.includes("componentes"),
    ),
  );
  assert.deepEqual(
    faltantes(
      "Preciso de CR para vender produtos químicos?",
      contextoInicial(),
    ),
    [],
  );
});

test("identifica consultas por norma e artigo sem confundir dúvidas gerais", () => {
  assert.equal(
    temReferenciaNormativa(
      "O art. 2º do Anexo I do Decreto nº 10.030 foi revogado?",
    ),
    true,
  );
  assert.equal(temReferenciaNormativa("Artigo 3 da Portaria 118/2019"), true);
  assert.equal(temReferenciaNormativa("Arts. 98 e 99 do Decreto 10030"), true);
  assert.equal(temReferenciaNormativa("O que é PCE?"), false);
  assert.equal(temReferenciaNormativa("A Portaria 56 foi revogada?"), false);
});
test("valida opções de esclarecimento antes de mostrar ou salvar", () => {
  const c = registro("1").consulta;
  assert.equal(
    validarConsulta({
      ...c,
      esclarecimentos: [
        { rotulo: "Anexo I", pergunta: "Art. 2º do Anexo I do Decreto 10030" },
      ],
    }),
    true,
  );
  assert.equal(
    validarConsulta({
      ...c,
      esclarecimentos: [{ rotulo: { invalido: true } }],
    }),
    false,
  );
});

const registro = (id: string, favorito = false): RegistroConsulta => ({
  id,
  favorito,
  pergunta: "Importação de químicos",
  criadoEm: "2026-10-08T12:00:00Z",
  contexto: contextoInicial(),
  consulta: {
    fontes: [],
    orientacoes: [],
    data_referencia: "2026-10-08",
    versao: "v2",
    fontes_excluidas: 0,
  },
});
test("preserva favorito antigo e a consulta recém-feita no limite do histórico", () => {
  const itens = Array.from({ length: 30 }, (_, i) =>
    registro(String(i), i === 29),
  );
  const salvos = limitarHistorico([registro("nova"), ...itens]);
  assert.equal(salvos.length, 30);
  assert.equal(salvos[0].id, "nova");
  assert.ok(salvos.some((r) => r.id === "29"));
  const todosFavoritos = limitarHistorico([
    registro("nova"),
    ...itens.map((r) => ({ ...r, favorito: true })),
  ]);
  assert.equal(todosFavoritos[0].id, "nova");
  assert.equal(todosFavoritos.length, 30);
});
test("busca no histórico ignora acentos e respeita favoritos", () => {
  assert.equal(
    filtrarHistorico([registro("1"), registro("2", true)], "IMPORTACAO", true)
      .length,
    1,
  );
  assert.equal(
    filtrarHistorico([registro("1")], "explosivos", false).length,
    0,
  );
});
test("rejeita resposta ou histórico com conteúdo interno corrompido", () => {
  assert.equal(validarConsulta(registro("1").consulta), true);
  assert.equal(
    validarConsulta({ ...registro("1").consulta, fontes: [null] }),
    false,
  );
  assert.equal(
    validarConsulta({
      ...registro("1").consulta,
      orientacoes: [{ secoes: "inválido" }],
    }),
    false,
  );
  Object.defineProperty(globalThis, "localStorage", {
    configurable: true,
    value: {
      getItem: () =>
        JSON.stringify([
          registro("valido"),
          { ...registro("corrompido"), contexto: { publico: "empresa" } },
        ]),
    },
  });
  assert.deepEqual(
    lerHistorico().map((r) => r.id),
    ["valido"],
  );
});

test("distingue cobertura e denuncia referências ausentes sem usar relevância como confiança", () => {
  const consulta = {
    fontes: [],
    orientacoes: [],
    data_referencia: "2026-10-08",
    versao: "v4",
    fontes_excluidas: 0,
  };
  assert.equal(coberturaConsulta(consulta).titulo, "Fundamento insuficiente");
  const documental = {
    ...consulta,
    fontes: [
      {
        ...fonte,
        fonte_oficial: "javascript:alert(1)",
        ultima_verificacao: null,
        relevancia: 100,
      },
    ],
  };
  assert.equal(
    coberturaConsulta(documental).titulo,
    "Pesquisa documental, sem orientação revisada",
  );
  assert.equal(coberturaConsulta(documental).semLink, 1);
  assert.equal(coberturaConsulta(documental).semData, 1);
  assert.equal(
    coberturaConsulta({ ...documental, referencia_exata: true }).titulo,
    "Referência normativa localizada",
  );
  const orientacao = {
    id: "o",
    titulo: "Tema",
    produto: "todos",
    atividade: "todas",
    pergunta_modelo: "Pergunta",
    estado: "publicada" as const,
    revisado_em: null,
    secoes: [
      {
        titulo: "Regra",
        texto: "Texto",
        dispositivo_ids: ["id", "ausente", "ausente"],
      },
    ],
  };
  assert.equal(
    coberturaConsulta({ ...documental, orientacoes: [orientacao] })
      .fundamentosAusentes,
    1,
  );
});
