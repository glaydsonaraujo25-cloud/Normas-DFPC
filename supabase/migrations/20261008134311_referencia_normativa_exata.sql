-- Preserva a consulta temática v3, sem alterar seus resultados.
create or replace function public.consultar_empresa_pce_v3(
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

create or replace function public.consultar_referencia_pce(p_pergunta text,p_data date default current_date)
returns jsonb language plpgsql stable security invoker set search_path=public,pg_temp as $$
declare
 q text:=lower(translate(left(coalesce(p_pergunta,''),2000),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'));
 art text; citacao text[]; numero_norma text; tipo_norma text; ano_norma integer; secao text;
 normas_ids uuid[]; norma uuid; titulo_norma text; resultado jsonb; fontes jsonb; opcoes jsonb; total integer; v_paragrafo text; v_inciso text; v_alinea text;
begin
 art:=substring(q from '\mart(?:igo|s|igos)?[. ]*([0-9]{1,5})');
 citacao:=regexp_match(q,'\m(decreto|portaria|lei|ita)[ ]+(?:n[º°o.]*[ ]*)?([0-9][0-9.]*)');
 if art is null or citacao is null then return null; end if;
 tipo_norma:=citacao[1]; numero_norma:=ltrim(regexp_replace(citacao[2],'[^0-9]','','g'),'0');
 ano_norma:=nullif(substring(q from '(?:/|\mde[ ]+)(19[0-9]{2}|20[0-9]{2})\M'),'')::integer;
 resultado:=jsonb_build_object('fontes','[]'::jsonb,'orientacoes','[]'::jsonb,'data_referencia',p_data,
 'versao','empresas-v4-referencia-exata','fontes_excluidas',0,'referencia_exata',true);
 -- Não reduzir comparações entre normas/artigos a uma única referência.
 if (select count(*) from regexp_matches(q,'\m(decreto|portaria|lei|ita)[ ]+(?:n[º°o.]*[ ]*)?[0-9]','g'))>1
 or (select count(*) from regexp_matches(q,'\mart(?:igo)?[. ]*[0-9]','g'))>1
 or q ~ '\marts[.]|\martigos[ ]|\mart(?:igo)?[. ]*[0-9]+[º°]?[ ]+(e|a|ao)[ ]+[0-9]' then
  return resultado||jsonb_build_object('aviso_referencia','Consulte um artigo e uma norma por vez para recuperar a referência exata.');
 end if;
 select array_agg(n.id),min(n.titulo) into normas_ids,titulo_norma from normas n
 where lower(n.tipo) like tipo_norma||'%'
 and ltrim(regexp_replace(substring(n.numero from '^[0-9.]+'),'[^0-9]','','g'),'0')=numero_norma
 and (ano_norma is null or n.ano=ano_norma);
 if coalesce(cardinality(normas_ids),0)<>1 then
  return resultado||jsonb_build_object('aviso_referencia',case when cardinality(normas_ids)>1
   then 'Há mais de uma norma com esse tipo e número. Inclua o ano e o órgão na pergunta.'
   else 'Não localizei essa norma no acervo. Confira o tipo, o número e o ano; a ausência não comprova revogação.' end);
 end if;
 norma:=normas_ids[1];
 v_paragrafo:=coalesce(substring(q from '§[ ]*([0-9]+)'),substring(q from '\mparagrafo[ ]+([0-9]+)'));
 if q ~ 'paragrafo unico' then v_paragrafo:='unico'; end if;
 v_inciso:=substring(q from '\minciso[ ]+([ivxlcdm]+)\M');
 v_alinea:=substring(q from '\malinea[ ]+([a-z])\M');
 if q ~ '§§|\mincisos\M|\malineas\M|\mparagrafos\M' then
  return resultado||jsonb_build_object('aviso_referencia','Consulte um inciso, parágrafo ou alínea por vez, ou consulte o artigo completo. Não são separados automaticamente dispositivos agrupados.');
 end if;
 -- O prefixo da referência separa anexos, normas aprovadas e corpo principal.
 secao:=case
  when q ~ '\manexo[ ]+[ivxlcdm0-9]+' then 'anexo '||substring(q from '\manexo[ ]+([ivxlcdm0-9]+)')
  when q ~ 'corpo principal|corpo do|sem anexo' then 'corpo'
  when q ~ 'normas aprovadas|normas reguladoras|das normas|nas normas' then 'normas'
  else null end;
 if secao is null and (tipo_norma='decreto' or exists(select 1 from dispositivos d where d.norma_id=norma and lower(d.referencia) ~ '^(anexo|normas)')) then
  select coalesce(jsonb_agg(jsonb_build_object('rotulo',s.rotulo,'pergunta',p_pergunta||' — '||s.rotulo) order by s.rotulo),'[]'::jsonb)
  into opcoes from (
   select distinct initcap(substring(lower(d.referencia) from '^(anexo [ivxlcdm0-9]+)')) rotulo
   from dispositivos d where d.norma_id=norma and lower(d.referencia) ~ '^anexo '
   union select 'Corpo principal'
   union select 'Normas aprovadas' where exists(select 1 from dispositivos d where d.norma_id=norma and lower(d.referencia) ~ '^normas')
  ) s;
  return resultado||jsonb_build_object('aviso_referencia','Informe se o artigo pertence ao corpo principal, a um anexo ou às normas aprovadas. A numeração pode se repetir.', 'esclarecimentos',opcoes);
 end if;
 secao:=coalesce(secao,'corpo');
 secao:=case secao when 'anexo 1' then 'anexo i' when 'anexo 2' then 'anexo ii'
 when 'anexo 3' then 'anexo iii' when 'anexo 4' then 'anexo iv' when 'anexo 5' then 'anexo v' else secao end;
 with candidatos as (
  select d.*,n.titulo,n.status ns,n.usar_como_fundamento,n.ultima_verificacao,n.fonte_oficial,
   n.vigencia_inicio ni,n.vigencia_fim nf,doc.nome_arquivo,doc.sha256
  from dispositivos d join normas n on n.id=d.norma_id left join documentos doc on doc.id=d.documento_id
  where d.norma_id=norma
   -- Somente referências de um artigo. Faixas agrupadas não viram transcrição isolada.
   and regexp_replace(coalesce(d.artigo,''),'^[^0-9]*([0-9]+)[º°.]*$','\1')=art
   and case when secao='corpo' then lower(d.referencia) !~ '^(anexo|normas)'
    when secao='normas' then lower(d.referencia) ~ '^normas'
    else substring(lower(d.referencia) from '^(anexo [ivxlcdm0-9]+)')=secao end
   and (v_paragrafo is null or case when v_paragrafo='unico' then lower(d.paragrafo) like '%único%'
    else regexp_replace(coalesce(d.paragrafo,''),'^§?[ ]*([0-9]+)[º°.]?$','\1')=v_paragrafo end)
   and (v_inciso is null or lower(trim(d.inciso))=v_inciso)
   and (v_alinea is null or lower(trim(d.alinea))=v_alinea)
 ), seguros as (
  select * from candidatos where conferido and status in ('vigente','alterado') and usar_como_fundamento
   and ns in ('vigente','vigente_com_alteracoes','parcialmente_vigente')
   and (vigencia_inicio is null or vigencia_inicio<=p_data) and (vigencia_fim is null or vigencia_fim>=p_data)
   and (ni is null or ni<=p_data) and (nf is null or nf>=p_data)
 ) select coalesce(jsonb_agg(jsonb_build_object(
  'trecho_id',id,'norma_id',norma_id,'titulo',titulo,'dispositivo',referencia,'conteudo',texto_literal,'pagina',pagina,'relevancia',1,
  'status',ns,'ultima_verificacao',ultima_verificacao,'dispositivo_id',id,'texto_literal',texto_literal,'status_dispositivo',status,
  'literal_conferido',conferido,'vigencia_inicio',vigencia_inicio,'vigencia_fim',vigencia_fim,'fonte_oficial',fonte_oficial,
  'nome_arquivo',nome_arquivo,'sha256',sha256,'tipo_conteudo','referencia_exata','relacoes','[]'::jsonb
 ) order by (referencia ilike '%caput%') desc, referencia),'[]'::jsonb),(select count(*) from candidatos) into fontes,total from seguros;
 resultado:=jsonb_set(resultado,'{fontes}',fontes)||jsonb_build_object('fontes_excluidas',total-jsonb_array_length(fontes));
 return resultado||jsonb_build_object('aviso_referencia',case when jsonb_array_length(fontes)>0 then
 'Consulta do dispositivo cadastrado: art. '||art||' — '||titulo_norma||' — '||secao||'. Os textos abaixo não constituem uma orientação revisada para um caso empresarial.'
 else 'Não há redação individual conferida e aplicável desse artigo nessa seção no acervo. Não substituí o artigo por outro nem por uma faixa de artigos. Isso não comprova revogação ou dispensa.' end);
end $$;

create or replace function public.consultar_empresa_pce(
 p_pergunta text,p_produto text default 'todos',p_atividade text default 'todos',
 p_publico text default 'empresa',p_data date default current_date,p_limite integer default 10
) returns jsonb language plpgsql stable security invoker set search_path=public,pg_temp as $$
declare direta jsonb;
begin
 direta:=public.consultar_referencia_pce(p_pergunta,p_data);
 if direta is not null then return direta; end if;
 return public.consultar_empresa_pce_v3(p_pergunta,p_produto,p_atividade,p_publico,p_data,p_limite);
end $$;
revoke execute on function public.consultar_referencia_pce(text,date) from public;
grant execute on function public.consultar_referencia_pce(text,date) to anon,authenticated;
revoke execute on function public.consultar_empresa_pce_v3(text,text,text,text,date,integer) from public;
grant execute on function public.consultar_empresa_pce_v3(text,text,text,text,date,integer) to anon,authenticated;
notify pgrst,'reload schema';
