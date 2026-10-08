-- Snapshot das funções existentes antes da consulta empresarial.
-- Sem alteração de comportamento. Dependências são definidas nas migrations anteriores.
CREATE OR REPLACE FUNCTION public.consultar_base_normativa_raw(consulta text, limite integer DEFAULT 5)
 RETURNS TABLE(trecho_id bigint, pagina integer, dispositivo text, conteudo text, relevancia real, norma_id uuid, titulo text, tipo text, numero text, ano integer, status text, relacoes jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
with entrada as (
  select trim(coalesce(consulta,'')) raw,
         trim(regexp_replace(lower(coalesce(consulta,'')),'[^[:alnum:]áéíóúâêôãõç]+',' ','g')) normalizada
), sinonimos as (
  select e.raw,e.normalizada,coalesce(string_agg(s.expansao,' ' order by length(s.termo) desc),'') expansoes
  from entrada e left join public.sinonimos_busca s on s.ativo=true and (' '||e.normalizada||' ') like ('% '||lower(s.termo)||' %')
  group by e.raw,e.normalizada
), expandida as (
  select raw,normalizada,trim(raw||' '||expansoes) expanded from sinonimos
), q as (
  select raw,normalizada,expanded,
         websearch_to_tsquery('portuguese',raw) query_exact,
         websearch_to_tsquery('portuguese',expanded) query_expanded,
         case when cardinality(tsvector_to_array(to_tsvector('portuguese',expanded)))>0 then to_tsquery('portuguese',array_to_string(tsvector_to_array(to_tsvector('portuguese',expanded)),' | ')) else websearch_to_tsquery('portuguese',expanded) end query_any,
         substring(lower(raw) from '(art\.?\s*[0-9]+[a-z]?)') artigo_busca,
         regexp_replace(coalesce(substring(lower(raw) from '([0-9]{2,6}(?:\.[0-9]{3})*)'),'') ,'[^0-9]','','g') numero_compacto,
         substring(lower(raw) from '([12][0-9]{3})') ano_busca,
         substring(lower(raw) from 'n[ií]vel\s*([123])') nivel_busca,
         (lower(raw) ~ '(o que (é|e)|conceito|defini(c|ç)[aã]o|define|significa)') pergunta_definicao,
         (lower(raw) ~ '(^|[^a-z0-9])pce([^a-z0-9]|$)|produto(s)? controlado(s)?') pergunta_pce,
         (lower(raw) ~ '(^|[^a-z0-9])(gt|gte)([^a-z0-9]|$)|guia de tr[aá]fego') pergunta_gt,
         (lower(raw) ~ '(^|[^a-z0-9])cac([^a-z0-9]|$)|colecionador|atirador|ca[cç]ador') pergunta_cac,
         (lower(raw) ~ '(quantos?|quantas?|limite|m[aá]ximo|maximo|quantidade)') pergunta_quantidade,
         (lower(raw) ~ '(requisito|documento|exig[eê]ncia|necess[aá]rio|precisa|deve apresentar)') pergunta_requisitos,
         (lower(raw) ~ '(como (fazer|obter|solicitar|funciona)|procedimento|passo|tramita[cç][aã]o|pedido|requerer)') pergunta_procedimento,
         (lower(raw) ~ '(quem pode|quem deve|quem tem direito|pode adquirir|pode comprar|autorizado)') pergunta_quem,
         (lower(raw) ~ '(prazo|validade|dias|meses|anos|vence|expira)') pergunta_prazo,
         (lower(raw) ~ '(proibido|vedado|n[aã]o pode|restri[cç][aã]o|impedido)') pergunta_restricao,
         (lower(raw) ~ 'atirador' and lower(raw) ~ 'n[ií]vel\s*[123]') pergunta_nivel_atirador,
         (lower(raw) ~ 'sinarm' and lower(raw) ~ 'sigma' and lower(raw) ~ 'transfer') pergunta_transferencia_sistemas,
         (lower(raw) ~ '(diferen[cç]a|comparar|compare|comparativo|versus|\bvs\b|qual muda|o que muda)') pergunta_comparativa,
         (lower(raw) ~ '(adquir|aquisi[cç][aã]o|comprar|compra)') pergunta_aquisicao,
         (lower(raw) ~ '(transport|tr[aá]fego|guia de tr[aá]fego|\bgt\b|\bgte\b)') pergunta_transporte,
         (lower(raw) ~ '(registr|cadastr|craf|certificado de registro)') pergunta_registro,
         (lower(raw) ~ '(transfer)') pergunta_transferencia,
         (lower(raw) ~ '(muni[cç][aã]o|muni[cç][oõ]es|cartuchos?|recarga)') pergunta_municao,
         (lower(raw) ~ '(porte|portar arma)') pergunta_porte
  from expandida
), base as (
 select t.id trecho_id,t.pagina,t.dispositivo,t.conteudo,t.norma_id,n.titulo,n.tipo,n.numero,n.ano,n.status,
 (1.10*ts_rank_cd(t.fts,q.query_exact,32)+0.90*ts_rank_cd(t.fts,q.query_expanded,32)+0.55*ts_rank_cd(t.fts,q.query_any,32)
 +case when lower(coalesce(t.dispositivo,''))=lower(q.raw) then 2.50 else 0 end
 +case when q.artigo_busca is not null and lower(coalesce(t.dispositivo,'')) like '%'||q.artigo_busca||'%' then 2.40 else 0 end
 +case when lower(t.conteudo) like '%'||lower(q.raw)||'%' then 1.20 else 0 end
 +case when lower(t.conteudo) like '%'||lower(q.expanded)||'%' then 0.80 else 0 end
 +case when lower(n.titulo) like '%'||lower(q.raw)||'%' then 1.00 else 0 end
 +case when lower(coalesce(n.assunto,'')) like '%'||lower(q.raw)||'%' then 0.70 else 0 end
 +least(word_similarity(lower(q.normalizada),lower(coalesce(t.dispositivo,''))),1.0)*1.20
 +least(word_similarity(lower(q.normalizada),lower(n.titulo)),1.0)*0.85
 +least(word_similarity(lower(q.normalizada),lower(coalesce(n.assunto,''))),1.0)*0.70
 +case when q.numero_compacto<>'' and regexp_replace(lower(coalesce(n.numero,'')),'[^0-9]','','g') like q.numero_compacto||'%' then 3.50 else 0 end
 +case when q.ano_busca is not null and n.ano::text=q.ano_busca then 1.50 else 0 end
 +case when q.numero_compacto<>'' and q.ano_busca is not null and regexp_replace(lower(coalesce(n.numero,'')),'[^0-9]','','g') like q.numero_compacto||'%' and n.ano::text=q.ano_busca then 3.50 else 0 end
 +case when exists(select 1 from unnest(coalesce(n.palavras_chave,array[]::text[])) k where lower(k) like '%'||lower(q.raw)||'%' or lower(q.raw) like '%'||lower(k)||'%') then 0.60 else 0 end
 +case when q.pergunta_pce and lower(t.conteudo) ~ '(define pce|produto que apresente poder destrutivo|produto controlado pelo exército)' then 2.60 else 0 end
 +case when q.pergunta_pce and q.pergunta_definicao and n.titulo ilike 'Decreto nº 10.030%' and lower(coalesce(t.dispositivo,'')) like '%2º a 4º%' then 4.50 else 0 end
 +case when q.pergunta_gt and lower(t.conteudo) ~ 'guia de tr[aá]fego|porte de tr[aâ]nsito' then 2.80 else 0 end
 +case when q.pergunta_gt and q.pergunta_cac and lower(t.conteudo) ~ 'guia de tr[aá]fego|porte de tr[aâ]nsito' and lower(t.conteudo) ~ 'colecionador|atirador|ca[cç]ador' then 5.00 else 0 end
 +case when q.pergunta_quantidade and lower(t.conteudo) ~ '(até|limite|m[aá]ximo|quantidade|unidades|armas|muni[cç][oõ]es)' then 2.40 else 0 end
 +case when q.pergunta_requisitos and lower(t.conteudo) ~ '(requisit|document|comprov|certid|declara[cç][aã]o|laudo|exig)' then 2.20 else 0 end
 +case when q.pergunta_procedimento and lower(t.conteudo) ~ '(solicit|requer|procediment|pedido|sistema|tramita|autoriza[cç][aã]o)' then 2.00 else 0 end
 +case when q.pergunta_quem and lower(t.conteudo) ~ '(poder[aá]|pode|autorizad|integrante|pessoa f[ií]sica|pessoa jur[ií]dica|militar|institui[cç][aã]o)' then 2.00 else 0 end
 +case when q.pergunta_prazo and lower(t.conteudo) ~ '(prazo|validade|dias|meses|anos|vig[eê]ncia)' then 2.10 else 0 end
 +case when q.pergunta_restricao and lower(t.conteudo) ~ '(vedad|proibid|n[aã]o poder|restrit|imped)' then 2.20 else 0 end
 +case when q.pergunta_nivel_atirador and q.nivel_busca is not null and lower(t.conteudo) ~ ('n[ií]vel\s*'||q.nivel_busca) then 6.50 else 0 end
 +case when q.pergunta_nivel_atirador and lower(t.conteudo) ~ 'limites? de armas|at[eé] dezesseis|uso restrito' then 3.50 else 0 end
 +case when q.pergunta_transferencia_sistemas and lower(t.conteudo) ~ 'sinarm' and lower(t.conteudo) ~ 'sigma' then 5.50 else 0 end
 +case when q.pergunta_transferencia_sistemas and lower(t.conteudo) ~ 'document|anu[eê]ncia|transfer' then 2.50 else 0 end
 +case when q.pergunta_comparativa and lower(t.conteudo) ~ 'n[ií]vel 1' and lower(t.conteudo) ~ 'n[ií]vel 2' and lower(t.conteudo) ~ 'n[ií]vel 3' then 6.00 else 0 end
 +case when q.pergunta_comparativa and lower(t.conteudo) ~ '(diferen|nível|limite|requisit|permitid|restrit)' then 1.80 else 0 end
 +case when q.pergunta_aquisicao and lower(t.conteudo) ~ '(aquisi[cç][aã]o|adquir|compr|autoriza[cç][aã]o para aquisi)' then 2.60 else 0 end
 +case when q.pergunta_transporte and lower(t.conteudo) ~ '(transport|guia de tr[aá]fego|porte de tr[aâ]nsito)' then 2.60 else 0 end
 +case when q.pergunta_registro and lower(t.conteudo) ~ '(registro|cadastr|craf|sigma|sinarm)' then 2.30 else 0 end
 +case when q.pergunta_transferencia and lower(t.conteudo) ~ '(transfer[eê]ncia|transferir|alienante|adquirente)' then 2.40 else 0 end
 +case when q.pergunta_municao and lower(t.conteudo) ~ '(muni[cç][aã]o|muni[cç][oõ]es|cartuchos?|recarga|insumos)' then 2.40 else 0 end
 +case when q.pergunta_porte and lower(t.conteudo) ~ '(porte de arma|portar arma|autoriza[cç][aã]o para portar)' then 2.40 else 0 end
 +case n.status when 'vigente' then 0.35 when 'vigente_com_alteracoes' then 0.25 else 0 end)::real score
 from public.trechos t join public.normas n on n.id=t.norma_id cross join q
 where n.usar_como_fundamento=true and n.status in('vigente','vigente_com_alteracoes') and (
   t.fts@@q.query_exact or t.fts@@q.query_expanded or t.fts@@q.query_any or lower(t.conteudo) like '%'||lower(q.raw)||'%' or lower(coalesce(t.dispositivo,'')) like '%'||lower(q.raw)||'%' or (q.artigo_busca is not null and lower(coalesce(t.dispositivo,'')) like '%'||q.artigo_busca||'%') or lower(n.titulo) like '%'||lower(q.raw)||'%' or lower(coalesce(n.assunto,'')) like '%'||lower(q.raw)||'%' or word_similarity(lower(q.normalizada),lower(coalesce(t.dispositivo,'')))>0.42 or word_similarity(lower(q.normalizada),lower(n.titulo))>0.42 or word_similarity(lower(q.normalizada),lower(coalesce(n.assunto,'')))>0.42 or exists(select 1 from unnest(coalesce(n.palavras_chave,array[]::text[])) k where lower(k) like '%'||lower(q.raw)||'%' or lower(q.raw) like '%'||lower(k)||'%') or (q.numero_compacto<>'' and regexp_replace(lower(coalesce(n.numero,'')),'[^0-9]','','g') like q.numero_compacto||'%')
 )
), diversificado as (select b.*,row_number() over(partition by b.norma_id order by b.score desc,b.trecho_id) pos_norma from base b),
final as (select d.*,(d.score-((d.pos_norma-1)*0.08))::real relevancia_final from diversificado d where d.pos_norma<=20)
select f.trecho_id,f.pagina,f.dispositivo,f.conteudo,f.relevancia_final,f.norma_id,f.titulo,f.tipo,f.numero,f.ano,f.status,
coalesce((select jsonb_agg(jsonb_build_object('tipo',z.tipo,'dispositivo',z.dispositivo,'observacoes',z.observacoes,'norma_relacionada',z.titulo) order by z.tipo,z.titulo) from (select rn.tipo,rn.dispositivo,rn.observacoes,n2.titulo from public.relacoes_normativas rn join public.normas n2 on n2.id=rn.norma_destino_id where rn.norma_origem_id=f.norma_id union all select rn.tipo,rn.dispositivo,rn.observacoes,n2.titulo from public.relacoes_normativas rn join public.normas n2 on n2.id=rn.norma_origem_id where rn.norma_destino_id=f.norma_id) z),'[]'::jsonb)
from final f order by f.relevancia_final desc,case f.status when 'vigente' then 0 when 'vigente_com_alteracoes' then 1 else 2 end,f.ano desc limit greatest(limite,1)
$function$
;

CREATE OR REPLACE FUNCTION public.consultar_base_normativa_v2(consulta text, limite integer DEFAULT 8)
 RETURNS TABLE(trecho_id bigint, pagina integer, dispositivo text, conteudo text, relevancia real, norma_id uuid, titulo text, tipo text, numero text, ano integer, status text, relacoes jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
with ampliada as (
  select *
  from public.consultar_base_normativa(consulta, greatest(limite * 4, 24))
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
$function$
;

CREATE OR REPLACE FUNCTION public.consultar_base_normativa_composta(consulta text, limite integer DEFAULT 10)
 RETURNS TABLE(aspecto text, trecho_id bigint, pagina integer, dispositivo text, conteudo text, relevancia real, norma_id uuid, titulo text, tipo text, numero text, ano integer, status text, relacoes jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
with entrada as (
  select lower(trim(coalesce(consulta,''))) q,
         (lower(coalesce(consulta,'')) ~ '(militar(es)? do ex[eé]rcito|ex[eé]rcito brasileiro|(^|[^a-z])eb([^a-z]|$))') escopo_exercito,
         (lower(coalesce(consulta,'')) ~ '(pol[ií]cia militar|policial militar|corpo de bombeiros militar|bombeiro militar|(^|[^a-z])(pm|cbm)([^a-z]|$)|gsi)') escopo_pm_cbm,
         (lower(coalesce(consulta,'')) ~ '((^|[^a-z])cac([^a-z]|$)|colecionador|atirador|ca[cç]ador)') escopo_cac,
         (lower(coalesce(consulta,'')) ~ '(seguran[cç]a privada|vigilante|servi[cç]o org[aâ]nico de seguran[cç]a|crpj|menor potencial ofensivo)') escopo_seguranca_privada,
         (lower(coalesce(consulta,'')) ~ '(explosiv|detona[cç][aã]o|sicoex|nitrato de am[oô]nio|blaster)') escopo_explosivos,
         (lower(coalesce(consulta,'')) ~ '(marca[cç][aã]o|remarca[cç][aã]o|rastreabilidade|n[uú]mero de s[eé]rie|identifica[cç][aã]o.*arma|arma.*importad)') escopo_marcacao
), aspectos(aspecto, contexto, padrao, prioridade) as (
  select 'Explosivos e detonação','explosivos SICOEX detonação aquisição tráfego armazenagem IIS','(explosiv|detona[cç][aã]o|sicoex|nitrato|armazenagem|transfer[eê]ncia de posse)',1 from entrada where escopo_explosivos
  union all select 'Marcação e rastreabilidade','marcação identificação rastreabilidade arma importada remarcação número de série','(marca[cç][aã]o|remarca[cç][aã]o|rastreab|n[uú]mero de s[eé]rie|identifica[cç][aã]o)',1 from entrada where escopo_marcacao
  union all select 'Segurança privada','segurança privada CRPJ Polícia Federal menor potencial ofensivo','(seguran[cç]a privada|crpj|pol[ií]cia federal|menor potencial ofensivo|servi[cç]o org[aâ]nico)',1 from entrada where escopo_seguranca_privada
  union all select 'Recarga e equipamentos','equipamento de recarga dies matriz apostilamento recarga','(equipamento.*recarga|recarga|matriz|dies|apostil)',2 from entrada where q ~ '(equipamento.*recarga|recarga|matriz|dies)'
  union all select 'Classificação de risco','classificação nível risco CNAE atividade econômica PCE','(classifica[cç][aã]o.*risco|n[ií]vel.*risco|cnae|atividade econ[oô]mica)',2 from entrada where q ~ '(risco|cnae|atividade econ[oô]mica)'
  union all select 'Aquisição','aquisição comprar adquirir autorização compra','(aquisi[cç][aã]o|adquir|compra|autoriza[cç][aã]o para aquisi)',3 from entrada where q ~ '(adquir|aquisi[cç][aã]o|comprar|compra)'
  union all select 'Transporte','transporte guia de tráfego GT porte de trânsito','(transport|guia de tr[aá]fego|porte de tr[aâ]nsito|tr[aá]fego)',4 from entrada where q ~ '(transport|tr[aá]fego|(^|[^a-z])(gt|gte)([^a-z]|$))'
  union all select 'Registro e cadastro','registro cadastro CRAF SIGMA SINARM','(registro|cadastr|craf|sigma|sinarm)',5 from entrada where q ~ '(registr|cadastr|craf|sigma|sinarm)'
  union all select 'Transferência','transferência alienante adquirente SINARM SIGMA anuência','(transfer[eê]ncia|transferir|alienante|adquirente|anu[eê]ncia)',6 from entrada where q ~ '(transfer)'
  union all select 'Munições','munição munições cartuchos recarga insumos','(muni[cç][aã]o|muni[cç][oõ]es|cartuchos?|recarga|insumos)',7 from entrada where q ~ '(muni[cç][aã]o|muni[cç][oõ]es|cartuchos?|recarga|insumos)'
  union all select 'Porte','porte de arma portar autorização para portar','((^|[^a-z])porte([^a-z]|$)|(^|[^a-z])portar[[:space:]]+arma)',8 from entrada where q ~ '((^|[^a-z])porte([^a-z]|$)|(^|[^a-z])portar[[:space:]]+arma)'
  union all select 'Validade e renovação','validade renovação revalidação vencimento CRAF CR','(validade|revalid|renova|venc|expira|tr[eê]s anos|3 anos)',9 from entrada where q ~ '(validade|revalid|renova|venc|expira|prazo do (craf|cr)|quando vence)'
  union all select 'Níveis e habitualidade','nível habitualidade progressão treinamento competição atirador','(n[ií]vel|habitual|progress[aã]o|treinament|competi[cç][aã]o|doze meses|12 meses)',10 from entrada where q ~ '(n[ií]vel[[:space:]]*[123]|habitual|progress[aã]o|treinament|competi[cç][aã]o)'
  union all select 'Requisitos e documentos','requisitos documentos comprovantes certidões laudo','(requisit|document|comprov|certid|declara[cç][aã]o|laudo|exig)',11 from entrada where q ~ '(requisito|documento|exig[eê]ncia|necess[aá]rio|precisa|deve apresentar)'
  union all select 'Procedimento','procedimento requerimento solicitação tramitação pedido','(procediment|requer|solicit|tramita|pedido|autoriza[cç][aã]o)',12 from entrada where q ~ '(como (fazer|obter|solicitar|funciona)|procedimento|passo|tramita[cç][aã]o|pedido|requerer)'
  union all select 'Comparação','comparação diferença limites requisitos níveis','(n[ií]vel|limite|requisit|permitid|restrit|quantidade)',13 from entrada where q ~ '(diferen[cç]a|comparar|compare|comparativo|versus|(^|[^a-z])vs([^a-z]|$)|o que muda)'
), aspectos_validos as (
  select * from aspectos
  union all select 'Consulta geral','','.',99 where not exists(select 1 from aspectos)
), candidatos as (
  select a.aspecto,a.prioridade,r.*,
         (r.relevancia
          + case when lower(coalesce(r.dispositivo,'')) ~ a.padrao then 8.0 else 0 end
          + case when lower(r.conteudo) ~ a.padrao then 1.5 else 0 end
          - case when lower(coalesce(r.dispositivo,'')) like '%ato aprovador%' then 4.0 else 0 end
          + case when a.aspecto='Validade e renovação' and e.q ~ '(craf|certificado de registro de arma)' and (lower(r.conteudo) ~ '(revalid|renova|vencimento)' or lower(coalesce(r.dispositivo,'')) ~ '(92|93|94)') then 12.0 else 0 end
          - case when a.aspecto='Validade e renovação' and e.q ~ '(craf|certificado de registro de arma)' and lower(r.conteudo) ~ '(180 dias|cento e oitenta)' then 5.0 else 0 end
          + case when e.escopo_exercito and (lower(r.titulo) like '%164 colog%' or lower(r.conteudo) ~ 'militares? do ex[eé]rcito') then 10.0 else 0 end
          + case when e.escopo_pm_cbm and (lower(r.titulo) like '%167 colog%' or lower(r.conteudo) ~ '(pol[ií]cias? militares?|corpos? de bombeiros|gsi/pr)') then 10.0 else 0 end
          + case when e.escopo_cac and (lower(r.titulo) like '%166 colog%' or lower(r.titulo) like '%11.615%' or lower(r.conteudo) ~ '(colecionador|atirador|ca[cç]ador)') then 10.0 else 0 end
          + case when e.escopo_seguranca_privada and (lower(r.titulo) like '%291%' or lower(r.conteudo) ~ 'seguran[cç]a privada|servi[cç]o org[aâ]nico|crpj') then 14.0 else 0 end
          + case when e.escopo_explosivos and (lower(r.titulo) like '%147 colog%' or lower(r.conteudo) ~ '(sicoex|explosiv|detona[cç][aã]o)') then 16.0 else 0 end
          + case when e.escopo_marcacao and (lower(r.titulo) like '%213 colog%' or lower(r.titulo) like '%ita nº 25%' or lower(r.conteudo) ~ '(remarca[cç][aã]o|marca[cç][aã]o.*arma|rastreab)') then 16.0 else 0 end
         )::real as score_aspecto
  from aspectos_validos a
  cross join entrada e
  cross join lateral public.consultar_base_normativa_raw(consulta || ' ' || a.contexto, greatest(limite*8,80)) r
  where (lower(r.conteudo) ~ a.padrao or lower(coalesce(r.dispositivo,'')) ~ a.padrao)
    and not (e.escopo_pm_cbm and not e.escopo_exercito and lower(r.titulo) like '%164 colog%')
    and not (e.escopo_exercito and not e.escopo_pm_cbm and lower(r.titulo) like '%167 colog%')
    and not (e.escopo_cac and not e.escopo_exercito and not e.escopo_pm_cbm and (lower(r.titulo) like '%164 colog%' or lower(r.titulo) like '%167 colog%'))
    and not (e.escopo_seguranca_privada and not e.escopo_exercito and not e.escopo_pm_cbm and not e.escopo_cac and (lower(r.titulo) like '%164 colog%' or lower(r.titulo) like '%166 colog%' or lower(r.titulo) like '%167 colog%'))
    and not (e.escopo_explosivos and lower(r.titulo) not like '%147 colog%' and lower(r.conteudo) !~ '(sicoex|explosiv|detona[cç][aã]o|nitrato)')
    and not (e.escopo_marcacao and lower(r.titulo) not like '%213 colog%' and lower(r.titulo) not like '%ita nº 25%' and lower(r.conteudo) !~ '(marca[cç][aã]o|remarca[cç][aã]o|rastreab|n[uú]mero de s[eé]rie)')
), ranqueados as (
  select c.*,row_number() over(partition by c.aspecto order by c.score_aspecto desc,c.relevancia desc,c.trecho_id) pos_aspecto
  from candidatos c
)
select aspecto,trecho_id,pagina,dispositivo,conteudo,score_aspecto as relevancia,norma_id,titulo,tipo,numero,ano,status,relacoes
from ranqueados where pos_aspecto<=2
order by prioridade,score_aspecto desc
limit greatest(limite,1)
$function$
;

CREATE OR REPLACE FUNCTION public.consultar_base_normativa(consulta text, limite integer DEFAULT 5)
 RETURNS TABLE(trecho_id bigint, pagina integer, dispositivo text, conteudo text, relevancia real, norma_id uuid, titulo text, tipo text, numero text, ano integer, status text, relacoes jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
with entrada as (
  select
    nullif(substring(lower(coalesce(consulta,'')) from 'art(?:igo)?s?\.?\s*([0-9]+)'), '')::integer as artigo_num,
    regexp_replace(coalesce(substring(lower(coalesce(consulta,'')) from '([0-9]{2,6}(?:\.[0-9]{3})*)'),''),'[^0-9]','','g') as numero_compacto,
    substring(lower(coalesce(consulta,'')) from '((?:19|20)[0-9]{2})') as ano_busca,
    nullif(substring(lower(coalesce(consulta,'')) from '(?:§|par[aá]grafo)\s*([0-9]+)'), '')::integer as paragrafo_num,
    (lower(coalesce(consulta,'')) ~ 'par[aá]grafo\s+[uú]nico') as paragrafo_unico,
    substring(lower(coalesce(consulta,'')) from '(?:inciso|inc\.)\s*([ivxlcdm]+)') as inciso_busca,
    substring(lower(coalesce(consulta,'')) from 'al[ií]nea\s*["''“”]?([a-z])') as alinea_busca,
    nullif(substring(lower(coalesce(consulta,'')) from 'item\s*([0-9]+)'), '')::integer as item_num,
    (lower(coalesce(consulta,'')) ~ '\bcaput\b') as busca_caput
),
raw as (
  select * from public.consultar_base_normativa_raw(consulta, greatest(limite * 7, 42))
),
diretos as (
  select t.id trecho_id,t.pagina,t.dispositivo,t.conteudo,0.5::real relevancia,t.norma_id,n.titulo,n.tipo,n.numero,n.ano,n.status,
    coalesce((select jsonb_agg(jsonb_build_object('tipo',z.tipo,'dispositivo',z.dispositivo,'observacoes',z.observacoes,'norma_relacionada',z.titulo) order by z.tipo,z.titulo)
      from (select rn.tipo,rn.dispositivo,rn.observacoes,n2.titulo from public.relacoes_normativas rn join public.normas n2 on n2.id=rn.norma_destino_id where rn.norma_origem_id=n.id
            union all
            select rn.tipo,rn.dispositivo,rn.observacoes,n2.titulo from public.relacoes_normativas rn join public.normas n2 on n2.id=rn.norma_origem_id where rn.norma_destino_id=n.id) z),'[]'::jsonb) relacoes
  from public.trechos t join public.normas n on n.id=t.norma_id cross join entrada e
  where n.usar_como_fundamento=true and n.status in ('vigente','vigente_com_alteracoes')
    and e.artigo_num is not null and public.dispositivo_contem_artigo(t.dispositivo,e.artigo_num)
    and (e.numero_compacto='' or regexp_replace(lower(coalesce(n.numero,'')),'[^0-9]','','g') like e.numero_compacto||'%')
    and (e.ano_busca is null or n.ano::text=e.ano_busca)
),
ampliada as (
  select * from raw
  union all
  select * from diretos
),
ajustada as (
  select a.*,
    (a.relevancia
      + case when public.dispositivo_contem_artigo(a.dispositivo,e.artigo_num) then 5.5 else 0 end
      + case when e.numero_compacto<>'' and regexp_replace(lower(coalesce(a.numero,'')),'[^0-9]','','g') like e.numero_compacto||'%' then 4.5 else 0 end
      + case when e.ano_busca is not null and a.ano::text=e.ano_busca then 1.5 else 0 end
      + case when e.busca_caput and lower(coalesce(a.dispositivo,'')) ~ '\bcaput\b' then 4.5 else 0 end
      + case when e.paragrafo_unico and lower(coalesce(a.dispositivo,'')) like '%parágrafo único%' then 4.5 else 0 end
      + case when e.paragrafo_num is not null and lower(coalesce(a.dispositivo,'')) ~ ('§\s*'||e.paragrafo_num::text||'º?') then 4.5 else 0 end
      + case when e.inciso_busca is not null and lower(coalesce(a.dispositivo,'')) ~ ('inciso(s)?\s+'||e.inciso_busca||'([^ivxlcdm]|$)') then 4.2 else 0 end
      + case when e.alinea_busca is not null and lower(coalesce(a.dispositivo,'')) ~ ('alínea(s)?\s+'||e.alinea_busca||'([^a-z]|$)') then 4.0 else 0 end
      + case when e.item_num is not null and lower(coalesce(a.dispositivo,'')) ~ ('item\s+'||e.item_num::text||'([^0-9]|$)') then 4.0 else 0 end
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
$function$
;

CREATE OR REPLACE FUNCTION public.executar_regressao_busca()
 RETURNS TABLE(caso_id bigint, nome text, pergunta text, aprovado boolean, posicao_encontrada integer, titulo_encontrado text, dispositivo_encontrado text, esperado text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  c record;
  r record;
  pos integer;
  achou boolean;
begin
  for c in select * from public.casos_regressao_busca where ativo order by id loop
    pos := 0;
    achou := false;
    if c.usar_busca_composta then
      for r in select x.titulo, x.dispositivo from public.consultar_base_normativa_composta(c.pergunta, greatest(c.top_n,5)) x loop
        pos := pos + 1;
        if lower(r.titulo) like lower(c.titulo_esperado_like)
           and (c.dispositivo_esperado_like is null or lower(coalesce(r.dispositivo,'')) like lower(c.dispositivo_esperado_like)) then
          achou := true;
          caso_id := c.id; nome := c.nome; pergunta := c.pergunta; aprovado := pos <= c.top_n;
          posicao_encontrada := pos; titulo_encontrado := r.titulo; dispositivo_encontrado := r.dispositivo;
          esperado := c.titulo_esperado_like || coalesce(' / ' || c.dispositivo_esperado_like,'');
          return next;
          exit;
        end if;
      end loop;
    else
      for r in select x.titulo, x.dispositivo from public.consultar_base_normativa(c.pergunta, greatest(c.top_n,5)) x loop
        pos := pos + 1;
        if lower(r.titulo) like lower(c.titulo_esperado_like)
           and (c.dispositivo_esperado_like is null or lower(coalesce(r.dispositivo,'')) like lower(c.dispositivo_esperado_like)) then
          achou := true;
          caso_id := c.id; nome := c.nome; pergunta := c.pergunta; aprovado := pos <= c.top_n;
          posicao_encontrada := pos; titulo_encontrado := r.titulo; dispositivo_encontrado := r.dispositivo;
          esperado := c.titulo_esperado_like || coalesce(' / ' || c.dispositivo_esperado_like,'');
          return next;
          exit;
        end if;
      end loop;
    end if;
    if not achou then
      caso_id := c.id; nome := c.nome; pergunta := c.pergunta; aprovado := false;
      posicao_encontrada := null; titulo_encontrado := null; dispositivo_encontrado := null;
      esperado := c.titulo_esperado_like || coalesce(' / ' || c.dispositivo_esperado_like,'');
      return next;
    end if;
  end loop;
end $function$
;
