import { useTranslation } from "react-i18next";
import type { GameAction } from "../../../domain/game.types";

interface EventTimelineProps {
  actions: GameAction[];
}

export function EventTimeline({ actions }: EventTimelineProps) {
  const { t } = useTranslation();
  const recentActions = [...(actions ?? [])].slice(-24).reverse();

  return (
    <section className="event-timeline">
      <h2>{t("events.title")}</h2>

      {recentActions.length === 0 ? (
        <p className="muted-text">{t("events.empty")}</p>
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
                  <strong>{formatActor(action, t)}</strong>
                  <span>{formatActionLabel(action, t)}</span>
                </div>

                <div className="event-meta-line">
                  <em>{formatPhase(action, t)}</em>
                  {formatExtra(action, t) && <small>{formatExtra(action, t)}</small>}
                </div>
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}

function formatActor(action: GameAction, t: (key: string, options?: Record<string, unknown>) => string): string {
  const playerId = getString(action, "playerId");

  if (!playerId || playerId === "ALL") {
    return t("common.system");
  }

  const team = getString(action, "team");

  if (team) {
    return t("events.teamActor", { player: playerId, team });
  }

  return playerId;
}

function formatPhase(action: GameAction, t: (key: string, options?: Record<string, unknown>) => string): string {
  const phase = getString(action, "phase");

  if (!phase) {
    return "-";
  }

  return t(`phases.${phase}`);
}

function formatActionLabel(action: GameAction, t: (key: string, options?: Record<string, unknown>) => string): string {
  const explicitLabel = getString(action, "label");

  if (explicitLabel) {
    return explicitLabel;
  }

  const type = String(action.type ?? "");

  if (type === "declarar_pares") {
    return getBoolean(action, "hasValue") ? t("events.declarations.yesPares") : t("events.declarations.noPares");
  }

  if (type === "declarar_juego") {
    return getBoolean(action, "hasValue") ? t("events.declarations.yesJuego") : t("events.declarations.noJuego");
  }

  if (type === "fase_saltada") {
    return t("actions.labels.fase_saltada");
  }

  if (type === "fase_auto_resuelta") {
    return t("events.autoResolved");
  }

  if (type === "descartes") {
    const totalDiscarded = getNumber(action, "totalDiscarded");

    if (totalDiscarded !== null) {
      return t("events.discardCount", { count: totalDiscarded });
    }

    return t("actions.labels.descartes");
  }

  if (type === "pasar") {
    return t("events.verbs.pasar");
  }

  if (type === "envidar") {
    return t("events.verbs.envidar");
  }

  if (type === "querer") {
    return t("events.verbs.querer");
  }

  if (type === "no_querer") {
    return t("events.verbs.no_querer");
  }

  if (type === "ordago") {
    return t("events.verbs.ordago");
  }

  return type || t("common.action");
}

function formatExtra(action: GameAction, t: (key: string, options?: Record<string, unknown>) => string): string {
  const parts: string[] = [];

  const amount = getNumber(action, "amount");

  if (amount !== null && amount > 0 && amount !== 999) {
    parts.push(t("events.meta.amount", { count: amount }));
  }

  const betAmount = getNumber(action, "betAmount");

  if (betAmount !== null && betAmount > 0 && betAmount !== amount) {
    parts.push(t("events.meta.bet", { amount: betAmount }));
  }

  const value = getNumber(action, "value");

  if (value !== null) {
    parts.push(t("events.meta.value", { value }));
  }

  const points = getNumber(action, "points");
  const pointsAwarded = getNumber(action, "pointsAwarded");
  const resolvedPoints = points ?? pointsAwarded;

  if (resolvedPoints !== null) {
    parts.push(t("events.meta.points", { count: resolvedPoints }));
  }

  const winnerTeam = getString(action, "winnerTeam");

  if (winnerTeam) {
    parts.push(t("events.meta.winner", { team: winnerTeam }));
  }

  const acceptedByPlayerId = getString(action, "acceptedByPlayerId");

  if (acceptedByPlayerId) {
    parts.push(t("events.meta.acceptedBy", { player: acceptedByPlayerId }));
  }

  const rejectedByPlayerId = getString(action, "rejectedByPlayerId");

  if (rejectedByPlayerId) {
    parts.push(t("events.meta.rejectedBy", { player: rejectedByPlayerId }));
  }

  const respondingPlayers = getStringArray(action, "respondingPlayers");

  if (respondingPlayers.length > 0) {
    parts.push(t("events.meta.responders", { players: respondingPlayers.join(", ") }));
  }

  const reason = getString(action, "reason");

  if (reason) {
    parts.push(formatReason(reason, t));
  }

  return parts.join(" · ");
}

function formatReason(reason: string, t: (key: string, options?: Record<string, unknown>) => string): string {
  const key = `events.reasons.${reason}`;
  const translated = t(key);
  return translated === key ? reason : translated;
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