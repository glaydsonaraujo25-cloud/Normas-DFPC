-- Linha do tempo normativa e vigência por dispositivo
-- Gerado em 2026-10-07. Idempotente.

create table if not exists public.alteracoes_dispositivos (
  id uuid primary key default gen_random_uuid(),
  norma_alteradora_id uuid not null references public.normas(id) on delete cascade,
  norma_base_id uuid not null references public.normas(id) on delete cascade,
  dispositivo_base text not null,
  tipo_alteracao text not null check (tipo_alteracao in ('altera','inclui','revoga_dispositivo','substitui_anexo','regra_transitoria','atualiza_modelo')),
  texto_novo text,
  vigencia_inicio date,
  vigencia_fim date,
  conferido boolean not null default false,
  fonte_tipo text,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (norma_alteradora_id, norma_base_id, dispositivo_base, tipo_alteracao)
);

create index if not exists idx_alteracoes_dispositivos_base on public.alteracoes_dispositivos(norma_base_id);
create index if not exists idx_alteracoes_dispositivos_alteradora on public.alteracoes_dispositivos(norma_alteradora_id);

create table if not exists public.vigencia_dispositivos (
  id uuid primary key default gen_random_uuid(),
  norma_id uuid not null references public.normas(id) on delete cascade,
  dispositivo text not null,
  status_dispositivo text not null check (status_dispositivo in ('vigente','revogado','alterado','vigencia_a_confirmar','historico')),
  norma_responsavel_id uuid references public.normas(id) on delete set null,
  data_efeito date,
  observacoes text,
  fonte_tipo text,
  conferido boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(norma_id,dispositivo,status_dispositivo)
);

create index if not exists idx_vigencia_dispositivos_norma on public.vigencia_dispositivos(norma_id,status_dispositivo);

create or replace view public.v_linha_tempo_normativa as
select b.id as norma_base_id,b.titulo as norma_base,b.status as status_norma_base,
       a.id as alteracao_id,alt.id as norma_alteradora_id,alt.titulo as norma_alteradora,
       alt.data_norma as data_alteracao,a.dispositivo_base,a.tipo_alteracao,a.texto_novo,
       a.vigencia_inicio,a.vigencia_fim,a.conferido,a.observacoes
from public.alteracoes_dispositivos a
join public.normas b on b.id=a.norma_base_id
join public.normas alt on alt.id=a.norma_alteradora_id;

create or replace view public.v_mapa_vigencia_normativa as
select n.id as norma_id,n.titulo,n.status as status_norma,v.dispositivo,v.status_dispositivo,
       nr.titulo as norma_responsavel,v.data_efeito,v.observacoes,v.conferido
from normas n
join vigencia_dispositivos v on v.norma_id=n.id
left join normas nr on nr.id=v.norma_responsavel_id;

