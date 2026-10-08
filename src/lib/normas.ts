import type { Norma, StatusNorma } from '../types';

export const STATUS_ORDEM: Record<StatusNorma, number> = {
  'Vigente': 0,
  'Vigente com alterações': 1,
  'Parcialmente vigente': 2,
  'Ato alterador': 3,
  'Vigência a confirmar': 4,
  'Superada materialmente': 5,
  'Revogada': 6,
};

export function normalizarStatus(status?: string): StatusNorma {
  const valor = (status || '').trim().toLowerCase();
  if (valor === 'vigente') return 'Vigente';
  if (valor === 'alterada' || valor === 'vigente_com_alteracoes' || valor === 'vigente com alterações') return 'Vigente com alterações';
  if (valor === 'parcialmente_vigente' || valor === 'parcialmente vigente') return 'Parcialmente vigente';
  if (valor === 'ato_alterador' || valor === 'ato alterador') return 'Ato alterador';
  if (valor === 'revogada' || valor === 'revogado') return 'Revogada';
  if (valor === 'superada_materialmente' || valor === 'superada materialmente') return 'Superada materialmente';
  return 'Vigência a confirmar';
}

export function statusSlug(status: StatusNorma) {
  return status
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replaceAll(' ', '-');
}

export function podeFundamentar(norma: Norma) {
  if (norma.usarComoFundamento === false) return false;
  return !['Revogada', 'Superada materialmente', 'Vigência a confirmar', 'Ato alterador', 'Parcialmente vigente'].includes(norma.status);
}

export function exigeAlerta(norma: Pick<Norma, 'status'>) {
  return norma.status !== 'Vigente';
}

export function ordenarPorSeguranca<T extends { status?: string; relevancia?: number }>(itens: T[]) {
  return [...itens].sort((a, b) => {
    const sa = normalizarStatus(a.status);
    const sb = normalizarStatus(b.status);
    return STATUS_ORDEM[sa] - STATUS_ORDEM[sb] || (b.relevancia || 0) - (a.relevancia || 0);
  });
}
