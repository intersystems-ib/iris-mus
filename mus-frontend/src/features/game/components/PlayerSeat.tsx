import type {
  ActionType,
  GameState,
  Player,
  PlayerId,
} from "../../../domain/game.types";
import { CardHand, getCardImageUrl } from "./CardHand";

type AgentDiscardDecision = "discard" | "cut";
type LanceDeclarationText = "TENGO" | "NO LLEVO";
type LanceDeclarationPhase = "pares" | "juego";

interface PlayerActionView {
  playerId: PlayerId;
  actionType: ActionType;
  amount: number;
  reason?: string;
}

interface LanceDeclarationView {
  playerId: PlayerId;
  phase: LanceDeclarationPhase;
  text: LanceDeclarationText;
  hasLance: boolean;
}

interface PlayerSeatProps {
  gameState: GameState;
  playerId: PlayerId;
  perspectivePlayerId?: PlayerId;
  musVoteEnabled?: boolean;
  musVote?: boolean;
  discardSelectionEnabled?: boolean;
  selectedDiscardCards?: string[];
  onMus?: () => void;
  onCutMus?: () => void;
  onToggleDiscardCard?: (card: string) => void;
  discardConfirmed?: boolean;
  isSubmittingDiscards?: boolean;
  onConfirmDiscards?: () => void;
  actionControlsEnabled?: boolean;
  legalActions?: ActionType[];
  actionAmount?: number;
  actionMinAmount?: number;
  isSubmittingAction?: boolean;
  onActionAmountChange?: (amount: number) => void;
  onPlayerAction?: (actionType: ActionType) => void;
  isAgent?: boolean;
  forceHideCards?: boolean;
  agentProfile?: string;
  agentActionEnabled?: boolean;
  agentDiscardDecision?: AgentDiscardDecision;
  agentRecommendedDiscards?: string[];
  agentDiscardLoading?: boolean;
  playerActionView?: PlayerActionView;
  lanceDeclarationView?: LanceDeclarationView;
  isDeclaringLance?: boolean;
  isExecutingAgent?: boolean;
  forceTurnHighlight?: boolean;
  playerDisplayName?: string;
  teamDisplayName?: string;
  onExecuteAgent?: () => void;
}

