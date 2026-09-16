import { useTranslation } from "react-i18next";
import type { GameState, Player, PlayerId } from "../../../domain/game.types";

interface PhaseSummaryPanelProps {
  gameState: GameState;
}

const PLAYER_IDS: PlayerId[] = ["P1", "P2", "P3", "P4"];

export function PhaseSummaryPanel({ gameState }: PhaseSummaryPanelProps) {
  const { t } = useTranslation();
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
      <h2>{t("phaseSummary.title")}</h2>

      {shouldShowCurrent && activeSummary && (
        <PhaseSummaryBlock
          title={t("phaseSummary.current", { phase: t(`phases.${phase}`) })}
          phase={phase}
          summary={activeSummary}
          players={gameState.players}
        />
      )}

      {completedPares && phase !== "pares" && (
        <PhaseSummaryBlock
          title={t("phases.pares")}
          phase="pares"
          summary={completedPares}
          players={gameState.players}
        />
      )}

      {completedJuego && phase !== "juego" && (
        <PhaseSummaryBlock
          title={t("phases.juego")}
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
  const { t } = useTranslation();
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
        {status && <span className={`phase-status phase-status-${status}`}>{t(`statuses.${status}`)}</span>}
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

                <span>{player?.team ? t("phaseSummary.team", { team: player.team }) : t("phaseSummary.teamUnknown")}</span>

                <b>{participates ? getYesLabel(phase, t) : getNoLabel(phase, t)}</b>

                {info && <small>{formatEligibilityInfo(phase, info, t)}</small>}
              </div>
            );
          })}
        </div>
      ) : (
        <p className="muted-text">{t("phaseSummary.noDeclarations")}</p>
      )}

      {(winnerTeam || pointsAwarded !== null || reason) && (
        <p className="phase-result-line">
          {winnerTeam && <span>{t("phaseSummary.winner", { team: winnerTeam })}</span>}
          {pointsAwarded !== null && (
            <span>
              {t("phaseSummary.points", { count: pointsAwarded })}
            </span>
          )}
          {reason && <span>{formatReason(reason, t)}</span>}
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

function getYesLabel(
  phase: string,
  t: (key: string, options?: Record<string, unknown>) => string
): string {
  const key = phase === "pares" || phase === "juego"
    ? `phaseSummary.yes.${phase}`
    : "phaseSummary.yes.default";
  return t(key);
}

function getNoLabel(
  phase: string,
  t: (key: string, options?: Record<string, unknown>) => string
): string {
  const key = phase === "pares" || phase === "juego"
    ? `phaseSummary.no.${phase}`
    : "phaseSummary.no.default";
  return t(key);
}

function formatEligibilityInfo(
  phase: string,
  info: Record<string, unknown>,
  t: (key: string, options?: Record<string, unknown>) => string
): string {
  if (phase === "pares") {
    const type = getString(info, "type");

    if (!type || type === "none") {
      return t("phaseSummary.eligibility.noPairs");
    }

    const key = `phaseSummary.eligibility.${type}`;
    const translated = t(key);
    return translated === key ? type : translated;
  }

  if (phase === "juego") {
    const total = getNumber(info, "total");
    const hasJuego = getBoolean(info, "hasJuego");

    if (total === null) {
      return hasJuego ? t("phaseSummary.eligibility.withGame") : t("phaseSummary.eligibility.withoutGame");
    }

    return hasJuego ? t("phaseSummary.eligibility.gameTotal", { total }) : t("phaseSummary.eligibility.pointTotal", { total });
  }

  if (phase === "punto") {
    const total = getNumber(info, "total");

    return total === null ? t("phaseSummary.eligibility.point") : t("phaseSummary.eligibility.pointTotal", { total });
  }

  return "";
}

function formatReason(reason: string, t: (key: string, options?: Record<string, unknown>) => string): string {
  const key = `phaseSummary.reasons.${reason}`;
  const translated = t(key);
  return translated === key ? reason : translated;
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