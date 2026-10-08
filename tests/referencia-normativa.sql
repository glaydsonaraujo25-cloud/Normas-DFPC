-- Verifica isolamento de norma/seção/artigo e comportamento com lacunas.
with casos(q,esperado,esclarecer) as (values
 ('Art. 2º do Decreto 10.030',0,true),
 ('Art. 2º do Anexo I do Decreto 10.030',1,false),
 ('Art. 2º do Anexo 1 do Decreto 10.030',1,false),
 ('Art. 2º do corpo principal do Decreto 10.030',0,false),
 ('Art. 2º da Portaria 56 de 2017',2,false),
 ('Art. 2º § 1º da Portaria 56 de 2017',1,false),
 ('Art. 1º inciso V da Portaria 291 de 2026',1,false),
 ('Art. 3º da Portaria 118 de 1900 — corpo principal',0,false),
 ('Art. 9999 do Anexo I do Decreto 10030',0,false),
 ('Art. 81 do Anexo I do Decreto 10030',0,false),
 ('Art. 64 das normas reguladoras da Portaria 2566 de 2025',1,false),
 ('Arts. 98 e 99 do Anexo I do Decreto 10030',0,false)
), respostas as (select *,consultar_empresa_pce(q,'todos','todos','empresa',current_date,10) r from casos)
select q,jsonb_array_length(r->'fontes')=esperado as quantidade_correta,
 (coalesce(jsonb_array_length(r->'esclarecimentos'),0)>0)=esclarecer as esclarecimento_correto,
 (r->>'referencia_exata')::boolean as referencia_exata,
 not exists(select 1 from jsonb_array_elements(r->'fontes') f where not (f->>'literal_conferido')::boolean or f->>'status_dispositivo' not in ('vigente','alterado')) as fontes_validas
from respostas;
