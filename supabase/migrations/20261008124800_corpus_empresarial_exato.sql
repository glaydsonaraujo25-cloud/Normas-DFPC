-- Pesquisa diretamente os dispositivos conferidos, sem aproximar referências.
create or replace function public.consultar_empresa_pce(
 p_pergunta text, p_produto text default 'todos', p_atividade text default 'todos',
 p_publico text default 'empresa', p_data date default current_date, p_limite integer default 10
) returns jsonb language sql stable security invoker set search_path=public,pg_temp as $$
with entrada as (
 select left(trim(coalesce(p_pergunta,'')),2000) q,
 websearch_to_tsquery('portuguese',left(trim(coalesce(p_pergunta,'')),2000)) tsq,
 regexp_replace(plainto_tsquery('portuguese',regexp_replace(lower(p_pergunta),
 '\m(empresa|empresas|precisa|preciso|quais|qual|requisitos|documentos|aplicam|pce|sobre)\M','','g'))::text,' & ',' | ','g')::tsquery ampla,
 plainto_tsquery('portuguese',coalesce((select string_agg(s.expansao,' ') from sinonimos_busca s
 where s.ativo and lower(p_pergunta) like '%'||lower(s.termo)||'%'),'')) sinonimos,
 case when p_produto<>'todos' then p_produto
 when lower(p_pergunta) ~ 'explosiv|sicoex|nitrato' then 'explosivos'
 when lower(p_pergunta) ~ 'qu[ií]mic' then 'quimicos'
 when lower(p_pergunta) ~ 'blind|bal[ií]stic|sicovab|colete' then 'blindagem'
 when lower(p_pergunta) ~ 'pirot[eé]cn|fogos de artif' then 'pirotecnicos'
 when lower(p_pergunta) ~ 'menor potencial|menos.letal|espargidor' then 'menos_letais'
 when lower(p_pergunta) ~ 'muni[cç]' then 'municoes'
 when lower(p_pergunta) ~ 'arma de fogo|armas de fogo' then 'armas' else 'todos' end produto,
 case when p_atividade<>'todos' then p_atividade
 when lower(p_pergunta) ~ 'importa' and lower(p_pergunta) !~ 'exporta' then 'importacao'
 when lower(p_pergunta) ~ 'exporta' and lower(p_pergunta) !~ 'importa' then 'exportacao'
 else 'todos' end atividade
), corpus as (
 select d.id did,d.norma_id,d.documento_id,d.referencia dispositivo,d.texto_literal conteudo,
 d.pagina,d.status ds,d.conferido,d.vigencia_inicio,d.vigencia_fim,d.metadata,
 to_tsvector('portuguese',d.texto_literal || ' ' || d.referencia) fts,
 n.titulo,n.status,n.ultima_verificacao,n.fonte_oficial,n.usar_como_fundamento,
 n.produtos,n.publicos,n.atividades,n.vigencia_inicio inicio_norma,n.vigencia_fim fim_norma
 from dispositivos d join normas n on n.id=d.norma_id
), candidatos as (
 select c.*,
 (ts_rank_cd(c.fts,e.ampla)*12+ts_rank_cd(c.fts,e.tsq)*8+
 case when c.fts @@ e.tsq then 2 else 0 end+
 case when e.produto=any(c.produtos) then 1 else 0 end+
 case when e.atividade=any(c.atividades) then 0.5 else 0 end+
 case when lower(e.q) ~ 'art(igo)?[. ]*[0-9]' and public.dispositivo_contem_artigo(c.dispositivo,nullif(substring(lower(e.q) from 'art(?:igo)?[. ]*([0-9]+)'), '')::integer) then 5 else 0 end+
 case when length(regexp_replace(substring(e.q from '[0-9]{2,6}(?:\.[0-9]{3})*'),'[^0-9]','','g'))>=2
 and regexp_replace(c.titulo,'[^0-9]','','g') like '%'||regexp_replace(substring(e.q from '[0-9]{2,6}(?:\.[0-9]{3})*'),'[^0-9]','','g')||'%' then 3 else 0 end
 )::real score
 from corpus c cross join entrada e
 where length(e.q)>=3 and (c.fts @@ e.ampla or c.fts @@ e.tsq or c.fts @@ e.sinonimos)
 and (p_publico='todos' or c.publicos && array['empresa','geral'])
 and not (p_publico='empresa' and lower(c.conteudo) ~ 'atirador|colecionador|ca[cç]ador|militar|gsi'
 and lower(c.conteudo) !~ 'empresa|pessoa jur[ií]dica|fabrica[cç]|com[eé]rcio|importa[cç]|exporta[cç]|produtos controlados')
 and (e.produto='todos' or e.produto=any(c.produtos) or
 (cardinality(c.produtos)=0 and lower(c.conteudo) ~ 'pce|produtos controlados|registro|atividade|fiscaliza')
 or lower(c.conteudo) ~ case e.produto
 when 'explosivos' then 'explosiv|sicoex|nitrato' when 'quimicos' then 'qu[ií]mic|concentra[cç]|composi[cç]'
 when 'blindagem' then 'blind|bal[ií]stic|sicovab|colete' when 'pirotecnicos' then 'pirot[eé]cn|fogos'
 when 'menos_letais' then 'menor potencial|menos.letal|espargidor|dardos' when 'municoes' then 'muni[cç]|cartucho'
 when 'armas' then 'arma de fogo|armas de fogo' else 'a^' end)
 and (e.atividade='todos' or lower(c.conteudo) ~ case e.atividade
 when 'registro' then 'registro|apostil|revalid' when 'fabricacao' then 'fabric|conformidade'
 when 'comercio' then 'comerci|com[eé]rcio|vend' when 'aquisicao' then 'aquisi|adquir|compr'
 when 'transporte' then 'transport|tr[aá]fego' when 'armazenagem' then 'armazen'
 when 'utilizacao' then 'utiliz|emprego|detona|presta[cç]' when 'importacao' then 'import'
 when 'exportacao' then 'export' when 'fiscalizacao' then 'fiscaliz|sancion|infra[cç]' else 'a^' end)
), enriquecidos as (
 select c.*,doc.nome_arquivo,doc.sha256,
 (c.usar_como_fundamento and c.status in ('vigente','vigente_com_alteracoes','parcialmente_vigente')
 and c.conferido and c.ds in ('vigente','alterado')
 and (c.vigencia_inicio is null or c.vigencia_inicio<=p_data)
 and (c.vigencia_fim is null or c.vigencia_fim>=p_data)
 and (c.inicio_norma is null or c.inicio_norma<=p_data)
 and (c.fim_norma is null or c.fim_norma>=p_data)) seguro
 from candidatos c left join documentos doc on doc.id=c.documento_id
), ordenados as (
 select e.*,row_number() over(partition by norma_id order by score desc,did) pos
 from enriquecidos e where seguro
), selecionados as (
 select * from ordenados where pos<=3 order by score desc,did limit least(greatest(p_limite,1),20)
), fontes as (
 select coalesce(jsonb_agg(jsonb_build_object(
 'trecho_id',s.did,'norma_id',s.norma_id,'titulo',s.titulo,'dispositivo',s.dispositivo,
 'conteudo',s.conteudo,'pagina',s.pagina,'relevancia',s.score,'status',s.status,
 'ultima_verificacao',s.ultima_verificacao,'dispositivo_id',s.did,'texto_literal',s.conteudo,
 'status_dispositivo',s.ds,'literal_conferido',s.conferido,'vigencia_inicio',s.vigencia_inicio,'vigencia_fim',s.vigencia_fim,
 'fonte_oficial',s.fonte_oficial,'nome_arquivo',s.nome_arquivo,'sha256',s.sha256,'tipo_conteudo','dispositivo_cadastrado',
 'relacoes',coalesce((select jsonb_agg(jsonb_build_object('tipo',r.tipo,'norma_relacionada',n.titulo,'dispositivo',r.dispositivo,'observacoes',r.observacoes))
 from relacoes_normativas r join normas n on n.id=r.norma_destino_id where r.norma_origem_id=s.norma_id),'[]'::jsonb)
 ) order by s.score desc,s.did),'[]'::jsonb) itens from selecionados s
), guias as (
 select coalesce(jsonb_agg(to_jsonb(o)),'[]'::jsonb) itens from orientacoes_empresariais o cross join entrada e
 where o.estado='publicada' and (o.produto='todos' or o.produto=e.produto)
 and (o.atividade='todos' or o.atividade=e.atividade)
 and lower(trim(o.pergunta_modelo))=lower(trim(e.q))
 and not exists (select 1 from jsonb_array_elements(o.secoes) secao,
 jsonb_array_elements_text(secao->'dispositivo_ids') ref
 where not exists(select 1 from selecionados s where s.did::text=ref))
)
select jsonb_build_object('fontes',(select itens from fontes),'orientacoes',(select itens from guias),
 'data_referencia',p_data,'versao','empresas-v2-2026-10-08',
 'fontes_excluidas',(select count(*) from enriquecidos where not coalesce(seguro,false)));
$$;
notify pgrst,'reload schema';
