import assert from "node:assert/strict";
import { test } from "node:test";
import { buscarPerguntas } from "../src/lib/perguntas.ts";
import type { PerguntaRevisada } from "../src/lib/perguntas.ts";
const guias: PerguntaRevisada[] = [
  {
    id: "1",
    titulo: "Revalidação de registro",
    pergunta_modelo: "Como revalidar registro de empresa não fabricante?",
    produto: "todos",
    atividade: "registro",
    revisado_em: null,
  },
  {
    id: "2",
    titulo: "Registros e estoques de munições",
    pergunta_modelo:
      "Quais registros e prazos de guarda se aplicam ao comércio empresarial de munições?",
    produto: "municoes",
    atividade: "comercio",
    revisado_em: null,
  },
  {
    id: "3",
    titulo: "Plano de segurança",
    pergunta_modelo:
      "O que deve constar no plano de segurança de PCE da empresa?",
    produto: "todos",
    atividade: "todos",
    revisado_em: null,
  },
];
test("tolera uma edição e transposição sem flexibilizar siglas, números ou filtros", () => {
  for (const busca of ["seguranca plano", "seguranca plnao", "seguranca planox", "seguranca plao"]) {
    // A omissão que reduz o termo a quatro letras permanece sem aproximação.
    assert.equal(buscarPerguntas(guias, busca).length, busca === "seguranca plao" ? 0 : 1);
  }
  for (const busca of ["seguranca", "segurnaca", "segurancax", "seguraca", "segurxanca"]) {
    assert.equal(buscarPerguntas(guias, busca)[0]?.id, "3");
  }
  assert.equal(buscarPerguntas(guias, "segxxanca").length, 0);
  assert.equal(buscarPerguntas(guias, "cx").length, 0);
  assert.equal(buscarPerguntas(guias, "municao2").length, 0);
  assert.equal(buscarPerguntas(guias, "municaox", "comercio", "explosivos").length, 0);
  const semelhante = { ...guias[2], id: "4", titulo: "A segurança", pergunta_modelo: "" };
  const exata = { ...guias[2], id: "5", titulo: "Z segurancaX", pergunta_modelo: "" };
  assert.equal(buscarPerguntas([semelhante, exata], "segurancax")[0]?.id, "5");
});
test("busca ignora ordem e acentos e reconhece renovação de CR", () => {
  assert.equal(buscarPerguntas(guias, "municoes registros")[0]?.id, "2");
  assert.equal(buscarPerguntas(guias, "renovar CR")[0]?.id, "1");
  assert.equal(buscarPerguntas(guias, "registros inexistente").length, 0);
});
test("sugestões respeitam filtros, limitam resultados e não usam palavras vazias", () => {
  assert.deepEqual(
    buscarPerguntas(
      guias,
      "Minha empresa precisa de PCE",
      "todos",
      "todos",
      true,
    ),
    [],
  );
  assert.deepEqual(
    buscarPerguntas(
      guias,
      "registros munições",
      "comercio",
      "explosivos",
      true,
    ),
    [],
  );
  assert.equal(
    buscarPerguntas(
      guias,
      "preciso guardar registros de munições por quanto tempo?",
      "comercio",
      "municoes",
      true,
    )[0]?.id,
    "2",
  );
  assert.equal(
    buscarPerguntas(guias, "plano segurança", "transporte", "explosivos")[0]
      ?.id,
    "3",
  );
});
