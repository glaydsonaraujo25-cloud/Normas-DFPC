-- Contrato da RPC empresarial: variações, condições específicas e complementos.
with casos(q,modelo) as (values
 ('O que significa PCE?',true),
 ('Preciso de CR para vender produtos químicos?',true),
 ('Como incluir nova atividade no CR?',true),
 ('Empresa de segurança privada pode comprar produtos de menor potencial ofensivo?',true),
 ('Qual o prazo para apostilar uma atividade?',false),
 ('Minha empresa é dispensada de registro para vender químicos?',false),
 ('O que é PCE e como transportar?',false),
 ('Empresa de segurança privada pode comprar munição calibre 12 de menor potencial ofensivo?',false)
), respostas as (
 select q,modelo,consultar_empresa_pce(q,'todos','todos','empresa',current_date,10) r from casos
)
select q, (r->>'pergunta_interpretada' is not null)=modelo as interpretacao_correta,
 not exists(select 1 from jsonb_array_elements(r->'fontes') f where f->>'status_dispositivo' not in ('vigente','alterado') or not (f->>'literal_conferido')::boolean) as fontes_validas,
 (select count(distinct f->>'dispositivo_id') from jsonb_array_elements(r->'fontes') f)=jsonb_array_length(r->'fontes') as sem_duplicatas
from respostas;
