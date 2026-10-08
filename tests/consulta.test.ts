import assert from "node:assert/strict";
import { test } from "node:test";
import {
  contextoInicial,
  faltantes,
  fonteAtual,
  urlSegura,
  lerHistorico,
  salvarHistorico,
  secoesExtraidas,
} from "../src/lib/consulta.ts";
import type { Fonte } from "../src/lib/consulta.ts";
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
