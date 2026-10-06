-- Melhora consultas por subdispositivos (parágrafo, inciso e alínea)
-- e adiciona trechos granulares das normas mais usadas.

create or replace function public.pontuacao_referencia_especifica(
  p_dispositivo text,
  p_conteudo text,
  p_consulta text
)
returns real
language sql
immutable
set search_path = public, pg_temp
as $$
with x as (
  select lower(coalesce(p_dispositivo,'') || ' ' || coalesce(p_conteudo,'')) alvo,
         lower(coalesce(p_consulta,'')) q
), refs as (
  select alvo,q,
    (regexp_match(q, '(§|par[aá]grafo)\s*(único|[0-9]+)'))[2] paragrafo_ref,
    (regexp_match(q, 'inciso\s+([ivxlcdm]+|[0-9]+)'))[1] inciso_ref,
    (regexp_match(q, 'al[ií]nea\s*["''“”]?([a-z])'))[1] alinea_ref
  from x
)
select (
  case
    when paragrafo_ref = 'único' and alvo ~ '(par[aá]grafo\s+único|§\s*único)' then 6.5
    when paragrafo_ref ~ '^[0-9]+$' and alvo ~ ('(§|par[aá]grafo)\s*' || paragrafo_ref || '([º°o ]|[^0-9]|$)') then 6.5
    else 0 end
  + case
    when inciso_ref is not null and alvo ~ ('incisos?[^.;:]{0,40}\m' || inciso_ref || '\M') then 5.5
    when inciso_ref is not null and lower(coalesce(p_dispositivo,'')) ~ ('\m' || inciso_ref || '\M') then 4.0
    else 0 end
  + case
    when alinea_ref is not null and alvo ~ ('al[ií]nea\s*["''“”]?' || alinea_ref || '\M') then 5.5
    when alinea_ref is not null and alvo ~ ('(^|[;,.:( ]+)' || alinea_ref || '\)') then 3.2
    else 0 end
)::real
from refs;
$$;

