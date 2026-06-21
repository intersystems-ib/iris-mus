import type {
  ActionType,
  GameState,
  Player,
  PlayerId,
} from "../../../domain/game.types";
import { CardHand, getCardImageUrl } from "./CardHand";

type AgentDiscardDecision = "discard" | "cut";

interface PlayerActionView {
  playerId: PlayerId;
  actionType: ActionType;
  amount: number;
  reason?: string;
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
  agentProfile?: string;
  agentActionEnabled?: boolean;
  agentDiscardDecision?: AgentDiscardDecision;
  agentRecommendedDiscards?: string[];
  agentDiscardLoading?: boolean;
  playerActionView?: PlayerActionView;
  isExecutingAgent?: boolean;
  forceTurnHighlight?: boolean;
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

  legalActions = [],
  actionAmount = 2,
  actionMinAmount = 2,
  isSubmittingAction = false,
  onActionAmountChange,
  onPlayerAction,

  isAgent = false,
  agentProfile,
  agentActionEnabled = false,
  agentDiscardDecision,
  agentRecommendedDiscards = [],
  agentDiscardLoading = false,
  playerActionView,
  isExecutingAgent = false,
  forceTurnHighlight = false,
  onExecuteAgent,
}: PlayerSeatProps) {
  const players = normalizePlayersForView(gameState.players);
  const player = players.find((item) => item.id === playerId);

  const cards = getPlayerCards(gameState, playerId);

  const isTurn = gameState.turnPlayerId === playerId;
  const isThinkingAgent = isExecutingAgent || agentDiscardLoading;
  const shouldHighlightAsTurn = isTurn || isThinkingAgent || forceTurnHighlight;
  const isDealer = gameState.dealerPlayerId === playerId;
  const isWinnerTeam =
    Boolean(gameState.winnerTeam) && player?.team === gameState.winnerTeam;

  const shouldHideCards =
    Boolean(perspectivePlayerId) && perspectivePlayerId !== playerId;

  const canSelectDiscards =
    discardSelectionEnabled && !discardConfirmed && !shouldHideCards && !isAgent;

  const visibleCards =
    discardConfirmed && !shouldHideCards
      ? cards.filter((card) => !selectedDiscardCards.includes(card))
      : cards;

  const hasVisibleActionStatus = Boolean(
    agentDiscardLoading ||
      agentDiscardDecision ||
      isExecutingAgent ||
      playerActionView
  );

  const shouldShowHumanDiscardActions =
    musVoteEnabled &&
    !isAgent &&
    !agentDiscardDecision &&
    !playerActionView &&
    !isSubmittingAction;

  const shouldShowAgentAction =
    !hasVisibleActionStatus &&
    !isSubmittingAction &&
    !musVoteEnabled &&
    isAgent &&
    agentActionEnabled;

  const shouldShowActionControls = !hasVisibleActionStatus && !isSubmittingAction;

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
          <strong>{player?.name ?? playerId}</strong>
          <span>
            {playerId} · Equipo {player?.team ?? "-"}
          </span>
        </div>

        <div className="player-badges">
          {isAgent && (
            <span className="badge agent-badge">
              Agente{agentProfile ? ` · ${agentProfile}` : ""}
            </span>
          )}

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
              <div className="player-seat-action-status thinking">
                PENSANDO
              </div>
            )}

            {!agentDiscardLoading && agentDiscardDecision && (
              <AgentDiscardResult
                decision={agentDiscardDecision}
                discards={agentRecommendedDiscards}
              />
            )}

            {isExecutingAgent && (
              <div className="player-seat-action-status thinking">
                PENSANDO
              </div>
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
                    isExecutingAgent ||
                    isSubmittingDiscards ||
                    isSubmittingAction
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
                        musVote === true ||
                        musVote === false ||
                        isSubmittingDiscards
                      }
                    >
                      MUS
                    </button>

                    <button
                      type="button"
                      onClick={onCutMus}
                      className={musVote === false ? "selected cut" : "cut"}
                      disabled={
                        musVote === true ||
                        musVote === false ||
                        isSubmittingDiscards
                      }
                    >
                      CORTAR
                    </button>
                  </>
                )
              ) : (
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
                              Math.max(
                                actionMinAmount,
                                Number(event.target.value)
                              )
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
              ))}
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
  discards,
}: AgentDiscardResultProps) {
  if (decision === "cut") {
    return (
      <div className="player-seat-action-status cut">
        CORTO EL MUS
      </div>
    );
  }

  return (
    <div className="player-seat-action-status mus">
      <span>
        MUS{discards.length > 0 ? ` · ${discards.length}` : ""}
      </span>

      {discards.length > 0 && (
        <div className="agent-discard-card-list">
          {discards.map((card, index) => {
            const imageUrl = getCardImageUrl(card);

            return (
              <span
                key={`${card}-${index}`}
                className="agent-discard-card"
              >
                {imageUrl ? (
                  <img
                    src={imageUrl}
                    alt={card}
                    className="agent-discard-card-image"
                  />
                ) : (
                  card
                )}
              </span>
            );
          })}
        </div>
      )}
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
    return "PASA";
  }

  if (actionType === "envidar") {
    return `ENVIDA ${amount}`;
  }

  if (actionType === "querer") {
    return "QUIERE";
  }

  if (actionType === "no_querer") {
    return "NO QUIERE";
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
              <span className="playing-card playing-card-fallback">
                {card}
              </span>
            )}
          </button>
        );
      })}
    </div>
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