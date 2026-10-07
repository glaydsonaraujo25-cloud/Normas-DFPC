-- Estrutura de dispositivos literais, vigência por dispositivo e testes de regressão.

create table if not exists public.dispositivos (
  id uuid primary key default gen_random_uuid(),
  norma_id uuid not null references public.normas(id) on delete cascade,
  documento_id uuid references public.documentos(id) on delete set null,
  referencia text not null,
  artigo text,
  paragrafo text,
  inciso text,
  alinea text,
  item text,
  texto_literal text not null,
  pagina integer,
  status text not null default 'vigente' check (status in ('vigente','alterado','revogado','suspenso','vigencia_futura','vigencia_a_confirmar')),
  vigencia_inicio date,
  vigencia_fim date,
  norma_alteradora_id uuid references public.normas(id) on delete set null,
  observacao_vigencia text,
  fonte_tipo text not null default 'pdf_oficial',
  conferido boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (norma_id, referencia)
);

create index if not exists dispositivos_norma_idx on public.dispositivos(norma_id);
create index if not exists dispositivos_status_idx on public.dispositivos(status);
create index if not exists dispositivos_referencia_trgm_idx on public.dispositivos using gin (referencia gin_trgm_ops);

alter table public.dispositivos enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='dispositivos' and policyname='public read dispositivos') then
    create policy "public read dispositivos" on public.dispositivos for select to public using (true);
  end if;
end $$;

alter table public.trechos add column if not exists dispositivo_id uuid references public.dispositivos(id) on delete set null;
create index if not exists trechos_dispositivo_idx on public.trechos(dispositivo_id);

create table if not exists public.casos_regressao_busca (
  id bigserial primary key,
  nome text not null unique,
  pergunta text not null,
  usar_busca_composta boolean not null default false,
  titulo_esperado_like text not null,
  dispositivo_esperado_like text,
  top_n integer not null default 1 check (top_n between 1 and 10),
  ativo boolean not null default true,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.casos_regressao_busca enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='casos_regressao_busca' and policyname='public read regressao') then
    create policy "public read regressao" on public.casos_regressao_busca for select to public using (true);
  end if;
end $$;

create or replace function public.executar_regressao_busca()
returns table(caso_id bigint,nome text,pergunta text,aprovado boolean,posicao_encontrada integer,titulo_encontrado text,dispositivo_encontrado text,esperado text)
language plpgsql stable set search_path=public,pg_temp as $$
declare c record; r record; pos integer; achou boolean;
begin
  for c in select * from public.casos_regressao_busca where ativo order by id loop
    pos:=0; achou:=false;
    if c.usar_busca_composta then
      for r in select x.titulo,x.dispositivo from public.consultar_base_normativa_composta(c.pergunta,greatest(c.top_n,5)) x loop
        pos:=pos+1;
        if lower(r.titulo) like lower(c.titulo_esperado_like) and (c.dispositivo_esperado_like is null or lower(coalesce(r.dispositivo,'')) like lower(c.dispositivo_esperado_like)) then
          achou:=true; caso_id:=c.id; nome:=c.nome; pergunta:=c.pergunta; aprovado:=pos<=c.top_n; posicao_encontrada:=pos; titulo_encontrado:=r.titulo; dispositivo_encontrado:=r.dispositivo; esperado:=c.titulo_esperado_like||coalesce(' / '||c.dispositivo_esperado_like,''); return next; exit;
        end if;
      end loop;
    else
      for r in select x.titulo,x.dispositivo from public.consultar_base_normativa(c.pergunta,greatest(c.top_n,5)) x loop
        pos:=pos+1;
        if lower(r.titulo) like lower(c.titulo_esperado_like) and (c.dispositivo_esperado_like is null or lower(coalesce(r.dispositivo,'')) like lower(c.dispositivo_esperado_like)) then
          achou:=true; caso_id:=c.id; nome:=c.nome; pergunta:=c.pergunta; aprovado:=pos<=c.top_n; posicao_encontrada:=pos; titulo_encontrado:=r.titulo; dispositivo_encontrado:=r.dispositivo; esperado:=c.titulo_esperado_like||coalesce(' / '||c.dispositivo_esperado_like,''); return next; exit;
        end if;
      end loop;
    end if;
    if not achou then caso_id:=c.id; nome:=c.nome; pergunta:=c.pergunta; aprovado:=false; posicao_encontrada:=null; titulo_encontrado:=null; dispositivo_encontrado:=null; esperado:=c.titulo_esperado_like||coalesce(' / '||c.dispositivo_esperado_like,''); return next; end if;
  end loop;
