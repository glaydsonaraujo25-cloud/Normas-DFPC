-- Melhora a busca composta por escopo do consulente e detalha a Portaria 164/2023.
-- Aplicado em produção em 06/10/2026.

-- 1) A função consultar_base_normativa_composta foi atualizada no banco para:
--    - priorizar militar do Exército -> Portaria 164/2023;
--    - priorizar PM/CBM/GSI -> Portaria 167/2024;
--    - priorizar CAC -> Portaria 166/2023 e Decreto 11.615/2023;
--    - priorizar segurança privada -> Portaria 291/2026;
--    - diferenciar corretamente "porte" de "transporte".
--
-- A definição completa vigente da função pode ser obtida no banco com:
-- select pg_get_functiondef('public.consultar_base_normativa_composta(text,integer)'::regprocedure);

-- 2) Trechos adicionais da Portaria 164/2023 foram inseridos de forma idempotente,
--    com granularidade suficiente para consultas por porte, transporte, munição e exclusão.
do $$
declare v_norma uuid;
begin
  select id into v_norma from public.normas where titulo ilike 'Portaria nº 164 COLOG/C Ex%' limit 1;
  if v_norma is null then raise exception 'Portaria 164 não localizada'; end if;

  insert into public.trechos(norma_id,pagina,dispositivo,conteudo,metadata)
  select v_norma,9,'Normas, art. 7º e parágrafo único','Oficiais em serviço ativo ou na inatividade têm direito ao porte de arma de fogo na forma indicada pela norma. Para oficiais temporários, o direito ao porte fica limitado ao prazo de convocação.',jsonb_build_object('origem','PDF fornecido','tipo','sintese_fiel','curadoria','2026-10-06')
  where not exists(select 1 from public.trechos where norma_id=v_norma and dispositivo='Normas, art. 7º e parágrafo único');

  insert into public.trechos(norma_id,pagina,dispositivo,conteudo,metadata)
  select v_norma,9,'Normas, art. 8º e parágrafo único','Subtenentes e sargentos de carreira, em serviço ativo ou na inatividade, têm autorização para portar arma de fogo assegurada nos termos da norma, observadas as restrições aplicáveis. Também são autorizados os sargentos oriundos das escolas de formação de sargentos ainda não estabilizados.',jsonb_build_object('origem','PDF fornecido','tipo','sintese_fiel','curadoria','2026-10-06')
  where not exists(select 1 from public.trechos where norma_id=v_norma and dispositivo='Normas, art. 8º e parágrafo único');

  insert into public.trechos(norma_id,pagina,dispositivo,conteudo,metadata)
  select v_norma,9,'Normas, art. 9º e §§ 1º a 3º','A comprovação da autorização de porte para as categorias tratadas nos arts. 7º e 8º é feita pela identificação militar e pelo CRAF da arma conduzida. Para oficiais temporários e sargentos não estabilizados, a autorização vincula-se à validade da identidade militar. A norma também prevê avaliação psicológica periódica para militares inativos e, em certos casos, parecer favorável da Região Militar.',jsonb_build_object('origem','PDF fornecido','tipo','sintese_fiel','curadoria','2026-10-06')
  where not exists(select 1 from public.trechos where norma_id=v_norma and dispositivo='Normas, art. 9º e §§ 1º a 3º');

  insert into public.trechos(norma_id,pagina,dispositivo,conteudo,metadata)
  select v_norma,9,'Normas, art. 10 e §§ 1º a 4º','Excepcionalmente, pode ser concedida autorização para portar arma de fogo a sargentos temporários e a cabos, taifeiros ou soldados, ativos ou inativos, quando houver fatos e circunstâncias que a justifiquem. A autorização é concedida pela autoridade competente, publicada em boletim interno, deve constar do CRAF, tem validade vinculada à identidade militar e é comprovada pela identificação militar e pelo CRAF.',jsonb_build_object('origem','PDF fornecido','tipo','sintese_fiel','curadoria','2026-10-06')
  where not exists(select 1 from public.trechos where norma_id=v_norma and dispositivo='Normas, art. 10 e §§ 1º a 4º');

  insert into public.trechos(norma_id,pagina,dispositivo,conteudo,metadata)
  select v_norma,12,'Normas, arts. 26 e 27 — munições','Cada militar pode adquirir anualmente até seiscentos cartuchos por arma registrada. Em alternativa, pode adquirir insumos para recarga, desde que a soma entre munições adquiridas e recarregadas não ultrapasse o limite. A aquisição de munição na indústria ou no comércio exige CRAF válido da arma registrada e identificação funcional do adquirente.',jsonb_build_object('origem','PDF fornecido','tipo','sintese_fiel','curadoria','2026-10-06')
  where not exists(select 1 from public.trechos where norma_id=v_norma and dispositivo='Normas, arts. 26 e 27 — munições');

  insert into public.trechos(norma_id,pagina,dispositivo,conteudo,metadata)
  select v_norma,13,'Normas, art. 29 e §§ 1º e 2º — transporte','O transporte de arma de fogo pertencente a militar sem autorização para portá-la deve ser realizado com a respectiva Guia de Tráfego. A solicitação e a expedição da guia seguem instrução técnico-administrativa da DFPC. A arma pode ser transportada desmuniciada e acompanhada da munição, observado o limite anual de aquisição.',jsonb_build_object('origem','PDF fornecido','tipo','sintese_fiel','curadoria','2026-10-06')
  where not exists(select 1 from public.trechos where norma_id=v_norma and dispositivo='Normas, art. 29 e §§ 1º e 2º — transporte');

  insert into public.trechos(norma_id,pagina,dispositivo,conteudo,metadata)
  select v_norma,13,'Normas, art. 30 e §§ 1º e 2º — sinistro','O proprietário deve comunicar imediatamente ao SIGMA o extravio, furto, roubo ou recuperação da arma. A comunicação é feita na OM de vinculação com boletim de ocorrência; para militar inativo, pode ser feita em qualquer OM do SisFPC. A OM publica o sinistro em Boletim Interno e solicita ao SFPC a atualização da situação da arma no SIGMA.',jsonb_build_object('origem','PDF fornecido','tipo','sintese_fiel','curadoria','2026-10-06')
  where not exists(select 1 from public.trechos where norma_id=v_norma and dispositivo='Normas, art. 30 e §§ 1º e 2º — sinistro');

  insert into public.trechos(norma_id,pagina,dispositivo,conteudo,metadata)
  select v_norma,13,'Normas, art. 31 — exclusão das Forças Armadas','O militar que possuir arma cadastrada no SIGMA e for excluído das Forças Armadas deve providenciar imediatamente a transferência da arma para o SINARM, em razão da nova situação, antes do vencimento do CRAF.',jsonb_build_object('origem','PDF fornecido','tipo','sintese_fiel','curadoria','2026-10-06')
  where not exists(select 1 from public.trechos where norma_id=v_norma and dispositivo='Normas, art. 31 — exclusão das Forças Armadas');
end $$;
