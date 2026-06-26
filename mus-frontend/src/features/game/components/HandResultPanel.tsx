import type { GameState, TeamId } from "../../../domain/game.types";

interface HandResultPanelProps {
  gameState: GameState;
  titleId?: string;
}

type PhaseResultKind = "phase" | "cardValue";

type PhaseResult = {
  phase: string;
  winnerTeam: string;
  playerId: string;
  points: number | string | null;
  reason: string;
  kind: PhaseResultKind;
  team?: TeamId;
  breakdown?: unknown[];
};

type TeamSummaryEntry = {
  phase: string;
  points: number;
  reason: string;
  kind: PhaseResultKind;
};

type TeamSummary = {
  team: TeamId;
  total: number;
  entries: TeamSummaryEntry[];
};

const RESULT_PHASES = ["grande", "chica", "pares", "juego", "punto"];
const CARD_VALUE_EVENT_TYPE = "valores_cartas_liquidados";

export function HandResultPanel({ gameState, titleId }: HandResultPanelProps) {
  const hand = gameState.hand as unknown as Record<string, unknown> | undefined;
  const completedPhases = hand?.completedPhases;

  const phaseResults =
    completedPhases && typeof completedPhases === "object"
      ? RESULT_PHASES.map((phase) =>
          buildPhaseResult(phase, completedPhases as Record<string, unknown>)
        ).filter(Boolean)
      : [];

  const cardValueResults = buildCardValueResults(gameState);
  const results = [...phaseResults, ...cardValueResults] as PhaseResult[];
  const summaries = buildTeamSummaries(results);

  if (summaries.every((summary) => summary.entries.length === 0)) {
    return null;
  }

  return (
    <section className="hand-result-panel hand-result-panel-table-section">
      <header className="hand-result-panel-header">
        <div>
          <h2 id={titleId}>Resultado de la mano</h2>
          <p>Mano {gameState.handNumber}</p>
        </div>
      </header>

      <div className="hand-result-table-wrapper">
        <table className="hand-result-table">
          <thead>
            <tr>
              <th scope="col">Equipo</th>
              {RESULT_PHASES.map((phase) => (
                <th key={phase} scope="col">
                  {formatPhase(phase)}
                </th>
              ))}
              <th scope="col">Total mano</th>
              <th scope="col">Marcador</th>
            </tr>
          </thead>
          <tbody>
            {summaries.map((summary) => (
              <tr key={summary.team}>
                <th scope="row">{getTeamDisplayName(gameState, summary.team)}</th>
                {RESULT_PHASES.map((phase) => (
                  <td key={phase}>{formatPhaseCell(summary, phase)}</td>
                ))}
                <td className="hand-result-table-total">{summary.total}</td>
                <td>{getCurrentScoreForTeam(gameState, summary.team)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

    </section>
  );
}


function getTeamDisplayName(gameState: GameState, team: TeamId): string {
  const state = gameState as unknown as Record<string, unknown>;
  const teamKey = team === "A" ? "teamA" : "teamB";
  const teamNameKey = team === "A" ? "teamAName" : "teamBName";

  const directName = getString(state, teamNameKey);
  if (directName) {
    return directName;
  }

  const directTeam = getObject(state, teamKey);
  const directTeamName = getString(directTeam, "name") || getString(directTeam, "displayName");
  if (directTeamName) {
    return directTeamName;
  }

  const teamNames = getObject(state, "teamNames");
  const namedFromMap =
    getString(teamNames, team) ||
    getString(teamNames, teamKey) ||
    getString(teamNames, teamNameKey);
  if (namedFromMap) {
    return namedFromMap;
  }

  const namedFromTeams = getTeamNameFromTeamsArray(state, team);
  if (namedFromTeams) {
    return namedFromTeams;
  }

  const namedFromPlayers = getTeamNameFromPlayers(state, team);
  if (namedFromPlayers) {
    return namedFromPlayers;
  }

  return `Equipo ${team}`;
}

function getTeamNameFromTeamsArray(
  state: Record<string, unknown>,
  team: TeamId
): string {
  const teams = getArray(state, "teams");

  for (const item of teams) {
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      continue;
    }

    const teamObject = item as Record<string, unknown>;
    const side = normalizeTeamId(
      getString(teamObject, "team") ||
        getString(teamObject, "side") ||
        getString(teamObject, "id") ||
        getString(teamObject, "code")
    );

    if (side !== team) {
      continue;
    }

    const name = getString(teamObject, "name") || getString(teamObject, "displayName");
    if (name) {
      return name;
    }
  }

  return "";
}

function getTeamNameFromPlayers(
  state: Record<string, unknown>,
  team: TeamId
): string {
  const players = getArray(state, "players");

  for (const item of players) {
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      continue;
    }

    const player = item as Record<string, unknown>;
    if (normalizeTeamId(getString(player, "team")) !== team) {
      continue;
    }

    const teamName =
      getString(player, "teamName") ||
      getString(player, "teamDisplayName") ||
      getString(player, "tournamentTeamName");

    if (teamName) {
      return teamName;
    }
  }

  return "";
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
  const winnerTeam = getString(phaseState, "winnerTeam") || getString(winner, "team");
  const playerId = getString(winner, "playerId");
  const points =
    getNumber(phaseState, "pointsAwarded") ??
    getNumber(phaseState, "points") ??
    getStringOrNull(phaseState, "pointsAwarded");
  const reason = getString(phaseState, "reason") || inferReasonFromPhaseState(phaseState);

  return {
    phase,
    winnerTeam,
    playerId,
    points,
    reason,
    kind: "phase",
  };
}

function buildCardValueResults(gameState: GameState): PhaseResult[] {
  const hand = gameState.hand as unknown as Record<string, unknown> | undefined;
  const completedPhases = getObject(hand ?? null, "completedPhases");
  const settledEvents = getCardValueSettlementEvents(gameState);

  if (settledEvents.length > 0) {
    return settledEvents.flatMap((event): PhaseResult[] => {
      const phase = getString(event, "phase");
      const team = normalizeTeamId(getString(event, "team"));

      if (!team) {
        return [];
      }

      const points = getNumber(event, "points") ?? 0;
      const breakdown = getArray(event, "breakdown");

      return [
        {
          phase,
          winnerTeam: team,
          team,
          playerId: "",
          points,
          reason: getString(event, "reason") || "hand_end_card_values",
          kind: "cardValue",
          breakdown,
        },
      ];
    });
  }

  const fallbackResults: PhaseResult[] = [];

  for (const phase of ["pares", "juego"]) {
    const phaseState = getObject(completedPhases, phase);
    const teamCountPoints = getObject(phaseState, "teamCountPoints");

    if (!teamCountPoints) {
      continue;
    }

    for (const team of ["A", "B"] as TeamId[]) {
      const points = getNumber(teamCountPoints, team) ?? 0;

      if (points <= 0) {
        continue;
      }

      fallbackResults.push({
        phase,
        winnerTeam: team,
        team,
        playerId: "",
        points,
        reason: "hand_end_card_values",
        kind: "cardValue",
      });
    }
  }

  return fallbackResults;
}

function getCardValueSettlementEvents(gameState: GameState): Record<string, unknown>[] {
  const hand = gameState.hand as unknown as Record<string, unknown> | undefined;
  const candidates = [
    getArray(hand ?? null, "settledPoints"),
    getArray(hand ?? null, "handEndSettledPoints"),
    getArray(hand ?? null, "actions"),
  ];

  const events: Record<string, unknown>[] = [];
  const seen = new Set<string>();

  for (const candidate of candidates) {
    for (const item of candidate) {
      if (!item || typeof item !== "object" || Array.isArray(item)) {
        continue;
      }

      const event = item as Record<string, unknown>;

      if (getString(event, "type") !== CARD_VALUE_EVENT_TYPE) {
        continue;
      }

      const phase = getString(event, "phase");
      const team = getString(event, "team");
      const points = String(event.points ?? "");
      const key = `${phase}:${team}:${points}`;

      if (seen.has(key)) {
        continue;
      }

      seen.add(key);
      events.push(event);
    }
  }

  return events;
}

function buildTeamSummaries(results: PhaseResult[]): TeamSummary[] {
  const summaries: Record<TeamId, TeamSummary> = {
    A: { team: "A", total: 0, entries: [] },
    B: { team: "B", total: 0, entries: [] },
  };

  for (const result of results) {
    const team = normalizeTeamId(result.team ?? result.winnerTeam);

    if (!team || typeof result.points !== "number" || result.points <= 0) {
      continue;
    }

    summaries[team].total += result.points;
    summaries[team].entries.push({
      phase: result.phase,
      points: result.points,
      reason: result.reason,
      kind: result.kind,
    });
  }

  for (const team of ["A", "B"] as TeamId[]) {
    summaries[team].entries.sort((left, right) => {
      const phaseDiff = phaseOrder(left.phase) - phaseOrder(right.phase);

      if (phaseDiff !== 0) {
        return phaseDiff;
      }

      if (left.kind === right.kind) {
        return 0;
      }

      return left.kind === "phase" ? -1 : 1;
    });
  }

  return [summaries.A, summaries.B];
}

function formatPhaseCell(summary: TeamSummary, phase: string): string {
  const entries = summary.entries.filter((entry) => entry.phase === phase);

  if (entries.length === 0) {
    return "-";
  }

  return joinSpanishList(entries.map(formatPhaseCellEntry));
}

function formatPhaseCellEntry(entry: TeamSummaryEntry): string {
  if (entry.kind === "cardValue") {
    return `${entry.points} de cartas`;
  }

  if (entry.reason === "bet_rejected") {
    return `${entry.points} de envite rechazado`;
  }

  if (entry.reason === "accepted_bet") {
    return `${entry.points} de envite aceptado`;
  }

  if (entry.reason === "all_players_passed") {
    return `${entry.points} en paso`;
  }

  return `${entry.points} de ${formatReason(entry.reason)}`;
}

function phaseOrder(phase: string): number {
  const index = RESULT_PHASES.indexOf(phase);
  return index >= 0 ? index : RESULT_PHASES.length;
}

function formatTeamSummary(entries: TeamSummaryEntry[]): string {
  return joinSpanishList(entries.map(formatTeamSummaryEntry));
}

function formatTeamSummaryEntry(entry: TeamSummaryEntry): string {
  const phase = formatPhase(entry.phase).toLowerCase();

  if (entry.kind === "cardValue") {
    return `${entry.points} de ${phase}`;
  }

  if (entry.reason === "bet_rejected") {
    return `${entry.points} a ${phase} de envite rechazado`;
  }

  if (entry.reason === "accepted_bet") {
    return `${entry.points} a ${phase} de envite aceptado`;
  }

  if (entry.reason === "all_players_passed") {
    return `${entry.points} de ${phase} en paso`;
  }

  return `${entry.points} de ${phase} de ${formatReason(entry.reason)}`;
}

function joinSpanishList(parts: string[]): string {
  if (parts.length <= 1) {
    return parts[0] ?? "Sin puntos";
  }

  if (parts.length === 2) {
    return `${parts[0]} y ${parts[1]}`;
  }

  return `${parts.slice(0, -1).join(", ")} y ${parts[parts.length - 1]}`;
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
    hand_end_card_values: "valor de cartas",
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

function normalizeTeamId(value: unknown): TeamId | "" {
  const team = String(value ?? "").trim().toUpperCase();

  if (team === "A" || team === "B") {
    return team;
  }

  return "";
}

function getCurrentScoreForTeam(gameState: GameState, team: TeamId): number {
  if (team === "A") {
    return gameState.score?.teamA ?? 0;
  }

  return gameState.score?.teamB ?? 0;
}

function getObject(
  source: Record<string, unknown> | null | undefined,
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

function getArray(
  source: Record<string, unknown> | null | undefined,
  key: string
): unknown[] {
  if (!source) {
    return [];
  }

  const value = source[key];

  return Array.isArray(value) ? value : [];
}

function getString(
  source: Record<string, unknown> | null | undefined,
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

function getNumber(source: Record<string, unknown> | null, key: string): number | null {
  if (!source) {
    return null;
  }

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
