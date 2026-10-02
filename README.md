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
