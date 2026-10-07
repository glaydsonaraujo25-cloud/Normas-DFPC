-- Expansão de cobertura e busca especializada para segurança privada,
-- explosivos/SICOEX e marcação/rastreabilidade de armas.
-- Aplicada em produção em 07/10/2026.

DO $$
DECLARE
  n291 uuid;
  n147 uuid;
  n213 uuid;
BEGIN
  SELECT id INTO n291 FROM normas WHERE titulo ILIKE 'Portaria COLOG/C Ex nº 291%' LIMIT 1;
  SELECT id INTO n147 FROM normas WHERE titulo ILIKE 'Portaria nº 147 COLOG%' LIMIT 1;
  SELECT id INTO n213 FROM normas WHERE titulo ILIKE 'Portaria nº 213 COLOG/C Ex%' LIMIT 1;

  IF n291 IS NOT NULL THEN
    INSERT INTO trechos(norma_id,pagina,dispositivo,conteudo,metadata)
    SELECT n291,v.pagina,v.dispositivo,v.conteudo,
           jsonb_build_object('origem','curadoria normativa','tipo','sintese_fiel','tema','seguranca privada')
    FROM (VALUES
      (1,'Art. 1º, incisos I a X — PCE de menor potencial ofensivo','Autoriza empresas especializadas de segurança privada e entidades com serviço orgânico de segurança, registradas na Polícia Federal, a adquirir diretamente do fabricante determinados PCE de menor potencial ofensivo, incluindo espargidores de agente químico irritante, armas de dardos energizados, armas de pressão específicas, granadas com agente irritante ou fumígenas, lançadores e munições calibre 12 de menor potencial ofensivo, máscaras, filtros e coletes balísticos.'),
      (2,'Art. 1º, §§ 1º e 2º — anuência da Polícia Federal e CRPJ','A aquisição prevista no art. 1º depende da comprovação de anuência da Polícia Federal. O registro da empresa perante a Polícia Federal é comprovado pelo Certificado de Registro de Pessoa Jurídica (CRPJ), vinculado às atividades legais declaradas de segurança privada.'),
      (2,'Art. 2º — munições calibre 12 de menor potencial ofensivo','Munições calibre 12 com balins de borracha ou plástico e cartuchos calibre 12 para lançamento de munição de menor potencial ofensivo, quando de uso permitido, podem ser adquiridos no comércio especializado ou na indústria mediante solicitação à Polícia Federal, observada a anuência exigida pela norma.'),
      (2,'Art. 3º — autorização específica da Polícia Federal','A aquisição de PCE junto à indústria, de uso restrito ou permitido, para emprego em atividades de segurança privada fica condicionada à autorização específica da Polícia Federal e à verificação dos requisitos legais do interessado.'),
      (2,'Arts. 4º e 5º — revogação e vigência','Revoga a Portaria nº 001-DLOG, de 5 de janeiro de 2009, e entra em vigor na data de sua publicação.')
    ) AS v(pagina,dispositivo,conteudo)
    WHERE NOT EXISTS (
      SELECT 1 FROM trechos t WHERE t.norma_id=n291 AND lower(t.dispositivo)=lower(v.dispositivo)
    );
  END IF;

  IF n147 IS NOT NULL THEN
    INSERT INTO trechos(norma_id,pagina,dispositivo,conteudo,metadata)
    SELECT n147,v.pagina,v.dispositivo,v.conteudo,
           jsonb_build_object('origem','curadoria normativa','tipo','sintese_fiel','tema','explosivos')
    FROM (VALUES
      (2,'Arts. 4º a 6º — SICOEX e demonstrativos','Institui o Sistema de Controle de Explosivos (SICOEX) para controle, informações, autorizações de aquisição e de serviço de detonação e relatórios. Empresas que atuam com explosivos devem documentar entradas e saídas com dados de origem, destino, especificações e Identificador Individual Seriado (IIS).'),
      (2,'Arts. 11 a 13 — importação e exportação','Importadores de explosivos devem manter controles dos produtos em trânsito e informar imediatamente incidentes ou sinistros à fiscalização. Explosivos importados devem ser marcados conforme o Anexo D, e as informações de exportação devem constar do Portal Único de Comércio Exterior.'),
      (3,'Arts. 18 a 20 — comércio e nota fiscal','O adquirente deve verificar se o vendedor possui autorização do Exército para comercializar explosivos. É vedada a comercialização de explosivos sem marcação e a nota fiscal deve conter o CR do adquirente ou o número da autorização de aquisição para pessoa sem registro.'),
      (11,'Arts. 62 a 65 — autorização para aquisição de explosivos','A aquisição de explosivos depende de autorização, com requerimento contendo dados do adquirente, produtos e fornecedor e comprovante da taxa. A autorização está condicionada à existência de local de armazenagem registrado no Exército, salvo aquisição para emprego imediato; para pessoas isentas de registro há requerimento específico e a autorização tem validade de até noventa dias.'),
      (12,'Arts. 66 a 70 — transferência de posse e tráfego','É vedada a transferência de posse de explosivos a pessoa não autorizada a adquiri-los. O tráfego deve observar a documentação exigida, incluindo Termo de Transferência de Posse e documento fiscal; o retorno de sobras ou explosivos não utilizados pode ocorrer mediante nova guia de tráfego ou conforme a forma prevista na norma.')
    ) AS v(pagina,dispositivo,conteudo)
    WHERE NOT EXISTS (
      SELECT 1 FROM trechos t WHERE t.norma_id=n147 AND lower(t.dispositivo)=lower(v.dispositivo)
    );
  END IF;

  IF n213 IS NOT NULL THEN
    INSERT INTO trechos(norma_id,pagina,dispositivo,conteudo,metadata)
    SELECT n213,v.pagina,v.dispositivo,v.conteudo,
           jsonb_build_object('origem','curadoria normativa','tipo','sintese_fiel','tema','marcacao e rastreabilidade')
    FROM (VALUES
      (4,'Art. 3º — finalidade da marcação e identificação','A marcação e a identificação de armas de fogo têm por finalidade possibilitar o rastreamento, conforme as regras de controle e rastreabilidade aplicáveis aos PCE.'),
      (4,'Arts. 4º a 6º — marcações obrigatórias','Armas de fogo fabricadas no País ou importadas devem apresentar as marcações previstas na norma, incluindo identificação do fabricante e do país, além dos demais elementos de individualização exigidos para rastreabilidade.'),
      (5,'Arts. 7º a 9º — armas adquiridas por órgãos públicos','Armas adquiridas pelas Forças Armadas, Polícia Federal, Polícia Rodoviária Federal, Polícias Militares, Corpos de Bombeiros e outros órgãos públicos devem receber, além das marcações gerais, identificação institucional conforme a categoria do órgão; a norma admite gravação a laser para brasões e nomes.'),
      (6,'Arts. 10 e 11 — armas importadas em regime definitivo','Armas importadas em regime definitivo devem permitir a identificação da empresa importadora e conter as marcações gerais. A execução complementar de marcações no Brasil depende de solicitação prévia e de serviço por pessoa especializada; o descumprimento das marcações mínimas pode levar à liberação alfandegária apenas para reexportação ao país de origem.'),
      (7,'Art. 12 — importação temporária','Armas importadas temporariamente devem possuir marcações mínimas que permitam sua identificação e individualização. O responsável pelo evento deve manter, pelo prazo previsto na norma, dados que identifiquem arma, importador, motivo do ingresso, datas de entrada e saída e detentor ou possuidor direto.'),
      (8,'Art. 14 e §§ — remarcação de arma de fogo','A DFPC pode autorizar remarcação de arma de fogo cuja identificação ou marcações tenham sido suprimidas ou adulteradas. O pedido deve ser acompanhado de laudo pericial ou técnico capaz de recuperar integralmente os dados originais, e a execução deve observar as condições definidas pela norma.')
    ) AS v(pagina,dispositivo,conteudo)
    WHERE NOT EXISTS (
      SELECT 1 FROM trechos t WHERE t.norma_id=n213 AND lower(t.dispositivo)=lower(v.dispositivo)
    );
  END IF;

  INSERT INTO sinonimos_busca(termo,expansao,ativo,observacao,atualizado_em) VALUES
    ('menor potencial ofensivo','segurança privada espargidor dardos energizados granada agente irritante borracha plastico colete balistico',true,'PCE de menor potencial ofensivo',now()),
    ('crpj','certificado de registro de pessoa juridica policia federal seguranca privada',true,'CRPJ da Polícia Federal',now()),
    ('sicoex','sistema de controle de explosivos aquisição detonação tráfego armazenagem explosivos',true,'Sistema de Controle de Explosivos',now()),
    ('marcacao arma','marcação identificação rastreabilidade arma de fogo numero serie importada fabricante',true,'Marcação e rastreabilidade de armas',now())
  ON CONFLICT (termo) DO UPDATE SET
    expansao=excluded.expansao,
    ativo=true,
    observacao=excluded.observacao,
    atualizado_em=now();
END $$;

-- A função consultar_base_normativa_composta foi atualizada em produção para:
-- 1. reconhecer escopos específicos de explosivos/SICOEX, marcação/rastreabilidade e segurança privada;
-- 2. priorizar Portaria 147/2019, Portaria 213/2021 + ITA 25/2022 e Portaria 291/2026, respectivamente;
-- 3. impedir que consultas especializadas sejam dominadas por regras de armas/CAC sem relação direta;
-- 4. expor os aspectos 'Explosivos e detonação', 'Marcação e rastreabilidade' e 'Segurança privada'.
