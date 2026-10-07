-- Expansão de cobertura literal: Portarias 291/2026, 800/2020 e 118/2019.
-- Migração já aplicada no Supabase de produção em 2026-10-07.

DO $$
DECLARE
  n291 uuid;
  n800 uuid;
  n118 uuid;
BEGIN
  SELECT id INTO n291 FROM normas WHERE titulo='Portaria COLOG/C Ex nº 291, de 10 de agosto de 2026' LIMIT 1;
  SELECT id INTO n800 FROM normas WHERE titulo='Portaria nº 800, de 14 de agosto de 2020' LIMIT 1;
  SELECT id INTO n118 FROM normas WHERE titulo='Portaria nº 118 COLOG, de 4 de outubro de 2019' LIMIT 1;

  INSERT INTO dispositivos (norma_id,referencia,artigo,inciso,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 1º, inciso V','Art. 1º','V','lançador de munição de menor potencial ofensivo no calibre 12;',1,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","granularidade":"inciso"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 1º, inciso V');

  INSERT INTO dispositivos (norma_id,referencia,artigo,inciso,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 1º, inciso VI','Art. 1º','VI','munição no calibre 12 com agente químico irritante (CS ou OC);',1,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","granularidade":"inciso"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 1º, inciso VI');

  INSERT INTO dispositivos (norma_id,referencia,artigo,inciso,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 1º, inciso VII','Art. 1º','VII','munição no calibre 12 com projéteis de borracha ou plástico duro;',1,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","granularidade":"inciso"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 1º, inciso VII');

  INSERT INTO dispositivos (norma_id,referencia,artigo,inciso,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 1º, inciso X','Art. 1º','X','colete balístico.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","granularidade":"inciso"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 1º, inciso X');

  INSERT INTO dispositivos (norma_id,referencia,artigo,paragrafo,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 1º, § 1º','Art. 1º','§ 1º','As autorizações para as aquisições previstas neste artigo ficam condicionadas à comprovação, pela empresa interessada, da anuência da Polícia Federal na aquisição pretendida.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","granularidade":"paragrafo"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 1º, § 1º');

  INSERT INTO dispositivos (norma_id,referencia,artigo,paragrafo,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 1º, § 2º','Art. 1º','§ 2º','A comprovação de registro junto à Polícia Federal que trata o caput será feita por meio do Certificado de Registro de Pessoa Jurídica (CRPJ), documento emitido pela Polícia Federal que autoriza a aquisição, o uso e a estocagem de armas de fogo para a prestação de serviços de segurança privada vinculado às finalidades e às atividades legais declaradas, nos termos do inciso XXIII do art. 2º do Decreto nº 11.615, de 21 de julho de 2023.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","granularidade":"paragrafo"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 1º, § 2º');

  INSERT INTO dispositivos (norma_id,referencia,artigo,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 2º','Art. 2º','A aquisição de munições calibre 12 com balins de borracha ou plástico e de cartuchos de calibre 12 para lançamento de munição de menor potencial ofensivo, considerados de uso permitido, poderá ser realizada no comércio especializado ou junto à indústria, mediante solicitação à Polícia Federal, observado o disposto no § 1º do art. 1º.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 2º');

  INSERT INTO dispositivos (norma_id,referencia,artigo,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 3º','Art. 3º','A aquisição de produtos controlados junto à indústria, de uso restrito ou permitido, fica condicionada à autorização específica da Polícia Federal, mediante verificação do preenchimento dos requisitos legais pelo interessado, para emprego nas atividades de segurança privada exercidas por empresas especializadas ou por entidades que possuam serviço orgânico de segurança.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 3º');

  INSERT INTO dispositivos (norma_id,referencia,artigo,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 4º','Art. 4º','Fica revogada a Portaria nº 001 - DLOG, de 05 de janeiro de 2009.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 4º');

  INSERT INTO dispositivos (norma_id,referencia,artigo,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n291,'Art. 5º','Art. 5º','Esta Portaria entra em vigor na data de sua publicação.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido"}'::jsonb
  WHERE n291 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n291 AND referencia='Art. 5º');

  INSERT INTO dispositivos (norma_id,referencia,artigo,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n800,'Art. 4º','Art. 4º','Esta portaria entra em vigor em 1º de setembro de 2020.',1,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido"}'::jsonb
  WHERE n800 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n800 AND referencia='Art. 4º');

  INSERT INTO dispositivos (norma_id,referencia,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n800,'Anexo Único — título','ÚNICO TABELA DE CLASSIFICAÇÃO DO NÍVEL DE RISCO DAS ATIVIDADES ECONÔMICAS ENVOLVENDO OS PRODUTOS CONTROLADOS PELO EXÉRCITO',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","tipo":"anexo"}'::jsonb
  WHERE n800 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n800 AND referencia='Anexo Único — título');

  INSERT INTO dispositivos (norma_id,referencia,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n800,'Anexo Único — CNAE 1323-5/00','1323-5/00 — Tecelagem de fios de fibras artificiais e sintéticas — Fabricação de tecido balístico — nível de risco III.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","tipo":"linha_anexo"}'::jsonb
  WHERE n800 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n800 AND referencia='Anexo Único — CNAE 1323-5/00');

  INSERT INTO dispositivos (norma_id,referencia,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n800,'Anexo Único — CNAE 1354-5/00','1354-5/00 — Fabricação de tecidos especiais, inclusive artefatos — fabricação de blindagem balística opaca de uso permitido e fabricação de blindagem balística opaca de uso restrito — nível de risco III.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","tipo":"linha_anexo"}'::jsonb
  WHERE n800 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n800 AND referencia='Anexo Único — CNAE 1354-5/00');

  INSERT INTO dispositivos (norma_id,referencia,artigo,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n118,'Art. 4º','Art. 4º','Esta portaria entra em vigor na data de sua publicação.',1,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido"}'::jsonb
  WHERE n118 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n118 AND referencia='Art. 4º');

  INSERT INTO dispositivos (norma_id,referencia,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n118,'Anexo I — 1. Arma de fogo','1. ARMA DE FOGO — 1.1. ARMA DE FOGO: arma de fogo automática; arma de fogo de repetição de uso permitido; arma de fogo de repetição de uso restrito; arma de fogo de valor histórico; arma de fogo obsoleta; arma de fogo semi-automática de uso permitido; arma de fogo semi-automática de uso restrito; armamento pesado; réplica ou simulacro de arma de fogo destinada à instrução, ao adestramento ou à coleção de usuário autorizado.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","tipo":"anexo"}'::jsonb
  WHERE n118 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n118 AND referencia='Anexo I — 1. Arma de fogo');

  INSERT INTO dispositivos (norma_id,referencia,texto_literal,pagina,status,fonte_tipo,conferido,metadata)
  SELECT n118,'Anexo I — 3. Explosivo','3. EXPLOSIVO — 3.1. EXPLOSIVOS DE RUPTURA: inclui, entre outros, ácido picrâmico, ácido pícrico, RDX, HMX, dinamite, explosivo plástico, ANFO, emulsões, PETN, TETRIL, TATB e TNT; 3.2. BAIXOS EXPLOSIVOS (PROPELENTES): inclui, entre outros, hidrazina, nitrocelulose, pólvoras mecânicas e pólvoras químicas.',2,'vigente','pdf_oficial',true,'{"origem":"pdf_fornecido","tipo":"anexo","observacao":"transcricao_literal_parcial_do_bloco"}'::jsonb
  WHERE n118 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dispositivos WHERE norma_id=n118 AND referencia='Anexo I — 3. Explosivo');
END $$;
