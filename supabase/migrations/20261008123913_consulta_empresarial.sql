-- Consulta empresarial com filtros estruturados, citações exatas e curadoria.
alter table public.normas add column if not exists fonte_oficial text;
alter table public.normas add column if not exists produtos text[] not null default '{}';
alter table public.normas add column if not exists publicos text[] not null default '{}';
alter table public.normas add column if not exists atividades text[] not null default '{}';

-- Classificação inicial é indicativa; normas gerais continuam disponíveis.
update public.normas set
 produtos = array_remove(array[
 case when lower(assunto) ~ 'arma|calibre' then 'armas' end,
 case when lower(assunto) ~ 'muni[cç]' then 'municoes' end,
 case when lower(assunto) ~ 'explosiv|nitrato' then 'explosivos' end,
 case when lower(assunto) ~ 'qu[ií]mic' then 'quimicos' end,
 case when lower(assunto) ~ 'pirot[eé]cn|fogos' then 'pirotecnicos' end,
 case when lower(assunto) ~ 'blind|bal[ií]stic|sicovab' then 'blindagem' end,
 case when lower(assunto) ~ 'menos.letal|menor potencial' then 'menos_letais' end
 ],null),
 publicos = case
 when lower(assunto) ~ 'militares do ex[eé]rcito|for[cç]as armadas|modelos de craf|porte de arma.*militar' then array['militar']
 when lower(assunto) ~ 'colecionamento|tiro desportivo|ca[cç]a excepcional|recarga para tiro' then array['cac']
 else array['empresa','geral'] end,
 atividades = array_remove(array[
 case when lower(assunto) ~ 'registro|apostil|revalida' then 'registro' end,
 case when lower(assunto) ~ 'fabric|conformidade' then 'fabricacao' end,
 case when lower(assunto) ~ 'comerc|com[eé]rc' then 'comercio' end,
 case when lower(assunto) ~ 'aquisi' then 'aquisicao' end,
 case when lower(assunto) ~ 'tr[aá]fego|transporte' then 'transporte' end,
 case when lower(assunto) ~ 'armazen' then 'armazenagem' end,
 case when lower(assunto) ~ 'detona|emprego|presta[cç]' then 'utilizacao' end,
 case when lower(assunto) ~ 'importa|com[eé]rcio exterior' then 'importacao' end,
 case when lower(assunto) ~ 'exporta|com[eé]rcio exterior' then 'exportacao' end,
 case when lower(assunto) ~ 'fiscaliza|sancion|infra[cç]' then 'fiscalizacao' end
 ],null)
where cardinality(publicos)=0;

-- Nunca associar artigos por coincidência de números ou similaridade.
update public.trechos t set dispositivo_id=d.id
from public.dispositivos d
where t.dispositivo_id is null and t.norma_id=d.norma_id
 and lower(trim(t.dispositivo))=lower(trim(d.referencia));

