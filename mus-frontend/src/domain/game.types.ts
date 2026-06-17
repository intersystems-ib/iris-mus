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
  | "ordago";

export interface Score {
  teamA: number;
  teamB: number;
}

export interface Player {
  id: PlayerId;
  name: string;
  team: TeamId;
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
  type: ActionType | "descartes";
  phase: Phase;
  playerId?: PlayerId | "ALL";
  team?: TeamId;
  amount?: number;
  createdAt?: string;
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