-- Mapeamentos dos atos alteradores conferidos nas fontes do projeto.
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Art. 19','altera','Para pessoa jurídica, respeitada a validade do registro, a Guia de Tráfego tem o mesmo prazo de validade do Certificado de Registro para entidades de tiro desportivo e sessenta dias corridos para as demais pessoas jurídicas.','2017-05-10',true,'PDF fornecido pelo usuário','Alteração da ITA nº 03/2015; a norma-base continua com vigência material a confirmar.' from normas a,normas b where a.titulo='ITA nº 09, de 10 de maio de 2017' and b.titulo='ITA nº 03 DFPC, de 13 de outubro de 2015' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Arts. 9º, 13 e 25','altera','Dá nova redação ao art. 9º e altera os arts. 13 e 25 da ITA nº 03/2015.','2017-10-30',true,'PDF fornecido pelo usuário','Alteração histórica; validar a norma-base antes de uso material.' from normas a,normas b where a.titulo='ITA nº 13, de 30 de outubro de 2017' and b.titulo='ITA nº 03 DFPC, de 13 de outubro de 2015' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Arts. 2º e 26','altera','Altera hipóteses de isenção/dispensa de registro e as hipóteses obrigatórias de vistoria.','2018-03-28',true,'PDF fornecido pelo usuário','Ler a Portaria nº 56/2017 de forma consolidada.' from normas a,normas b where a.titulo='Portaria nº 41-COLOG, de 28 de março de 2018' and b.titulo='Portaria nº 56 COLOG, de 5 de junho de 2017' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Arts. 4º, 5º, 6º, 8º e 9º; revogações parciais dos arts. 4º, 6º, 7º, 8º, 9º e 11','altera','Atualiza o regime de avaliação da conformidade de fogos de artifício para OAC e revoga dispositivos incompatíveis.','2019-11-21',true,'PDF fornecido pelo usuário','Usar a Portaria nº 08-D Log/2008 somente consolidada com a Portaria nº 148/2019.' from normas a,normas b where a.titulo='Portaria nº 148-COLOG, de 21 de novembro de 2019' and b.titulo='Portaria nº 08-D Log, de 29 de outubro de 2008' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Anexo B-5','altera','Exclui atividades de teste industrial e inclui emprego em testes ou ensaios de munição, arma de fogo, pirotécnicos, proteção balística e menos-letais.','2022-06-01',true,'PDF fornecido pelo usuário','Alteração do Anexo B-5.' from normas a,normas b where a.titulo='ITA nº 24 DFPC/COLOG, de 25 de maio de 2022' and b.titulo='Portaria nº 56 COLOG, de 5 de junho de 2017' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Anexo — modelos de CRAF','atualiza_modelo','O Anexo passa a vigorar com novos modelos de CRAF.','2024-02-01',true,'PDF fornecido pelo usuário','Usar a norma-base com o Anexo atualizado.' from normas a,normas b where a.titulo='Portaria GM-MD nº 132, de 11 de janeiro de 2024' and b.titulo='Portaria Normativa nº 1.369/MD, de 25 de novembro de 2004' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Art. 2º','altera','Redação intermediária do art. 2º da Portaria nº 167/2024, posteriormente substituída pela Portaria nº 225/2024.','2024-05-21',true,'PDF fornecido pelo usuário','Redação intermediária.' from normas a,normas b where a.titulo='Portaria nº 224 COLOG/C Ex, de 17 de maio de 2024' and b.titulo='Portaria nº 167 COLOG/C Ex, de 22 de janeiro de 2024' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Art. 2º','altera','Ativa e inatividade das PM/CBM/GSI: até quatro armas, duas de uso restrito, com regras específicas para arma longa.','2024-05-28',true,'PDF fornecido pelo usuário','Redação posterior e prevalente na consolidação.' from normas a,normas b where a.titulo='Portaria nº 225 COLOG/C Ex, de 28 de maio de 2024' and b.titulo='Portaria nº 167 COLOG/C Ex, de 22 de janeiro de 2024' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Anexos A e C','substitui_anexo','Substitui a redação dos Anexos A e C da Portaria Conjunta nº 2/2023.','2024-09-04',true,'PDF fornecido pelo usuário','Listagens de calibres.' from normas a,normas b where a.titulo='Portaria Conjunta C Ex/DG-PF nº 3, de 29 de agosto de 2024' and b.titulo='Portaria Conjunta C Ex/DG-PF nº 2, de 6 de novembro de 2023' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Arts. 2º, 38 a 38-H e correlatos','altera','Inclui e altera regras sobre arma histórica, acervo de coleção e atirador de alto rendimento.','2024-12-30',true,'PDF fornecido pelo usuário','Ler o Decreto nº 11.615/2023 consolidado com o Decreto nº 12.345/2024.' from normas a,normas b where a.titulo='Decreto nº 12.345, de 30 de dezembro de 2024' and b.titulo='Decreto nº 11.615, de 21 de julho de 2023' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Arts. 1º, 6º, 17, 20, 22, 30, 39, 43, 44, 67, 73-A, 74, 98 e 109; revogação do §2º do art. 20','altera','Atualiza coleção, habitualidade, entidades de tiro, GTE, alto rendimento, transferências e ranking/calendário.','2025-06-10',true,'PDF fornecido pelo usuário','Usar a Portaria nº 166/2023 consolidada com a Portaria nº 260/2025.' from normas a,normas b where a.titulo='Portaria nº 260 COLOG/C Ex, de 9 de junho de 2025' and b.titulo='Portaria nº 166 COLOG/C Ex, de 22 de dezembro de 2023' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Arts. 8º, 8º-A, 8º-B e art. 9º, parágrafo único','altera','Atualiza classificação de armas longas semiautomáticas, armas de alma lisa e multicalibre.','2025-08-01',true,'PDF fornecido pelo usuário','Redação consolidada atualmente aplicável.' from normas a,normas b where a.titulo='Portaria Conjunta C Ex/DG-PF nº 4, de 18 de julho de 2025' and b.titulo='Portaria Conjunta C Ex/DG-PF nº 2, de 6 de novembro de 2023' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Art. 1º — incisos I e II','altera','Amplia o âmbito da Portaria Conjunta nº 1/2024 para CAC e instituições públicas, abrangendo também importação, munições e acessórios.','2025-09-05',true,'PDF fornecido pelo usuário','Usar a norma-base consolidada.' from normas a,normas b where a.titulo='Portaria Conjunta COLOG/C Ex e DPA/PF nº 2, de 1º de setembro de 2025' and b.titulo='Portaria Conjunta COLOG/C Ex e DPA/PF nº 1, de 29 de novembro de 2024' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Art. 48, §§ 3º a 7º','regra_transitoria','Autorização prévia para aquisições institucionais de coletes até III-A/HG2 produz efeitos em 1º/1/2027; até 31/12/2026 aplica-se o rito transitório de comunicação.','2026-06-22',true,'PDF fornecido pelo usuário','Regra transitória aplicável em 2026.' from normas a,normas b where a.titulo='Portaria COLOG/C Ex nº 294, de 22 de junho de 2026' and b.titulo='Portaria COLOG/C Ex nº 289, de 22 de maio de 2026' on conflict do nothing;
insert into public.alteracoes_dispositivos (norma_alteradora_id,norma_base_id,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,conferido,fonte_tipo,observacoes)
select a.id,b.id,'Arts. 76 e 76-A','regra_transitoria','A exigência do art. 47 passa a vigorar em 8/6/2027, com regras de transição para materiais e processos de avaliação.','2026-06-22',true,'PDF fornecido pelo usuário','Aplicar a transição até a data definida.' from normas a,normas b where a.titulo='Portaria COLOG/C Ex nº 294, de 22 de junho de 2026' and b.titulo='Portaria COLOG/C Ex nº 290, de 4 de maio de 2026' on conflict do nothing;

