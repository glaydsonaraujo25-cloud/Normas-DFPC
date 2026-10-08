import assert from "node:assert/strict";
import {
  validarConsulta,
  fonteAtual,
  faltantes,
  contextoInicial,
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
  `${url}/rest/v1/orientacoes_empresariais?estado=eq.publicada&select=pergunta_modelo,produto,atividade`,
  { headers },
);
assert.equal(response.status, 200);
const guias = await response.json();
assert.equal(guias.length, 22);
for (const g of guias) {
  for (const usarFiltros of [true, false]) {
    assert.deepEqual(
      faltantes(g.pergunta_modelo, {
        ...contextoInicial(),
        produto: g.produto,
        atividade: g.atividade,
      }),
      [],
      g.pergunta_modelo,
    );
    const r = await fetch(`${url}/rest/v1/rpc/consultar_empresa_pce`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        p_pergunta: g.pergunta_modelo,
        p_produto: usarFiltros ? g.produto : "todos",
        p_atividade: usarFiltros ? g.atividade : "todos",
        p_publico: "empresa",
        p_data: "2026-10-08",
        p_limite: 12,
      }),
    });
    assert.equal(r.status, 200);
    const data = await r.json();
    assert.ok(validarConsulta(data), g.pergunta_modelo);
    assert.equal(data.orientacoes.length, 1, g.pergunta_modelo);
    assert.ok(data.fontes.every((f) => fonteAtual(f, "2026-10-08")));
  }
}
console.log(
  "44 cenários públicos aprovados: 22 perguntas com filtros e com identificação automática.",
);
