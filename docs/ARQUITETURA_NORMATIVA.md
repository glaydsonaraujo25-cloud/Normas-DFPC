# Arquitetura normativa — Normas DFPC

## Objetivo

A aplicação deve responder perguntas sobre Produtos Controlados pelo Exército usando somente fundamentos normativos rastreáveis e com situação de vigência conhecida.

## Estados de vigência

- `Vigente`: pode fundamentar respostas automaticamente.
- `Vigente com alterações`: pode fundamentar respostas, desde que seja usado o texto consolidado aplicável.
- `Parcialmente vigente`: pode fundamentar apenas após validação do dispositivo específico.
- `Ato alterador`: permanece na base para formar a cadeia normativa, mas não deve ser priorizado como fonte principal quando o texto consolidado estiver disponível.
- `Vigência a confirmar`: não pode fundamentar resposta automática.
- `Superada materialmente`: não pode fundamentar resposta automática, salvo consulta histórica explicitamente solicitada.
- `Revogada`: não pode fundamentar resposta atual.

## Hierarquia de consulta

1. Lei aplicável.
2. Decreto regulamentador vigente.
3. Portaria ou ato normativo setorial vigente.
4. ITA/IN complementar vigente.
5. Atos alteradores somente para explicar a cadeia de alteração.

## Regras obrigatórias

1. Nunca concluir que uma norma está vigente apenas porque não foi encontrada revogação expressa.
2. Para normas parcialmente vigentes, controlar a situação no nível de artigo, parágrafo, inciso e alínea quando necessário.
3. Quando houver versão consolidada, usar a versão consolidada como fundamento principal e manter o ato alterador como relação normativa.
4. Não usar consulta pública, minuta ou proposta como norma vigente.
5. Não gerar resposta jurídica sem fonte cadastrada que suporte a conclusão.
6. Exibir norma, dispositivo, trecho, situação de vigência e relações normativas relevantes.
7. Registrar a data da última verificação de vigência.

## Modelo de dados

A entidade `Norma` possui metadados de identificação, vigência e política de uso. Relações entre normas devem ser estruturadas separadamente quando migradas ao banco de dados.

Campos principais:

- `id`
- `tipo`
- `numero`
- `ano`
- `titulo`
- `assunto`
- `status`
- `statusDetalhado`
- `normaPrincipal`
- `usarComoFundamento`
- `vigenciaInicio`
- `vigenciaFim`
- `ultimaVerificacao`
- `observacaoVigencia`
- `palavrasChave`
- `relacoesEstruturadas`

## Próxima etapa do banco

Aplicar a migration `supabase/migrations/20261006_normative_status.sql`, migrar o catálogo local para a tabela `normas` e cadastrar as relações na tabela `relacoes_normativas`. Em seguida, atualizar a função `consultar_base_normativa` para excluir automaticamente fontes não aptas a fundamentar respostas.
