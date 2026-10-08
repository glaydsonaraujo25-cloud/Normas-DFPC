import { supabase } from './supabase';
import '../timeline.css';

type LinhaTempo = {
  norma_base_id: string;
  norma_base: string;
  status_norma_base: string;
  alteracao_id: string;
  norma_alteradora_id: string;
  norma_alteradora: string;
  data_alteracao?: string | null;
  dispositivo_base?: string | null;
  tipo_alteracao: string;
  texto_novo?: string | null;
  vigencia_inicio?: string | null;
  vigencia_fim?: string | null;
  conferido: boolean;
  observacoes?: string | null;
};

type MapaVigencia = {
  norma_id: string;
  titulo: string;
  status_norma: string;
  dispositivo: string;
  status_dispositivo: string;
  norma_responsavel?: string | null;
  data_efeito?: string | null;
  observacoes?: string | null;
  conferido: boolean;
};

const cacheLinha = new Map<string, LinhaTempo[]>();
const cacheMapa = new Map<string, MapaVigencia[]>();
let timer: number | undefined;

const formatarData = (valor?: string | null) => valor ? valor.split('-').reverse().join('/') : '';
const tituloStatus = (status: string) => ({
  vigente: 'Vigente',
  revogado: 'Revogado',
  historico: 'Histórico',
  alterado: 'Alterado',
  suspenso: 'Suspenso',
  vigencia_futura: 'Vigência futura',
  vigencia_a_confirmar: 'Vigência a confirmar',
}[status] || status.replaceAll('_', ' '));

async function buscarLinhaTempo(titulo: string) {
  if (cacheLinha.has(titulo)) return cacheLinha.get(titulo)!;
  if (!supabase) return [];
  const { data } = await supabase
    .from('v_linha_tempo_normativa')
    .select('norma_base_id,norma_base,status_norma_base,alteracao_id,norma_alteradora_id,norma_alteradora,data_alteracao,dispositivo_base,tipo_alteracao,texto_novo,vigencia_inicio,vigencia_fim,conferido,observacoes')
    .eq('norma_base', titulo)
    .eq('conferido', true)
    .order('data_alteracao', { ascending: true });
  const itens = (data || []) as LinhaTempo[];
  cacheLinha.set(titulo, itens);
  return itens;
}

async function buscarMapaVigencia(titulo: string) {
  if (cacheMapa.has(titulo)) return cacheMapa.get(titulo)!;
  if (!supabase) return [];
  const { data } = await supabase
    .from('v_mapa_vigencia_normativa')
    .select('norma_id,titulo,status_norma,dispositivo,status_dispositivo,norma_responsavel,data_efeito,observacoes,conferido')
    .eq('titulo', titulo)
    .eq('conferido', true);
  const itens = (data || []) as MapaVigencia[];
  cacheMapa.set(titulo, itens);
  return itens;
}

function criarLinhaTempo(itens: LinhaTempo[]) {
  const bloco = document.createElement('div');
  bloco.className = 'norm-timeline-block';
  bloco.dataset.normTimeline = 'true';

  const cab = document.createElement('div');
  cab.className = 'norm-timeline-head';
  cab.innerHTML = '<strong>Linha do tempo normativa</strong><span>Redação original → alterações → redação aplicável</span>';
  bloco.append(cab);

  const trilha = document.createElement('div');
  trilha.className = 'norm-timeline-track';

  itens.forEach((item, indice) => {
    const passo = document.createElement('div');
    passo.className = 'norm-timeline-step';
    const data = formatarData(item.vigencia_inicio || item.data_alteracao);
    const tipo = item.tipo_alteracao.replaceAll('_', ' ');
    passo.innerHTML = `<div class="norm-dot">${indice + 1}</div><div class="norm-step-content"><b>${item.norma_alteradora}</b><small>${data ? `${data} • ` : ''}${tipo}${item.dispositivo_base ? ` • ${item.dispositivo_base}` : ''}</small>${item.texto_novo ? `<p>${item.texto_novo}</p>` : ''}${item.observacoes ? `<em>${item.observacoes}</em>` : ''}</div>`;
    trilha.append(passo);
  });

  bloco.append(trilha);
  return bloco;
}

