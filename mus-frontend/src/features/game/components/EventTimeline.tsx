import type { GameAction } from "../../../domain/game.types";

interface EventTimelineProps {
  actions: GameAction[];
}

export function EventTimeline({ actions }: EventTimelineProps) {
  const recentActions = [...(actions ?? [])].slice(-24).reverse();

  return (
    <section className="event-timeline">
      <h2>Historial</h2>

      {recentActions.length === 0 ? (
        <p className="muted-text">No hay acciones todavía.</p>
      ) : (
        <ol className="event-list">
          {recentActions.map((action, index) => {
            const type = String(action.type ?? "unknown");

            return (
              <li
                key={`${action.createdAt ?? "event"}-${type}-${index}`}
                className={[
                  "event-item",
                  `event-${type}`,
                  isAutomaticEvent(action) ? "event-automatic" : "",
                ]
                  .filter(Boolean)
                  .join(" ")}
              >
                <div className="event-main-line">
                  <strong>{formatActor(action)}</strong>
                  <span>{formatActionLabel(action)}</span>
                </div>

                <div className="event-meta-line">
                  <em>{formatPhase(action)}</em>
                  {formatExtra(action) && <small>{formatExtra(action)}</small>}
                </div>
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}

function formatActor(action: GameAction): string {
  const playerId = getString(action, "playerId");

  if (!playerId || playerId === "ALL") {
    return "Sistema";
  }

  const team = getString(action, "team");

  if (team) {
    return `${playerId} · Equipo ${team}`;
  }

  return playerId;
}

function formatPhase(action: GameAction): string {
  const phase = getString(action, "phase");

  if (!phase) {
    return "-";
  }

  const phaseLabels: Record<string, string> = {
    descartes: "Descartes",
    grande: "Grande",
    chica: "Chica",
    pares: "Pares",
    juego: "Juego",
    punto: "Punto",
    manoCerrada: "Mano cerrada",
  };

  return phaseLabels[phase] ?? phase;
}

function formatActionLabel(action: GameAction): string {
  const explicitLabel = getString(action, "label");

  if (explicitLabel) {
    return explicitLabel;
  }

  const type = String(action.type ?? "");

  if (type === "declarar_pares") {
    return getBoolean(action, "hasValue") ? "Sí a pares" : "No a pares";
  }

  if (type === "declarar_juego") {
    return getBoolean(action, "hasValue") ? "Sí a juego" : "No a juego";
  }

  if (type === "fase_saltada") {
    return "Fase saltada";
  }

  if (type === "fase_auto_resuelta") {
    return "Fase resuelta automáticamente";
  }

  if (type === "descartes") {
    const totalDiscarded = getNumber(action, "totalDiscarded");

    if (totalDiscarded !== null) {
      return `Descartes: ${totalDiscarded} carta${
        totalDiscarded === 1 ? "" : "s"
      }`;
    }

    return "Descartes";
  }

  if (type === "pasar") {
    return "Pasa";
  }

  if (type === "envidar") {
    return "Envida";
  }

  if (type === "querer") {
    return "Quiere";
  }

  if (type === "no_querer") {
    return "No quiere";
  }

  if (type === "ordago") {
    return "Órdago";
  }

  return type || "Acción";
}

function formatExtra(action: GameAction): string {
  const parts: string[] = [];

  const amount = getNumber(action, "amount");

  if (amount !== null && amount > 0 && amount !== 999) {
    parts.push(`${amount} puntos`);
  }

  const betAmount = getNumber(action, "betAmount");

  if (betAmount !== null && betAmount > 0 && betAmount !== amount) {
    parts.push(`envite ${betAmount}`);
  }

  const value = getNumber(action, "value");

  if (value !== null) {
    parts.push(`valor ${value}`);
  }

  const points = getNumber(action, "points");
  const pointsAwarded = getNumber(action, "pointsAwarded");
  const resolvedPoints = points ?? pointsAwarded;

  if (resolvedPoints !== null) {
    parts.push(
      `${resolvedPoints} punto${resolvedPoints === 1 ? "" : "s"}`
    );
  }

  const winnerTeam = getString(action, "winnerTeam");

  if (winnerTeam) {
    parts.push(`gana Equipo ${winnerTeam}`);
  }

  const acceptedByPlayerId = getString(action, "acceptedByPlayerId");

  if (acceptedByPlayerId) {
    parts.push(`acepta ${acceptedByPlayerId}`);
  }

  const rejectedByPlayerId = getString(action, "rejectedByPlayerId");

  if (rejectedByPlayerId) {
    parts.push(`rechaza ${rejectedByPlayerId}`);
  }

  const respondingPlayers = getStringArray(action, "respondingPlayers");

  if (respondingPlayers.length > 0) {
    parts.push(`responden ${respondingPlayers.join(", ")}`);
  }

  const reason = getString(action, "reason");

  if (reason) {
    parts.push(formatReason(reason));
  }

  return parts.join(" · ");
}

function formatReason(reason: string): string {
  const reasonLabels: Record<string, string> = {
    no_players_with_pares: "nadie tiene pares",
    no_players_with_juego: "nadie tiene juego",
    only_team_with_pares: "solo un equipo tiene pares",
    only_team_with_juego: "solo un equipo tiene juego",
    all_players_passed: "todos pasan",
    accepted_bet: "envite aceptado",
    bet_rejected: "envite rechazado",
    ordago_accepted: "órdago aceptado",
    no_participants: "sin participantes",
    first_grande_action: "descartes cerrados automáticamente",
  };

  return reasonLabels[reason] ?? reason;
}

function isAutomaticEvent(action: GameAction): boolean {
  const type = String(action.type ?? "");

  return (
    type === "declarar_pares" ||
    type === "declarar_juego" ||
    type === "fase_saltada" ||
    type === "fase_auto_resuelta"
  );
}

function getString(action: GameAction, key: string): string {
  const value = action[key];

  return typeof value === "string" ? value : "";
}

function getNumber(action: GameAction, key: string): number | null {
  const value = action[key];

  if (typeof value === "number") {
    return value;
  }

  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);

    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

function getBoolean(action: GameAction, key: string): boolean {
  const value = action[key];

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

function getStringArray(action: GameAction, key: string): string[] {
  const value = action[key];

  if (!Array.isArray(value)) {
    return [];
  }

  return value.map(String);
}