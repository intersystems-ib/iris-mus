import type { GameState, Player, PlayerId } from "../../../domain/game.types";

interface PhaseSummaryPanelProps {
  gameState: GameState;
}

const PLAYER_IDS: PlayerId[] = ["P1", "P2", "P3", "P4"];

export function PhaseSummaryPanel({ gameState }: PhaseSummaryPanelProps) {
  const phase = String(gameState.phase ?? "");
  const activeSummary = getCurrentPhaseSummary(gameState);

  const completedPares = getCompletedPhase(gameState, "pares");
  const completedJuego = getCompletedPhase(gameState, "juego");

  const shouldShowCurrent =
    phase === "pares" || phase === "juego" || phase === "punto";

  if (!shouldShowCurrent && !completedPares && !completedJuego) {
    return null;
  }

  return (
    <section className="phase-summary-panel">
      <h2>Resumen de jugada</h2>

      {shouldShowCurrent && activeSummary && (
        <PhaseSummaryBlock
          title={`Fase actual: ${formatPhase(phase)}`}
          phase={phase}
          summary={activeSummary}
          players={gameState.players}
        />
      )}

      {completedPares && phase !== "pares" && (
        <PhaseSummaryBlock
          title="Pares"
          phase="pares"
          summary={completedPares}
          players={gameState.players}
        />
      )}

      {completedJuego && phase !== "juego" && (
        <PhaseSummaryBlock
          title="Juego"
          phase="juego"
          summary={completedJuego}
          players={gameState.players}
        />
      )}
    </section>
  );
}

interface PhaseSummaryBlockProps {
  title: string;
  phase: string;
  summary: Record<string, unknown>;
  players: Player[];
}

function PhaseSummaryBlock({
  title,
  phase,
  summary,
  players,
}: PhaseSummaryBlockProps) {
  const eligibility = getObject(summary, "eligibility");
  const participants = getStringArray(summary, "participants");
  const status = getString(summary, "status");
  const reason = getString(summary, "reason");
  const winnerTeam = getString(summary, "winnerTeam");
  const pointsAwarded = getNumber(summary, "pointsAwarded");

  return (
    <div className="phase-summary-block">
      <header>
        <h3>{title}</h3>
        {status && <span className={`phase-status phase-status-${status}`}>{formatStatus(status)}</span>}
      </header>

      {eligibility ? (
        <div className="phase-declaration-grid">
          {PLAYER_IDS.map((playerId) => {
            const player = players.find((item) => item.id === playerId);
            const info = getObject(eligibility, playerId);
            const participates = participants.includes(playerId);

            return (
              <div
                key={`${phase}-${playerId}`}
                className={[
                  "phase-declaration-card",
                  participates ? "phase-declaration-yes" : "phase-declaration-no",
                ]
                  .filter(Boolean)
                  .join(" ")}
              >
                <strong>
                  {playerId}
                  {player?.name ? ` · ${player.name}` : ""}
                </strong>

                <span>{player?.team ? `Equipo ${player.team}` : "Equipo -"}</span>

                <b>{participates ? getYesLabel(phase) : getNoLabel(phase)}</b>

                {info && <small>{formatEligibilityInfo(phase, info)}</small>}
              </div>
            );
          })}
        </div>
      ) : (
        <p className="muted-text">No hay declaraciones disponibles para esta fase.</p>
      )}

      {(winnerTeam || pointsAwarded !== null || reason) && (
        <p className="phase-result-line">
          {winnerTeam && <span>Gana Equipo {winnerTeam}</span>}
          {pointsAwarded !== null && (
            <span>
              {pointsAwarded} punto{pointsAwarded === 1 ? "" : "s"}
            </span>
          )}
          {reason && <span>{formatReason(reason)}</span>}
        </p>
      )}
    </div>
  );
}

function getCurrentPhaseSummary(gameState: GameState): Record<string, unknown> | null {
  const phaseState = gameState.hand?.phaseState;

  if (phaseState && typeof phaseState === "object") {
    return phaseState as Record<string, unknown>;
  }

  return null;
}

function getCompletedPhase(
  gameState: GameState,
  phase: string
): Record<string, unknown> | null {
  const completedPhases = gameState.hand?.completedPhases;

  if (!completedPhases || typeof completedPhases !== "object") {
    return null;
  }

  const value = (completedPhases as Record<string, unknown>)[phase];

  if (!value || typeof value !== "object") {
    return null;
  }

  return value as Record<string, unknown>;
}

function formatPhase(phase: string): string {
  const labels: Record<string, string> = {
    descartes: "Descartes",
    grande: "Grande",
    chica: "Chica",
    pares: "Pares",
    juego: "Juego",
    punto: "Punto",
    manoCerrada: "Mano cerrada",
  };

  return labels[phase] ?? phase;
}

function formatStatus(status: string): string {
  const labels: Record<string, string> = {
    open: "Abierta",
    closed: "Cerrada",
    skipped: "Saltada",
    autoResolved: "Auto-resuelta",
  };

  return labels[status] ?? status;
}

function getYesLabel(phase: string): string {
  if (phase === "pares") return "Sí a pares";
  if (phase === "juego") return "Sí a juego";
  return "Participa";
}

function getNoLabel(phase: string): string {
  if (phase === "pares") return "No a pares";
  if (phase === "juego") return "No a juego";
  return "No participa";
}

function formatEligibilityInfo(
  phase: string,
  info: Record<string, unknown>
): string {
  if (phase === "pares") {
    const type = getString(info, "type");

    if (!type || type === "none") {
      return "Sin pares";
    }

    const labels: Record<string, string> = {
      pares: "Pares",
      medias: "Medias",
      duples: "Duples",
    };

    return labels[type] ?? type;
  }

  if (phase === "juego") {
    const total = getNumber(info, "total");
    const hasJuego = getBoolean(info, "hasJuego");

    if (total === null) {
      return hasJuego ? "Con juego" : "Sin juego";
    }

    return hasJuego ? `Juego ${total}` : `Punto ${total}`;
  }

  if (phase === "punto") {
    const total = getNumber(info, "total");

    return total === null ? "Punto" : `Punto ${total}`;
  }

  return "";
}

function formatReason(reason: string): string {
  const labels: Record<string, string> = {
    no_players_with_pares: "Nadie tenía pares",
    no_players_with_juego: "Nadie tenía juego",
    only_team_with_pares: "Solo un equipo tenía pares",
    only_team_with_juego: "Solo un equipo tenía juego",
    all_players_passed: "Todos pasaron",
    accepted_bet: "Envite aceptado",
    bet_rejected: "Envite rechazado",
    no_participants: "Sin participantes",
  };

  return labels[reason] ?? reason;
}

function getObject(
  source: Record<string, unknown>,
  key: string
): Record<string, unknown> | null {
  const value = source[key];

  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as Record<string, unknown>;
}

function getString(source: Record<string, unknown>, key: string): string {
  const value = source[key];

  return typeof value === "string" ? value : "";
}

function getNumber(source: Record<string, unknown>, key: string): number | null {
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

function getBoolean(source: Record<string, unknown>, key: string): boolean {
  const value = source[key];

  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value === "number") {
    return value === 1;
  }

  if (typeof value === "string") {
    return value === "true" || value === "1";
  }

  return false;
}

function getStringArray(source: Record<string, unknown>, key: string): string[] {
  const value = source[key];

  if (!Array.isArray(value)) {
    return [];
  }

  return value.map(String);
}