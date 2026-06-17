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

export type DiscardsRequest = {
  discards: Record<PlayerId, string[]>;
};

const API_MODE = import.meta.env.VITE_API_MODE ?? "proxy";

const API_BASE_URL =
  API_MODE === "direct"
    ? import.meta.env.VITE_IRIS_API_URL
    : import.meta.env.VITE_MUS_API_BASE_URL ?? "/api/mus";

function buildUrl(path: string): string {
  const base = String(API_BASE_URL).replace(/\/$/, "");
  const cleanPath = path.startsWith("/") ? path : `/${path}`;

  return `${base}${cleanPath}`;
}

async function requestJson<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const url = buildUrl(path);

  const response = await fetch(url, {
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      ...(options.headers ?? {}),
    },
    ...options,
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
      body: JSON.stringify(request),
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
      body: JSON.stringify({}),
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
      body: JSON.stringify({
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
      body: JSON.stringify({}),
    });
  },

  createTournament(
    request: CreateTournamentRequest
  ): Promise<CreateTournamentResponse> {
    return requestJson<CreateTournamentResponse>("/tournaments", {
      method: "POST",
      body: JSON.stringify(request),
    });
  },

  listTournaments(): Promise<ListTournamentsResponse> {
    return requestJson<ListTournamentsResponse>("/tournaments", {
      method: "GET",
    });
  },

  submitDiscards(gameId: string, request: DiscardsRequest): Promise<GetGameStateResponse> {
    return requestJson<GetGameStateResponse>(`/games/${gameId}/discards`, {
      method: "POST",
      body: JSON.stringify(request),
    });
  },

  getTournament(tournamentId: string): Promise<unknown> {
    return requestJson<unknown>(`/tournaments/${tournamentId}`, {
      method: "GET",
    });
  },

  startTournament(tournamentId: string): Promise<unknown> {
    return requestJson<unknown>(`/tournaments/${tournamentId}/start`, {
      method: "POST",
      body: JSON.stringify({}),
    });
  },
};