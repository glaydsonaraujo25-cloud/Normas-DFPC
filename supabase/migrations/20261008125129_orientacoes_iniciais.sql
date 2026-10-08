-- Orientações iniciais conferidas contra os dispositivos já cadastrados.
-- Não amplia a validação de vigência dos documentos de origem.
insert into public.orientacoes_empresariais(titulo,produto,atividade,pergunta_modelo,secoes,estado)
select 'O que é PCE','todos','todos','o que é PCE?',
 jsonb_build_array(jsonb_build_object('titulo','Resposta direta','texto','PCE é um produto enquadrado nos critérios do Regulamento de Produtos Controlados: poder destrutivo, possibilidade de dano a pessoas ou patrimônio, necessidade de restrição por incolumidade pública ou interesse militar. A referência aqui é o art. 2º do Anexo I do Decreto nº 10.030/2019, não o art. 2º do corpo principal do decreto.','dispositivo_ids',jsonb_build_array(d.id))),
 'publicada' from dispositivos d join normas n on n.id=d.norma_id
where n.titulo='Decreto nº 10.030, de 30 de setembro de 2019' and d.referencia='Anexo I, art. 2º, caput e incisos I e II'
 and not exists(select 1 from orientacoes_empresariais where pergunta_modelo='o que é PCE?');

insert into public.orientacoes_empresariais(titulo,produto,atividade,pergunta_modelo,secoes,estado)
select 'Registro para atividade empresarial com PCE','quimicos','todos','Minha empresa precisa de registro para comercializar produtos químicos?',
 jsonb_build_array(jsonb_build_object('titulo','Regra geral e identificação do caso','texto','Se o produto químico for efetivamente um PCE e a atividade estiver sujeita a registro, a regra geral cadastrada determina o registro da pessoa física ou jurídica para exercer a atividade, própria ou terceirizada. A expressão “produto químico” sozinha não identifica o enquadramento do produto nem afasta eventuais hipóteses específicas de dispensa; informe qual é o produto e a atividade antes de aplicar a regra ao caso.','dispositivo_ids',jsonb_build_array(d.id))),
 'publicada' from dispositivos d join normas n on n.id=d.norma_id
where n.titulo='Portaria nº 56 COLOG, de 5 de junho de 2017' and d.referencia='Art. 2º, caput'
 and not exists(select 1 from orientacoes_empresariais where pergunta_modelo='Minha empresa precisa de registro para comercializar produtos químicos?');

insert into public.orientacoes_empresariais(titulo,produto,atividade,pergunta_modelo,secoes,estado)
select 'Apostilamento de atividade no registro','todos','todos','Como funciona o apostilamento de atividade no registro da empresa?',
 jsonb_build_array(jsonb_build_object('titulo','O que muda no registro','texto','Apostilamento é o processo de inclusão, exclusão ou atualização dos dados da pessoa, do produto, da atividade ou de informações complementares do registro, por iniciativa do interessado. Para alterar uma atividade, identifique precisamente qual dado será incluído, excluído ou atualizado; os documentos e requisitos devem ser conferidos no procedimento aplicável.','dispositivo_ids',jsonb_build_array(d.id))),
 'publicada' from dispositivos d join normas n on n.id=d.norma_id
where n.titulo='Portaria nº 56 COLOG, de 5 de junho de 2017' and d.referencia='Art. 22'
 and not exists(select 1 from orientacoes_empresariais where pergunta_modelo='Como funciona o apostilamento de atividade no registro da empresa?');

insert into public.orientacoes_empresariais(titulo,produto,atividade,pergunta_modelo,secoes,estado)
select 'Tratamento administrativo de importação de PCE','todos','todos','Quais requisitos se aplicam à importação de PCE?',
 jsonb_build_array(jsonb_build_object('titulo','Como a operação é controlada','texto','O dispositivo cadastrado prevê tratamento administrativo no Portal Único de Comércio Exterior, incluindo LPCO e conferência da DUIMP pelo Exército. A conferência abrange documentação e inspeção física ou remota da mercadoria. Os demais requisitos dependem do produto e da operação; este resumo não substitui a conferência de todos os dispositivos aplicáveis.','dispositivo_ids',jsonb_build_array(d.id))),
 'publicada' from dispositivos d join normas n on n.id=d.norma_id
where n.titulo='Portaria C Ex nº 2.566, de 8 de outubro de 2025' and d.referencia='Normas, art. 2º, §§ 1º a 3º'
 and not exists(select 1 from orientacoes_empresariais where pergunta_modelo='Quais requisitos se aplicam à importação de PCE?');

insert into public.orientacoes_empresariais(titulo,produto,atividade,pergunta_modelo,secoes,estado)
select 'Aquisição para segurança privada','menos_letais','todos','Empresa de segurança privada pode adquirir PCE de menor potencial ofensivo?',
 jsonb_build_array(
 jsonb_build_object('titulo','Resposta direta','texto','A norma cadastrada admite aquisição direta do fabricante de produtos abrangidos por ela, para emprego nas atividades de segurança privada, por empresas especializadas ou entidades com serviço orgânico de segurança registradas na Polícia Federal. Isso não é uma autorização geral para qualquer produto ou operação.','dispositivo_ids',jsonb_build_array(a.id)),
 jsonb_build_object('titulo','Condição para a aquisição','texto','A aquisição junto à indústria está condicionada à autorização específica da Polícia Federal e à verificação dos requisitos legais do interessado. Identifique o produto pretendido e confira as condições antes de realizar a operação.','dispositivo_ids',jsonb_build_array(b.id))),
 'publicada' from normas n join dispositivos a on a.norma_id=n.id join dispositivos b on b.norma_id=n.id
where n.titulo='Portaria COLOG/C Ex nº 291, de 10 de agosto de 2026' and a.referencia='Art. 1º, caput' and b.referencia='Art. 3º'
 and not exists(select 1 from orientacoes_empresariais where pergunta_modelo='Empresa de segurança privada pode adquirir PCE de menor potencial ofensivo?');

-- Fonte oficial consultada; a data de verificação pré-existente não é alterada.
update normas set fonte_oficial='https://www.planalto.gov.br/ccivil_03/_ato2019-2022/2019/decreto/d10030.htm'
where titulo='Decreto nº 10.030, de 30 de setembro de 2019' and fonte_oficial is null;