export function PlayerSeat({
  gameState,
  playerId,
  perspectivePlayerId,
  musVoteEnabled = false,
  musVote,
  discardSelectionEnabled = false,
  discardConfirmed = false,
  selectedDiscardCards = [],
  isSubmittingDiscards = false,
  onMus,
  onCutMus,
  onConfirmDiscards,
  onToggleDiscardCard,
  actionControlsEnabled = false,
  legalActions = [],
  actionAmount = 2,
  actionMinAmount = 2,
  isSubmittingAction = false,
  onActionAmountChange,
  onPlayerAction,
  isAgent = false,
  forceHideCards = false,
  agentActionEnabled = false,
  agentDiscardDecision,
  agentRecommendedDiscards = [],
  agentDiscardLoading = false,
  playerActionView,
  lanceDeclarationView,
  isDeclaringLance = false,
  isExecutingAgent = false,
  forceTurnHighlight = false,
  playerDisplayName,
  teamDisplayName,
  onExecuteAgent,
}: PlayerSeatProps) {
  const players = normalizePlayersForView(gameState.players);
  const player = players.find((item) => item.id === playerId);
  const resolvedPlayerName =
    getCleanDisplayText(playerDisplayName) ||
    getCleanDisplayText(player?.name) ||
    getPlayerDisplayNameFromGameState(gameState, playerId) ||
    playerId;
  const cards = getPlayerCards(gameState, playerId);
  const isTurn = gameState.turnPlayerId === playerId;
  const isThinkingAgent = isExecutingAgent || agentDiscardLoading || isDeclaringLance;
  const shouldHighlightAsTurn = isTurn || isThinkingAgent || forceTurnHighlight;
  const isDealer = gameState.dealerPlayerId === playerId;
  const playerTeam = player?.team || getDefaultTeamForSeat(playerId);
  const resolvedTeamName =
    getCleanDisplayText(teamDisplayName) ||
    getTeamDisplayName(gameState, playerTeam);
  const isWinnerTeam =
    Boolean(gameState.winnerTeam) && player?.team === gameState.winnerTeam;
  const shouldHideCards =
    forceHideCards ||
    (Boolean(perspectivePlayerId) && perspectivePlayerId !== playerId);
  const canSelectDiscards =
    discardSelectionEnabled && !discardConfirmed && !shouldHideCards && !isAgent;
  /*
    Cuando ya conocemos los descartes de un jugador, quitamos esas cartas de
    su mano visible aunque las cartas estén ocultas con BACK.png. Así el humano
    no ve qué cartas concretas descartan los agentes, pero sí ve cuántas cartas
    quedan en cada mano después de que todos hayan querido MUS.
  */
  const visibleCards =
    selectedDiscardCards.length > 0
      ? cards.filter((card) => !selectedDiscardCards.includes(card))
      : cards;

  const hasVisibleActionStatus = Boolean(
    agentDiscardLoading ||
      agentDiscardDecision ||
      isDeclaringLance ||
      lanceDeclarationView ||
      isExecutingAgent ||
      playerActionView
  );

  const canShowDecisionButtons =
    actionControlsEnabled &&
    !isAgent &&
    !hasVisibleActionStatus &&
    !isSubmittingAction;

  const shouldShowHumanDiscardActions =
    musVoteEnabled &&
    !isAgent &&
    !agentDiscardDecision &&
    !lanceDeclarationView &&
    !playerActionView &&
    !isSubmittingAction;

  const shouldShowAgentAction =
    !hasVisibleActionStatus &&
    !isSubmittingAction &&
    !musVoteEnabled &&
    isAgent &&
    agentActionEnabled;

  const shouldShowActionControls =
    shouldShowAgentAction || shouldShowHumanDiscardActions || canShowDecisionButtons;

  const shouldShowActionRow = true;

  return (
    <article
      className={[
        "player-seat",
        shouldHighlightAsTurn ? "is-turn" : "",
        isWinnerTeam ? "is-winner-team" : "",
        musVote === true ? "has-voted-mus" : "",
        musVote === false ? "has-cut-mus" : "",
        discardConfirmed ? "has-confirmed-discard" : "",
        isAgent ? "is-agent" : "",
      ]
        .filter(Boolean)
        .join(" ")}
    >
      <header className="player-seat-header">
        <div>
          <strong>{resolvedPlayerName}</strong>
          <span>
            {playerId} · {resolvedTeamName}
          </span>
        </div>

        <div className="player-badges">          
          {isDealer && <span className="badge">Mano</span>}
          {shouldHighlightAsTurn && <span className="badge active">Turno</span>}
        </div>
      </header>

      <div className="player-seat-playset">
        <div className="player-seat-cards-row">
          <div className="player-seat-cards-stack">
            {canSelectDiscards ? (
              <SelectableCardHand
                cards={cards}
                selectedCards={selectedDiscardCards}
                onToggleCard={onToggleDiscardCard}
              />
            ) : (
              <CardHand cards={visibleCards} hidden={shouldHideCards} />
            )}
          </div>
        </div>

        {shouldShowActionRow && (
          <div className="player-seat-actions-row">
            {agentDiscardLoading && (
              <div className="player-seat-action-status thinking">PENSANDO</div>
            )}

            {!agentDiscardLoading && agentDiscardDecision && (
              <AgentDiscardResult
                decision={agentDiscardDecision}
                discards={agentRecommendedDiscards}
              />
            )}

            {isDeclaringLance && (
              <div className="player-seat-action-status thinking">PENSANDO</div>
            )}

            {!isDeclaringLance && lanceDeclarationView && (
              <LanceDeclarationResult declaration={lanceDeclarationView} />
            )}

            {isExecutingAgent && (
              <div className="player-seat-action-status thinking">PENSANDO</div>
            )}

            {!isExecutingAgent && playerActionView && (
              <PlayerActionResult
                actionType={playerActionView.actionType}
                amount={playerActionView.amount}
              />
            )}

            {shouldShowActionControls &&
              (shouldShowAgentAction ? (
                <button
                  type="button"
                  className="agent-action"
                  onClick={onExecuteAgent}
                  disabled={
                    isExecutingAgent || isSubmittingDiscards || isSubmittingAction
                  }
                >
                  {isExecutingAgent ? "EJECUTANDO..." : "EJECUTAR AGENTE"}
                </button>
              ) : shouldShowHumanDiscardActions ? (
                discardSelectionEnabled ? (
                  <button
                    type="button"
                    onClick={onConfirmDiscards}
                    className={discardConfirmed ? "selected discard" : "discard"}
                    disabled={discardConfirmed || isSubmittingDiscards}
                  >
                    {discardConfirmed ? "DESCARTADO" : "DESCARTAR"}
                  </button>
                ) : (
                  <>
                    <button
                      type="button"
                      onClick={onMus}
                      className={musVote === true ? "selected" : ""}
                      disabled={
                        musVote === true || musVote === false || isSubmittingDiscards
                      }
                    >
                      MUS
                    </button>
                    <button
                      type="button"
                      onClick={onCutMus}
                      className={musVote === false ? "selected cut" : "cut"}
                      disabled={
                        musVote === true || musVote === false || isSubmittingDiscards
                      }
                    >
                      CORTAR
                    </button>
                  </>
                )
              ) : canShowDecisionButtons ? (
                <>
                  {legalActions.includes("pasar") && (
                    <button
                      type="button"
                      onClick={() => onPlayerAction?.("pasar")}
                      disabled={isSubmittingAction}
                    >
                      PASAR
                    </button>
                  )}

                  {legalActions.includes("envidar") && (
                    <>
                      <label className="player-seat-action-amount">
                        <span>Envite</span>
                        <input
                          type="number"
                          min={actionMinAmount}
                          max={30}
                          value={Math.max(actionAmount, actionMinAmount)}
                          onChange={(event) =>
                            onActionAmountChange?.(
                              Math.max(actionMinAmount, Number(event.target.value))
                            )
                          }
                          disabled={isSubmittingAction}
                        />
                      </label>
                      <button
                        type="button"
                        onClick={() => onPlayerAction?.("envidar")}
                        disabled={isSubmittingAction}
                      >
                        ENVIDAR
                      </button>
                    </>
                  )}

                  {legalActions.includes("querer") && (
                    <button
                      type="button"
                      className="accept"
                      onClick={() => onPlayerAction?.("querer")}
                      disabled={isSubmittingAction}
                    >
                      QUERER
                    </button>
                  )}

                  {legalActions.includes("no_querer") && (
                    <button
                      type="button"
                      className="reject"
                      onClick={() => onPlayerAction?.("no_querer")}
                      disabled={isSubmittingAction}
                    >
                      NO QUERER
                    </button>
                  )}

                  {legalActions.includes("ordago") && (
                    <button
                      type="button"
                      className="ordago"
                      onClick={() => onPlayerAction?.("ordago")}
                      disabled={isSubmittingAction}
                    >
                      ÓRDAGO
                    </button>
                  )}
                </>
              ) : null)}
          </div>
        )}
      </div>
    </article>
  );
}

