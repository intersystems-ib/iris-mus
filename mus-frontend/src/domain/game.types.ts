export type TeamId = "A" | "B";

export type PlayerId = "P1" | "P2" | "P3" | "P4";

export type GameStatus =
  | "created"
  | "started"
  | "handClosed"
  | "finished";

export type Phase =
  | "descartes"
  | "grande"
  | "chica"
  | "pares"
  | "juego"
  | "punto"
  | "manoCerrada";

export type ActionType =
  | "pasar"
  | "envidar"
  | "querer"
  | "no_querer"
  | "ordago"
  | "descartes"
  | "declarar_pares"
  | "declarar_juego"
  | "fase_saltada"
  | "fase_auto_resuelta";

export interface Score {
  teamA: number;
  teamB: number;
}

export interface Player {
  id: PlayerId;
  name: string;
  team: TeamId;
  type?: "human" | "agent" | string;
  playerType?: "human" | "agent" | string;
  kind?: "human" | "agent" | string;
  agentProfile?: string;
  profile?: string;
  isAgent?: boolean;
}

export interface PendingBet {
  type: "envidar" | "ordago";
  amount: number;
  previousAmount: number;
  openedByPlayerId: PlayerId;
  openedByTeam: TeamId;
  lastRaisePlayerId: PlayerId;
  lastRaiseTeam: TeamId;
  respondingTeam: TeamId;
  respondingPlayerId: PlayerId;
  respondingPlayers: PlayerId[];
  rejectedPlayers?: PlayerId[];
  acceptedByPlayerId?: PlayerId;
  acceptedByTeam?: TeamId;
}

export interface GameAction {
  type: ActionType | string;
  phase: Phase | string;
  playerId?: PlayerId | "ALL" | string;
  team?: TeamId | string;
  amount?: number;
  createdAt?: string;
  label?: string;
  hasValue?: boolean;
  value?: number;
  points?: number;
  pointsAwarded?: number;
  winnerTeam?: TeamId | string;
  reason?: string;
  [key: string]: unknown;
}

export interface Hand {
  status: string;
  handNumber: number;
  dealerPlayerId: PlayerId;
  phase: Phase;
  turnPlayerId: PlayerId | "";
  pendingBet?: PendingBet | null;
  cards: Record<PlayerId, string[]>;
  remainingDeck?: string[];
  discardRound?: number;
  discardsClosed?: boolean | number;
  discardsApplied?: boolean | number;
  actions: GameAction[];
  phaseState: Record<string, unknown>;
  completedPhases?: Record<string, unknown>;
}

export interface GameState {
  status: GameStatus;
  targetScore: number;
  winnerTeam?: TeamId;
  nextAction: string;
  score: Score;
  players: Player[];
  gameId: string;
  currentHandId: string;
  handNumber: number;
  dealerPlayerId: PlayerId;
  phase: Phase;
  turnPlayerId: PlayerId | "";
  discardRound?: number;
  discardsClosed?: boolean | number;
  hand: Hand;
}