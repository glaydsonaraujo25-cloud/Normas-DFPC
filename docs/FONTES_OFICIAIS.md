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

## Reconferência empresarial — segunda rodada de 08/10/2026

Foram comparados 42 registros textuais aos PDFs oficiais fornecidos das Portarias 56/2017, 41/2018, 147/2019 e 2.566/2025 e ao Decreto 10.030 consolidado no Planalto. Destes, 41 permanecem utilizáveis; o texto da dispensa de registro da Portaria 56, alterado pela 41, fica pendente de comprovação da cadeia de vigência e não fundamenta respostas. Evidências por dispositivo: `curadoria-2026-10-08.json`. Não se atualizou a data global de vigência das normas.

Seis registros anteriores resumidos, incompletos ou com redação riscada foram desmarcados como conferidos; os dados anteriores foram preservados para auditoria. Novos registros individualizam os arts. 80, 81, 82, 98 e 99 do Anexo I do Decreto 10.030. O art. 23 foi separado da redação riscada do § 2º. A exceção do parágrafo único do art. 28 da Portaria 147 e o parágrafo único do art. 64 das Normas da Portaria 2.566 foram incluídos.

Links exatos adicionais: Decretos 11.615/2023, 12.345/2024 e 9.847/2019, Lei 10.826/2003 (Planalto) e Portaria 167/2024 (DOU, localizada no índice Siscomex; destino ainda indisponível). Links de índice não foram apresentados como documentos de normas individuais.

A orientação de importação também indica a fonte complementar oficial https://www.gov.br/siscomex/pt-br/noticias/noticias-siscomex-importacao/Comunicados/importacao-no-2026-082, recuperada em 08/10/2026. A dispensa de LPCO ali descrita exige verificar as condições do comunicado; a aplicação não trata toda importação de PCE como obrigada ou dispensada. Fontes complementares são distinguidas dos dispositivos transcritos.

O índice DFPC continuou indisponível (HTTP 502). Esta revisão não comprova atualização integral das 59 normas, todos os anexos ou todas as revogações. O painel registra as pendências e separa conferência textual de vigência.

## Rastreabilidade e risco — terceira rodada de 08/10/2026

Mais 18 dispositivos reconferidos nas Portarias 213/2021, 214/2021 e 800/2020, totalizando 59 dispositivos com registro desta reconferência (não 59 normas integralmente auditadas). Os textos de regras documentais e de conservação de dados foram confrontados com as páginas dos PDFs, incluindo as imagens quando a extração apresentou caracteres corrompidos. Evidências: `curadoria-rastreabilidade-2026-10-08.json`.

Foram corrigidos resumos indevidamente marcados como literais nos arts. 10 e 14 das Normas da Portaria 213 e arts. 4º e 6º das Normas da Portaria 214. O art. 2º da Portaria 214 passou a incluir seus parágrafos. As referências dos artigos das Normas da Portaria 213 agora explicitam o escopo e não se confundem com o corpo principal. Textos anteriores ficam preservados em metadados.

Dois vínculos oficiais exatos adicionais:

- Portaria 147: https://www.defesacivil.pr.gov.br/sites/defesa-civil/arquivos_restritos/files/documento/2025-07/portarian147.pdf — cópia em órgão público recuperada, identificação do ato e os artigos iniciais comparados. Não se inferiu consolidação integral pelo link.
- Portaria 800: https://www.sgex.eb.mil.br/sg8/006_outras_publicacoes/07_publicacoes_diversas/01_comando_do_exercito/port_n_800_cmdo_eb_14ago2020.html — link exato localizado na indexação da SGEx, compatível com o cabeçalho do PDF fornecido; destino retornou 502. Os arts. 1º a 4º foram reconferidos no PDF, não no destino indisponível.

Restam 48 normas sem link oficial cadastrado. O índice DFPC voltou a retornar 502. O Anexo Único completo da Portaria 800 e a cadeia integral de alterações das 59 normas permanecem fora do escopo da conferência desta rodada. Não se alteraram datas globais de vigência.
