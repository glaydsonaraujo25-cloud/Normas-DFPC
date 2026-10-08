-- A subconsulta da política de orientação precisa poder avaliar a tabela de revisores.
-- RLS continua sem política para anon: nenhuma associação é exposta ao público.
grant select on public.revisores_normativos to anon;
revoke insert,update,delete on public.revisores_normativos from anon,authenticated;
revoke insert,update,delete on public.orientacoes_empresariais from anon;
revoke insert,update,delete on public.dispositivos,public.trechos,public.documentos,public.relacoes_normativas from anon,authenticated;
notify pgrst,'reload schema';

