# Normas DFPC

Aplicação de consulta normativa sobre Produtos Controlados pelo Exército, com foco em empresas.

## Recursos

- Busca textual PostgreSQL em português, sem OpenAI, créditos pagos ou embeddings externos.
- Contexto por produto, atividade e público; perguntas incompletas recebem pedidos de esclarecimento.
- Pesquisa diretamente em dispositivos conferidos. Cada fonte devolve o ID do dispositivo, texto cadastrado, situação, data e origem.
- Validação de vigência por dispositivo e norma na data da consulta. Redações futuras, revogadas, suspensas e não conferidas ficam fora.
- Orientações práticas revisadas com citações em cada seção. Quando não há orientação cadastrada, a interface distingue os fundamentos encontrados de uma conclusão.
- Procedimentos empresariais, histórico local (até 30 consultas), favoritos, exportação Markdown e impressão/PDF.
- Painel de cobertura, origem e vínculos exatos, com área de curadoria para revisores autorizados.
- Componentes React para texto e cadeia normativa; sem injeção de HTML ou alterações externas ao DOM do React.

## Desenvolvimento

Node.js 24 ou superior.

```bash
npm ci
npm test
npm run build
npm run dev
```

Configure somente a URL do projeto e a chave pública:

```env
VITE_SUPABASE_URL=https://<projeto>.supabase.co
VITE_SUPABASE_ANON_KEY=<chave publicável>
```

Nunca use a chave `service_role` no frontend.

## Banco e curadoria

As migrations versionam a busca e a consulta empresarial. O snapshot de produção preserva as funções antigas; as novas funções não substituem os casos existentes de busca geral.

As primeiras migrations deste repositório dependem das tabelas e do corpus criados anteriormente no projeto Supabase. Não constituem, por si sós, um bootstrap completo de banco vazio. Veja [operação e curadoria](docs/OPERACAO_EMPRESARIAL.md) e [validação](docs/VALIDACAO_EMPRESARIAL.md).

O corpus cadastrado continua exigindo conferência editorial. Um dispositivo marcado como conferido no banco não implica que todo o documento tenha sido auditado nesta atualização. Links oficiais e proveniência ausentes aparecem como pendências, sem preenchimento fictício.

## Limites da versão

- A consulta empresarial trabalha com a data atual. Consultas históricas e futuras são bloqueadas até que as redações históricas e os respectivos intervalos sejam completos.
- Situação de registro e detalhes são anotados localmente e não certificam autorização da empresa. A busca usa pergunta, produto, atividade e público.
- Orientações publicadas correspondem às perguntas modelo cadastradas; perguntas diferentes usam os dispositivos encontrados.
- Histórico e favoritos ficam neste navegador; não há sincronização entre dispositivos.
- Contas de revisão são provisionadas pelo proprietário no Supabase Auth e autorizadas explicitamente. O público não pode conceder a si mesmo essa permissão.
