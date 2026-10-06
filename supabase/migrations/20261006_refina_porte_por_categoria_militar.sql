-- Refinamento da consulta composta por categoria de militar.
-- Mantém o projeto sem OpenAI/embeddings externos.

-- Expande a granularidade da Portaria 164/2023 para porte e condições associadas.
insert into public.trechos (norma_id,pagina,dispositivo,conteudo,metadata)
select n.id,v.pagina,v.dispositivo,v.conteudo,jsonb_build_object('origem','curadoria manual','tipo','sintese_fiel','granularidade','subdispositivo')
from public.normas n
cross join (values
 (9,'Normas, art. 7º e parágrafo único — oficiais','Oficiais do Exército, em serviço ativo ou na inatividade, têm direito ao porte de arma de fogo na forma da Lei nº 6.880/1980. Para oficiais temporários, o direito ao porte limita-se ao prazo de convocação.'),
 (9,'Normas, art. 8º e parágrafo único — subtenentes e sargentos','Subtenentes e sargentos de carreira, ativos ou inativos, têm autorização para portar arma de fogo assegurada na forma da norma, observadas as restrições aplicáveis. Também são autorizados os sargentos oriundos das escolas de formação de sargentos ainda não estabilizados.'),
 (9,'Normas, art. 9º e §§ 1º a 3º — comprovação e inativos','A comprovação da autorização para porte é feita pela identificação militar e pelo CRAF da arma conduzida. Para oficiais temporários e sargentos não estabilizados, a autorização fica vinculada à validade da identidade militar. Militares inativos devem observar a avaliação psicológica periódica prevista na norma; para determinadas praças inativas, também é exigido parecer favorável da Região Militar.'),
 (10,'Normas, arts. 11 e 12 — abrangência e ostensividade','A autorização para portar arma de fogo tem abrangência em todo o território nacional. Se o militar transportar mais de uma arma simultaneamente, apenas uma arma de porte poderá estar municiada. A arma objeto da autorização não pode ser conduzida ou transportada ostensivamente.'),
 (10,'Normas, art. 13, incisos I a VI — impedimentos ao porte','Não será concedida autorização para portar arma de fogo a alunos em cursos ou estágios de formação, durante o Serviço Militar Inicial, a praças com comportamento insuficiente ou mau, a inaptos psicologicamente para manuseio de arma, a quem responda a inquérito ou processo criminal ou tenha condenação transitada em julgado por crime doloso, nem quando houver decisão judicial impeditiva.'),
 (10,'Normas, arts. 14 e 15 — taxas e alteração de situação','Militares são isentos do pagamento das taxas de registro e porte de arma de fogo e de suas renovações, na forma da Lei nº 10.826/2003. A mudança de Região Militar de vinculação ou a passagem da ativa para a inatividade não exige substituição do CRAF.'),
 (10,'Normas, arts. 16 e 17 — revogação do porte','A autorização para porte pode ser revogada pela autoridade competente da OM ou RM de vinculação mediante decisão motivada e publicada em Boletim Interno. A norma prevê hipóteses de revogação, entre elas situações impeditivas do art. 13, ocorrência envolvendo porte em estado de embriaguez ou sob efeito de substâncias, interdição ou falecimento e licenciamento de militar temporário.'),
 (11,'Normas, arts. 18 e 19 — CRAF após revogação e novo pedido','Revogado o porte, o CRAF com autorização para portar deve ser entregue à OM ou RM de vinculação para substituição por CRAF não válido como porte de arma. O militar poderá solicitar nova autorização quando voltar a atender às condições previstas nas normas.')
) as v(pagina,dispositivo,conteudo)
where n.titulo='Portaria nº 164 COLOG/C Ex, de dezembro de 2023'
  and not exists (select 1 from public.trechos t where t.norma_id=n.id and lower(t.dispositivo)=lower(v.dispositivo));

-- A busca bruta passa a reter mais candidatos da mesma norma, permitindo que
-- subdispositivos específicos não sejam descartados cedo demais.
do $$
declare ddl text;
begin
  select pg_get_functiondef('public.consultar_base_normativa_raw(text,integer)'::regprocedure) into ddl;
  ddl := replace(ddl, 'where d.pos_norma<=8', 'where d.pos_norma<=20');
  ddl := replace(ddl, 'where d.pos_norma<=3', 'where d.pos_norma<=20');
  execute ddl;
end $$;

-- A função consultar_base_normativa_composta foi atualizada no banco para
-- priorizar categorias militares específicas (oficial, ST/SGT de carreira,
-- sargento temporário/cabo/taifeiro/soldado e militar inativo) nas consultas
-- sobre porte, preservando o escopo material da Portaria 164/2023.
