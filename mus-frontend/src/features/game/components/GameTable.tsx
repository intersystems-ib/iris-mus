import { useEffect, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import type { ActionType, GameState, PlayerId } from "../../../domain/game.types";
import { musApi } from "../../../api/musApi";
import { EventTimeline } from "./EventTimeline";
import { PendingBetPanel } from "./PendingBetPanel";
import { PlayerSeat } from "./PlayerSeat";
import { ScoreBoard } from "./ScoreBoard";
import { PhaseSummaryPanel } from "./PhaseSummaryPanel";
import { HandResultPanel } from "./HandResultPanel";

interface GameTableProps {
  gameState: GameState;
  perspectivePlayerId?: PlayerId;
  onRefresh: () => void;
}

const PLAYER_IDS: PlayerId[] = ["P1", "P2", "P3", "P4"];

const EMPTY_DISCARDS: Record<PlayerId, string[]> = {
  P1: [],
  P2: [],
  P3: [],
  P4: [],
};

type AgentDiscardDecision = "discard" | "cut";
type DiscardPhaseStep = "waiting" | "musDecision" | "discardCount" | "ready";

interface AgentDiscardView {
  playerId: PlayerId;
  decision: AgentDiscardDecision;
  discards: string[];
  cutsMus: boolean;
}

export function GameTable({
  gameState,
  perspectivePlayerId,
  onRefresh,
}: GameTableProps) {
  const [musVotes, setMusVotes] = useState<Partial<Record<PlayerId, boolean>>>(
    {}
  );

  const [selectedDiscards, setSelectedDiscards] =
    useState<Record<PlayerId, string[]>>(EMPTY_DISCARDS);

  const [confirmedDiscards, setConfirmedDiscards] = useState<
    Partial<Record<PlayerId, boolean>>
  >({});

  const [agentDiscardResponses, setAgentDiscardResponses] = useState<
    Partial<Record<PlayerId, AgentDiscardView>>
  >({});

  const [agentDiscardError, setAgentDiscardError] = useState<string | null>(
    null
  );

  const [discardConversationStarted, setDiscardConversationStarted] =
    useState(false);

  const [discardConversationRunning, setDiscardConversationRunning] =
    useState(false);

  const [discardPhaseStep, setDiscardPhaseStep] =
    useState<DiscardPhaseStep>("waiting");

  const [activeDiscardPlayerId, setActiveDiscardPlayerId] =
    useState<PlayerId | null>(null);

  const [pendingHumanDecisionPlayerId, setPendingHumanDecisionPlayerId] =
    useState<PlayerId | null>(null);

  const [visibleDiscardCounts, setVisibleDiscardCounts] = useState<
    Partial<Record<PlayerId, boolean>>
  >({});

  const [actionAmount, setActionAmount] = useState(2);

  const humanDecisionResolversRef = useRef<
    Partial<Record<PlayerId, (decision: boolean) => void>>
  >({});

  const phase = gameState.phase;
  const hand = gameState.hand;

  const isDiscardPhase = gameState.phase === "descartes";
  const startDiscardPlayerId = getDiscardStartPlayerId(gameState);

  const hasAnyCut =
    PLAYER_IDS.some((playerId) => musVotes[playerId] === false) ||
    PLAYER_IDS.some(
      (playerId) => agentDiscardResponses[playerId]?.cutsMus === true
    );

  const allPlayersWantMus =
    isDiscardPhase &&
    PLAYER_IDS.every((playerId) => musVotes[playerId] === true);

  const discardSelectionEnabled =
    isDiscardPhase && allPlayersWantMus && !hasAnyCut;

  const isHandClosed =
    gameState.phase === "manoCerrada" ||
    gameState.hand?.phase === "manoCerrada" ||
    gameState.hand?.status === "closed";

  const targetScore = gameState.targetScore || 40;
  const teamAScore = gameState.score?.teamA ?? 0;
  const teamBScore = gameState.score?.teamB ?? 0;

  const canStartNextHand =
    isHandClosed &&
    gameState.status !== "finished" &&
    !gameState.winnerTeam &&
    teamAScore < targetScore &&
    teamBScore < targetScore;

  const startNextHandMutation = useMutation({
    mutationFn: () => musApi.startNextHand(String(gameState.gameId)),
    onSuccess: () => {
      onRefresh();
    },
  });

  const applyDiscardsMutation = useMutation({
    mutationFn: (discards: Record<PlayerId, string[]>) =>
      musApi.submitDiscards(String(gameState.gameId), {
        discards,
      }),
    onSuccess: () => {
      onRefresh();
    },
  });

  const playerActionMutation = useMutation({
    mutationFn: ({
      playerId,
      actionType,
    }: {
      playerId: PlayerId;
      actionType: ActionType;
    }) =>
      musApi.playerAction(String(gameState.gameId), {
        playerId,
        phase: gameState.phase,
        actionType,
        amount:
          actionType === "ordago"
            ? 999
            : actionType === "envidar"
              ? actionAmount
              : 0,
      }),
    onSuccess: () => {
      setActionAmount(2);
      onRefresh();
    },
  });

  useEffect(() => {
    setMusVotes({});
    setSelectedDiscards({
      P1: [],
      P2: [],
      P3: [],
      P4: [],
    });
    setConfirmedDiscards({});
    setAgentDiscardResponses({});
    setAgentDiscardError(null);
    setDiscardConversationStarted(false);
    setDiscardConversationRunning(false);
    setDiscardPhaseStep("waiting");
    setActiveDiscardPlayerId(null);
    setPendingHumanDecisionPlayerId(null);
    setVisibleDiscardCounts({});
    setActionAmount(2);
    humanDecisionResolversRef.current = {};
  }, [gameState.currentHandId, gameState.discardRound]);

  useEffect(() => {
    if (!isDiscardPhase) {
      return;
    }

    if (discardConversationStarted || discardConversationRunning) {
      return;
    }

    if (!isAgentPlayer(startDiscardPlayerId)) {
      return;
    }

    void runDiscardConversation();
  }, [
    isDiscardPhase,
    discardConversationStarted,
    discardConversationRunning,
    startDiscardPlayerId,
    gameState.currentHandId,
    gameState.discardRound,
  ]);

  function handleMus(playerId: PlayerId) {
    if (!isDiscardPhase || isAgentPlayer(playerId)) {
      return;
    }

    if (
      discardConversationRunning &&
      pendingHumanDecisionPlayerId === playerId
    ) {
      resolveHumanDecision(playerId, true);
      return;
    }

    if (discardConversationStarted) {
      return;
    }

    if (playerId !== startDiscardPlayerId) {
      return;
    }

    setMusVotes((current) => ({
      ...current,
      [playerId]: true,
    }));

    void runDiscardConversation(true);
  }

  function handleCutMus(playerId: PlayerId) {
    if (!isDiscardPhase || isAgentPlayer(playerId)) {
      return;
    }

    if (
      discardConversationRunning &&
      pendingHumanDecisionPlayerId === playerId
    ) {
      resolveHumanDecision(playerId, false);
      return;
    }

    if (discardConversationStarted) {
      return;
    }

    if (playerId !== startDiscardPlayerId) {
      return;
    }

    setMusVotes((current) => ({
      ...current,
      [playerId]: false,
    }));

    setSelectedDiscards({
      P1: [],
      P2: [],
      P3: [],
      P4: [],
    });

    setConfirmedDiscards({});
    setAgentDiscardResponses({});
    setAgentDiscardError(null);
    setDiscardConversationStarted(true);
    setDiscardPhaseStep("ready");
  }

  async function loadAgentDiscardViews(
    agentPlayerIdsToLoad: PlayerId[]
  ): Promise<Partial<Record<PlayerId, AgentDiscardView>>> {
    const responses = await Promise.all(
      agentPlayerIdsToLoad.map(async (playerId) => {
        const response = await musApi.getAgentDiscards(
          String(gameState.gameId),
          playerId
        );

        const discards = Array.isArray(response.discards)
          ? response.discards.map(String)
          : [];

        const cutsMus = Boolean(response.cutsMus) || discards.length === 0;

        const view: AgentDiscardView = {
          playerId,
          decision: cutsMus ? "cut" : "discard",
          discards,
          cutsMus,
        };

        return [playerId, view] as const;
      })
    );

    return Object.fromEntries(responses) as Partial<
      Record<PlayerId, AgentDiscardView>
    >;
  }

  async function runDiscardConversation(firstHumanDecision?: boolean) {
    if (!isDiscardPhase || discardConversationRunning) {
      return;
    }

    const orderedPlayers = getPlayerOrderFrom(startDiscardPlayerId);
    const collectedAgentResponses: Partial<Record<PlayerId, AgentDiscardView>> =
      {};

    setDiscardConversationStarted(true);
    setDiscardConversationRunning(true);
    setDiscardPhaseStep("musDecision");
    setActiveDiscardPlayerId(null);
    setPendingHumanDecisionPlayerId(null);
    setVisibleDiscardCounts({});
    setAgentDiscardError(null);

    try {
      /*
        Llamada en serie:
        cada agente consulta al LLM cuando llega su turno visual.
        Evitamos saturar el proveedor con llamadas paralelas.
      */
      for (const playerId of orderedPlayers) {
        setActiveDiscardPlayerId(playerId);
        setDiscardPhaseStep("musDecision");

        if (isAgentPlayer(playerId)) {
          const response = await musApi.getAgentDiscards(
            String(gameState.gameId),
            playerId
          );

          const discards = Array.isArray(response.discards)
            ? response.discards.map(String)
            : [];

          const cutsMus = Boolean(response.cutsMus) || discards.length === 0;

          const view: AgentDiscardView = {
            playerId,
            decision: cutsMus ? "cut" : "discard",
            discards,
            cutsMus,
          };

          collectedAgentResponses[playerId] = view;

          /*
            Primera fase:
            solo mostramos MUS/CORTAR.
            No rellenamos selectedDiscards ni confirmedDiscards todavía.
          */
          setAgentDiscardResponses((current) => ({
            ...current,
            [playerId]: view,
          }));

          setMusVotes((current) => ({
            ...current,
            [playerId]: !cutsMus,
          }));

          await wait(2000);

          if (cutsMus) {
            setDiscardPhaseStep("ready");
            setActiveDiscardPlayerId(null);
            return;
          }

          continue;
        }

        let humanDecision: boolean;

        if (
          playerId === startDiscardPlayerId &&
          firstHumanDecision !== undefined
        ) {
          humanDecision = firstHumanDecision;
        } else {
          humanDecision = await waitForHumanDecision(playerId);
        }

        setMusVotes((current) => ({
          ...current,
          [playerId]: humanDecision,
        }));

        await wait(2000);

        if (!humanDecision) {
          setDiscardPhaseStep("ready");
          setActiveDiscardPlayerId(null);
          return;
        }
      }

      setDiscardPhaseStep("discardCount");

      for (const playerId of orderedPlayers) {
        setActiveDiscardPlayerId(playerId);

        const agentResponse = collectedAgentResponses[playerId];

        /*
          Segunda fase:
          aquí sí aplicamos visualmente descartes de agentes.
        */
        if (agentResponse && !agentResponse.cutsMus) {
          setSelectedDiscards((current) => ({
            ...current,
            [playerId]: agentResponse.discards,
          }));

          setConfirmedDiscards((current) => ({
            ...current,
            [playerId]: true,
          }));
        }

        setVisibleDiscardCounts((current) => ({
          ...current,
          [playerId]: true,
        }));

        await wait(2000);
      }

      setDiscardPhaseStep("ready");
      setActiveDiscardPlayerId(null);
    } catch (error) {
      setAgentDiscardError(
        error instanceof Error
          ? error.message
          : "No se pudieron consultar los descartes de agentes"
      );
      setDiscardPhaseStep("ready");
      setActiveDiscardPlayerId(null);
    } finally {
      setDiscardConversationRunning(false);
      setPendingHumanDecisionPlayerId(null);
      humanDecisionResolversRef.current = {};
    }
  }

  function waitForHumanDecision(playerId: PlayerId): Promise<boolean> {
    setPendingHumanDecisionPlayerId(playerId);

    return new Promise((resolve) => {
      humanDecisionResolversRef.current[playerId] = resolve;
    });
  }

  function resolveHumanDecision(playerId: PlayerId, decision: boolean) {
    const resolver = humanDecisionResolversRef.current[playerId];

    setMusVotes((current) => ({
      ...current,
      [playerId]: decision,
    }));

    delete humanDecisionResolversRef.current[playerId];
    setPendingHumanDecisionPlayerId(null);

    if (resolver) {
      resolver(decision);
    }
  }

  function handleToggleDiscardCard(playerId: PlayerId, card: string) {
    if (
      !discardSelectionEnabled ||
      confirmedDiscards[playerId] ||
      isAgentPlayer(playerId)
    ) {
      return;
    }

    setSelectedDiscards((current) => {
      const currentCards = current[playerId] ?? [];
      const alreadySelected = currentCards.includes(card);

      return {
        ...current,
        [playerId]: alreadySelected
          ? currentCards.filter((item) => item !== card)
          : [...currentCards, card],
      };
    });
  }

  function handleConfirmDiscards(playerId: PlayerId) {
    if (
      !discardSelectionEnabled ||
      confirmedDiscards[playerId] ||
      applyDiscardsMutation.isPending ||
      isAgentPlayer(playerId)
    ) {
      return;
    }

    setConfirmedDiscards((current) => ({
      ...current,
      [playerId]: true,
    }));
  }

  function handleProceedFromDiscards() {
    if (!isDiscardPhase || applyDiscardsMutation.isPending) {
      return;
    }

    if (hasAnyCut) {
      applyDiscardsMutation.mutate(EMPTY_DISCARDS);
      return;
    }

    applyDiscardsMutation.mutate(selectedDiscards);
  }

  function isAgentPlayer(playerId: PlayerId): boolean {
    const player = getPlayerForAgentView(playerId);

    if (!player) {
      return false;
    }

    const type = String(
      player.type ?? player.playerType ?? player.kind ?? ""
    ).toLowerCase();

    return player.isAgent === true || type === "agent" || type === "bot";
  }

  function getAgentProfile(playerId: PlayerId): string {
    const player = getPlayerForAgentView(playerId);

    return String(player?.agentProfile ?? player?.profile ?? "");
  }

  function getPlayerForAgentView(playerId: PlayerId):
    | {
        id?: unknown;
        type?: unknown;
        playerType?: unknown;
        kind?: unknown;
        isAgent?: unknown;
        agentProfile?: unknown;
        profile?: unknown;
      }
    | undefined {
    const players = gameState.players as unknown;

    if (Array.isArray(players)) {
      return players.find((item) => {
        if (!item || typeof item !== "object") {
          return false;
        }

        return String((item as { id?: unknown }).id) === playerId;
      }) as ReturnType<typeof getPlayerForAgentView>;
    }

    if (players && typeof players === "object") {
      const rawPlayer = (players as Record<string, unknown>)[playerId];

      if (rawPlayer && typeof rawPlayer === "object") {
        return rawPlayer as ReturnType<typeof getPlayerForAgentView>;
      }
    }

    return undefined;
  }

  function canExecuteAgent(playerId: PlayerId): boolean {
    if (isDiscardPhase) {
      return false;
    }

    if (!isAgentPlayer(playerId)) {
      return false;
    }

    if (playerActionMutation.isPending) {
      return false;
    }

    return getLegalActionsForPlayer(playerId).length > 0;
  }

  function handleExecuteAgent(playerId: PlayerId) {
    if (!canExecuteAgent(playerId)) {
      return;
    }

    const actionType = chooseAgentAction(getLegalActionsForPlayer(playerId));

    if (!actionType) {
      return;
    }

    handlePlayerAction(playerId, actionType);
  }

  function chooseAgentAction(legalActions: ActionType[]): ActionType | null {
    if (legalActions.includes("querer")) {
      return "querer";
    }

    if (legalActions.includes("pasar")) {
      return "pasar";
    }

    if (legalActions.includes("envidar")) {
      return "envidar";
    }

    if (legalActions.includes("no_querer")) {
      return "no_querer";
    }

    if (legalActions.includes("ordago")) {
      return "ordago";
    }

    return null;
  }

  function getLegalActionsForPlayer(playerId: PlayerId): ActionType[] {
    if (
      gameState.status === "finished" ||
      gameState.phase === "manoCerrada" ||
      isDiscardPhase ||
      isHandClosed
    ) {
      return [];
    }

    const pendingBet = gameState.hand?.pendingBet;

    if (pendingBet) {
      const respondingPlayers = Array.isArray(pendingBet.respondingPlayers)
        ? pendingBet.respondingPlayers
        : [];

      const canRespond =
        pendingBet.respondingPlayerId === playerId ||
        respondingPlayers.includes(playerId);

      if (!canRespond) {
        return [];
      }

      return ["querer", "no_querer", "envidar", "ordago"];
    }

    if (gameState.turnPlayerId !== playerId) {
      return [];
    }

    return ["pasar", "envidar", "ordago"];
  }

  function handlePlayerAction(playerId: PlayerId, actionType: ActionType) {
    playerActionMutation.mutate({
      playerId,
      actionType,
    });
  }

  function getAgentDiscardDecision(
    playerId: PlayerId
  ): AgentDiscardDecision | undefined {
    return agentDiscardResponses[playerId]?.decision;
  }

  function getAgentRecommendedDiscards(playerId: PlayerId): string[] {
    if (!visibleDiscardCounts[playerId]) {
      return [];
    }

    return agentDiscardResponses[playerId]?.discards ?? [];
  }

  function canProceedFromDiscards(): boolean {
    if (!isDiscardPhase) {
      return false;
    }

    if (discardPhaseStep !== "ready") {
      return false;
    }

    if (applyDiscardsMutation.isPending || discardConversationRunning) {
      return false;
    }

    if (hasAnyCut) {
      return true;
    }

    return PLAYER_IDS.every((playerId) => {
      if (isAgentPlayer(playerId)) {
        const response = agentDiscardResponses[playerId];

        return Boolean(response) && !response.cutsMus;
      }

      return confirmedDiscards[playerId] === true;
    });
  }

  function shouldEnableHumanMusActions(playerId: PlayerId): boolean {
    if (!isDiscardPhase || isAgentPlayer(playerId)) {
      return false;
    }

    if (!discardConversationStarted) {
      return playerId === startDiscardPlayerId;
    }

    return pendingHumanDecisionPlayerId === playerId;
  }

  function renderPlayerSeat(playerId: PlayerId) {
    const isAgent = isAgentPlayer(playerId);

    return (
      <PlayerSeat
        gameState={gameState}
        playerId={playerId}
        perspectivePlayerId={perspectivePlayerId}
        musVoteEnabled={
          shouldEnableHumanMusActions(playerId) ||
          (discardSelectionEnabled && !isAgent)
        }        
        musVote={musVotes[playerId]}
        discardSelectionEnabled={discardSelectionEnabled}
        discardConfirmed={confirmedDiscards[playerId] === true}
        selectedDiscardCards={selectedDiscards[playerId]}
        isSubmittingDiscards={isSubmittingDiscards}
        onMus={() => handleMus(playerId)}
        onCutMus={() => handleCutMus(playerId)}
        onConfirmDiscards={() => handleConfirmDiscards(playerId)}
        onToggleDiscardCard={(card) => handleToggleDiscardCard(playerId, card)}
        actionControlsEnabled={!isDiscardPhase}
        legalActions={getLegalActionsForPlayer(playerId)}
        actionAmount={actionAmount}
        isSubmittingAction={playerActionMutation.isPending}
        onActionAmountChange={setActionAmount}
        onPlayerAction={(actionType) => handlePlayerAction(playerId, actionType)}
        isAgent={isAgent}
        agentProfile={getAgentProfile(playerId)}
        agentActionEnabled={canExecuteAgent(playerId)}
        agentDiscardDecision={getAgentDiscardDecision(playerId)}
        agentRecommendedDiscards={getAgentRecommendedDiscards(playerId)}
        agentDiscardLoading={
          isDiscardPhase &&
          isAgent &&
          discardConversationRunning &&
          activeDiscardPlayerId === playerId &&
          !agentDiscardResponses[playerId]
        }
        isExecutingAgent={playerActionMutation.isPending}
        onExecuteAgent={() => handleExecuteAgent(playerId)}
      />
    );
  }

  const isSubmittingDiscards = applyDiscardsMutation.isPending;

  return (
    <main className="game-table-page">
      <ScoreBoard gameState={gameState} />

      <section className="table-layout">
        <div className="seat-area seat-top">{renderPlayerSeat("P3")}</div>

        <div className="seat-area seat-left">{renderPlayerSeat("P2")}</div>

        <div className="table-center">
          <div className="table-felt">
            <h2>{phase}</h2>
            <p>Mano {hand?.handNumber ?? gameState.handNumber}</p>

            {gameState.winnerTeam && (
              <strong>Ganador: Equipo {gameState.winnerTeam}</strong>
            )}

            {isDiscardPhase && discardPhaseStep === "waiting" && (
              <p className="muted-text">
                {isAgentPlayer(startDiscardPlayerId)
                  ? "El agente inicial está decidiendo si quiere MUS..."
                  : `${startDiscardPlayerId} decide si pide MUS o corta.`}
              </p>
            )}

            {isDiscardPhase && discardPhaseStep === "musDecision" && (
              <p className="muted-text">
                {activeDiscardPlayerId
                  ? `${activeDiscardPlayerId} está decidiendo si quiere MUS...`
                  : "Los jugadores están decidiendo si quieren MUS..."}
              </p>
            )}

            {isDiscardPhase && discardPhaseStep === "discardCount" && (
              <p className="muted-text">
                {activeDiscardPlayerId
                  ? `${activeDiscardPlayerId} muestra sus descartes...`
                  : "Los jugadores muestran cuántas cartas descartan..."}
              </p>
            )}

            {isDiscardPhase && agentDiscardError && (
              <p className="muted-text error-text">
                Error consultando descartes de agentes: {agentDiscardError}
              </p>
            )}

            {isDiscardPhase && discardPhaseStep === "ready" && hasAnyCut && (
              <p className="muted-text">Un jugador corta MUS.</p>
            )}

            {isDiscardPhase && discardPhaseStep === "ready" && !hasAnyCut && (
              <p className="muted-text">
                Descartes preparados. Pulsa SIGUIENTE FASE.
              </p>
            )}

            {isDiscardPhase && discardSelectionEnabled && !hasAnyCut && (
              <p className="muted-text">
                Selecciona cartas y confirma descartes en cada asiento humano.
              </p>
            )}

            {isDiscardPhase && canProceedFromDiscards() && (
              <button
                type="button"
                className="primary-button"
                onClick={handleProceedFromDiscards}
                disabled={applyDiscardsMutation.isPending}
              >
                {applyDiscardsMutation.isPending
                  ? "Aplicando..."
                  : "SIGUIENTE FASE"}
              </button>
            )}
          </div>
        </div>

        <div className="seat-area seat-right">{renderPlayerSeat("P4")}</div>

        <div className="seat-area seat-bottom">{renderPlayerSeat("P1")}</div>
      </section>

      <section className="game-side-panels">
        <PhaseSummaryPanel gameState={gameState} />

        {isHandClosed ? (
          <HandResultPanel
            gameState={gameState}
            canStartNextHand={canStartNextHand}
            isStartingNextHand={startNextHandMutation.isPending}
            onStartNextHand={() => startNextHandMutation.mutate()}
          />
        ) : (
          <PendingBetPanel gameState={gameState} />
        )}

        <EventTimeline actions={gameState.hand?.actions ?? []} />
      </section>
    </main>
  );
}

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });
}

function getDiscardStartPlayerId(gameState: GameState): PlayerId {
  const turnPlayerId = gameState.turnPlayerId;

  if (PLAYER_IDS.includes(turnPlayerId as PlayerId)) {
    return turnPlayerId as PlayerId;
  }

  return "P1";
}

function getPlayerOrderFrom(startPlayerId: PlayerId): PlayerId[] {
  const index = PLAYER_IDS.indexOf(startPlayerId);

  if (index < 0) {
    return PLAYER_IDS;
  }

  return [...PLAYER_IDS.slice(index), ...PLAYER_IDS.slice(0, index)];
}