-- ITA 30/2025: ato revogador cujo alvo não está cadastrado como norma-base na base atual.
insert into public.dispositivos (norma_id,referencia,artigo,texto_literal,pagina,status,fonte_tipo,conferido,metadata,observacao_vigencia)
select n.id,'Art. 1º, incisos I a VII','Art. 1º','Revoga ITA nº 10/1996, ITA-14B-DFPC/1999, ITA nº 18/1999, ITA nº 21/2000, ITA nº 06D/2003, ITA nº 26A/2004 e ITA nº 14/2017.',1,'vigente','PDF fornecido pelo usuário',true,jsonb_build_object('tipo','texto_literal_conferido','funcao','ato_revogador'),'Não usar isoladamente como fundamento material atual.' from normas n where n.titulo='ITA nº 30 DFPC/COLOG, de 7 de abril de 2025' and not exists (select 1 from dispositivos d where d.norma_id=n.id and d.referencia='Art. 1º, incisos I a VII');

-- Decreto 9.847/2019: mapa de vigência em blocos de dispositivos conforme texto compilado oficial.
with n as (select id from normas where titulo='Decreto nº 9.847, de 25 de junho de 2019'), d11615 as (select id from normas where titulo='Decreto nº 11.615, de 21 de julho de 2023')
insert into vigencia_dispositivos(norma_id,dispositivo,status_dispositivo,norma_responsavel_id,data_efeito,observacoes,fonte_tipo,conferido)
select n.id,x.dispositivo,x.status_dispositivo,case when x.responsavel='11.615' then (select id from d11615 limit 1) end,x.data_efeito,x.observacoes,'Planalto — texto compilado oficial',true
from n cross join (values
 ('Art. 1º','revogado',null,'2023-01-01'::date,'Revogado pelo Decreto nº 11.366/2023.'),
 ('Art. 2º','vigente',null,null,'Permanece no texto compilado.'),
 ('Art. 3º','revogado','11.615','2023-07-21'::date,'Revogado pelo Decreto nº 11.615/2023.'),
 ('Art. 4º, caput, §§ 1º, 3º, 4º e 5º e § 2º exceto alíneas c dos incisos I e II','vigente',null,null,'Permanece parcialmente no texto compilado.'),
 ('Art. 4º, § 2º, I-c e II-c','revogado','11.615','2023-07-21'::date,'Revogados pelo Decreto nº 11.615/2023.'),
 ('Art. 5º, caput','vigente',null,null,'Permanece no texto compilado.'),
 ('Art. 5º, §§ 1º a 6º','revogado','11.615','2023-07-21'::date,'Revogados pelo Decreto nº 11.615/2023.'),
 ('Art. 6º','revogado','11.615','2023-07-21'::date,'Revogado pelo Decreto nº 11.615/2023.'),
 ('Arts. 7º e 8º','vigente',null,null,'Permanecem no texto compilado.'),
 ('Arts. 9º a 11','revogado','11.615','2023-07-21'::date,'Revogados pelo Decreto nº 11.615/2023.'),
 ('Arts. 12 a 15','revogado',null,'2023-01-01'::date,'Revogados pelo Decreto nº 11.366/2023.'),
 ('Art. 16','revogado','11.615','2023-07-21'::date,'Revogado pelo Decreto nº 11.615/2023.'),
 ('Art. 17','revogado',null,'2023-01-01'::date,'Revogado pelo Decreto nº 11.366/2023.'),
 ('Art. 18','revogado',null,'2021-04-12'::date,'Revogado pelo Decreto nº 10.630/2021.'),
 ('Arts. 19 e 20','revogado','11.615','2023-07-21'::date,'Revogados pelo Decreto nº 11.615/2023.'),
 ('Art. 21','revogado',null,'2023-01-01'::date,'Revogado pelo Decreto nº 11.366/2023.'),
 ('Arts. 22, 23, 24 e 24-A','revogado','11.615','2023-07-21'::date,'Revogados pelo Decreto nº 11.615/2023.'),
 ('Art. 25','vigente',null,null,'Permanece no texto compilado.'),
 ('Arts. 26 a 29-D','revogado','11.615','2023-07-21'::date,'Revogados pelo Decreto nº 11.615/2023.'),
 ('Arts. 30 e 31','vigente',null,null,'Permanecem no texto compilado.'),
 ('Art. 32','revogado','11.615','2023-07-21'::date,'Revogado pelo Decreto nº 11.615/2023.'),
 ('Arts. 33 a 44','vigente',null,null,'Permanecem no texto compilado; o art. 34 possui redações posteriores incorporadas.'),
 ('Arts. 45, 45-A, 45-B, 46 a 57-A','revogado','11.615','2023-07-21'::date,'Revogados pelo Decreto nº 11.615/2023.'),
 ('Art. 58','historico',null,null,'Dispositivo alterador de outro decreto.'),
 ('Art. 59','revogado',null,'2023-01-01'::date,'Revogado pelo Decreto nº 11.366/2023.'),
 ('Arts. 60 e 61','historico',null,null,'Cláusulas finais de revogação e vigência.')
) as x(dispositivo,status_dispositivo,responsavel,data_efeito,observacoes)
on conflict do nothing;

