-- Aplicada em produção em 06/10/2026.
-- Busca exata por caput, parágrafo, inciso, alínea e item.
-- Também corrige a extração de ano para não confundir o número 11.615 com 1161.

insert into public.trechos (norma_id, documento_id, pagina, dispositivo, conteudo, metadata)
select n.id, d.id, 7, 'Normas, art. 4º, caput',
'A aquisição de armas de fogo de porte ou portáteis, de uso permitido ou restrito, no comércio ou na indústria, por militares do Exército, segue o procedimento estabelecido no art. 4º.',
jsonb_build_object('origem','curadoria normativa','tipo','sintese_fiel','granularidade','caput')
from public.normas n left join public.documentos d on d.norma_id=n.id
where n.titulo='Portaria nº 164 COLOG/C Ex, de dezembro de 2023'
and not exists (select 1 from public.trechos t where t.norma_id=n.id and t.dispositivo='Normas, art. 4º, caput');

insert into public.trechos (norma_id, documento_id, pagina, dispositivo, conteudo, metadata)
select n.id, d.id, 7, x.dispositivo, x.conteudo, jsonb_build_object('origem','curadoria normativa','tipo','sintese_fiel','granularidade','item')
from public.normas n left join public.documentos d on d.norma_id=n.id
cross join (values
('Normas, art. 4º, inciso I, alínea b, item 1','O requerimento para aquisição deve conter cópia da identidade militar do adquirente.'),
('Normas, art. 4º, inciso I, alínea b, item 2','O requerimento para aquisição deve conter laudo de aptidão psicológica para manuseio de arma de fogo para militares inativos, exceto os militares em PTTC.'),
('Normas, art. 4º, inciso I, alínea b, item 3','O requerimento para aquisição deve conter comprovante do pagamento da taxa de aquisição de Produto Controlado pelo Exército (PCE).')) as x(dispositivo,conteudo)
where n.titulo='Portaria nº 164 COLOG/C Ex, de dezembro de 2023'
and not exists (select 1 from public.trechos t where t.norma_id=n.id and t.dispositivo=x.dispositivo);

insert into public.trechos (norma_id, documento_id, pagina, dispositivo, conteudo, metadata)
select n.id, d.id, 25, x.dispositivo, x.conteudo, jsonb_build_object('origem','curadoria normativa','tipo','sintese_fiel','granularidade','paragrafo')
from public.normas n left join public.documentos d on d.norma_id=n.id
cross join (values
('Art. 37, § 3º','O Comando do Exército poderá autorizar, em caráter excepcional, a aquisição de até quatro armas de fogo de uso restrito e de até seis mil unidades dos respectivos cartuchos por ano para atiradores de nível 3, nos limites estritamente necessários ao desporto.'),
('Art. 37, § 4º','A autorização excepcional prevista no § 3º não se aplica às armas de que trata o inciso I do caput do art. 12.'),
('Art. 37, § 5º','Para atiradores de nível 3, mediante comprovação de necessidade ligada a treinamento ou competição, o Comando do Exército poderá autorizar motivadamente aquisição de armas de uso permitido e munições acima dos limites do art. 36 e do art. 37.')) as x(dispositivo,conteudo)
where n.titulo='Decreto nº 11.615, de 21 de julho de 2023'
and not exists (select 1 from public.trechos t where t.norma_id=n.id and t.dispositivo=x.dispositivo);

-- A função consultar_base_normativa foi ajustada em produção para reconhecer e priorizar
-- caput, parágrafo, parágrafo único, inciso, alínea e item, além de incluir diretamente
-- trechos da norma/artigo citados quando o FTS não os recupera.
