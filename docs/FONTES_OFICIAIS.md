# Conferência de fontes — 08/10/2026

O índice solicitado https://www.dfpc.eb.mil.br/index.php/informacoes/legislacao retornou HTTP 502 nas tentativas desta atualização. Sua indexação foi localizada, mas a página e os documentos nela relacionados não foram integralmente auditados.

A página oficial https://www.gov.br/siscomex/pt-br/servicos/aprendendo-a-exportar/legislacao/dfpc/ foi recuperada e remete ao índice DFPC. Permitiram-se três vínculos exatos a normas existentes, sem modificar status ou data de conferência normativa:

| Norma | Documento/link | Conferência desta atualização |
| --- | --- | --- |
| Portaria 118-COLOG/2019 | https://www.gov.br/siscomex/pt-br/arquivos-e-imagens/2019/10/Portaria-no-118-COLOG-de-4-Out-2019-Lista-de-PCE.pdf | PDF recuperado; art. 3º comparado ao dispositivo cadastrado e usado na orientação de misturas |
| Lei 10.834/2003 | https://www.planalto.gov.br/ccivil_03/leis/2003/l10.834.htm | Página oficial recuperada; link vinculado |
| Portaria C Ex 2.566/2025 | https://www.in.gov.br/web/dou/-/portaria-c-ex-n-2.566-de-8-de-outubro-de-2025-661609153 | Link exato localizado no índice oficial Siscomex; destino retornou 502, texto não reconferido |

A presença em um índice não comprova vigência integral. Não se inferem dispensas, nem são alteradas vigências somente por presença de link. A aplicação não consulta esses sites em tempo real a cada pergunta. As atualizações do corpus passam pela curadoria.

## Consulta v3

Reconhece variantes linguísticas de cinco temas já revisados (definição, registro para comércio de químicos, apostilamento, requisitos gerais de importação e aquisição geral para segurança privada). A pergunta original permanece visível e a interpretação é informada. Perguntas com prazos, custos, dispensas, quantidades, normas específicas e condições particulares conservam a busca original.

Quando há orientação revisada, suas fontes são os fundamentos citados, sem misturar achados textuais de outros assuntos. A busca recupera também dispositivos conferidos do mesmo artigo e seção da norma, incluindo redações consolidadas aplicáveis das três fontes principais, limitada a 12 complementos. Não associa artigos de anexos ao corpo principal. A busca não afirma ter recuperado todos os dispositivos citados ou exceções do ordenamento.

A nova orientação sobre misturas explica a necessidade de Parecer Técnico da DFPC prevista no art. 3º; não classifica automaticamente o produto.

Testes SQL reproduzíveis: `tests/respostas-empresariais.sql`.
