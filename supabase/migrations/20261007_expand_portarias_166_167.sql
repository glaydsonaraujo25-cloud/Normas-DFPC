-- Expansão da cobertura normativa das Portarias 166/2023 e 167/2024.
-- A aplicação no banco de produção foi feita em 07/10/2026.
-- Este arquivo documenta os novos blocos temáticos usados pela busca.

-- Portaria 166/2023
-- Art. 61: aquisição por colecionador, atirador e caçador excepcional.
-- Art. 67: limites de armas por nível de atirador.
-- Art. 68: limites do caçador excepcional.
-- Arts. 72 a 78: transferências SIGMA/SINARM.
-- Arts. 79 a 81: acessórios e equipamentos de recarga.
-- Arts. 82 a 85: munições, progressão e autorização excepcional.
-- Arts. 86 e 87: caça excepcional e insumos.
-- Arts. 92 a 94: validade e revalidação do CRAF.
-- Arts. 95 a 99: níveis e habitualidade.
-- Os dispositivos alterados pela Portaria 260/2025 devem ser interpretados pela redação consolidada.

-- Portaria 167/2024
-- Art. 1º: aquisição institucional.
-- Art. 2º, caput: limites individuais de PM, CBM e GSI/PR na redação da Portaria 225/2024.
-- Art. 2º, §1º: autorização para arma de uso restrito e documentação.
-- Art. 2º, §§2º a 5º: registro, SIGMA, CRAF e entrega.
-- Art. 2º, §§7º a 10: aquisição excepcional, propriedade e vedações.
-- Arts. 3º a 8º: transferências entre SIGMA e SINARM.
-- Arts. 11 e 12: aquisição de munições por PM, CBM e GSI/PR.
-- Os dispositivos alterados pelas Portarias 224 e 225/2024 devem ser interpretados pela redação consolidada.

-- A função consultar_base_normativa_composta também foi atualizada em produção para:
-- 1. restringir resultados incompatíveis com o sujeito da consulta (Exército, PM/CBM, CAC, segurança privada);
-- 2. reconhecer os aspectos "Validade e renovação" e "Níveis e habitualidade";
-- 3. ampliar o conjunto de candidatos analisados antes do ranking final.
