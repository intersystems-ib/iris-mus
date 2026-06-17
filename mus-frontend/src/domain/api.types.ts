import type { GameState, ActionType, Phase, PlayerId, TeamId } from "./game.types";
import type { Tournament } from "./tournament.types";

export interface ApiResponse<T> {
  success: boolean;
  errorCode?: string;
  errorMessage?: string;
  statusCode?: number;
  payload?: T;
}

export interface CreateGameResponse {
  success: boolean;
  gameId: string;
  gameState?: GameState;
  [key: string]: unknown;
}

export interface GetGameStateResponse {
  success: boolean;
  gameState?: GameState;
  state?: GameState;
  [key: string]: unknown;
}

export interface PlayerActionRequest {
  playerId: PlayerId;
  phase: Phase;
  actionType: ActionType;
  amount?: number;
}

export interface PlayerActionResponse {
  success: boolean;
  gameId: string;
  updatedGameState?: GameState;
  actionEvent?: unknown;
  phaseClosed?: boolean;
  nextPlayerId?: PlayerId | "";
  errorCode?: string;
  errorMessage?: string;
  [key: string]: unknown;
}

export interface CreateTournamentResponse {
  success: boolean;
  tournamentId: string;
  tournament?: Tournament;
  payload?: Tournament;
  [key: string]: unknown;
}

export interface ListTournamentsResponse {
  success: boolean;
  tournaments?: Tournament[];
  items?: Tournament[];
  payload?: Tournament[];
  [key: string]: unknown;
}

export interface CreateGamePlayer {
  id: PlayerId;
  name: string;
  type: "human" | "agent";
  team: TeamId;
  agentProfile?: string;
}

export interface CreateGameRequest {
  players: CreateGamePlayer[];
}
