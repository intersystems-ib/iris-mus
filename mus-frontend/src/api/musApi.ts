import type {
  CreateGameRequest,
  CreateGameResponse,
  GetGameStateResponse,
  PlayerActionRequest,
  PlayerActionResponse,
  CreateTournamentResponse,
  ListTournamentsResponse,
} from "../domain/api.types";
import type { PlayerId } from "../domain/game.types";
import type { CreateTournamentRequest } from "../domain/tournament.types";

export type GenerateTournamentTeamsRequest = {
  teamCount: number;
  targetScore?: number;
  humanPlayerName?: string;
};

export type GenerateTournamentTeamsResponse = {
  success: boolean;
  statusCode: number;
  tournamentName?: string;
  teams?: CreateTournamentRequest["teams"];
  generatedBy?: "llm" | "fallback";
  errorCode?: string;
  errorMessage?: string;
};

export type DiscardsRequest = {
  discards: Record<PlayerId, string[]>;
};

export interface AgentDiscardsResponse {
  success: boolean;
  statusCode: number;
  gameId: number | string;
  playerId: PlayerId;
  phase: string;
  cards: string[];
  discards: string[];
  cutsMus: boolean;
  discardCount: number;
  errorCode?: string;
  errorMessage?: string;
}

export interface AgentActionResponse {
  success: boolean;
  statusCode: number;
  gameId: number | string;
  playerId: PlayerId;
  phase: string;
  turnPlayerId?: PlayerId;
  actionType: string;
  type?: string;
  amount: number;
  payload?: Record<string, unknown>;
  reason?: string;
  confidence?: number;
  errorCode?: string;
  errorMessage?: string;
}

const API_MODE = import.meta.env.VITE_API_MODE ?? "proxy";

const API_BASE_URL =
  API_MODE === "direct"
    ? import.meta.env.VITE_IRIS_API_URL
    : import.meta.env.VITE_MUS_API_BASE_URL ?? "/api/mus";

const JSON_CONTENT_TYPE = "application/json; charset=utf-8";

function buildUrl(path: string): string {
  const base = String(API_BASE_URL).replace(/\/$/, "");
  const cleanPath = path.startsWith("/") ? path : `/${path}`;

  return `${base}${cleanPath}`;
}

function jsonBody(value: unknown): Blob {
  return new Blob([JSON.stringify(value)], {
    type: JSON_CONTENT_TYPE,
  });
}

function buildRequestHeaders(options: RequestInit): Headers {
  const headers = new Headers(options.headers);

  if (!headers.has("Accept")) {
    headers.set("Accept", "application/json");
  }

  if (options.body !== undefined && options.body !== null) {
    const contentType = headers.get("Content-Type");

    if (!contentType) {
      headers.set("Content-Type", JSON_CONTENT_TYPE);
    } else if (
      contentType.toLowerCase().startsWith("application/json") &&
      !contentType.toLowerCase().includes("charset=")
    ) {
      headers.set("Content-Type", JSON_CONTENT_TYPE);
    }
  }

  return headers;
}

async function requestJson<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const url = buildUrl(path);

  const response = await fetch(url, {
    ...options,
    headers: buildRequestHeaders(options),
  });

  const text = await response.text();
  let data: unknown = null;

  if (text.trim().length > 0) {
    try {
      data = JSON.parse(text);
    } catch {
      throw new Error(`Respuesta no JSON desde ${url}: ${text}`);
    }
  }

  if (!response.ok) {
    const errorMessage =
      typeof data === "object" &&
      data !== null &&
      "errorMessage" in data
        ? String((data as { errorMessage?: unknown }).errorMessage)
        : `HTTP ${response.status} ${response.statusText}`;

    throw new Error(errorMessage);
  }

  return data as T;
}

export const musApi = {
  createGame(request: CreateGameRequest): Promise<CreateGameResponse> {
    return requestJson<CreateGameResponse>("/games", {
      method: "POST",
      body: jsonBody(request),
    });
  },

  getGame(gameId: string): Promise<GetGameStateResponse> {
    return requestJson<GetGameStateResponse>(`/games/${gameId}`, {
      method: "GET",
    });
  },

  startGame(gameId: string): Promise<GetGameStateResponse> {
    return requestJson<GetGameStateResponse>(`/games/${gameId}/start`, {
      method: "POST",
      body: jsonBody({}),
    });
  },

  getGameState(gameId: string): Promise<GetGameStateResponse> {
    return requestJson<GetGameStateResponse>(`/games/${gameId}/state`, {
      method: "GET",
    });
  },

  playerAction(
    gameId: string,
    action: PlayerActionRequest
  ): Promise<PlayerActionResponse> {
    return requestJson<PlayerActionResponse>(`/games/${gameId}/actions`, {
      method: "POST",
      body: jsonBody({
        playerId: action.playerId,
        phase: action.phase,
        type: action.actionType,
        amount: action.amount ?? 0,
      }),
    });
  },

  startNextHand(gameId: string): Promise<GetGameStateResponse> {
    return requestJson<GetGameStateResponse>(`/games/${gameId}/hands/next`, {
      method: "POST",
      body: jsonBody({}),
    });
  },

  createTournament(
    request: CreateTournamentRequest
  ): Promise<CreateTournamentResponse> {
    return requestJson<CreateTournamentResponse>("/tournaments", {
      method: "POST",
      body: jsonBody(request),
    });
  },

  generateTournamentTeams(
    request: GenerateTournamentTeamsRequest
  ): Promise<GenerateTournamentTeamsResponse> {
    return requestJson<GenerateTournamentTeamsResponse>("/tournaments/team-suggestions", {
      method: "POST",
      body: jsonBody(request),
    });
  },

  listTournaments(): Promise<ListTournamentsResponse> {
    return requestJson<ListTournamentsResponse>("/tournaments", {
      method: "GET",
    });
  },

  submitDiscards(
    gameId: string,
    request: DiscardsRequest
  ): Promise<GetGameStateResponse> {
    return requestJson<GetGameStateResponse>(`/games/${gameId}/discards`, {
      method: "POST",
      body: jsonBody(request),
    });
  },

  getTournament(tournamentId: string): Promise<unknown> {
    return requestJson<unknown>(`/tournaments/${tournamentId}`, {
      method: "GET",
    });
  },

  deleteTournament(tournamentId: string): Promise<{ success: boolean }> {
    return requestJson(`/tournaments/${tournamentId}`, {
      method: "DELETE",
    });
  },

  startTournamentTable(tableId: string | number): Promise<unknown> {
    return requestJson<unknown>(`/tables/${tableId}/start`, {
      method: "POST",
      body: jsonBody({}),
    });
  },

  completeTournamentTable(tableId: string | number): Promise<unknown> {
    return requestJson<unknown>(`/tables/${tableId}/complete`, {
      method: "POST",
      body: jsonBody({}),
    });
  },

  simulateTournamentTable(
    tableId: string | number
  ): Promise<CreateTournamentResponse> {
    return requestJson(`/tables/${tableId}/simulate`, {
      method: "POST",
      body: jsonBody({}),
    });
  },

  getAgentDiscards(
    gameId: string,
    playerId: PlayerId
  ): Promise<AgentDiscardsResponse> {
    return requestJson<AgentDiscardsResponse>(
      `/games/${gameId}/agents/${playerId}/discards`,
      {
        method: "GET",
      }
    );
  },

  getAgentAction(
    gameId: string,
    playerId: PlayerId
  ): Promise<AgentActionResponse> {
    return requestJson<AgentActionResponse>(
      `/games/${gameId}/agents/${playerId}/action`,
      { method: "GET" }
    );
  },
};
