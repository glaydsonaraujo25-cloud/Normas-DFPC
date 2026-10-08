# Validação da atualização empresarial — 08/10/2026

## Verificações concluídas

- TypeScript e build de produção: aprovados.
- Seis testes unitários: vigência/data, contexto insuficiente, URLs seguras e histórico inválido/bloqueado.
- Oito casos existentes de regressão de busca: todos aprovados após as migrations.
- Oito verificações de busca empresarial no banco: definição de PCE, registro de empresa, apostilamento, importação, explosivos, segurança privada, orientação correspondente e ausência de fonte revogada no resultado.
- Consulta pública pelo endpoint REST usando chave publicável: HTTP 200, com orientação e dispositivo.
- Revisão de segurança Supabase: sem apontamentos de RLS ou views após a atualização. Permanecem avisos preexistentes sobre localização das extensões `vector` e `pg_trgm`; movê-las exigiria tratar as dependências da busca.

## Limites da verificação

As verificações técnicas não equivalem a auditoria jurídica integral dos PDFs. A condição `conferido` é informação do corpus existente; a atualização não comprova que cada redação cadastrada reproduz integralmente a fonte oficial.

Não havia usuários no Supabase Auth. A autorização real de um revisor precisa ser provisionada pelo proprietário antes de validar o fluxo de edição com uma conta pessoal.

A interface publicada foi conferida em navegador: consulta com orientação/citação, histórico e favorito persistentes e pedido de contexto insuficiente. O download local do Chromium falhou; a conferência usou o navegador disponível.

## Segunda atualização — perguntas revisadas e histórico

- Nove testes unitários aprovados, incluindo proteção de favoritos, busca sem acentos e rejeição de estruturas internas corrompidas.
- Build aprovado; painel de revisão separado em arquivo carregado sob demanda.
- Cinco perguntas publicadas acessíveis ao público com as permissões existentes; nenhuma ampliação de acesso ou migração nesta atualização.
- Orientações só são exibidas se todas as citações permanecem entre os dispositivos válidos retornados.
