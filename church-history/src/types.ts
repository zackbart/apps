export type NodeType = 'tradition' | 'council' | 'schism' | 'event' | 'figure';

export interface HistoryNode {
  id: string;
  type: NodeType;
  name: string;
  start: number;
  end: number | null;
  parents?: string[];
  on?: string;
  splits?: string[];
  summary: string;
  why?: string;
  facts?: string[];
  sacraments?: string;
  today?: string;
  disputed?: string;
  outsideNicene?: boolean;
  importance: 1 | 2 | 3;
  sources?: string[];
}
