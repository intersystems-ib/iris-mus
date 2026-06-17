import { useState } from "react";
import type { GameState, PlayerId } from "../../../domain/game.types";
import { ActionPanel } from "./ActionPanel";
import { EventTimeline } from "./EventTimeline";
import { PendingBetPanel } from "./PendingBetPanel";
import { PlayerSeat } from "./PlayerSeat";
import { ScoreBoard } from "./ScoreBoard";
import { DiscardPanel } from "./DiscardPanel";

interface GameTableProps {
  gameState: GameState;
  perspectivePlayerId?: PlayerId;
  onRefresh: () => void;
}

export function GameTable({
  gameState,
  perspectivePlayerId,
  onRefresh,
}: GameTableProps) {
  const [selectedPlayerId, setSelectedPlayerId] = useState<PlayerId>(
    perspectivePlayerId ?? "P1"
  );

  const phase = gameState.phase;
  const hand = gameState.hand;

  return (
    <main className="game-table-page">
      <ScoreBoard gameState={gameState} />

      <section className="game-status-panel">
        <div>
          <span>Partida</span>
          <strong>{gameState.gameId}</strong>
        </div>

        <div>
          <span>Estado</span>
          <strong>{gameState.status}</strong>
        </div>

        <div>
          <span>Mano</span>
          <strong>{gameState.handNumber}</strong>
        </div>

        <div>
          <span>Fase</span>
          <strong>{phase}</strong>
        </div>

        <div>
          <span>Turno</span>
          <strong>{gameState.turnPlayerId || "-"}</strong>
        </div>
      </section>

      <section className="table-layout">
        <div className="seat-area seat-top">
          <PlayerSeat
            gameState={gameState}
            playerId="P3"
            perspectivePlayerId={perspectivePlayerId}
          />
        </div>

        <div className="seat-area seat-left">
          <PlayerSeat
            gameState={gameState}
            playerId="P2"
            perspectivePlayerId={perspectivePlayerId}
          />
        </div>

        <div className="table-center">
          <div className="table-felt">
            <h2>{phase}</h2>
            <p>Mano {hand?.handNumber ?? gameState.handNumber}</p>
            {gameState.winnerTeam && (
              <strong>Ganador: Equipo {gameState.winnerTeam}</strong>
            )}
          </div>
        </div>

        <div className="seat-area seat-right">
          <PlayerSeat
            gameState={gameState}
            playerId="P4"
            perspectivePlayerId={perspectivePlayerId}
          />
        </div>

        <div className="seat-area seat-bottom">
          <PlayerSeat
            gameState={gameState}
            playerId="P1"
            perspectivePlayerId={perspectivePlayerId}
          />
        </div>
      </section>

      <section className="game-side-panels">
        {gameState.phase === "descartes" ? (
            <DiscardPanel
            gameState={gameState}
            onDiscardsSubmitted={onRefresh}
            />
        ) : (
            <ActionPanel
            gameState={gameState}
            selectedPlayerId={selectedPlayerId}
            onSelectedPlayerChange={setSelectedPlayerId}
            onActionExecuted={onRefresh}
            />
        )}

        <PendingBetPanel gameState={gameState} />

        <EventTimeline actions={gameState.hand?.actions ?? []} />
        </section>
    </main>
  );
}