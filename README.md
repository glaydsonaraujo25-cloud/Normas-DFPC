# Normas DFPC

Aplicação para consulta técnica de normas relacionadas a Produtos Controlados pelo Exército (PCE).

## Arquitetura atual

**Política do projeto: não utilizar OpenAI, créditos pagos ou embeddings externos.**

A consulta usa o Supabase/PostgreSQL como fonte normativa e funciona integralmente com recursos do banco:

- React + TypeScript + Vite no frontend;
- Supabase/PostgreSQL para normas, trechos e relações normativas;
- PostgreSQL Full-Text Search em português;
- dicionário de siglas e sinônimos para PCE, GT, GTE, CAC, CRAF, SICOVAB, SICOEX etc.;
- `pg_trgm` para tolerância a erros de digitação e similaridade textual;
- filtros por tema, relevância, situação de vigência e cadeia normativa;
- resultados acompanhados de norma, dispositivo, página, situação e relações normativas;
- nenhuma resposta é inventada quando a base não possui fundamento seguro.

A busca textual é a arquitetura oficial do projeto. A coluna vetorial existente no banco não é necessária para o funcionamento e não deve acionar serviços externos.

## Executar

```bash
npm install
npm run dev
```

Variáveis necessárias no frontend:

```env
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
```

## Consulta normativa

O frontend chama a função PostgreSQL `consultar_base_normativa`, que pesquisa os trechos cadastrados e devolve os fundamentos relevantes com metadados da norma e suas relações.

A Edge Function `consulta-normativa`, quando utilizada, também consulta exclusivamente essa função PostgreSQL. As antigas rotas de geração/indexação de embeddings permanecem desativadas e não fazem chamadas a provedores externos.

## Próximas etapas

1. Continuar expandindo o corpus por artigo, parágrafo, inciso e anexo.
2. Melhorar o ranking textual por intenção da pergunta e tipo de dispositivo.
3. Refinar os filtros temáticos e a classificação de aderência.
4. Completar fonte oficial e rastreabilidade documental das normas.
5. Manter toda resposta vinculada a fundamento normativo verificável.
