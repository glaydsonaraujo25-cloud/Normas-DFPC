create or replace view public.auditoria_cobertura_normativa as
select
  n.id as norma_id,
  n.titulo,
  n.tipo,
  n.numero,
  n.ano,
  n.status,
  n.usar_como_fundamento,
  n.ultima_verificacao,
  count(distinct t.id)::integer as total_trechos,
  count(distinct rn.id)::integer as total_relacoes,
  case
    when n.usar_como_fundamento = true and count(distinct t.id) = 0 then 'sem_trechos'
    when n.usar_como_fundamento = true and count(distinct t.id) < 3 then 'cobertura_baixa'
    when n.ultima_verificacao is null then 'sem_verificacao'
    when n.ultima_verificacao < current_date - 180 then 'verificacao_antiga'
    else 'ok'
  end as situacao_auditoria
from public.normas n
left join public.trechos t on t.norma_id = n.id
left join public.relacoes_normativas rn on rn.norma_origem_id = n.id or rn.norma_destino_id = n.id
group by n.id,n.titulo,n.tipo,n.numero,n.ano,n.status,n.usar_como_fundamento,n.ultima_verificacao;

comment on view public.auditoria_cobertura_normativa is
'Auditoria de manutenção da base: identifica normas aptas sem trechos, cobertura baixa e verificação de vigência ausente ou antiga.';
