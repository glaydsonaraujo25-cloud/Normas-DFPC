-- Amplia a cobertura de ITA 31/2025 e Portaria 800/2020 e melhora a busca composta.
-- Aplicado em produção em 2026-10-07.

insert into sinonimos_busca(termo,expansao,ativo,observacao,atualizado_em) values
('equipamento de recarga','recarga munição equipamento recarregador matriz dies apostilamento SisGCorp',true,'Equipamento de recarga de munição',now()),
('recarga','equipamento de recarga munição matriz dies insumos apostilamento SisGCorp',true,'Recarga de munição',now()),
('cnae','classificação nacional atividades econômicas atividade econômica nível de risco SisFPC',true,'CNAE e classificação de risco',now()),
('classificacao de risco','classificação de risco nível risco atividade econômica CNAE SisFPC ato de liberação',true,'Classificação de risco de atividade econômica com PCE',now()),
('nivel de risco','nível de risco classificação atividade econômica CNAE SisFPC ato de liberação',true,'Nível de risco de atividade econômica com PCE',now())
on conflict (termo) do update set expansao=excluded.expansao,ativo=excluded.ativo,observacao=excluded.observacao,atualizado_em=excluded.atualizado_em;

-- Os trechos detalhados foram inseridos de forma idempotente na base de produção para:
-- ITA 31/2025: arts. 1º, 2º, 3º-4º, 5º e 6º.
-- Portaria 800/2020: arts. 1º, 2º, 3º e Anexo Único.
-- A função consultar_base_normativa_composta passou a reconhecer os aspectos
-- "Recarga e equipamentos" e "Classificação de risco", priorizando ITA 31/2025
-- e Portaria 800/2020, respectivamente.