interface AgentDiscardResultProps {
  decision: AgentDiscardDecision;
  discards: string[];
}

function AgentDiscardResult({
  decision,
}: AgentDiscardResultProps) {
  if (decision === "cut") {
    return <div className="player-seat-action-status cut">CORTO EL MUS</div>;
  }

  /*
    En la botonera de cada jugador solo debe verse la decisión de MUS.
    No mostramos cuántas cartas descartará ni cuáles son.
  */
  return <div className="player-seat-action-status mus">MUS</div>;
}

interface LanceDeclarationResultProps {
  declaration: LanceDeclarationView;
}

function LanceDeclarationResult({
  declaration,
}: LanceDeclarationResultProps) {
  return (
    <div
      className={[
        "player-seat-action-status",
        "lance-declaration",
        declaration.hasLance ? "has-lance" : "no-lance",
        `lance-${declaration.phase}`,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      {declaration.text}
    </div>
  );
}

interface PlayerActionResultProps {
  actionType: ActionType;
  amount: number;
}

function PlayerActionResult({
  actionType,
  amount,
}: PlayerActionResultProps) {
  return (
    <div className={`player-seat-action-status action-${actionType}`}>
      {getPlayerActionText(actionType, amount)}
    </div>
  );
}

function getPlayerActionText(actionType: ActionType, amount: number): string {
  if (actionType === "pasar") {
    return "PASO";
  }

  if (actionType === "envidar") {
    return `ENVIDO ${amount}`;
  }

  if (actionType === "querer") {
    return "QUIERO";
  }

  if (actionType === "no_querer") {
    return "NO QUIERO";
  }

  if (actionType === "ordago") {
    return "ÓRDAGO";
  }

  return String(actionType).toUpperCase();
}

interface SelectableCardHandProps {
  cards: string[];
  selectedCards: string[];
  onToggleCard?: (card: string) => void;
}

function SelectableCardHand({
  cards,
  selectedCards,
  onToggleCard,
}: SelectableCardHandProps) {
  if (cards.length === 0) {
    return <p className="muted-text">Sin cartas</p>;
  }

  return (
    <div className="card-hand">
      {cards.map((card, index) => {
        const isSelected = selectedCards.includes(card);
        const imageUrl = getCardImageUrl(card);

        return (
          <button
            key={`${card}-${index}`}
            type="button"
            className={[
              "playing-card-button",
              "playing-card-selectable",
              isSelected ? "playing-card-selected" : "",
            ]
              .filter(Boolean)
              .join(" ")}
            onClick={() => onToggleCard?.(card)}
          >
            {imageUrl ? (
              <img className="playing-card-image" src={imageUrl} alt={card} />
            ) : (
              <span className="playing-card playing-card-fallback">{card}</span>
            )}
          </button>
        );
      })}
    </div>
  );
}


function getCleanDisplayText(value: unknown): string {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }

  if (typeof value === "number") {
    return String(value);
  }

  return "";
}

function getDefaultTeamForSeat(playerId: PlayerId): string {
  if (playerId === "P1" || playerId === "P3") {
    return "A";
  }

  if (playerId === "P2" || playerId === "P4") {
    return "B";
  }

  return "";
}

function getPlayerDisplayNameFromGameState(
  gameState: GameState,
  playerId: PlayerId
): string {
  const state = gameState as unknown as Record<string, unknown>;
  const teamId = getDefaultTeamForSeat(playerId);
  const teamPlayerIndex = playerId === "P1" || playerId === "P2" ? 0 : 1;

  const directPlayer = getPlayerObjectBySeatId(state.players, playerId);
  const directName = getPlayerNameFromObject(directPlayer);
  if (directName) {
    return directName;
  }

  const playerNames = state.playerNames;
  if (playerNames && typeof playerNames === "object") {
    const names = playerNames as Record<string, unknown>;
    const candidate = names[playerId] ?? names[playerId.toLowerCase()];
    const name = getPlayerNameFromObjectOrValue(candidate);

    if (name) {
      return name;
    }
  }

  const team = getTeamObjectFromState(state, teamId);
  const nameFromTeam = getPlayerNameFromTeamObject(team, teamPlayerIndex);
  if (nameFromTeam) {
    return nameFromTeam;
  }

  return "";
}

function getPlayerObjectBySeatId(value: unknown, playerId: PlayerId): unknown {
  if (Array.isArray(value)) {
    return value.find((item) => {
      if (!item || typeof item !== "object") {
        return false;
      }

      const player = item as Record<string, unknown>;
      return String(player.id ?? player.playerId ?? player.seatId ?? "") === playerId;
    });
  }

  if (value && typeof value === "object") {
    const players = value as Record<string, unknown>;
    return players[playerId] ?? players[playerId.toLowerCase()];
  }

  return null;
}

function getPlayerNameFromObjectOrValue(value: unknown): string {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }

  return getPlayerNameFromObject(value);
}

