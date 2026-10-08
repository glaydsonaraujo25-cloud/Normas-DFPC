# Operação e curadoria empresarial

## Fluxo de consulta

1. Identificar produto e atividade. Não concluir dispensa de controle apenas porque não há resultado.
2. Consultar `consultar_empresa_pce` com pergunta e filtros separados; filtros não viram palavras artificiais na pergunta.
3. Recuperar dispositivos conferidos e aptos na data da consulta. A pesquisa usa a entidade dispositivo, sem aproximar números de artigos.
4. Exibir orientação revisada quando existir pergunta modelo correspondente e todos os fundamentos estiverem presentes e aplicáveis.
5. Caso contrário, exibir os fundamentos e as condições encontradas como consulta documental, sem alegar conclusão validada.
6. Preservar a versão da consulta no histórico/exportação. Para atualização, executar nova consulta.

## Provisionar um revisor

Não existiam contas no Supabase Auth durante a implantação inicial. O proprietário deve criar/convidar a conta pelo painel **Authentication / Users**, com o e-mail correto e o fluxo de definição de senha do Supabase. Não divulgar credenciais no repositório.

Após a conta existir, o proprietário autoriza seu UUID no SQL Editor:

```sql
insert into public.revisores_normativos (user_id)
select id from auth.users where id = '<UUID DA CONTA AUTORIZADA>'::uuid
on conflict do nothing;
```

O frontend não possui acesso para inserir nessa tabela. O revisor entra na aba Revisão, usando e-mail e senha, para revisar fontes e editar orientações. Para revogar sua permissão, remover somente esse UUID da tabela no painel administrativo.

## Publicar uma orientação

- Cadastrar produto e atividade, pergunta modelo e seções de resposta, condições, documentos e procedimento, conforme houver suporte.
- Cada seção deve citar os IDs exatos dos dispositivos conferidos.
- O banco valida a presença dos fundamentos e a vigência na publicação. A consulta repete a validação; uma orientação deixa de aparecer quando o fundamento perde aplicabilidade.
- Não afirmar que todos os documentos/requisitos foram identificados se o corpus for parcial.
- Salvar como rascunho antes da revisão. Para retirar uma orientação publicada, abri-la e salvar como rascunho.
- A data da conferência de uma norma deve ser atualizada apenas após a verificação efetiva; o cadastro de um link não comprova vigência.

## Segurança

- Normas e documentos públicos têm acesso somente de leitura para o público.
- Tabelas de alterações e vigência usam RLS; views usam `security_invoker=true`.
- Alterações editoriais exigem permissão na tabela `revisores_normativos`.
- A publicação valida conteúdo e fontes no banco, não somente no frontend.
- Textos são renderizados pelo React, sem `innerHTML`. URLs externas admitem somente HTTPS.
- O histórico contém dados que o usuário informou; fica no navegador e pode ser limpo na aba Histórico.

## Cobertura

A busca empresarial pesquisa os dispositivos cadastrados diretamente. O indicador de vínculo entre trechos e dispositivos mede apenas referências que são exatamente iguais, não o percentual integral do texto de uma norma. Vínculos aproximados não são criados automaticamente.

## Perguntas revisadas e histórico

A página Consulta lista até 100 perguntas publicadas pela curadoria. Selecionar uma pergunta preenche seu produto e atividade e remove filtros anteriores, sem reaproveitar detalhes de outro caso. A consulta valida novamente os fundamentos na data atual; a presença no catálogo não garante que uma orientação continuará disponível.

O histórico permite buscar por pergunta e título das normas, ignorando acentos, e filtrar favoritos. Ao ultrapassar 30 registros, a consulta mais recente é preservada e os favoritos têm prioridade. Exclusões individuais e limpeza podem ser desfeitas na mesma sessão, até recarregar/sair da página. O conteúdo interno dos registros é validado antes da abertura; registros corrompidos são ignorados.

## Referência normativa exata

Perguntas que identificam uma norma e um artigo usam a consulta direta em vez de aproximar artigos pela busca textual. Exemplos:

- `Art. 2º do Anexo I do Decreto 10.030`.
- `Art. 2º da Portaria 56 de 2017`.
- `Art. 2º § 1º da Portaria 56 de 2017`.
- `Art. 64 das normas reguladoras da Portaria 2566 de 2025`.

Quando a seção não está identificada e pode haver numeração repetida, a interface apresenta escolhas de corpo principal, anexo ou normas aprovadas. A escolha preenche a pergunta; clique em Consultar. Esse esclarecimento não é salvo como resposta no histórico.

São exibidas somente redações individuais conferidas e aplicáveis na data da consulta. Uma referência cadastrada como faixa de artigos não é apresentada como transcrição isolada de um deles. Incisos, parágrafos e alíneas exigem correspondência individual nos campos do dispositivo. A consulta de um artigo não constitui conclusão sobre a autorização de uma empresa. Os filtros de produto/atividade são usados nas consultas temáticas; uma referência expressamente solicitada pesquisa o dispositivo indicado.

Lacunas de transcrição, seção ou identificação não comprovam revogação nem dispensa. O status mantém a conferência existente do corpus; não há nova auditoria integral nesta atualização.


### Alcance e leitura das respostas

Cada resultado distingue orientação prática revisada, referência normativa localizada, pesquisa documental e fundamento insuficiente. O painel informa quantas fontes têm link oficial, datas de verificação ausentes e fundamentos citados por orientações que não constam no resultado. Esses indicadores descrevem o cadastro e não medem confiança nem garantem atualização integral da legislação. A exportação Markdown preserva essas informações e a data de revisão das orientações.

Os blocos de requisitos, condições e prazos são índices por palavras presentes nos textos. Não constituem conclusões adicionais: apontam para o texto completo nos fundamentos, evitando repetir o mesmo dispositivo em vários blocos.
