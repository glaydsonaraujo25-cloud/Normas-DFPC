import { supabase } from './supabase';
import '../literal.css';

type DispositivoLiteral = {
  id: string;
  referencia: string;
  artigo?: string | null;
  texto_literal: string;
  pagina?: number | null;
  status: string;
  observacao_vigencia?: string | null;
  conferido: boolean;
};

const cacheNorma = new Map<string, string | null>();
const cacheDispositivos = new Map<string, DispositivoLiteral[]>();
let timer: number | undefined;

const normalizar = (valor: string) => valor
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '')
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, ' ')
  .trim();

const numeros = (valor: string) => new Set((valor.match(/\d+/g) || []).map(Number));

function pontuarReferencia(referenciaBusca: string, dispositivo: DispositivoLiteral) {
  const busca = normalizar(referenciaBusca);
  const ref = normalizar(dispositivo.referencia);
  if (!busca || !ref) return 0;
  if (busca === ref) return 100;
  let score = 0;
  if (ref.includes(busca) || busca.includes(ref)) score += 30;
  const nb = numeros(busca);
  const nr = numeros(ref);
  for (const n of nb) if (nr.has(n)) score += 12;
  const tokensBusca = new Set(busca.split(' ').filter((x) => x.length > 2));
  const tokensRef = new Set(ref.split(' ').filter((x) => x.length > 2));
  for (const t of tokensBusca) if (tokensRef.has(t)) score += 2;
  if (dispositivo.status === 'vigente') score += 3;
  if (dispositivo.status === 'alterado') score += 2;
  return score;
}

async function normaIdPorTitulo(titulo: string) {
  if (cacheNorma.has(titulo)) return cacheNorma.get(titulo) || null;
  if (!supabase) return null;
  const { data } = await supabase.from('normas').select('id').eq('titulo', titulo).maybeSingle();
  const id = data?.id || null;
  cacheNorma.set(titulo, id);
  return id;
}

async function dispositivosPorNorma(normaId: string) {
  if (cacheDispositivos.has(normaId)) return cacheDispositivos.get(normaId)!;
  if (!supabase) return [];
  const { data } = await supabase
    .from('dispositivos')
    .select('id,referencia,artigo,texto_literal,pagina,status,observacao_vigencia,conferido')
    .eq('norma_id', normaId)
    .eq('conferido', true)
    .in('status', ['vigente', 'alterado', 'vigencia_futura'])
    .limit(80);
  const itens = (data || []) as DispositivoLiteral[];
  cacheDispositivos.set(normaId, itens);
  return itens;
}

function criarBloco(dispositivo: DispositivoLiteral) {
  const bloco = document.createElement('div');
  bloco.className = 'literal-source-block';
  bloco.dataset.literalSource = 'true';

  const topo = document.createElement('div');
  topo.className = 'literal-source-head';
  const titulo = document.createElement('strong');
  titulo.textContent = 'Texto literal conferido';
  const selo = document.createElement('span');
  selo.className = `literal-status literal-${dispositivo.status}`;
  selo.textContent = dispositivo.status === 'vigencia_futura' ? 'Vigência futura' : dispositivo.status === 'alterado' ? 'Redação alterada/consolidada' : 'Vigente';
  topo.append(titulo, selo);

  const referencia = document.createElement('small');
  referencia.textContent = `${dispositivo.referencia}${dispositivo.pagina ? ` • pág. ${dispositivo.pagina}` : ''}`;

  const texto = document.createElement('blockquote');
  texto.textContent = dispositivo.texto_literal;

  bloco.append(topo, referencia, texto);
  if (dispositivo.observacao_vigencia) {
    const alerta = document.createElement('p');
    alerta.className = 'literal-vigencia-note';
    alerta.textContent = dispositivo.observacao_vigencia;
    bloco.append(alerta);
  }
  return bloco;
}

async function enriquecerArtigo(article: HTMLElement) {
  if (article.dataset.literalChecked === 'true') return;
  article.dataset.literalChecked = 'true';
  const titulo = article.querySelector('.result-title > b')?.textContent?.trim();
  const spanReferencia = Array.from(article.children).find((el) => el.tagName === 'SPAN') as HTMLElement | undefined;
  const referenciaBusca = spanReferencia?.textContent?.replace(/\s*•\s*pág\..*$/i, '').trim() || '';
  if (!titulo || !referenciaBusca) return;

  const normaId = await normaIdPorTitulo(titulo);
  if (!normaId) return;
  const dispositivos = await dispositivosPorNorma(normaId);
  if (!dispositivos.length) return;

  const ordenados = dispositivos
    .map((d) => ({ d, score: pontuarReferencia(referenciaBusca, d) }))
    .sort((a, b) => b.score - a.score);
  const melhor = ordenados[0];
  if (!melhor || melhor.score < 12) return;

  const paragrafoResumo = Array.from(article.children).find((el) => el.tagName === 'P');
  if (paragrafoResumo) paragrafoResumo.insertAdjacentElement('afterend', criarBloco(melhor.d));
  else article.append(criarBloco(melhor.d));
}

async function executar() {
  const artigos = document.querySelectorAll<HTMLElement>('.detailed-sources article:not([data-literal-checked="true"])');
  await Promise.all(Array.from(artigos).map(enriquecerArtigo));
}

function agendar() {
  window.clearTimeout(timer);
  timer = window.setTimeout(() => { void executar(); }, 120);
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
