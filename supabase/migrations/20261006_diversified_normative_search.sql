-- Diversifica a saída da busca sem alterar o ranking-base.
-- Mantém no máximo um resultado por dispositivo e dois dispositivos por norma.

alter function public.consultar_base_normativa(text, integer)
  rename to consultar_base_normativa_raw;

create or replace function public.consultar_base_normativa(
  consulta text,
  limite integer default 5
)
returns table(
  trecho_id bigint,
  pagina integer,
  dispositivo text,
  conteudo text,
  relevancia real,
  norma_id uuid,
  titulo text,
  tipo text,
  numero text,
  ano integer,
  status text,
  relacoes jsonb
)
language sql
stable
set search_path = 'public','pg_temp'
as $$
with ampliada as (
  select *
  from public.consultar_base_normativa_raw(consulta, greatest(limite * 4, 24))
),
unicos_dispositivo as (
  select distinct on (norma_id, lower(coalesce(dispositivo,'')))
    trecho_id,pagina,dispositivo,conteudo,relevancia,norma_id,titulo,tipo,numero,ano,status,relacoes
  from ampliada
  order by norma_id, lower(coalesce(dispositivo,'')), relevancia desc, trecho_id
),
diversificada as (
  select u.*,
         row_number() over (partition by norma_id order by relevancia desc, trecho_id) as pos_norma
  from unicos_dispositivo u
)
select trecho_id,pagina,dispositivo,conteudo,relevancia,norma_id,titulo,tipo,numero,ano,status,relacoes
from diversificada
where pos_norma <= 2
order by relevancia desc,
         case status when 'vigente' then 0 when 'vigente_com_alteracoes' then 1 else 2 end,
         ano desc
limit greatest(limite,1);
$$;

comment on function public.consultar_base_normativa(text,integer) is
'Busca normativa de produção. Usa o ranking textual da função raw e remove repetição do mesmo dispositivo, limitando a dois trechos por norma para diversificar fundamentos.';
