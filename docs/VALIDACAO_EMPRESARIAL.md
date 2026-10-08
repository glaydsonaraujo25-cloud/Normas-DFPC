# Validação da atualização empresarial — 08/10/2026

## Verificações concluídas

- TypeScript e build de produção: aprovados.
- Quatro testes unitários: vigência/data, contexto insuficiente, URLs seguras e histórico inválido/bloqueado.
- Oito casos existentes de regressão de busca: todos aprovados após as migrations.
- Oito verificações de busca empresarial no banco: definição de PCE, registro de empresa, apostilamento, importação, explosivos, segurança privada, orientação correspondente e ausência de fonte revogada no resultado.
- Consulta pública pelo endpoint REST usando chave publicável: HTTP 200, com orientação e dispositivo.
- Revisão de segurança Supabase: sem apontamentos de RLS ou views após a atualização. Permanecem avisos preexistentes sobre localização das extensões `vector` e `pg_trgm`; movê-las exigiria tratar as dependências da busca.

## Limites da verificação

As verificações técnicas não equivalem a auditoria jurídica integral dos PDFs. A condição `conferido` é informação do corpus existente; a atualização não comprova que cada redação cadastrada reproduz integralmente a fonte oficial.

Não havia usuários no Supabase Auth. A autorização real de um revisor precisa ser provisionada pelo proprietário antes de validar o fluxo de edição com uma conta pessoal.

O download do Chromium no ambiente de desenvolvimento falhou. A interface será conferida no endereço publicado por navegador disponível; o build e o fluxo REST foram verificados independentemente.
