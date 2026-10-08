-- Escopo das normas aprovadas e integridade das orientações com inferência automática.
begin;
do $test$
declare g record; r jsonb;
begin
 for g in select * from public.orientacoes_empresariais where estado='publicada' loop
  r:=public.consultar_empresa_pce(g.pergunta_modelo,'todos','todos','empresa','2026-10-08',12);
  if jsonb_array_length(r->'orientacoes')<>1 then raise exception 'Identificação automática falhou: %',g.pergunta_modelo; end if;
 end loop;
 r:=public.consultar_empresa_pce('Artigo 16 das normas aprovadas pela Portaria 213 de 2021');
 if jsonb_array_length(r->'fontes')<>1 then raise exception 'Registro de armas ausente'; end if;
 if r->'fontes'->0->>'dispositivo'<>'Normas, art. 16, caput e §§ 1º a 3º' then raise exception 'Escopo incorreto'; end if;
 r:=public.consultar_empresa_pce('Artigo 16 do corpo principal da Portaria 213 de 2021');
 if jsonb_array_length(r->'fontes')<>0 then raise exception 'Normas confundidas com corpo principal'; end if;
 r:=public.consultar_empresa_pce('Artigo 9 das normas aprovadas pela Portaria 214 de 2021');
 if jsonb_array_length(r->'fontes')<>1 or position('§4º' in (r->'fontes'->0->>'conteudo'))=0 then raise exception 'Texto de registros incompleto'; end if;
 if exists(select 1 from public.dispositivos d join public.normas n on n.id=d.norma_id where n.titulo='Portaria nº 213 COLOG/C Ex, de 15 de setembro de 2021' and d.referencia like 'Art.%') then raise exception 'Referência sem escopo'; end if;
end $test$;
set local role anon;
select count(*) orientacoes_publicadas from public.orientacoes_empresariais where estado='publicada';
rollback;
