import assert from "node:assert/strict";
import { test } from "node:test";
import { perguntasExemplo } from "../src/data/perguntas-exemplo.ts";
import { identificarPublico, ehHistoricoNormativo } from "../src/lib/publicos.ts";
import { contextoInicial, faltantes, conflitosContexto, temReferenciaNormativa } from "../src/lib/consulta.ts";

test("as 46 perguntas chegam à consulta sem bloqueio indevido de contexto", () => {
  const perguntas = perguntasExemplo.flatMap(g => [...g.perguntas]);
  assert.equal(new Set(perguntas).size, 46);
  for (const q of perguntas) {
    if (ehHistoricoNormativo(q) || temReferenciaNormativa(q)) continue;
    const c = {...contextoInicial(), publico: identificarPublico(q)};
    assert.deepEqual([...faltantes(q,c), ...conflitosContexto(q,c)], [], q);
  }
});
test("policiais militares não recebem enquadramento de militar do Exército", () => {
  assert.equal(identificarPublico("Policial militar pode adquirir arma?"), "policial");
  assert.equal(identificarPublico("Soldado temporário tem porte automático?"), "militar");
  assert.equal(identificarPublico("Atirador nível 3 pode ter quantas armas?"), "cac");
  assert.equal(identificarPublico("Militar e CAC podem transportar arma?"), "todos");
});
test("consulta de redação exata mantém desambiguação de artigo", () => {
  assert.equal(temReferenciaNormativa("Qual é a redação atual do art. 2º da Portaria 167/2024?"), true);
  assert.equal(ehHistoricoNormativo("Quais artigos do Decreto 9.847/2019 foram revogados?"), true);
});
