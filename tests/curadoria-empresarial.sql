-- Executar em transação: nenhuma alteração de teste é persistida.
begin;
do $test$
declare g record; r jsonb; ref text;
begin
 for g in select * from public.orientacoes_empresariais where estado='publicada' loop
  r:=public.consultar_empresa_pce(g.pergunta_modelo,g.produto,g.atividade,'empresa','2026-10-08',12);
  if jsonb_array_length(r->'orientacoes')<>1 then raise exception 'Guia ausente: %',g.pergunta_modelo; end if;
  for ref in select jsonb_array_elements_text(s->'dispositivo_ids') from jsonb_array_elements(g.secoes) s loop
   if not exists(select 1 from jsonb_array_elements(r->'fontes') f where f->>'dispositivo_id'=ref) then raise exception 'Fundamento ausente'; end if;
  end loop;
 end loop;
 r:=public.consultar_empresa_pce('Como importar explosivos?','quimicos','exportacao','empresa','2026-10-08',12);
 if jsonb_array_length(r->'fontes')<>0 or r->>'aviso_referencia' is null then raise exception 'Conflito ignorado'; end if;
 r:=public.consultar_orientacao_pce('Qual a concentração dispensada para exportar produtos controlados?','todos','todos','empresa','2026-10-08');
 if r is not null then raise exception 'Caso específico virou orientação geral'; end if;
 if exists(select 1 from public.dispositivos where conferido and metadata->'conferencia_textual'->>'documento' is not null and documento_id is null) then raise exception 'PDF não vinculado'; end if;
 -- Uma orientação deve desaparecer se qualquer fundamento perde a conferência.
 update public.dispositivos set conferido=false where artigo='81' and norma_id=(select id from public.normas where titulo='Decreto nº 10.030, de 30 de setembro de 2019');
 if public.consultar_orientacao_pce('Quais regras gerais se aplicam ao transporte empresarial de PCE?','todos','todos','empresa','2026-10-08') is not null then raise exception 'Guia com fundamento pendente'; end if;
end $test$;
set local role anon;
select sum(textos_reconferidos) as textos_reconferidos from public.v_auditoria_textual;
rollback;