-- Trechos granulares. Mantidos como síntese fiel e idempotentes por norma+dispositivo.
with alvo as (
  select n.id norma_id,d.id documento_id,n.titulo
  from public.normas n left join public.documentos d on d.norma_id=n.id
  where n.titulo in (
    'Portaria nº 164 COLOG/C Ex, de dezembro de 2023',
    'Portaria C Ex nº 1.757, de 31 de maio de 2022',
    'Decreto nº 11.615, de 21 de julho de 2023'
  )
), novos(titulo,dispositivo,conteudo,pagina) as (values
('Portaria nº 164 COLOG/C Ex, de dezembro de 2023','Normas, art. 4º, inciso I, alínea a','A autorização para aquisição de arma de fogo depende do atendimento do limite previsto no art. 1º e é formalizada por despacho da OM de vinculação no próprio requerimento. Para militar inativo, a autorização é formalizada pela OM com encargo de SFPC escolhida pelo requerente, ressalvados os militares em PTTC, cuja OM de designação autoriza.',7),
('Portaria nº 164 COLOG/C Ex, de dezembro de 2023','Normas, art. 4º, inciso I, alínea b','O requerimento de aquisição deve ser instruído com cópia da identidade militar, laudo de aptidão psicológica para manuseio de arma de fogo para militares inativos, exceto PTTC, e comprovante de pagamento da taxa de aquisição de PCE.',7),
('Portaria nº 164 COLOG/C Ex, de dezembro de 2023','Normas, art. 4º, inciso I, alíneas c a f','As tratativas da compra e a nota fiscal ocorrem diretamente entre adquirente e fornecedor; o fabricante lança os dados no SICOFA; o comerciante encaminha ao Comando do Exército as informações da venda no prazo de 48 horas; e a autorização para aquisição tem validade de 180 dias.',7),
('Portaria nº 164 COLOG/C Ex, de dezembro de 2023','Normas, art. 4º, inciso II, alíneas a a c','O registro é publicado em documento oficial permanente da OM que autorizou a aquisição, mediante requerimento instruído com identidade militar, nota fiscal, requerimento de aquisição e ficha de cadastro no SIGMA. Após o registro, a OM solicita o cadastro da arma no SIGMA.',7),
('Portaria nº 164 COLOG/C Ex, de dezembro de 2023','Normas, art. 4º, inciso III, alíneas a e b','A arma somente pode ser entregue depois do cadastro no SIGMA e mediante apresentação do CRAF, acompanhada da guia de tráfego expedida pelo fornecedor. O recebimento do CRAF e da arma conclui o processo de aquisição.',8),
('Portaria nº 164 COLOG/C Ex, de dezembro de 2023','Normas, art. 4º, § 1º','Se o registro da arma for indeferido, cabe ao adquirente e ao fornecedor adotar as medidas administrativas necessárias ao distrato da compra.',8),
('Portaria nº 164 COLOG/C Ex, de dezembro de 2023','Normas, art. 4º, § 2º','As informações relativas à venda devem ser disponibilizadas no SICOFA. Enquanto a funcionalidade não estiver operacionalizada, as informações devem permanecer disponíveis para apresentação à fiscalização de produtos controlados, quando solicitadas, pelo prazo de dois anos.',8),
('Portaria nº 164 COLOG/C Ex, de dezembro de 2023','Normas, art. 4º, § 3º','O CRAF tem validade indeterminada para as categorias indicadas nos arts. 7º e 8º; para militares temporários, cabos, taifeiros ou soldados em serviço ativo ou na inatividade, a validade é de três anos.',8),
('Portaria C Ex nº 1.757, de 31 de maio de 2022','Art. 55, inciso VIII','Compete ao COLOG receber, por intermédio da DFPC, solicitações de aquisição e/ou importação de armas de fogo, munições e demais PCE de uso restrito, ressalvadas as exceções previstas, e verificar o alinhamento das solicitações com o planejamento estratégico aprovado para emissão de autorização.',12),
('Portaria C Ex nº 1.757, de 31 de maio de 2022','Art. 55, inciso IX','Compete ao COLOG emitir autorização ao órgão requerente e informar o fornecedor do PCE de uso restrito, por intermédio da DFPC, nas aquisições no mercado nacional, bem como anuir a licença de importação nas aquisições por importação.',12),
('Decreto nº 11.615, de 21 de julho de 2023','Art. 35, parágrafo único','Além dos requisitos de habitualidade previstos no caput, a progressão de nível do atirador desportivo depende da permanência por doze meses em cada nível.',24),
('Decreto nº 11.615, de 21 de julho de 2023','Art. 36, incisos I a III','Para aquisição de armas de fogo, o nível 1 pode adquirir até quatro armas de uso permitido; o nível 2, até oito de uso permitido; e o nível 3, até dezesseis armas, das quais até quatro podem ser de uso restrito e as demais de uso permitido.',24),
('Decreto nº 11.615, de 21 de julho de 2023','Art. 37, § 1º','As munições adquiridas pelo atirador desportivo devem corresponder às armas apostiladas em seu Certificado de Registro.',25),
('Decreto nº 11.615, de 21 de julho de 2023','Art. 37, § 2º','Quando o atirador informar que utiliza arma pertencente à entidade de tiro ou a outro atirador desportivo, o requerimento deve registrar o número de cadastro da arma e conter declaração do proprietário.',25),
('Decreto nº 11.615, de 21 de julho de 2023','Art. 37, §§ 3º a 5º','O Comando do Exército pode autorizar excepcionalmente, para atiradores de nível 3 e nos limites necessários ao desporto, aquisição de armas e munições em hipóteses e quantidades previstas na norma; a autorização do § 3º não se aplica às armas indicadas no § 4º e o § 5º admite autorização motivada acima dos limites ordinários mediante comprovação de necessidade.',25)
)
insert into public.trechos(norma_id,documento_id,pagina,dispositivo,conteudo,metadata)
select a.norma_id,a.documento_id,n.pagina,n.dispositivo,n.conteudo,
       jsonb_build_object('origem','curadoria_manual','tipo','sintese_fiel','granularidade','subdispositivo','data_curadoria','2026-10-06')
from novos n join alvo a using(titulo)
where not exists(select 1 from public.trechos t where t.norma_id=a.norma_id and lower(coalesce(t.dispositivo,''))=lower(n.dispositivo));

-- A função consultar_base_normativa em produção também inclui candidatos diretos da norma/artigo
-- antes do reranking, para que um subdispositivo exato não seja descartado pelo FTS inicial.
