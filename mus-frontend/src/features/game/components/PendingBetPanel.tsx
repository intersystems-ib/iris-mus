import type { GameState } from "../../../domain/game.types";

interface PendingBetPanelProps {
  gameState: GameState;
}

export function PendingBetPanel({ gameState }: PendingBetPanelProps) {
  const pendingBet =
    gameState.hand?.pendingBet ??
    (gameState.hand?.phaseState?.pendingBet as unknown);

  if (!pendingBet || typeof pendingBet !== "object") {
    return (
      <section className="pending-bet-panel muted">
        <h2>Envite pendiente</h2>
        <p>No hay envite pendiente.</p>
      </section>
    );
  }

  const bet = pendingBet as {
    type?: string;
    amount?: number;
    previousAmount?: number;
    openedByPlayerId?: string;
    openedByTeam?: string;
    lastRaisePlayerId?: string;
    lastRaiseTeam?: string;
    respondingTeam?: string;
    respondingPlayerId?: string;
    respondingPlayers?: string[];
    rejectedPlayers?: string[];
  };

  return (
    <section className="pending-bet-panel">
      <h2>Envite pendiente</h2>

      <div className="pending-bet-grid">
        <Info label="Tipo" value={bet.type ?? "-"} />
        <Info label="Importe" value={bet.amount ?? "-"} />
        <Info label="Anterior" value={bet.previousAmount ?? "-"} />
        <Info label="Última subida" value={bet.lastRaisePlayerId ?? "-"} />
        <Info label="Equipo responde" value={bet.respondingTeam ?? "-"} />
        <Info label="Turno sugerido" value={bet.respondingPlayerId ?? "-"} />
        <Info
          label="Pueden responder"
          value={bet.respondingPlayers?.join(", ") ?? "-"}
        />
        <Info
          label="Han rechazado"
          value={bet.rejectedPlayers?.join(", ") ?? "-"}
        />
      </div>
    </section>
  );
}

interface InfoProps {
  label: string;
  value: string | number;
}

function Info({ label, value }: InfoProps) {
  return (
    <div className="info-row">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}