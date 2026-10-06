export type StatusNorma =
  | 'Vigente'
  | 'Vigente com alterações'
  | 'Parcialmente vigente'
  | 'Ato alterador'
  | 'Revogada'
  | 'Superada materialmente'
  | 'Vigência a confirmar';

export type TipoRelacaoNormativa =
  | 'altera'
  | 'revoga'
  | 'revogada_por'
  | 'complementa'
  | 'regulamenta'
  | 'substitui'
  | 'consolida';

export interface RelacaoNormativa {
  tipo: TipoRelacaoNormativa;
  normaRelacionada: string;
  dispositivo?: string;
  observacao?: string;
}

export interface Norma {
  id: string;
  tipo: string;
  numero: string;
  ano: number;
  titulo: string;
  assunto: string;
  orgao?: string;
  dataPublicacao?: string;
  vigenciaInicio?: string;
  vigenciaFim?: string | null;
  status: StatusNorma;
  statusDetalhado?: string;
  normaPrincipal?: boolean;
  usarComoFundamento?: boolean;
  ultimaVerificacao?: string;
  fonteOficial?: string;
  observacaoVigencia?: string;
  relacoes?: string[];
  relacoesEstruturadas?: RelacaoNormativa[];
  palavrasChave?: string[];
}
