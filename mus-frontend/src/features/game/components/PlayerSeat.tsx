import type { GameState, Player, PlayerId } from "../../../domain/game.types";
import { CardHand } from "./CardHand";

interface PlayerSeatProps {
  gameState: GameState;
  playerId: PlayerId;
  perspectivePlayerId?: PlayerId;
}

export function PlayerSeat({
  gameState,
  playerId,
  perspectivePlayerId,
}: PlayerSeatProps) {
  const players = normalizePlayersForView(gameState.players);
  const player = players.find((item) => item.id === playerId);

  const cards = getPlayerCards(gameState, playerId);

  const isTurn = gameState.turnPlayerId === playerId;
  const isDealer = gameState.dealerPlayerId === playerId;
  const isWinnerTeam =
    Boolean(gameState.winnerTeam) && player?.team === gameState.winnerTeam;

  const shouldHideCards =
    Boolean(perspectivePlayerId) && perspectivePlayerId !== playerId;

  return (
    <article
      className={[
        "player-seat",
        isTurn ? "is-turn" : "",
        isWinnerTeam ? "is-winner-team" : "",
      ]
        .filter(Boolean)
        .join(" ")}
    >
      <header className="player-seat-header">
        <div>
          <strong>{player?.name ?? playerId}</strong>
          <span>
            {playerId} · Equipo {player?.team ?? "-"}
          </span>
        </div>

        <div className="player-badges">
          {isDealer && <span className="badge">Mano</span>}
          {isTurn && <span className="badge active">Turno</span>}
        </div>
      </header>

      <CardHand cards={cards} hidden={shouldHideCards} />
    </article>
  );
}

function normalizePlayersForView(value: unknown): Player[] {
  if (Array.isArray(value)) {
    return value as Player[];
  }

  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;

    return Object.entries(obj).map(([id, rawPlayer]) => {
      if (rawPlayer && typeof rawPlayer === "object") {
        const player = rawPlayer as Record<string, unknown>;

        return {
          id: String(player.id ?? id) as PlayerId,
          name: String(player.name ?? player.displayName ?? id),
          team: String(player.team ?? player.teamId ?? "") as Player["team"],
        };
      }

      return {
        id: id as PlayerId,
        name: id,
        team: "" as Player["team"],
      };
    });
  }

  return [];
}

function getPlayerCards(gameState: GameState, playerId: PlayerId): string[] {
  const cards = gameState.hand?.cards;

  if (!cards || typeof cards !== "object") {
    return [];
  }

  const rawCards = (cards as Record<string, unknown>)[playerId];

  if (Array.isArray(rawCards)) {
    return rawCards.map(String);
  }

  return [];
}