-- Execute após as migrações. Verifica o acesso público sem alterar dados.
begin;
set local role anon;
do $teste$
declare q text; r jsonb; f jsonb;
begin
 for q in select jsonb_array_elements_text($perguntas$["O que é PCE?","Quantas armas um atirador nível 3 pode ter?","Quais os limites de munição para CAC?","Como funciona a Guia de Tráfego para CAC?","Militar do Exército pode portar arma de fogo?","Soldado do Exército pode ter porte de arma?","Soldado temporário tem porte automático?","Militar sem porte pode transportar arma?","Policial militar pode adquirir arma de uso restrito?","Quais documentos um policial militar precisa para adquirir arma?","Como transferir uma arma do SINARM para o SIGMA?","Como transferir uma arma do SIGMA para o SINARM?","O que é o SICOEX?","Como adquirir explosivos pelo SICOEX?","Como funciona o tráfego de explosivos?","Quais marcações uma arma importada precisa ter?","Quando uma arma pode ser remarcada?","Como funciona a importação de PCE?","O que são LPCO e DUIMP na importação de PCE?","Empresa de segurança privada pode adquirir munição calibre 12?","Quais PCE de menor potencial ofensivo podem ser adquiridos por empresa de segurança privada?","Qual o nível de risco de atividade econômica com PCE?","Como funciona a classificação por CNAE para atividade com PCE?","O que é o SisFPC?","Quem fiscaliza produtos controlados pelo Exército?","O que é TFPC e quem precisa pagar?","Quem é isento da TFPC?","Atirador pode comprar equipamento de recarga?","Quantos equipamentos de recarga um atirador pode ter?","Quais regras existem para colete balístico?","Como funciona o SICOVAB?","CAC pode portar arma carregada fora do trajeto autorizado?","Qual a diferença entre porte e transporte de arma?","A Portaria 167/2024 está vigente?","A Portaria 166/2023 foi alterada?","O que a Portaria 260/2025 alterou?","O que a Portaria 225/2024 alterou?","O Decreto 9.847/2019 ainda está vigente?","Quais artigos do Decreto 9.847/2019 foram revogados?","O que mudou na Portaria 167/2024?","Qual é a redação atual do art. 2º da Portaria 167/2024?","A Portaria 56/2017 foi alterada por quais normas?","O que mudou na Portaria Conjunta 2/2023?","Uma norma revogada ainda pode ser usada como fundamento?","Se uma portaria foi alterada, qual redação vale hoje?","A ITA 25/2022 ainda pode ser usada para importação?"]$perguntas$::jsonb) loop
  r:=public.consultar_publico_pce(q);
  if not (jsonb_array_length(coalesce(r->'orientacoes','[]'))>0 or jsonb_array_length(coalesce(r->'historico_normativo','[]'))>0 or r ? 'metodologia' or jsonb_array_length(coalesce(r->'esclarecimentos','[]'))>0) then raise exception 'Sem resposta: %',q; end if;
  for f in select jsonb_array_elements(r->'fontes') loop
   if not (f->>'literal_conferido')::boolean or f->>'status_dispositivo' not in ('vigente','alterado') or f->>'status' not in ('vigente','vigente_com_alteracoes','parcialmente_vigente') then raise exception 'Fonte inválida: %',q; end if;
  end loop;
 end loop;
 r:=public.consultar_publico_pce('Soldado temporário tem porte automático?',p_publico=>'policial');
 if jsonb_array_length(r->'orientacoes')<>0 then raise exception 'Mistura de públicos'; end if;
 r:=public.consultar_publico_pce('Qual é a redação atual do art. 2º da Portaria 167/2024?');
 if not r ? 'esclarecimentos' then raise exception 'Artigo ambíguo'; end if;
 r:=public.consultar_publico_pce('O Decreto 9.847/2019 ainda está vigente?');
 if r#>>'{historico_normativo,0,status}'<>'parcialmente_vigente' then raise exception 'Revogação parcial perdida'; end if;
end $teste$;
rollback;
