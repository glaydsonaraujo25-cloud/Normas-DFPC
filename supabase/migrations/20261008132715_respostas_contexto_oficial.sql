-- Pesquisa diretamente os dispositivos conferidos, sem aproximar referências.
create or replace function public.consultar_empresa_pce_v2(
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
 n.numero,n.titulo,n.status,n.ultima_verificacao,n.fonte_oficial,n.usar_como_fundamento,
 n.produtos,n.publicos,n.atividades,n.vigencia_inicio inicio_norma,n.vigencia_fim fim_norma
 from dispositivos d join normas n on n.id=d.norma_id
), candidatos as (
 select c.*,
 (ts_rank_cd(c.fts,e.ampla)*12+ts_rank_cd(c.fts,e.tsq)*8+
 case when c.fts @@ e.tsq then 2 else 0 end+
 case when e.produto=any(c.produtos) then 1 else 0 end+
 case when lower(e.q) ~ '(o que [ée]|defini[cç][aã]o|conceito).*pce' and regexp_replace(c.numero,'[^0-9]','','g')='10030' and c.dispositivo ilike '%art. 2º,%' then 30 else 0 end+
 case when lower(e.q) ~ 'seguran[cç]a privada|menor potencial' and lower(c.conteudo) ~ 'seguran[cç]a privada|menor potencial' then 12 else 0 end+
 case when lower(e.q) ~ 'precis.*registro' and lower(c.conteudo) like '%qualquer atividade%' then 8 else 0 end+
 case when lower(e.q) ~ 'apostil' and c.dispositivo='Art. 22' and c.titulo ilike 'Portaria nº 56%' then 12 else 0 end+
 case when lower(e.q) ~ 'registro|apostil' and lower(c.conteudo) ~ 'registro|apostil' then 4 else 0 end+
 case when e.atividade=any(c.atividades) then 0.5 else 0 end+
 case when lower(e.q) ~ 'art(igo)?[. ]*[0-9]' and public.dispositivo_contem_artigo(c.dispositivo,nullif(substring(lower(e.q) from 'art(?:igo)?[. ]*([0-9]+)'), '')::integer) then 5 else 0 end+
 case when length(regexp_replace(substring(e.q from '[0-9]{2,6}(?:\.[0-9]{3})*'),'[^0-9]','','g'))>=2
 and regexp_replace(c.titulo,'[^0-9]','','g') like '%'||regexp_replace(substring(e.q from '[0-9]{2,6}(?:\.[0-9]{3})*'),'[^0-9]','','g')||'%' then 3 else 0 end
 )::real score
 from corpus c cross join entrada e
 where length(e.q)>=3 and (c.fts @@ e.ampla or c.fts @@ e.tsq or c.fts @@ e.sinonimos)
 and (p_publico='todos' or c.publicos && array['empresa','geral'])
 and not (p_publico='empresa' and lower(c.conteudo) ~ 'atirador|colecionador|colecionamento|tiro desportivo|ca[cç]ador|militar|gsi'
 and lower(c.conteudo) !~ 'empresa|pessoa jur[ií]dica|fabrica[cç]|com[eé]rcio|importa[cç]|exporta[cç]|produto(s)? controlado(s)?')
 and not (p_publico='empresa' and lower(c.conteudo) ~ 'órgão requerente|administra[cç][aã]o p[uú]blica|for[cç]as auxiliares' and lower(c.conteudo) !~ 'empresa|pessoa jur[ií]dica')
 and (e.produto='todos' or e.produto=any(c.produtos) or
 (cardinality(c.produtos)=0 and lower(c.conteudo) ~ 'pce|produto(s)? controlado(s)?|registro|atividade|fiscaliza')
 or lower(c.conteudo) ~ case e.produto
 when 'explosivos' then 'explosiv|sicoex|nitrato' when 'quimicos' then 'qu[ií]mic|concentra[cç]|composi[cç]'
 when 'blindagem' then 'blind|bal[ií]stic|sicovab|colete' when 'pirotecnicos' then 'pirot[eé]cn|fogos'
 when 'menos_letais' then 'menor potencial|menos.letal|espargidor|dardos' when 'municoes' then 'muni[cç]|cartucho'
 when 'armas' then 'arma de fogo|armas de fogo' else 'a^' end)
 and (e.atividade='todos' or lower(c.conteudo) like '%qualquer atividade%' or lower(c.conteudo) ~ case e.atividade
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
 select * from ordenados where pos<=3 and score>=greatest(0.2,(select max(score)*0.18 from ordenados)) order by score desc,did limit least(greatest(p_limite,1),20)
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

-- Expansões são linguísticas; não constituem autorização ou enquadramento.
create or replace function public.normalizar_pergunta_pce(pergunta text)
returns text language sql immutable security invoker set search_path=public,pg_temp as $$
 select regexp_replace(regexp_replace(regexp_replace(regexp_replace(
 lower(translate(left(coalesce(pergunta,''),2000),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc')),
 '\mcr\M','registro','g'), '\m(vender|venda|vendas)\M','comercializar','g'),
 '\mcomprar\M','adquirir','g'), '\mpce(s)?\M','produto controlado','g');
$$;
create or replace function public.consultar_empresa_pce(
 p_pergunta text, p_produto text default 'todos', p_atividade text default 'todos',
 p_publico text default 'empresa', p_data date default current_date, p_limite integer default 10
) returns jsonb language plpgsql stable security invoker set search_path=public,pg_temp as $$
declare q text:=public.normalizar_pergunta_pce(p_pergunta); modelo text; resultado jsonb; adicional jsonb; busca text;
begin
 -- Não substituir perguntas com condições particulares por uma resposta geral.
 if q !~ 'prazo|quanto|validade|taxa|custo|document|dispens|isent|sem registro|nao|exceto|percent|concentr|mistura|solucao|%|[0-9]|calibre|acido|nitrato|marca|modelo|somente|apenas|sem |spray|espargidor|munic|art[. ]|decreto|portaria' then
  if q ~ '(o que e|o que sao|significa|definicao|conceito)' and q ~ 'produto(s)? controlado' and q !~ 'transport|comerci|import|export|fabric|registr|adquir|armazen' then modelo:='o que é PCE?';
  elsif (q ~ 'apostil' or q ~ 'incluir|adicionar' and q ~ 'atividade' and q ~ 'registro') and q ~ 'registro|atividade' and q ~ 'como|o que|significa' then modelo:='Como funciona o apostilamento de atividade no registro da empresa?';
  elsif q ~ 'quimic' and q ~ 'comerci' and q ~ 'registro' and q ~ 'precis|obrig' then modelo:='Minha empresa precisa de registro para comercializar produtos químicos?';
  elsif q ~ 'import' and q ~ 'produto controlado' and q ~ 'requisit|procedimento|como funciona' and q !~ 'export' then modelo:='Quais requisitos se aplicam à importação de PCE?';
  elsif q ~ 'seguranca privada' and q ~ 'menor potencial|menos.letal' and q ~ 'adquir' and q ~ 'pode|permit' then modelo:='Empresa de segurança privada pode adquirir PCE de menor potencial ofensivo?';
  end if;
 end if;
 busca:=coalesce(modelo, regexp_replace(regexp_replace(regexp_replace(p_pergunta,'\m[Cc][Rr]\M','registro','g'),'\m[vV]ender\M','comercializar','g'),'\m[cC]omprar\M','adquirir','g'));
 resultado:=public.consultar_empresa_pce_v2(busca,p_produto,p_atividade,p_publico,p_data,p_limite);
 -- Parágrafos do mesmo artigo e seção, incluindo redações consolidadas aplicáveis.
 -- Nunca associar art. 2º do decreto ao art. 2º de seu Anexo I.
 -- Respostas revisadas exibem seus fundamentos; pesquisa documental mantém os achados.
 if jsonb_array_length(resultado->'orientacoes')>0 then
  select jsonb_set(resultado,'{fontes}',coalesce(jsonb_agg(f.value order by f.ordinality),'[]'::jsonb))
  into resultado from jsonb_array_elements(resultado->'fontes') with ordinality f
  where exists(select 1 from jsonb_array_elements(resultado->'orientacoes') o,
   jsonb_array_elements(o->'secoes') sec,jsonb_array_elements_text(sec->'dispositivo_ids') ref
   where ref=f.value->>'dispositivo_id');
 end if;
 -- Os fundamentos citados recebem prioridade.
 select jsonb_set(resultado,'{fontes}',coalesce(jsonb_agg(f.value order by
 exists(select 1 from jsonb_array_elements(resultado->'orientacoes') o,
 jsonb_array_elements(o->'secoes') sec,jsonb_array_elements_text(sec->'dispositivo_ids') ref
 where ref=f.value->>'dispositivo_id') desc, f.ordinality),'[]'::jsonb))
 into resultado from jsonb_array_elements(resultado->'fontes') with ordinality f;
 with sementes as (
  select d.* from dispositivos d where d.id::text in (select value->>'dispositivo_id' from jsonb_array_elements(resultado->'fontes') with ordinality f where f.ordinality<=3)
 ), extras as (
  select distinct d.id,d.norma_id,d.documento_id,d.referencia,d.texto_literal,d.pagina,d.status,d.conferido,d.vigencia_inicio,d.vigencia_fim,
   n.titulo,n.status ns,n.ultima_verificacao,n.fonte_oficial,doc.nome_arquivo,doc.sha256
  from sementes s join dispositivos d on d.norma_id=s.norma_id and d.artigo=s.artigo
   and split_part(lower(d.referencia),'art.',1)=split_part(lower(s.referencia),'art.',1)
  join normas n on n.id=d.norma_id left join documentos doc on doc.id=d.documento_id
  where not exists(select 1 from jsonb_array_elements(resultado->'fontes') f where f->>'dispositivo_id'=d.id::text)
   and d.conferido and d.status in ('vigente','alterado') and n.usar_como_fundamento
   and n.status in ('vigente','vigente_com_alteracoes','parcialmente_vigente')
   and (d.vigencia_inicio is null or d.vigencia_inicio<=p_data) and (d.vigencia_fim is null or d.vigencia_fim>=p_data)
   and (n.vigencia_inicio is null or n.vigencia_inicio<=p_data) and (n.vigencia_fim is null or n.vigencia_fim>=p_data)
  order by d.referencia limit 12
 ) select coalesce(jsonb_agg(jsonb_build_object(
 'trecho_id',e.id,'norma_id',e.norma_id,'titulo',e.titulo,'dispositivo',e.referencia,'conteudo',e.texto_literal,'pagina',e.pagina,'relevancia',0,
 'status',e.ns,'ultima_verificacao',e.ultima_verificacao,'dispositivo_id',e.id,'texto_literal',e.texto_literal,'status_dispositivo',e.status,
 'literal_conferido',e.conferido,'vigencia_inicio',e.vigencia_inicio,'vigencia_fim',e.vigencia_fim,'fonte_oficial',e.fonte_oficial,
 'nome_arquivo',e.nome_arquivo,'sha256',e.sha256,'tipo_conteudo','dispositivo_complementar','relacoes','[]'::jsonb
 ) order by e.referencia),'[]'::jsonb) into adicional from extras e;
 resultado:=jsonb_set(resultado,'{fontes}',(resultado->'fontes')||adicional);
 return resultado||jsonb_build_object('versao','empresas-v3-2026-10-08','pergunta_interpretada',modelo,'complementares',jsonb_array_length(adicional));
end $$;
revoke execute on function public.consultar_empresa_pce_v2(text,text,text,text,date,integer) from public;
grant execute on function public.consultar_empresa_pce_v2(text,text,text,text,date,integer) to anon,authenticated;
revoke execute on function public.normalizar_pergunta_pce(text) from public;
grant execute on function public.normalizar_pergunta_pce(text) to anon,authenticated;
-- Links recuperados do índice oficial Siscomex/Exército. Não mudam status nem data de conferência.
update normas set fonte_oficial='https://www.gov.br/siscomex/pt-br/arquivos-e-imagens/2019/10/Portaria-no-118-COLOG-de-4-Out-2019-Lista-de-PCE.pdf'
where titulo='Portaria nº 118 COLOG, de 4 de outubro de 2019' and fonte_oficial is null;
update normas set fonte_oficial='https://www.planalto.gov.br/ccivil_03/leis/2003/l10.834.htm'
where titulo='Lei nº 10.834, de 29 de dezembro de 2003' and fonte_oficial is null;
update normas set fonte_oficial='https://www.in.gov.br/web/dou/-/portaria-c-ex-n-2.566-de-8-de-outubro-de-2025-661609153'
where titulo='Portaria C Ex nº 2.566, de 8 de outubro de 2025' and fonte_oficial is null;
notify pgrst,'reload schema';

-- Art. 3º conferido contra o PDF disponibilizado no portal oficial Siscomex.
insert into public.orientacoes_empresariais(titulo,produto,atividade,pergunta_modelo,secoes,estado)
select 'Enquadramento de misturas e soluções químicas','todos','todos','Como verificar se uma mistura ou solução química é PCE?',
 jsonb_build_array(jsonb_build_object('titulo','Procedimento de caracterização','texto',
 'Para misturas ou soluções que contenham pelo menos um PCE do tipo produto químico, o art. 3º prevê avaliação por Parecer Técnico elaborado pela DFPC para caracterização como PCE. O parecer considera a viabilidade de separar o PCE dos demais componentes e as recomendações das Nações Unidas para transporte de produtos perigosos. Portanto, a aplicação não pode concluir automaticamente que uma mistura é controlada ou dispensada apenas pelo nome comercial ou por um componente informado.',
 'dispositivo_ids',jsonb_build_array(d.id))), 'publicada'
from dispositivos d join normas n on n.id=d.norma_id
where n.titulo='Portaria nº 118 COLOG, de 4 de outubro de 2019' and d.referencia='Art. 3º e parágrafo único'
and not exists(select 1 from orientacoes_empresariais where pergunta_modelo='Como verificar se uma mistura ou solução química é PCE?');
