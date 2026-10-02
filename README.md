# Normas DFPC

Aplicação para consulta técnica de normas relacionadas a Produtos Controlados pelo Exército (PCE).

## Arquitetura atual

A aplicação funciona sem API da OpenAI. A consulta usa o Supabase/PostgreSQL como fonte normativa e o mecanismo de Full-Text Search em português já disponível no banco.

- React + TypeScript + Vite no frontend;
- Supabase/PostgreSQL para normas, trechos e relações normativas;
- PostgreSQL Full-Text Search para localizar fundamentos;
- resultados acompanhados de norma, dispositivo, página, situação e relações normativas;
- nenhuma resposta é inventada quando a base não possui fundamento;
- controle conservador de vigência: vigente, alterada, revogada ou vigência a confirmar.

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

O frontend chama a função PostgreSQL `consultar_base_normativa`, que pesquisa os trechos cadastrados e devolve os fundamentos relevantes com os metadados da norma e suas relações.

A arquitetura não exige `OPENAI_API_KEY`, créditos da OpenAI ou embeddings para funcionar.

## Próximas etapas

1. Expandir o corpus com os documentos normativos enviados.
2. Fragmentar o conteúdo por artigo/dispositivo preservando a fonte.
3. Validar vigência, alterações e revogações sem inferir revogação apenas pela existência de norma posterior.
4. Melhorar ranking textual, sinônimos e pesquisa por número/ano.
5. Manter toda resposta rastreável aos fundamentos cadastrados.
