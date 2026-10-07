-- 2026-10-07 — fechamento da cobertura literal das normas vigentes
--
-- Esta migração registra o marco de cobertura atingido após as cargas idempotentes
-- complete_literal_coverage_batch_20261007, topoff_literal_coverage_batch_20261007
-- e complete_remaining_current_literal_coverage_20261007, aplicadas no Supabase.
--
-- Foram completados, entre outros:
--   * Decreto 10.030/2019
--   * Decreto 11.615/2023
--   * Lei 10.826/2003
--   * Portarias 56/2017, 118/2019, 189/2020, 212/2021, 213/2021, 214/2021
--   * Portarias C Ex 1.518/2021, 1.757/2022 e 2.566/2025
--   * Portarias 164/2023, 166/2023, 167/2024, 291/2026 e 800/2020
--   * ITA 25/2022, ITA 31/2025 e ITA 33/2026
--   * Portaria Normativa 1.369/MD/2004
--   * Portaria Conjunta C Ex/DG-PF 2/2023
--
-- Regra de qualidade: o percentual representa cobertura literal dos fundamentos
-- pesquisáveis cadastrados, não a transcrição integral de todos os artigos da norma.
-- Dispositivos de vigência duvidosa permanecem fora do conjunto utilizável.

-- Verificação esperada: nenhuma norma vigente ou vigente_com_alteracoes abaixo de 100%.
do $$
begin
  if exists (
    select 1
    from public.v_cobertura_literal
    where status_norma in ('vigente','vigente_com_alteracoes')
      and cobertura_percentual < 100
  ) then
    raise notice 'Ainda existem normas vigentes abaixo de 100%% de cobertura literal.';
  else
    raise notice 'Todas as normas vigentes monitoradas atingiram 100%% de cobertura literal.';
  end if;
end $$;
