import type { GameState } from "../domain/game.types";

export function extractGameState(response: unknown): GameState | null {
  if (!response || typeof response !== "object") {
    return null;
  }

  const obj = response as Record<string, unknown>;

  if (isGameState(obj)) {
    return obj;
  }

  const candidates = [
    obj.gameState,
    obj.state,
    obj.payload,
    obj.updatedGameState,
  ];

  for (const candidate of candidates) {
    if (isGameState(candidate)) {
      return candidate;
    }
  }

  return null;
}

function isGameState(value: unknown): value is GameState {
  if (!value || typeof value !== "object") {
    return false;
  }

  const obj = value as Record<string, unknown>;

  return (
    typeof obj.status === "string" &&
    typeof obj.phase === "string" &&
    typeof obj.score === "object" &&
    obj.score !== null
  );
}