update normas set status_detalhado='Parcialmente vigente, com mapa de vigência por dispositivo conferido no texto compilado oficial.', observacao_vigencia='Consultar v_mapa_vigencia_normativa antes de usar qualquer dispositivo como fundamento. Dispositivos revogados não podem fundamentar respostas atuais.', ultima_verificacao=current_date where titulo='Decreto nº 9.847, de 25 de junho de 2019';

drop view if exists public.v_cobertura_alteradores;
create view public.v_cobertura_alteradores as
select n.id as norma_id,n.titulo,n.status,
 count(distinct r.id) as relacoes_mapeadas,
 count(distinct a.id) as alteracoes_dispositivo_mapeadas,
 count(distinct d.id) filter (where d.conferido=true) as dispositivos_proprios_conferidos,
 case when n.status='ato_alterador' and (count(distinct a.id)>0 or count(distinct d.id) filter (where d.conferido=true)>0) then 100
      when n.status='parcialmente_vigente' and exists (select 1 from vigencia_dispositivos vd where vd.norma_id=n.id and vd.conferido=true) then 100 else 0 end as cobertura_mapeamento_percentual,
 case when n.status='ato_alterador' and count(distinct a.id)>0 then 'mapeado_em_nivel_de_dispositivo'
      when n.status='ato_alterador' and count(distinct d.id) filter (where d.conferido=true)>0 then 'ato_revogador_mapeado'
      when n.status='parcialmente_vigente' and exists (select 1 from vigencia_dispositivos vd where vd.norma_id=n.id and vd.conferido=true) then 'mapa_de_vigencia_por_dispositivo_conferido'
      else 'pendente' end as nivel_mapeamento
from public.normas n
left join public.relacoes_normativas r on r.norma_origem_id=n.id
left join public.alteracoes_dispositivos a on a.norma_alteradora_id=n.id
left join public.dispositivos d on d.norma_id=n.id
where n.status in ('ato_alterador','parcialmente_vigente')
group by n.id,n.titulo,n.status;