function criarMapaVigencia(itens: MapaVigencia[]) {
  const bloco = document.createElement('div');
  bloco.className = 'norm-vigencia-block';
  bloco.dataset.normVigencia = 'true';

  const resumo = itens.reduce<Record<string, number>>((acc, item) => {
    acc[item.status_dispositivo] = (acc[item.status_dispositivo] || 0) + 1;
    return acc;
  }, {});

  const cab = document.createElement('div');
  cab.className = 'norm-vigencia-head';
  cab.innerHTML = `<strong>Mapa de vigência por dispositivo</strong><span>${Object.entries(resumo).map(([s, n]) => `${tituloStatus(s)}: ${n}`).join(' • ')}</span>`;
  bloco.append(cab);

  const lista = document.createElement('div');
  lista.className = 'norm-vigencia-list';
  itens.forEach((item) => {
    const row = document.createElement('div');
    row.className = 'norm-vigencia-row';
    row.innerHTML = `<div><b>${item.dispositivo}</b><small>${item.norma_responsavel ? `Responsável: ${item.norma_responsavel}` : ''}${item.data_efeito ? `${item.norma_responsavel ? ' • ' : ''}Efeito: ${formatarData(item.data_efeito)}` : ''}</small>${item.observacoes ? `<p>${item.observacoes}</p>` : ''}</div><span class="norm-status norm-status-${item.status_dispositivo}">${tituloStatus(item.status_dispositivo)}</span>`;
    lista.append(row);
  });
  bloco.append(lista);
  return bloco;
}

async function enriquecerConsultaStatus(section: HTMLElement) {
  if (section.dataset.timelineChecked === 'true') return;
  const marcador = section.querySelector('.structured-head > div > span')?.textContent?.trim();
  if (marcador !== 'VERIFICAÇÃO DE VIGÊNCIA') return;
  section.dataset.timelineChecked = 'true';

  const titulo = section.querySelector('.primary-block p b')?.textContent?.trim();
  if (!titulo) return;

  const [linha, mapa] = await Promise.all([buscarLinhaTempo(titulo), buscarMapaVigencia(titulo)]);
  if (!linha.length && !mapa.length) return;

  const referencia = section.querySelector('.norm-chain') || section.querySelector('.primary-block');
  if (!referencia) return;

  let anchor: Element = referencia;
  if (linha.length) {
    const blocoLinha = criarLinhaTempo(linha);
    anchor.insertAdjacentElement('afterend', blocoLinha);
    anchor = blocoLinha;
  }
  if (mapa.length) {
    const blocoMapa = criarMapaVigencia(mapa);
    anchor.insertAdjacentElement('afterend', blocoMapa);
  }
}

async function enriquecerBase() {
  if (!supabase) return;
  const rows = Array.from(document.querySelectorAll<HTMLElement>('.table .tr:not(.head):not([data-norm-audit-checked="true"])'));
  await Promise.all(rows.map(async (row) => {
    row.dataset.normAuditChecked = 'true';
    const titulo = row.children[0]?.querySelector('b')?.textContent?.trim();
    if (!titulo) return;
    const status = row.children[2]?.querySelector('.badge')?.textContent?.trim();
    if (status !== 'Ato alterador' && status !== 'Parcialmente vigente') return;

    const [linha, mapa] = await Promise.all([buscarLinhaTempo(titulo), buscarMapaVigencia(titulo)]);
    if (!linha.length && !mapa.length) return;

    const coluna = row.children[1] as HTMLElement | undefined;
    if (!coluna || coluna.querySelector('[data-norm-audit-summary="true"]')) return;
    const resumo = document.createElement('small');
    resumo.dataset.normAuditSummary = 'true';
    resumo.className = 'norm-audit-summary';
    resumo.textContent = linha.length
      ? `${linha.length} alteração(ões) mapeada(s) em nível de dispositivo.`
      : `${mapa.length} bloco(s) de vigência mapeado(s) em nível de dispositivo.`;
    coluna.append(resumo);
  }));
}

async function executar() {
  const secoes = Array.from(document.querySelectorAll<HTMLElement>('.structured-answer:not([data-timeline-checked="true"])'));
  await Promise.all(secoes.map(enriquecerConsultaStatus));
  await enriquecerBase();
}

function agendar() {
  window.clearTimeout(timer);
  timer = window.setTimeout(() => { void executar(); }, 150);
}

if (typeof window !== 'undefined') {
  window.addEventListener('DOMContentLoaded', () => {
    const root = document.getElementById('root');
    if (!root) return;
    const observer = new MutationObserver(agendar);
    observer.observe(root, { childList: true, subtree: true });
    agendar();
  });
}
