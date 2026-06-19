import type { GameState, TeamId } from "../../../domain/game.types";

interface HandResultPanelProps {
  gameState: GameState;
  canStartNextHand: boolean;
  isStartingNextHand: boolean;
  onStartNextHand: () => void;
}

type PhaseResult = {
  phase: string;
  label: string;
  winnerTeam: string;
  playerId: string;
  points: number | string | null;
  reason: string;
};

const RESULT_PHASES = ["grande", "chica", "pares", "juego", "punto"];

export function HandResultPanel({
  gameState,
  canStartNextHand,
  isStartingNextHand,
  onStartNextHand,
}: HandResultPanelProps) {
  const completedPhases = gameState.hand?.completedPhases;

  if (!completedPhases || typeof completedPhases !== "object") {
    return null;
  }

  const results = RESULT_PHASES.map((phase) =>
    buildPhaseResult(phase, completedPhases as Record<string, unknown>)
  ).filter(Boolean) as PhaseResult[];

  const totals = calculateTotals(results);

  if (results.length === 0) {
    return null;
  }

  return (
    <section className="hand-result-panel">
      <header>
        <h2>Resultado de la mano</h2>
        <span>Mano {gameState.handNumber}</span>
      </header>

      <div className="hand-result-total-grid">
        <div>
          <span>Equipo A</span>
          <strong>{totals.A}</strong>
        </div>

        <div>
          <span>Equipo B</span>
          <strong>{totals.B}</strong>
        </div>
      </div>

      <ol className="hand-result-list">
        {results.map((result) => (
          <li key={result.phase} className="hand-result-item">
            <div>
              <strong>{result.label}</strong>
              <span>{formatPhaseOutcome(result)}</span>
            </div>

            <b>{formatPoints(result.points)}</b>
          </li>
        ))}
      </ol>

      <p className="hand-result-score">
        Marcador actual: Equipo A {gameState.score?.teamA ?? 0} · Equipo B{" "}
        {gameState.score?.teamB ?? 0}
      </p>

      {canStartNextHand ? (
        <button
          type="button"
          className="primary-button hand-result-next-button"
          onClick={onStartNextHand}
          disabled={isStartingNextHand}
        >
          {isStartingNextHand ? "Repartiendo..." : "Repartir nueva mano"}
        </button>
      ) : (
        <p className="muted-text hand-result-finished-message">
          La partida ha finalizado o ya se ha alcanzado el objetivo de puntos.
        </p>
      )}
    </section>
  );
}

function buildPhaseResult(
  phase: string,
  completedPhases: Record<string, unknown>
): PhaseResult | null {
  const rawPhaseState = completedPhases[phase];

  if (!rawPhaseState || typeof rawPhaseState !== "object") {
    return null;
  }

  const phaseState = rawPhaseState as Record<string, unknown>;
  const winner = getObject(phaseState, "winner");

  const winnerTeam =
    getString(phaseState, "winnerTeam") || getString(winner, "team");

  const playerId = getString(winner, "playerId");

  const points =
    getNumber(phaseState, "pointsAwarded") ??
    getNumber(phaseState, "points") ??
    getStringOrNull(phaseState, "pointsAwarded");

  const reason =
    getString(phaseState, "reason") || inferReasonFromPhaseState(phaseState);

  return {
    phase,
    label: formatPhase(phase),
    winnerTeam,
    playerId,
    points,
    reason,
  };
}

function calculateTotals(results: PhaseResult[]): Record<TeamId, number> {
  const totals: Record<TeamId, number> = {
    A: 0,
    B: 0,
  };

  for (const result of results) {
    if (result.winnerTeam !== "A" && result.winnerTeam !== "B") {
      continue;
    }

    if (typeof result.points !== "number") {
      continue;
    }

    totals[result.winnerTeam] += result.points;
  }

  return totals;
}

function formatPhaseOutcome(result: PhaseResult): string {
  const parts: string[] = [];

  if (result.winnerTeam) {
    parts.push(`Equipo ${result.winnerTeam}`);
  }

  if (result.playerId) {
    parts.push(result.playerId);
  }

  if (result.reason) {
    parts.push(formatReason(result.reason));
  }

  if (parts.length === 0) {
    return "Sin puntos";
  }

  return parts.join(" · ");
}

function formatPoints(points: number | string | null): string {
  if (points === null || points === "") {
    return "0";
  }

  if (points === "ordago") {
    return "Órdago";
  }

  return `${points}`;
}

function formatPhase(phase: string): string {
  const labels: Record<string, string> = {
    grande: "Grande",
    chica: "Chica",
    pares: "Pares",
    juego: "Juego",
    punto: "Punto",
  };

  return labels[phase] ?? phase;
}

function formatReason(reason: string): string {
  const labels: Record<string, string> = {
    all_players_passed: "todos pasaron",
    accepted_bet: "envite aceptado",
    bet_rejected: "envite rechazado",
    no_players_with_pares: "nadie tenía pares",
    no_players_with_juego: "nadie tenía juego",
    only_team_with_pares: "solo un equipo tenía pares",
    only_team_with_juego: "solo un equipo tenía juego",
    no_participants: "sin participantes",
    ordago_accepted: "órdago aceptado",
  };

  return labels[reason] ?? reason;
}

function inferReasonFromPhaseState(phaseState: Record<string, unknown>): string {
  const status = getString(phaseState, "status");

  if (status === "skipped") {
    return getString(phaseState, "reason") || "fase saltada";
  }

  if (getObject(phaseState, "acceptedBet")) {
    return "accepted_bet";
  }

  if (getObject(phaseState, "rejectedBet")) {
    return "bet_rejected";
  }

  return "";
}

function getObject(
  source: Record<string, unknown> | null,
  key: string
): Record<string, unknown> | null {
  if (!source) {
    return null;
  }

  const value = source[key];

  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as Record<string, unknown>;
}

function getString(
  source: Record<string, unknown> | null,
  key: string
): string {
  if (!source) {
    return "";
  }

  const value = source[key];

  return typeof value === "string" ? value : "";
}

function getStringOrNull(
  source: Record<string, unknown>,
  key: string
): string | null {
  const value = source[key];

  return typeof value === "string" ? value : null;
}

function getNumber(
  source: Record<string, unknown>,
  key: string
): number | null {
  const value = source[key];

  if (typeof value === "number") {
    return value;
  }

  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);

    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}