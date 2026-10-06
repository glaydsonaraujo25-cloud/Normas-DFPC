# Estratégia de busca normativa

A consulta do Normas DFPC usa somente recursos do Supabase/PostgreSQL. Não usa OpenAI, embeddings externos ou créditos pagos.

## Camadas de recuperação

1. Full-Text Search em português nos trechos normativos.
2. Expansão de siglas e termos pelo dicionário `sinonimos_busca`.
3. Tolerância a pequenas diferenças de escrita com `pg_trgm`/`word_similarity`.
4. Priorização por referência direta a tipo, número, ano e artigo da norma.
5. Priorização por intenção da pergunta:
   - quantidade, limite e máximo;
   - requisitos, documentos e exigências;
   - procedimento e tramitação;
   - quem pode / sujeito autorizado;
   - prazo e validade;
   - proibição e restrição.
6. Regras especializadas para temas PCE de alta recorrência, como Guia de Tráfego, níveis de atirador e transferências SIGMA/SINARM.
7. Filtro obrigatório de vigência: respostas materiais usam somente normas marcadas como aptas a fundamentar e com status `vigente` ou `vigente_com_alteracoes`.

Perguntas sobre vigência usam `consultar_status_norma`, que consulta também atos revogados, alteradores, superados e normas com vigência a confirmar, sem transformá-los em fundamento material.

## Casos de regressão

Estas consultas devem ser usadas como referência após alterações no ranking:

- `o que é PCE?` -> Decreto nº 10.030/2019, definição de PCE.
- `Decreto 10030 de 2019 artigo 2` -> Decreto nº 10.030/2019, Anexo I, arts. 2º a 4º.
- `Lei 10826 artigo 24` -> Lei nº 10.826/2003, art. 24.
- `quantas armas um atirador nivel 3 pode ter` -> Decreto nº 11.615/2023, arts. 35 a 37.
- `quais documentos preciso para transferir arma do sinarm para sigma` -> normas específicas de transferência entre SIGMA e SINARM, priorizando o dispositivo de transferência.
- `qual o prazo de validade da guia de trafego` -> normas de GT/GTE com dispositivo sobre validade ou prazo.
- `decreto 10030 de 2019 ainda está vigente?` -> fluxo de consulta de situação normativa, não a busca material comum.

## Regra de segurança

Se a aderência do melhor trecho for baixa, a interface não deve apresentar o resultado como conclusão. Norma revogada, ato alterador, norma materialmente superada, parcialmente vigente sem validação de dispositivo ou com vigência a confirmar não deve fundamentar automaticamente uma resposta.