end $$;

grant execute on function public.executar_regressao_busca() to anon, authenticated;

insert into public.casos_regressao_busca (nome,pergunta,usar_busca_composta,titulo_esperado_like,dispositivo_esperado_like,top_n,observacoes) values
('definicao_pce','o que é PCE?',false,'%10.030%','%arts. 2%4%',1,'Definição central de PCE.'),
('nivel3_armas','quantas armas um atirador nível 3 pode ter?',false,'%11.615%','%35%37%',2,'Limites por nível.'),
('gt_cac','guia de tráfego para CAC',false,'%166%','%38%40%',3,'GTE de CAC.'),
('transferencia_sinarm_sigma','quais documentos preciso para transferir arma do SINARM para SIGMA?',true,'%167%','%transfer%',3,'Transferência entre sistemas.'),
('explosivos_sicoex','como adquirir e transportar explosivos pelo SICOEX?',true,'%147%',null,2,'Aquisição e tráfego de explosivos.'),
('marcacao_importada','quais marcações uma arma importada precisa ter?',false,'%213%','%4%6%',2,'Marcação obrigatória.'),
('seguranca_privada_mpo','empresa de segurança privada pode comprar munição calibre 12 de menor potencial ofensivo?',true,'%291%','%art. 2%',2,'Segurança privada.'),
('risco_pce_cnae','qual o nível de risco de atividade econômica com PCE e CNAE?',true,'%800%','%anexo%',2,'Classificação de risco.')
on conflict (nome) do update set pergunta=excluded.pergunta,usar_busca_composta=excluded.usar_busca_composta,titulo_esperado_like=excluded.titulo_esperado_like,dispositivo_esperado_like=excluded.dispositivo_esperado_like,top_n=excluded.top_n,observacoes=excluded.observacoes,updated_at=now();

create or replace view public.v_dispositivos_ativos as
select d.*,n.titulo,n.tipo,n.numero,n.ano,n.status as status_norma,n.usar_como_fundamento
from public.dispositivos d join public.normas n on n.id=d.norma_id
where d.status in ('vigente','alterado') and n.usar_como_fundamento=true and n.status not in ('revogada','superada_materialmente','vigencia_a_confirmar','ato_alterador');

grant select on public.v_dispositivos_ativos to anon, authenticated;

create or replace view public.v_cobertura_dispositivos as
select n.id as norma_id,n.titulo,n.status as status_norma,n.usar_como_fundamento,
       count(d.id)::int as dispositivos_literais,
       count(d.id) filter(where d.conferido)::int as dispositivos_conferidos,
       count(d.id) filter(where d.status='vigente')::int as dispositivos_vigentes,
       count(d.id) filter(where d.status in ('alterado','revogado','suspenso','vigencia_futura','vigencia_a_confirmar'))::int as dispositivos_com_atencao,
       case when count(d.id)=0 then 'sem_texto_literal' when count(d.id) filter(where d.conferido)<count(d.id) then 'revisao_pendente' else 'ok' end as situacao_cobertura
from public.normas n left join public.dispositivos d on d.norma_id=n.id
where n.usar_como_fundamento=true and n.status in ('vigente','vigente_com_alteracoes','parcialmente_vigente')
group by n.id,n.titulo,n.status,n.usar_como_fundamento;

grant select on public.v_cobertura_dispositivos to anon, authenticated;

create or replace function public.consultar_dispositivos_norma(p_norma_id uuid)
returns table(dispositivo_id uuid,referencia text,artigo text,paragrafo text,inciso text,alinea text,item text,texto_literal text,pagina integer,status text,vigencia_inicio date,vigencia_fim date,norma_alteradora text,observacao_vigencia text,conferido boolean)
language sql stable set search_path=public,pg_temp as $$
select d.id,d.referencia,d.artigo,d.paragrafo,d.inciso,d.alinea,d.item,d.texto_literal,d.pagina,d.status,d.vigencia_inicio,d.vigencia_fim,na.titulo,d.observacao_vigencia,d.conferido
from public.dispositivos d left join public.normas na on na.id=d.norma_alteradora_id
where d.norma_id=p_norma_id
order by nullif(regexp_replace(coalesce(d.artigo,''),'[^0-9]','','g'),'')::int nulls last,d.referencia;
$$;

grant execute on function public.consultar_dispositivos_norma(uuid) to anon, authenticated;

-- A carga inicial de texto literal é feita de forma incremental e somente após conferência com os PDFs oficiais/consolidados.
