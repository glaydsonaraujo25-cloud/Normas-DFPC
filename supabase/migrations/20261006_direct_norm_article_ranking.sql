-- Melhora a busca por referência normativa direta (tipo, número, ano e artigo).
-- Esta migração documenta a versão implantada da função consultar_base_normativa.

create or replace function public.consultar_base_normativa(consulta text, limite integer default 5)
returns table(trecho_id bigint, pagina integer, dispositivo text, conteudo text, relevancia real, norma_id uuid, titulo text, tipo text, numero text, ano integer, status text, relacoes jsonb)
language sql
stable
set search_path to 'public','pg_temp'
as $function$
with entrada as (
  select trim(coalesce(consulta,'')) raw,
         trim(regexp_replace(lower(coalesce(consulta,'')),'[^[:alnum:]áéíóúâêôãõçºª§./-]+',' ','g')) normalizada
),
sinonimos as (
  select e.raw,e.normalizada,
         coalesce(string_agg(s.expansao,' ' order by length(s.termo) desc),'') expansoes
  from entrada e
  left join public.sinonimos_busca s on s.ativo=true
    and (' '||e.normalizada||' ') like ('% '||lower(s.termo)||' %')
  group by e.raw,e.normalizada
),
expandida as (
  select raw, normalizada, trim(raw||' '||expansoes) expanded from sinonimos
),
q as (
  select raw,normalizada,expanded,
         websearch_to_tsquery('portuguese',raw) query_exact,
         websearch_to_tsquery('portuguese',expanded) query_expanded,
         case when cardinality(tsvector_to_array(to_tsvector('portuguese',expanded)))>0
              then to_tsquery('portuguese',array_to_string(tsvector_to_array(to_tsvector('portuguese',expanded)),' | '))
              else websearch_to_tsquery('portuguese',expanded) end query_any,
         substring(lower(raw) from '(?:art(?:igo)?\.?\s*)([0-9]+[a-z]?)') artigo_numero,
         substring(lower(raw) from '(?:decreto|lei|portaria|ita|instru[cç][aã]o\s+t[eé]cnico-administrativa)[^0-9]{0,15}([0-9][0-9./-]*)') norma_numero_raw,
         substring(lower(raw) from '((?:19|20)[0-9]{2})') ano_busca,
         case
           when lower(raw) ~ '\bdecreto\b' then 'decreto'
           when lower(raw) ~ '\blei\b' then 'lei'
           when lower(raw) ~ '\bportaria\b' then 'portaria'
           when lower(raw) ~ '(^|[^a-z])ita([^a-z]|$)|instru[cç][aã]o\s+t[eé]cnico-administrativa' then 'ita'
           else null
         end tipo_busca,
         (lower(raw) ~ '(o que (é|e)|conceito|defini(c|ç)[aã]o|define|significa)') pergunta_definicao,
         (lower(raw) ~ '(^|[^a-z0-9])pce([^a-z0-9]|$)|produto(s)? controlado(s)?') pergunta_pce,
         (lower(raw) ~ '(^|[^a-z0-9])(gt|gte)([^a-z0-9]|$)|guia de tr[aá]fego') pergunta_gt,
         (lower(raw) ~ '(^|[^a-z0-9])cac([^a-z0-9]|$)|colecionador|atirador|ca[cç]ador') pergunta_cac
  from expandida
),
base as (
 select t.id trecho_id,t.pagina,t.dispositivo,t.conteudo,t.norma_id,n.titulo,n.tipo,n.numero,n.ano,n.status,
 (1.10*ts_rank_cd(t.fts,q.query_exact,32)
 +0.90*ts_rank_cd(t.fts,q.query_expanded,32)
 +0.55*ts_rank_cd(t.fts,q.query_any,32)
 +case when lower(coalesce(t.dispositivo,''))=lower(q.raw) then 2.50 else 0 end
 +case when q.artigo_numero is not null and lower(coalesce(t.dispositivo,'')) ~ ('art(s|igos?)?\.?[^0-9]{0,5}'||q.artigo_numero||'([^0-9]|$)') then 4.00 else 0 end
 +case when lower(t.conteudo) like '%'||lower(q.raw)||'%' then 1.20 else 0 end
 +case when lower(t.conteudo) like '%'||lower(q.expanded)||'%' then 0.80 else 0 end
 +case when lower(n.titulo) like '%'||lower(q.raw)||'%' then 1.00 else 0 end
 +case when lower(coalesce(n.assunto,'')) like '%'||lower(q.raw)||'%' then 0.70 else 0 end
 +case when q.norma_numero_raw is not null and regexp_replace(lower(n.numero),'[^0-9a-z]','','g') like regexp_replace(lower(q.norma_numero_raw),'[^0-9a-z]','','g')||'%' then 6.00 else 0 end
 +case when q.ano_busca is not null and n.ano::text=q.ano_busca then 2.00 else 0 end
 +case when q.tipo_busca is not null and lower(n.tipo) like q.tipo_busca||'%' then 1.50 else 0 end
 +case when q.norma_numero_raw is not null and q.ano_busca is not null and regexp_replace(lower(n.numero),'[^0-9a-z]','','g') like regexp_replace(lower(q.norma_numero_raw),'[^0-9a-z]','','g')||'%' and n.ano::text=q.ano_busca then 5.00 else 0 end
 +least(word_similarity(lower(q.normalizada),lower(coalesce(t.dispositivo,''))),1.0)*1.20
 +least(word_similarity(lower(q.normalizada),lower(n.titulo)),1.0)*0.85
 +least(word_similarity(lower(q.normalizada),lower(coalesce(n.assunto,''))),1.0)*0.70
 +case when exists(select 1 from unnest(coalesce(n.palavras_chave,array[]::text[])) k where lower(k) like '%'||lower(q.raw)||'%' or lower(q.raw) like '%'||lower(k)||'%') then 0.60 else 0 end
 +case when q.pergunta_pce and lower(t.conteudo) ~ '(define pce|produto que apresente poder destrutivo|produto controlado pelo exército)' then 2.60 else 0 end
 +case when q.pergunta_pce and q.pergunta_definicao and n.titulo ilike 'Decreto nº 10.030%' and lower(coalesce(t.dispositivo,'')) like '%2º a 4º%' then 4.50 else 0 end
 +case when q.pergunta_gt and lower(t.conteudo) ~ 'guia de tr[aá]fego|porte de tr[aâ]nsito' then 2.80 else 0 end
 +case when q.pergunta_gt and q.pergunta_cac and lower(t.conteudo) ~ 'guia de tr[aá]fego|porte de tr[aâ]nsito' and lower(t.conteudo) ~ 'colecionador|atirador|ca[cç]ador' then 5.00 else 0 end
 +case n.status when 'vigente' then 0.35 when 'vigente_com_alteracoes' then 0.25 else 0 end)::real score
 from public.trechos t join public.normas n on n.id=t.norma_id cross join q
 where n.usar_como_fundamento=true and n.status in('vigente','vigente_com_alteracoes')
 and (
   t.fts@@q.query_exact or t.fts@@q.query_expanded or t.fts@@q.query_any
   or lower(t.conteudo) like '%'||lower(q.raw)||'%'
   or lower(coalesce(t.dispositivo,'')) like '%'||lower(q.raw)||'%'
   or (q.artigo_numero is not null and lower(coalesce(t.dispositivo,'')) ~ ('art(s|igos?)?\.?[^0-9]{0,5}'||q.artigo_numero||'([^0-9]|$)'))
   or lower(n.titulo) like '%'||lower(q.raw)||'%'
   or lower(coalesce(n.assunto,'')) like '%'||lower(q.raw)||'%'
   or (q.norma_numero_raw is not null and regexp_replace(lower(n.numero),'[^0-9a-z]','','g') like regexp_replace(lower(q.norma_numero_raw),'[^0-9a-z]','','g')||'%')
   or (q.ano_busca is not null and n.ano::text=q.ano_busca)
   or word_similarity(lower(q.normalizada),lower(coalesce(t.dispositivo,''))) > 0.42
   or word_similarity(lower(q.normalizada),lower(n.titulo)) > 0.42
   or word_similarity(lower(q.normalizada),lower(coalesce(n.assunto,''))) > 0.42
   or exists(select 1 from unnest(coalesce(n.palavras_chave,array[]::text[])) k where lower(k) like '%'||lower(q.raw)||'%' or lower(q.raw) like '%'||lower(k)||'%')
 )
),
diversificado as(
 select b.*,row_number() over(partition by b.norma_id order by b.score desc,b.trecho_id) pos_norma from base b
),
final as(
 select d.*,(d.score-((d.pos_norma-1)*0.08))::real relevancia_final from diversificado d where d.pos_norma<=3
)
select f.trecho_id,f.pagina,f.dispositivo,f.conteudo,f.relevancia_final,f.norma_id,f.titulo,f.tipo,f.numero,f.ano,f.status,
coalesce((select jsonb_agg(jsonb_build_object('tipo',z.tipo,'dispositivo',z.dispositivo,'observacoes',z.observacoes,'norma_relacionada',z.titulo) order by z.tipo,z.titulo)
from (select rn.tipo,rn.dispositivo,rn.observacoes,n2.titulo from public.relacoes_normativas rn join public.normas n2 on n2.id=rn.norma_destino_id where rn.norma_origem_id=f.norma_id
union all select rn.tipo,rn.dispositivo,rn.observacoes,n2.titulo from public.relacoes_normativas rn join public.normas n2 on n2.id=rn.norma_origem_id where rn.norma_destino_id=f.norma_id) z),'[]'::jsonb)
from final f
order by f.relevancia_final desc,case f.status when 'vigente' then 0 when 'vigente_com_alteracoes' then 1 else 2 end,f.ano desc
limit greatest(limite,1)
$function$;
