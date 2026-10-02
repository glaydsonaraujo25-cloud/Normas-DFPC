# Normas DFPC

Aplicação para consulta técnica de normas relacionadas a Produtos Controlados pelo Exército (PCE).

## Fase atual

MVP frontend com React + TypeScript + Vite, contendo:
- consulta normativa (interface preparada para IA/RAG);
- catálogo da base normativa;
- status de vigência e relações entre normas;
- layout responsivo.

## Executar

```bash
npm install
npm run dev
```

## Próximas etapas

1. Consolidar todos os documentos enviados e seus metadados.
2. Integrar Supabase (Postgres, Storage e pgvector).
3. Criar ingestão e fragmentação dos textos normativos.
4. Implementar busca semântica/RAG com citações por norma e dispositivo.
5. Implementar controle de vigência, alterações e revogações.

> A interface inicial não fornece respostas automáticas sem fonte. O mecanismo de consulta será conectado após a consolidação da base normativa.


## Busca híbrida

A arquitetura de consulta foi preparada para combinar PostgreSQL Full-Text Search com pgvector. Os embeddings devem usar dimensão 1536, compatível com a coluna `trechos.embedding vector(1536)`. A geração e consulta vetorial devem ocorrer somente no backend (Supabase Edge Functions), usando `OPENAI_API_KEY` armazenada como secret. O Full-Text Search permanece como fallback seguro.
