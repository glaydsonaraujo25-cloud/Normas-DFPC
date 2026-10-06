create extension if not exists pg_trgm;

create table if not exists public.sinonimos_busca (
  termo text primary key,
  expansao text not null,
  ativo boolean not null default true,
  observacao text,
  atualizado_em timestamptz not null default now()
);

alter table public.sinonimos_busca enable row level security;

drop policy if exists "sinonimos leitura publica" on public.sinonimos_busca;
create policy "sinonimos leitura publica" on public.sinonimos_busca
  for select using (ativo = true);

insert into public.sinonimos_busca (termo, expansao, observacao) values
('pce','produto controlado exercito produtos controlados pelo exército','Sigla principal de Produtos Controlados pelo Exército'),
('gt','guia de trafego guia de tráfego porte de trânsito','Guia de Tráfego'),
('gte','guia de trafego especial guia de tráfego especial porte de trânsito','Guia de Tráfego Especial'),
('cr','certificado de registro registro de pessoa física pessoa jurídica','Certificado de Registro'),
('craf','certificado de registro de arma de fogo registro arma','Certificado de Registro de Arma de Fogo'),
('cac','colecionador atirador cacador caçador tiro desportivo coleção caça','Colecionador, Atirador e Caçador'),
('epbi','equipamento de protecao balistica individual equipamento de proteção balística individual colete balístico','Equipamento de Proteção Balística Individual'),
('sicovab','sistema de controle de veiculos automotores blindados blindagem veículo blindado','Sistema de controle de blindagens'),
('sicoex','sistema de controle de explosivos explosivos','Sistema de controle de explosivos'),
('iis','identificador individual seriado rastreabilidade','Identificador Individual Seriado'),
('lpco','licencas permissoes certificados outros documentos comércio exterior siscomex importação exportação','LPCO no Portal Único Siscomex'),
('duimp','declaracao unica de importacao declaração única de importação siscomex','DUIMP'),
('sisfpc','sistema de fiscalizacao de produtos controlados sistema de fiscalização de produtos controlados dfpc sfpc','Sistema de Fiscalização de Produtos Controlados'),
('sigma','sistema de gerenciamento militar de armas cadastro arma','SIGMA'),
('sinarm','sistema nacional de armas polícia federal cadastro arma','SINARM')
on conflict (termo) do update set
  expansao = excluded.expansao,
  observacao = excluded.observacao,
  ativo = true,
  atualizado_em = now();

create index if not exists normas_titulo_trgm_idx
  on public.normas using gin (lower(titulo) gin_trgm_ops);
create index if not exists normas_assunto_trgm_idx
  on public.normas using gin (lower(coalesce(assunto,'')) gin_trgm_ops);
create index if not exists trechos_dispositivo_trgm_idx
  on public.trechos using gin (lower(coalesce(dispositivo,'')) gin_trgm_ops);

-- A função consultar_base_normativa em produção usa estes sinônimos e
-- word_similarity (pg_trgm) em conjunto com FTS. Mantemos o dicionário
-- separado da função para permitir novas siglas sem alterar o frontend.
