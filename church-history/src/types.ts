export type NodeType = 'tradition' | 'council' | 'schism' | 'event' | 'figure';

/** How a tradition describes its own relation to the apostolic church. */
export type Claim = 'continuity' | 'reform' | 'renewal' | 'restoration' | 'other';

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
  /** One sentence on how the tradition sees itself, in its own terms. */
  self?: string;
  claim?: Claim;
  importance: 1 | 2 | 3;
  sources?: string[];
}