function getPlayerNameFromObject(value: unknown): string {
  if (!value || typeof value !== "object") {
    return "";
  }

  const player = value as Record<string, unknown>;
  const name =
    player.name ??
    player.displayName ??
    player.playerName ??
    player.fullName ??
    player.label;

  return getCleanDisplayText(name);
}

function getTeamObjectFromState(
  state: Record<string, unknown>,
  teamId: string
): unknown {
  const directField = teamId.toUpperCase() === "A" ? state.teamA : state.teamB;
  if (directField) {
    return directField;
  }

  const teams = state.teams;

  if (Array.isArray(teams)) {
    const matchedTeam = teams.find((rawTeam) => {
      if (!rawTeam || typeof rawTeam !== "object") {
        return false;
      }

      const team = rawTeam as Record<string, unknown>;
      const rawId = team.id ?? team.teamId ?? team.code ?? team.key ?? team.letter;
      const normalizedId = normalizeTeamId(rawId).toUpperCase();

      return normalizedId === teamId.toUpperCase();
    });

    if (matchedTeam) {
      return matchedTeam;
    }

    return teams[teamId.toUpperCase() === "A" ? 0 : 1] ?? null;
  }

  if (teams && typeof teams === "object") {
    const teamsRecord = teams as Record<string, unknown>;
    return (
      teamsRecord[teamId] ??
      teamsRecord[teamId.toUpperCase()] ??
      teamsRecord[teamId.toLowerCase()]
    );
  }

  return null;
}

