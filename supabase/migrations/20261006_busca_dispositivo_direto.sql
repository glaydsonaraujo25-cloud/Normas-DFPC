-- Melhora consultas diretas por norma e dispositivo.
-- Objetivos:
-- 1. reconhecer artigo isolado e faixas como "Arts. 35 a 37";
-- 2. priorizar fortemente a norma explicitamente citada pelo usuário;
-- 3. preservar o ranking textual, a diversidade e as regras de vigência existentes.

create or replace function public.dispositivo_contem_artigo(p_dispositivo text, p_artigo integer)
returns boolean
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  d text := lower(coalesce(p_dispositivo,''));
  primeiro integer;
  segundo integer;
begin
  if p_artigo is null then return false; end if;
  primeiro := nullif(substring(d from 'art(?:s|igos?)?\.?\s*([0-9]+)'), '')::integer;
  if primeiro is null then return false; end if;
  segundo := nullif(substring(d from 'art(?:s|igos?)?\.?\s*[0-9]+[ºo]?\s*(?:a|ao|-)\s*([0-9]+)'), '')::integer;
  if segundo is not null then
    return p_artigo between least(primeiro,segundo) and greatest(primeiro,segundo);
  end if;
  if primeiro = p_artigo then return true; end if;
  return d ~ ('art(?:s|igos?)?\.?\s*' || primeiro || '[ºo]?\s*(?:e|,)\s*' || p_artigo || '[ºo]?');
end;
$$;

create or replace function public.consultar_base_normativa(consulta text, limite integer default 5)
returns table(trecho_id bigint, pagina integer, dispositivo text, conteudo text, relevancia real, norma_id uuid, titulo text, tipo text, numero text, ano integer, status text, relacoes jsonb)
language sql
stable
set search_path = public, pg_temp
as $$
with entrada as (
  select
    nullif(substring(lower(coalesce(consulta,'')) from 'art(?:igo)?s?\.?\s*([0-9]+)'), '')::integer as artigo_num,
    regexp_replace(coalesce(substring(lower(coalesce(consulta,'')) from '([0-9]{2,6}(?:\.[0-9]{3})*)'),''),'[^0-9]','','g') as numero_compacto,
    substring(lower(coalesce(consulta,'')) from '([12][0-9]{3})') as ano_busca
),
ampliada as (
  select * from public.consultar_base_normativa_raw(consulta, greatest(limite * 5, 30))
),
ajustada as (
  select a.*,
         (a.relevancia
          + case when public.dispositivo_contem_artigo(a.dispositivo,e.artigo_num) then 5.5 else 0 end
          + case when e.numero_compacto<>'' and regexp_replace(lower(coalesce(a.numero,'')),'[^0-9]','','g') like e.numero_compacto||'%' then 4.5 else 0 end
          + case when e.ano_busca is not null and a.ano::text=e.ano_busca then 1.5 else 0 end
         )::real as relevancia_ajustada
  from ampliada a cross join entrada e
),
unicos_dispositivo as (
  select distinct on (norma_id, lower(coalesce(dispositivo,'')))
    trecho_id,pagina,dispositivo,conteudo,relevancia_ajustada as relevancia,norma_id,titulo,tipo,numero,ano,status,relacoes
  from ajustada
  order by norma_id,lower(coalesce(dispositivo,'')),relevancia_ajustada desc,trecho_id
),
diversificada as (
  select u.*,row_number() over(partition by norma_id order by relevancia desc,trecho_id) pos_norma
  from unicos_dispositivo u
)
select trecho_id,pagina,dispositivo,conteudo,relevancia,norma_id,titulo,tipo,numero,ano,status,relacoes
from diversificada
where pos_norma<=2
order by relevancia desc,case status when 'vigente' then 0 when 'vigente_com_alteracoes' then 1 else 2 end,ano desc
limit greatest(limite,1);
$$;
