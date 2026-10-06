insert into public.sinonimos_busca (termo, expansao, observacao) values
('nivel 1','nível 1 atirador desportivo limites armas munições habitualidade','Nível 1 do atirador desportivo'),
('nivel 2','nível 2 atirador desportivo limites armas munições habitualidade','Nível 2 do atirador desportivo'),
('nivel 3','nível 3 atirador desportivo limites armas munições habitualidade dezesseis quatro uso restrito','Nível 3 do atirador desportivo'),
('transferir sinarm sigma','transferência SINARM SIGMA anuência cadastro CRAF documentos adquirente alienante','Transferência de arma entre sistemas'),
('transferencia sinarm sigma','transferência SINARM SIGMA anuência cadastro CRAF documentos adquirente alienante','Transferência de arma entre sistemas'),
('porte de transito','porte de trânsito guia de tráfego GT GTE deslocamento arma','Porte de trânsito'),
('revalidacao cr','revalidação certificado de registro CR documentos requisitos validade','Revalidação de CR')
on conflict (termo) do update set
  expansao = excluded.expansao,
  observacao = excluded.observacao,
  ativo = true,
  atualizado_em = now();

-- A função consultar_base_normativa em produção também aplica bônus de ranking
-- por intenção (quantidade/limite, requisitos/documentos, procedimento, sujeito
-- autorizado, prazo/validade, restrição), além de regras especializadas para
-- níveis de atirador e transferências SINARM <-> SIGMA.