function getPlayerNameFromTeamObject(
  rawTeam: unknown,
  playerIndex: number
): string {
  if (!rawTeam || typeof rawTeam !== "object") {
    return "";
  }

  const team = rawTeam as Record<string, unknown>;
  const players = team.players ?? team.members ?? team.teamPlayers;

  if (!Array.isArray(players)) {
    return "";
  }

  return getPlayerNameFromObject(players[playerIndex]);
}

function getTeamDisplayName(gameState: GameState, team: unknown): string {
  const teamId = normalizeTeamId(team);

  if (!teamId) {
    return "Equipo";
  }

  const state = gameState as unknown as Record<string, unknown>;

  const directName = getTeamNameFromDirectFields(state, teamId);
  if (directName) {
    return directName;
  }

  const teamNames = state.teamNames;
  const nameFromMap = getTeamNameFromMap(teamNames, teamId);
  if (nameFromMap) {
    return nameFromMap;
  }

  const directTeamObject = getTeamObjectFromState(state, teamId);
  const nameFromDirectTeamObject = getTeamNameFromTeamObject(directTeamObject, teamId);
  if (nameFromDirectTeamObject) {
    return nameFromDirectTeamObject;
  }

  const teams = state.teams;
  const nameFromTeams = getTeamNameFromTeams(teams, teamId);
  if (nameFromTeams) {
    return nameFromTeams;
  }

  return `Equipo ${teamId}`;
}

function normalizeTeamId(value: unknown): string {
  if (value === undefined || value === null) {
    return "";
  }

  return String(value).trim();
}

function getTeamNameFromDirectFields(
  state: Record<string, unknown>,
  teamId: string
): string {
  const directFieldByTeam: Record<string, string[]> = {
    A: ["teamAName", "teamNameA"],
    B: ["teamBName", "teamNameB"],
  };

  const fields = directFieldByTeam[teamId.toUpperCase()] ?? [];

  for (const field of fields) {
    const value = state[field];

    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }

  return "";
}

function getTeamNameFromMap(value: unknown, teamId: string): string {
  if (!value || typeof value !== "object") {
    return "";
  }

  const teamNames = value as Record<string, unknown>;
  const candidate =
    teamNames[teamId] ??
    teamNames[teamId.toUpperCase()] ??
    teamNames[teamId.toLowerCase()];

  if (typeof candidate === "string" && candidate.trim()) {
    return candidate.trim();
  }

  if (candidate && typeof candidate === "object") {
    const candidateObj = candidate as Record<string, unknown>;
    const name = candidateObj.name ?? candidateObj.displayName;

    if (typeof name === "string" && name.trim()) {
      return name.trim();
    }
  }

  return "";
}

function getTeamNameFromTeams(value: unknown, teamId: string): string {
  if (Array.isArray(value)) {
    for (const rawTeam of value) {
      const name = getTeamNameFromTeamObject(rawTeam, teamId);

      if (name) {
        return name;
      }
    }

    return "";
  }

  if (value && typeof value === "object") {
    const teams = value as Record<string, unknown>;
    const directTeam =
      teams[teamId] ?? teams[teamId.toUpperCase()] ?? teams[teamId.toLowerCase()];

    const directName = getTeamNameFromTeamObject(directTeam, teamId);
    if (directName) {
      return directName;
    }

    for (const [id, rawTeam] of Object.entries(teams)) {
      const name = getTeamNameFromTeamObject(rawTeam, teamId, id);

      if (name) {
        return name;
      }
    }
  }

  return "";
}

function getTeamNameFromTeamObject(
  rawTeam: unknown,
  teamId: string,
  fallbackId?: string
): string {
  if (!rawTeam || typeof rawTeam !== "object") {
    return "";
  }

  const team = rawTeam as Record<string, unknown>;
  const rawId =
    team.id ?? team.teamId ?? team.code ?? team.key ?? team.letter ?? fallbackId;

  if (normalizeTeamId(rawId).toUpperCase() !== teamId.toUpperCase()) {
    return "";
  }

  const name = team.name ?? team.displayName ?? team.teamName;

  if (typeof name === "string" && name.trim()) {
    return name.trim();
  }

  return "";
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
