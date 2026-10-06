-- Consulta separada para perguntas sobre vigência/status.
-- Pode retornar normas revogadas, superadas, alteradoras ou pendentes,
-- mas não deve ser usada para fundamentação material automática.

create or replace function public.consultar_status_norma(consulta text, limite integer default 8)
returns table(
  norma_id uuid,
  titulo text,
  tipo text,
  numero text,
  ano integer,
  status text,
  status_detalhado text,
  usar_como_fundamento boolean,
  observacao_vigencia text,
  ultima_verificacao date,
  relevancia real,
  relacoes jsonb
)
language sql
stable
set search_path = 'public','pg_temp'
as $function$
with entrada as (
  select trim(coalesce(consulta,'')) raw,
         lower(trim(coalesce(consulta,''))) lraw,
         substring(lower(coalesce(consulta,'')) from '([0-9]{1,3}(\.[0-9]{3})*)\s*/\s*[12][0-9]{3}') numero_busca,
         substring(lower(coalesce(consulta,'')) from '/\s*([12][0-9]{3})') ano_ref,
         substring(lower(coalesce(consulta,'')) from '([12][0-9]{3})') ano_busca
), base as (
  select n.*,
    (
      case when lower(n.titulo)=e.lraw then 6.0 else 0 end +
      case when lower(n.titulo) like '%'||e.lraw||'%' then 3.0 else 0 end +
      case when e.numero_busca is not null and regexp_replace(lower(n.numero),'[^0-9a-z\.]+','','g') like regexp_replace(e.numero_busca,'[^0-9a-z\.]+','','g')||'%' then 5.0 else 0 end +
      case when e.ano_ref is not null and n.ano::text=e.ano_ref then 3.0 when e.ano_busca is not null and n.ano::text=e.ano_busca then 1.2 else 0 end +
      case when e.numero_busca is not null and e.ano_ref is not null and regexp_replace(lower(n.numero),'[^0-9a-z\.]+','','g') like regexp_replace(e.numero_busca,'[^0-9a-z\.]+','','g')||'%' and n.ano::text=e.ano_ref then 8.0 else 0 end +
      greatest(word_similarity(e.lraw,lower(n.titulo))*2.2,word_similarity(e.lraw,lower(coalesce(n.numero,'')))*1.8)
    )::real relevancia
  from public.normas n cross join entrada e
  where e.raw<>'' and (
    lower(n.titulo) like '%'||e.lraw||'%' or
    lower(n.numero) like '%'||e.lraw||'%' or
    (e.numero_busca is not null and regexp_replace(lower(n.numero),'[^0-9a-z\.]+','','g') like regexp_replace(e.numero_busca,'[^0-9a-z\.]+','','g')||'%') or
    word_similarity(e.lraw,lower(n.titulo))>0.32 or
    word_similarity(e.lraw,lower(coalesce(n.numero,'')))>0.32 or
    (e.ano_busca is not null and n.ano::text=e.ano_busca)
  )
)
select b.id,b.titulo,b.tipo,b.numero,b.ano,b.status,b.status_detalhado,b.usar_como_fundamento,b.observacao_vigencia,b.ultima_verificacao,b.relevancia,
coalesce((select jsonb_agg(jsonb_build_object('tipo',z.tipo,'dispositivo',z.dispositivo,'observacoes',z.observacoes,'norma_relacionada',z.titulo) order by z.tipo,z.titulo)
from (
  select rn.tipo,rn.dispositivo,rn.observacoes,n2.titulo from public.relacoes_normativas rn join public.normas n2 on n2.id=rn.norma_destino_id where rn.norma_origem_id=b.id
  union all
  select rn.tipo,rn.dispositivo,rn.observacoes,n2.titulo from public.relacoes_normativas rn join public.normas n2 on n2.id=rn.norma_origem_id where rn.norma_destino_id=b.id
) z),'[]'::jsonb)
from base b
order by b.relevancia desc,b.ano desc
limit greatest(limite,1);
$function$;

comment on function public.consultar_status_norma(text,integer) is
'Consulta o catálogo normativo incluindo atos revogados, alteradores, superados ou com vigência a confirmar. Não usar como fundamento material automático.';
