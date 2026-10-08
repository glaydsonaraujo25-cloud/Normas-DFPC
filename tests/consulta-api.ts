import assert from "node:assert/strict";
import {
  validarConsulta,
  fonteAtual,
  faltantes,
  contextoInicial,
  hoje,
} from "../src/lib/consulta.ts";
const url = process.env.VITE_SUPABASE_URL;
const key = process.env.VITE_SUPABASE_ANON_KEY;
assert.ok(url && key, "Configure as variáveis públicas do Supabase");
const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  "Content-Type": "application/json",
};
const response = await fetch(
  `${url}/rest/v1/orientacoes_empresariais?estado=eq.publicada&select=pergunta_modelo,produto,atividade,publico`,
  { headers },
);
assert.equal(response.status, 200);
const guias = await response.json();
assert.ok(guias.length >= 33);
for (const g of guias) {
  for (const usarFiltros of [true, false]) {
    assert.deepEqual(
      faltantes(g.pergunta_modelo, {
        ...contextoInicial(),
        publico: g.publico,
        produto: g.produto,
        atividade: g.atividade,
      }),
      [],
      g.pergunta_modelo,
    );
    const r = await fetch(`${url}/rest/v1/rpc/consultar_publico_pce`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        p_pergunta: g.pergunta_modelo,
        p_produto: usarFiltros ? g.produto : "todos",
        p_atividade: usarFiltros ? g.atividade : "todos",
        p_publico: usarFiltros ? g.publico : "automatico",
        p_data: hoje(),
        p_limite: 12,
      }),
    });
    assert.equal(r.status, 200);
    const data = await r.json();
    assert.ok(validarConsulta(data), g.pergunta_modelo);
    assert.equal(data.orientacoes.length, 1, g.pergunta_modelo);
    assert.ok(data.fontes.every((f) => fonteAtual(f, hoje())));
  }
}
console.log(
  `${guias.length * 2} cenários públicos aprovados com filtros e identificação automática.`,
);