create table if not exists public.revisores_normativos (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.revisores_normativos enable row level security;
create policy "revisor consulta propria permissao" on public.revisores_normativos
 for select to authenticated using ((select auth.uid())=user_id);
grant select on public.revisores_normativos to authenticated;
revoke all on public.revisores_normativos from anon;
revoke insert,update,delete on public.revisores_normativos from authenticated;

create table if not exists public.orientacoes_empresariais (
 id uuid primary key default gen_random_uuid(),
 titulo text not null check (length(titulo) between 3 and 200),
 produto text not null default 'todos', atividade text not null default 'todos',
 pergunta_modelo text not null check (length(pergunta_modelo) between 5 and 1000),
 secoes jsonb not null default '[]' check (jsonb_typeof(secoes)='array'),
 estado text not null default 'rascunho' check (estado in ('rascunho','publicada')),
 revisado_em date, updated_at timestamptz not null default now(),
 revisado_por uuid references auth.users(id)
);
alter table public.orientacoes_empresariais enable row level security;
create policy "orientacoes publicadas ou revisor" on public.orientacoes_empresariais
 for select to anon,authenticated using (estado='publicada' or exists(select 1 from public.revisores_normativos where user_id=(select auth.uid())));
create policy "revisor cria orientacao" on public.orientacoes_empresariais
 for insert to authenticated with check (exists(select 1 from public.revisores_normativos where user_id=(select auth.uid())));
create policy "revisor atualiza orientacao" on public.orientacoes_empresariais
 for update to authenticated using (exists(select 1 from public.revisores_normativos where user_id=(select auth.uid())))
 with check (exists(select 1 from public.revisores_normativos where user_id=(select auth.uid())));
grant select on public.orientacoes_empresariais to anon,authenticated;
grant insert,update on public.orientacoes_empresariais to authenticated;
revoke delete on public.orientacoes_empresariais from anon,authenticated;

create or replace function public.validar_orientacao_empresarial()
returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare secao jsonb; ref text;
begin
 new.updated_at=now();
 if jsonb_array_length(new.secoes)=0 and new.estado='publicada' then
  raise exception 'Adicione seções e fundamentos antes de publicar.';
 end if;
 for secao in select value from jsonb_array_elements(new.secoes) loop
  if coalesce(secao->>'titulo','')='' or coalesce(secao->>'texto','')='' or jsonb_typeof(secao->'dispositivo_ids') is distinct from 'array' then
   raise exception 'Cada seção exige título, texto e lista de dispositivos.';
  end if;
  if new.estado='publicada' and jsonb_array_length(secao->'dispositivo_ids')=0 then
   raise exception 'Toda orientação publicada exige citação.';
  end if;
  if new.estado='publicada' then
   for ref in select jsonb_array_elements_text(secao->'dispositivo_ids') loop
    if not exists (select 1 from dispositivos d join normas n on n.id=d.norma_id
     where d.id::text=ref and d.conferido and d.status in ('vigente','alterado')
      and n.usar_como_fundamento and n.status in ('vigente','vigente_com_alteracoes','parcialmente_vigente')
      and (d.vigencia_inicio is null or d.vigencia_inicio<=current_date)
      and (d.vigencia_fim is null or d.vigencia_fim>=current_date)
      and (n.vigencia_inicio is null or n.vigencia_inicio<=current_date)
      and (n.vigencia_fim is null or n.vigencia_fim>=current_date)) then
     raise exception 'Fundamento não conferido ou não aplicável: %',ref;
    end if;
   end loop;
  end if;
 end loop;
 new.revisado_por=auth.uid();
 new.revisado_em=case when new.estado='publicada' then current_date else null end;
 return new;
end $$;
create trigger validar_orientacao before insert or update on public.orientacoes_empresariais
 for each row execute function public.validar_orientacao_empresarial();
revoke execute on function public.validar_orientacao_empresarial() from public;

-- Leitura pública do corpus; edição somente por revisores autorizados.
do $$ declare nome text; view_nome text;
begin
 foreach nome in array array['alteracoes_dispositivos','vigencia_dispositivos'] loop
  execute format('alter table public.%I enable row level security',nome);
  execute format('create policy "leitura corpus empresarial" on public.%I for select to anon,authenticated using (true)',nome);
  execute format('grant select on public.%I to anon,authenticated',nome);
  execute format('revoke insert,update,delete on public.%I from anon,authenticated',nome);
 end loop;
 foreach view_nome in array array['auditoria_cobertura_normativa','v_cobertura_dispositivos','v_dispositivos_ativos','v_linha_tempo_normativa','v_mapa_vigencia_normativa','v_cobertura_alteradores','v_cobertura_literal'] loop
  execute format('alter view public.%I set (security_invoker=true)',view_nome);
 end loop;
end $$;
create policy "revisor atualiza norma" on public.normas for update to authenticated
 using (exists(select 1 from public.revisores_normativos where user_id=(select auth.uid())))
 with check (exists(select 1 from public.revisores_normativos where user_id=(select auth.uid())));
grant update on public.normas to authenticated;
revoke insert,delete on public.normas from anon,authenticated;

create or replace function public.consultar_empresa_pce(
 p_pergunta text, p_produto text default 'todos', p_atividade text default 'todos',
 p_publico text default 'empresa', p_data date default current_date, p_limite integer default 10
) returns jsonb language sql stable security invoker set search_path=public,pg_temp as $$
with entrada as (
 select left(trim(coalesce(p_pergunta,'')),2000) q,
 websearch_to_tsquery('portuguese',left(trim(coalesce(p_pergunta,'')),2000)) tsq,
 plainto_tsquery('portuguese',coalesce((select string_agg(s.expansao,' ') from sinonimos_busca s
 where s.ativo and lower(p_pergunta) like '%'||lower(s.termo)||'%'),'')) sinonimos
), raw as materialized (
 select * from consultar_base_normativa_raw((select q from entrada),150)
), candidatos as (
 select t.id,t.norma_id,t.documento_id,t.dispositivo_id,t.pagina,t.dispositivo,t.conteudo,t.metadata,
 (coalesce(r.relevancia,0)+ts_rank_cd(t.fts,e.tsq)*8+
 case when t.fts @@ e.tsq then 3 else 0 end+
 case when p_produto=any(n.produtos) then 2 else 0 end+
 case when p_atividade=any(n.atividades) then 1 else 0 end)::real score
 from trechos t join normas n on n.id=t.norma_id cross join entrada e
 left join raw r on r.trecho_id=t.id
 where length(e.q)>=3
 and (t.fts @@ e.tsq or t.fts @@ e.sinonimos or coalesce(r.relevancia,0)>0 or word_similarity(lower(e.q),lower(t.conteudo))>0.28)
 and (p_publico='todos' or n.publicos && array['empresa','geral'])
 and (p_produto='todos' or p_produto=any(n.produtos) or cardinality(n.produtos)=0)
 and (p_atividade='todos' or p_atividade=any(n.atividades) or cardinality(n.atividades)=0
   or lower(t.conteudo) ~ case p_atividade
    when 'registro' then 'registro|apostil|revalid' when 'fabricacao' then 'fabric|conformidade'
    when 'comercio' then 'comerci|vend' when 'aquisicao' then 'aquisi|adquir|compr'
    when 'transporte' then 'transport|tr[aá]fego' when 'armazenagem' then 'armazen'
    when 'utilizacao' then 'utiliz|emprego|detona|presta[cç]' when 'importacao' then 'import'
    when 'exportacao' then 'export' when 'fiscalizacao' then 'fiscaliz|sancion|infra[cç]' else 'a^' end)
), enriquecidos as (
 select c.*,n.titulo,n.status,n.ultima_verificacao,n.fonte_oficial,n.usar_como_fundamento,
 d.id did,d.texto_literal,d.status ds,d.conferido,d.vigencia_inicio,d.vigencia_fim,
 doc.nome_arquivo,doc.sha256,
 (n.usar_como_fundamento and n.status in ('vigente','vigente_com_alteracoes','parcialmente_vigente')
 and d.id is not null and d.conferido and d.status in ('vigente','alterado')
 and (d.vigencia_inicio is null or d.vigencia_inicio<=p_data)
 and (d.vigencia_fim is null or d.vigencia_fim>=p_data)
 and (n.vigencia_inicio is null or n.vigencia_inicio<=p_data)
 and (n.vigencia_fim is null or n.vigencia_fim>=p_data)) seguro
 from candidatos c join normas n on n.id=c.norma_id
 left join dispositivos d on d.id=c.dispositivo_id and d.norma_id=c.norma_id
 left join documentos doc on doc.id=coalesce(d.documento_id,c.documento_id)
), ordenados as (
 select e.*,row_number() over(partition by norma_id order by score desc,id) pos
 from enriquecidos e where seguro
), selecionados as (
 select * from ordenados where pos<=3 order by score desc,id limit least(greatest(p_limite,1),20)
), fontes as (
 select coalesce(jsonb_agg(jsonb_build_object(
 'trecho_id',s.id,'norma_id',s.norma_id,'titulo',s.titulo,'dispositivo',s.dispositivo,
 'conteudo',s.conteudo,'pagina',s.pagina,'relevancia',s.score,'status',s.status,
 'ultima_verificacao',s.ultima_verificacao,'dispositivo_id',s.did,'texto_literal',s.texto_literal,
 'status_dispositivo',s.ds,'literal_conferido',s.conferido,'vigencia_inicio',s.vigencia_inicio,'vigencia_fim',s.vigencia_fim,
 'fonte_oficial',s.fonte_oficial,'nome_arquivo',s.nome_arquivo,'sha256',s.sha256,
 'tipo_conteudo',coalesce(s.metadata->>'tipo','trecho_cadastrado'),
 'relacoes',coalesce((select jsonb_agg(jsonb_build_object('tipo',r.tipo,'norma_relacionada',n.titulo,'dispositivo',r.dispositivo,'observacoes',r.observacoes))
 from relacoes_normativas r join normas n on n.id=r.norma_destino_id where r.norma_origem_id=s.norma_id),'[]'::jsonb)
 ) order by s.score desc,s.id),'[]'::jsonb) itens from selecionados s
), guias as (
 select coalesce(jsonb_agg(to_jsonb(o)),'[]'::jsonb) itens from orientacoes_empresariais o cross join entrada e
 where o.estado='publicada' and (o.produto='todos' or o.produto=p_produto)
 and (o.atividade='todos' or o.atividade=p_atividade)
 and lower(trim(o.pergunta_modelo))=lower(trim(e.q))
 and not exists (select 1 from jsonb_array_elements(o.secoes) secao,
 jsonb_array_elements_text(secao->'dispositivo_ids') ref
 where not exists(select 1 from selecionados s where s.did::text=ref))
)
select jsonb_build_object('fontes',(select itens from fontes),'orientacoes',(select itens from guias),
 'data_referencia',p_data,'versao','empresas-v1-2026-10-08',
 'fontes_excluidas',(select count(*) from enriquecidos where not coalesce(seguro,false)));
$$;
revoke execute on function public.consultar_empresa_pce(text,text,text,text,date,integer) from public;
grant execute on function public.consultar_empresa_pce(text,text,text,text,date,integer) to anon,authenticated;

create or replace view public.v_revisao_empresarial with (security_invoker=true) as
 select n.id,n.titulo,n.status,n.ultima_verificacao,n.fonte_oficial,n.produtos,n.atividades,
 count(distinct t.id)::int trechos,
 count(distinct t.id) filter(where t.dispositivo_id is not null)::int vinculados,
 count(distinct d.id)::int dispositivos,
 count(distinct d.id) filter(where d.conferido and d.status in ('vigente','alterado'))::int conferidos
 from normas n left join trechos t on t.norma_id=n.id left join dispositivos d on d.norma_id=n.id
 group by n.id;
grant select on public.v_revisao_empresarial to anon,authenticated;

notify pgrst,'reload schema';
