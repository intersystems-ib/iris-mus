import { useEffect, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import type { ActionType, GameState, PlayerId } from "../../../domain/game.types";
import { musApi } from "../../../api/musApi";
import { EventTimeline } from "./EventTimeline";
import { PendingBetPanel } from "./PendingBetPanel";
import { PlayerSeat } from "./PlayerSeat";
import { ScoreBoard } from "./ScoreBoard";
import { HandResultPanel } from "./HandResultPanel";

interface GameTableProps {
  gameState: GameState;
  perspectivePlayerId?: PlayerId;
  onRefresh: () => void;
}

const PLAYER_IDS: PlayerId[] = ["P1", "P2", "P3", "P4"];
const PHASE_CHANGE_DELAY_MS = 2000;

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

interface PlayerActionView {
  playerId: PlayerId;
  actionType: ActionType;
  amount: number;
  reason?: string;
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

  const [playerActionResponses, setPlayerActionResponses] = useState<
    Partial<Record<PlayerId, PlayerActionView>>
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

  const [executingAgentPlayerId, setExecutingAgentPlayerId] =
    useState<PlayerId | null>(null);

  const [submittingHumanActionPlayerId, setSubmittingHumanActionPlayerId] =
    useState<PlayerId | null>(null);

  const [phaseRefreshPending, setPhaseRefreshPending] = useState(false);

  const [pendingTeamResponses, setPendingTeamResponses] = useState<
    Partial<Record<PlayerId, PlayerActionView>>
  >({});

  const [teamResponseConversationRunning, setTeamResponseConversationRunning] =
    useState(false);

  const [teamResponseApplying, setTeamResponseApplying] = useState(false);

  const [agentActionError, setAgentActionError] = useState<string | null>(
    null
  );

  const humanDecisionResolversRef = useRef<
    Partial<Record<PlayerId, (decision: boolean) => void>>
  >({});

  const automaticAgentTurnRef = useRef("");
  const automaticDiscardSubmitRef = useRef("");
  const pendingTeamResponseApplyRef = useRef("");
  const delayedRefreshTimeoutRef = useRef<number | null>(null);

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

  const handActionCount = gameState.hand?.actions?.length ?? 0;
  const pendingBetKey = JSON.stringify(getCurrentPendingBet() ?? null);
  const actionMinAmount = getActionMinAmount();

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
      scheduleDelayedRefresh();
    },
  });

  const playerActionMutation = useMutation({
    mutationFn: ({
      playerId,
      actionType,
      amount,
    }: {
      playerId: PlayerId;
      actionType: ActionType;
      amount?: number;
    }) =>
      musApi.playerAction(String(gameState.gameId), {
        playerId,
        phase: gameState.phase,
        actionType,
        amount:
          actionType === "ordago"
            ? 999
            : actionType === "envidar"
              ? Math.max(
                  actionMinAmount,
                  amount && amount >= actionMinAmount ? amount : actionAmount
                )
              : 0,
      }),
    onSuccess: () => {
      setActionAmount(2);
      scheduleDelayedRefresh();
    },
    onError: () => {
      setSubmittingHumanActionPlayerId(null);
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
    setPlayerActionResponses({});
    setPendingTeamResponses({});
    setTeamResponseConversationRunning(false);
    setTeamResponseApplying(false);
    setAgentDiscardError(null);
    setDiscardConversationStarted(false);
    setDiscardConversationRunning(false);
    setDiscardPhaseStep("waiting");
    setActiveDiscardPlayerId(null);
    setPendingHumanDecisionPlayerId(null);
    setVisibleDiscardCounts({});
    setActionAmount(2);
    setExecutingAgentPlayerId(null);
    setSubmittingHumanActionPlayerId(null);
    setPhaseRefreshPending(false);
    setAgentActionError(null);
    humanDecisionResolversRef.current = {};
    automaticAgentTurnRef.current = "";
    automaticDiscardSubmitRef.current = "";
    pendingTeamResponseApplyRef.current = "";

    if (delayedRefreshTimeoutRef.current !== null) {
      window.clearTimeout(delayedRefreshTimeoutRef.current);
      delayedRefreshTimeoutRef.current = null;
    }
  }, [gameState.currentHandId, gameState.discardRound]);


  useEffect(() => {
    return () => {
      if (delayedRefreshTimeoutRef.current !== null) {
        window.clearTimeout(delayedRefreshTimeoutRef.current);
      }
    };
  }, []);

  useEffect(() => {
    setPlayerActionResponses({});
  }, [gameState.phase]);

  useEffect(() => {
    setActionAmount((current) =>
      current < actionMinAmount ? actionMinAmount : current
    );
  }, [actionMinAmount]);

  useEffect(() => {
    setPendingTeamResponses({});
    setTeamResponseConversationRunning(false);
    setTeamResponseApplying(false);
    pendingTeamResponseApplyRef.current = "";
  }, [pendingBetKey]);

  useEffect(() => {
    if (!isDiscardPhase || !startDiscardPlayerId) {
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

  useEffect(() => {
    if (!canApplyDiscardsAutomatically()) {
      return;
    }

    const automaticDiscardKey = [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.discardRound ?? "",
      hasAnyCut ? "cut" : "discard",
      JSON.stringify(selectedDiscards),
      JSON.stringify(confirmedDiscards),
      JSON.stringify(agentDiscardResponses),
    ].join(":");

    if (automaticDiscardSubmitRef.current === automaticDiscardKey) {
      return;
    }

    automaticDiscardSubmitRef.current = automaticDiscardKey;

    applyDiscardsMutation.mutate(hasAnyCut ? EMPTY_DISCARDS : selectedDiscards);
  }, [
    isDiscardPhase,
    discardPhaseStep,
    discardConversationRunning,
    hasAnyCut,
    applyDiscardsMutation.isPending,
    gameState.gameId,
    gameState.currentHandId,
    gameState.discardRound,
    selectedDiscards,
    confirmedDiscards,
    agentDiscardResponses,
  ]);

  useEffect(() => {
    if (
      isDiscardPhase ||
      isHandClosed ||
      gameState.status === "finished" ||
      phaseRefreshPending
    ) {
      return;
    }

    const currentPendingBet = getCurrentPendingBet();

    if (currentPendingBet) {
      const responderPlayerIds = getPendingBetResponderTeamPlayerIds(currentPendingBet);

      if (shouldUsePendingBetTeamConversation(currentPendingBet, responderPlayerIds)) {
        return;
      }
    }

    if (
      executingAgentPlayerId ||
      playerActionMutation.isPending ||
      teamResponseConversationRunning ||
      teamResponseApplying
    ) {
      return;
    }

    if (hasHumanPendingAction()) {
      return;
    }

    const nextAgentPlayerId = PLAYER_IDS.find((playerId) =>
      canExecuteAgent(playerId)
    );

    if (!nextAgentPlayerId) {
      automaticAgentTurnRef.current = "";
      return;
    }

    const automaticTurnKey = [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.phase,
      gameState.turnPlayerId ?? "",
      nextAgentPlayerId,
      handActionCount,
      pendingBetKey,
    ].join(":");

    if (automaticAgentTurnRef.current === automaticTurnKey) {
      return;
    }

    automaticAgentTurnRef.current = automaticTurnKey;
    void handleExecuteAgent(nextAgentPlayerId);
  }, [
    isDiscardPhase,
    isHandClosed,
    gameState.status,
    phaseRefreshPending,
    gameState.gameId,
    gameState.currentHandId,
    gameState.phase,
    gameState.turnPlayerId,
    handActionCount,
    pendingBetKey,
    executingAgentPlayerId,
    playerActionMutation.isPending,
    teamResponseConversationRunning,
    teamResponseApplying,
  ]);


  useEffect(() => {
    const pendingBet = getCurrentPendingBet();

    if (!pendingBet) {
      return;
    }

    if (
      isDiscardPhase ||
      isHandClosed ||
      gameState.status === "finished" ||
      phaseRefreshPending ||
      playerActionMutation.isPending ||
      teamResponseConversationRunning ||
      teamResponseApplying
    ) {
      return;
    }

    const responderPlayerIds = getPendingBetResponderTeamPlayerIds(pendingBet);

    if (responderPlayerIds.length === 0) {
      return;
    }

    if (!shouldUsePendingBetTeamConversation(pendingBet, responderPlayerIds)) {
      return;
    }

    const missingAgentPlayerIds = responderPlayerIds.filter(
      (playerId) =>
        isAgentPlayer(playerId) &&
        !pendingTeamResponses[playerId] &&
        !hasPlayerAlreadyRespondedToCurrentPendingBet(playerId)
    );

    /*
      En equipos mixtos humano + agente, consultamos al agente primero para
      mostrar su respuesta, pero no aplicamos nada hasta que el humano responda.
      Asi podemos comparar ambas respuestas y mostrar solo la mas fuerte.
    */
    if (missingAgentPlayerIds.length > 0) {
      void collectPendingBetAgentResponses(missingAgentPlayerIds);
      return;
    }

    const missingHumanPlayerIds = responderPlayerIds.filter(
      (playerId) =>
        !isAgentPlayer(playerId) &&
        !pendingTeamResponses[playerId] &&
        !hasPlayerAlreadyRespondedToCurrentPendingBet(playerId)
    );

    if (missingHumanPlayerIds.length > 0) {
      return;
    }

    void applyStrongestPendingBetTeamResponse(pendingBet, responderPlayerIds);
  }, [
    isDiscardPhase,
    isHandClosed,
    gameState.status,
    phaseRefreshPending,
    gameState.gameId,
    gameState.currentHandId,
    gameState.phase,
    gameState.turnPlayerId,
    handActionCount,
    pendingBetKey,
    pendingTeamResponses,
    playerActionMutation.isPending,
    teamResponseConversationRunning,
    teamResponseApplying,
  ]);

  function scheduleDelayedRefresh() {
    if (delayedRefreshTimeoutRef.current !== null) {
      window.clearTimeout(delayedRefreshTimeoutRef.current);
    }

    setPhaseRefreshPending(true);

    delayedRefreshTimeoutRef.current = window.setTimeout(() => {
      delayedRefreshTimeoutRef.current = null;
      onRefresh();
      setPhaseRefreshPending(false);
      setSubmittingHumanActionPlayerId(null);
    }, PHASE_CHANGE_DELAY_MS);
  }

  function hasHumanPendingAction(): boolean {
    if (
      isDiscardPhase ||
      isHandClosed ||
      gameState.status === "finished" ||
      phaseRefreshPending
    ) {
      return false;
    }

    return PLAYER_IDS.some((playerId) => {
      if (isAgentPlayer(playerId)) {
        return false;
      }

      return getLegalActionsForPlayer(playerId).length > 0;
    });
  }

  function handleMus(playerId: PlayerId) {
    if (!isDiscardPhase || !startDiscardPlayerId || isAgentPlayer(playerId)) {
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
    if (!isDiscardPhase || !startDiscardPlayerId || isAgentPlayer(playerId)) {
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
    setPlayerActionResponses({});
    setPendingTeamResponses({});
    setTeamResponseConversationRunning(false);
    setTeamResponseApplying(false);
    setAgentDiscardError(null);
    setDiscardConversationStarted(true);
    setDiscardPhaseStep("ready");
  }

  async function runDiscardConversation(firstHumanDecision?: boolean) {
    if (!isDiscardPhase || !startDiscardPlayerId || discardConversationRunning) {
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
    if (
      isDiscardPhase ||
      isHandClosed ||
      gameState.status === "finished" ||
      gameState.phase === "manoCerrada" ||
      gameState.hand?.phase === "manoCerrada" ||
      gameState.hand?.status === "closed"
    ) {
      return false;
    }

    if (!isAgentPlayer(playerId)) {
      return false;
    }

    if (playerActionMutation.isPending || executingAgentPlayerId !== null) {
      return false;
    }

    const pendingBet = getCurrentPendingBet();
    const currentTurnPlayerId = getCurrentTurnPlayerId();

    /*
      Si hay pendingBet y NO aplica conversacion de equipo entre dos agentes,
      el agente que tenga el turno real del backend debe poder responder.
      Antes se bloqueaba cualquier agente con pendingBet activo y el compañero
      agente del humano nunca contestaba.
    */
    if (pendingBet) {
      const responderPlayerIds = getPendingBetResponderTeamPlayerIds(pendingBet);

      if (shouldUsePendingBetTeamConversation(pendingBet, responderPlayerIds)) {
        return false;
      }

      if (currentTurnPlayerId && currentTurnPlayerId !== playerId) {
        return false;
      }

      return getLegalActionsForPlayer(playerId).length > 0;
    }

    if (currentTurnPlayerId && currentTurnPlayerId !== playerId) {
      return false;
    }

    return getLegalActionsForPlayer(playerId).length > 0;
  }

  async function handleExecuteAgent(playerId: PlayerId) {
    if (!canExecuteAgent(playerId)) {
      return;
    }

    if (
      isHandClosed ||
      gameState.status === "finished" ||
      gameState.phase === "manoCerrada" ||
      gameState.hand?.phase === "manoCerrada" ||
      gameState.hand?.status === "closed"
    ) {
      return;
    }

    setExecutingAgentPlayerId(playerId);
    setAgentActionError(null);

    try {
      const recommendation = await musApi.getAgentAction(
        String(gameState.gameId),
        playerId
      );

      if (!recommendation.success) {
        throw new Error(
          recommendation.errorMessage ??
            "No se pudo obtener la accion del agente"
        );
      }

      const actionType = normalizeAgentActionType(
        recommendation.actionType ?? recommendation.type
      );

      if (!actionType) {
        throw new Error("El agente no devolvio una accion valida");
      }

      const recommendedAmount = Number(recommendation.amount);
      const amount = Number.isFinite(recommendedAmount)
        ? recommendedAmount
        : undefined;

      const displayedAmount =
        actionType === "ordago"
          ? 999
          : actionType === "envidar"
            ? Math.max(actionMinAmount, amount ?? actionAmount)
            : 0;

      setPlayerActionResponses((current) => ({
        ...current,
        [playerId]: {
          playerId,
          actionType,
          amount: displayedAmount,
          reason: recommendation.reason,
        },
      }));

      /*
        No revalidamos contra getLegalActionsForPlayer aqui.
        La recomendacion del agente se calcula en backend con el estado real
        de la partida. La validacion definitiva corresponde al backend al
        aplicar la accion.
      */
      await playerActionMutation.mutateAsync({
        playerId,
        actionType,
        amount,
      });
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : "No se pudo ejecutar la accion del agente";

      if (isClosedPhaseAgentError(message)) {
        scheduleDelayedRefresh();
        return;
      }

      setAgentActionError(message);
    } finally {
      setExecutingAgentPlayerId(null);
    }
  }

  function isClosedPhaseAgentError(message: string): boolean {
    const normalized = message.toLowerCase();

    return (
      normalized.includes("manocerrada") ||
      normalized.includes("mano cerrada") ||
      normalized.includes("phase manocerrada") ||
      normalized.includes("phase manoCerrada".toLowerCase())
    );
  }

  function getCurrentPendingBet(): unknown {
    const handRecord = gameState.hand as unknown as Record<string, unknown>;
    const gameStateRecord = gameState as unknown as Record<string, unknown>;

    const candidates = [
      handRecord?.pendingBet,
      getNestedValue(handRecord, ["phaseState", "pendingBet"]),
      getNestedValue(gameStateRecord, ["phaseState", "pendingBet"]),
    ];

    return candidates.find(isActivePendingBet) ?? null;
  }

  function getNestedValue(
    source: Record<string, unknown> | undefined,
    path: string[]
  ): unknown {
    let current: unknown = source;

    for (const key of path) {
      if (!current || typeof current !== "object") {
        return null;
      }

      current = (current as Record<string, unknown>)[key];
    }

    return current;
  }

  function isActivePendingBet(value: unknown): boolean {
    if (!value || typeof value !== "object") {
      return false;
    }

    const record = value as Record<string, unknown>;

    /*
      Un pendingBet activo debe tener al menos alguna señal real de envite.
      Esto evita coger objetos residuales o vacíos.
    */
    return Boolean(
      record.type ||
        record.amount ||
        record.respondingTeam ||
        record.responderTeam ||
        record.pendingTeam ||
        record.respondingPlayerId ||
        record.respondingPlayers ||
        record.responderPlayers ||
        record.pendingPlayers ||
        record.aggressorPlayerId ||
        record.lastAggressorPlayerId ||
        record.raiserPlayerId ||
        record.playerId
    );
  }

  function getCurrentTurnPlayerId(): PlayerId | null {
    const turnPlayerId = gameState.turnPlayerId;

    if (PLAYER_IDS.includes(turnPlayerId as PlayerId)) {
      return turnPlayerId as PlayerId;
    }

    return null;
  }

  function getLegalActionsForPlayer(playerId: PlayerId): ActionType[] {
    if (
      gameState.status === "finished" ||
      gameState.phase === "manoCerrada" ||
      isDiscardPhase ||
      isHandClosed ||
      phaseRefreshPending
    ) {
      return [];
    }

    const pendingBet = getCurrentPendingBet();

    /*
      Regla importante:
      si existe pendingBet, estamos en modo respuesta.
      En modo respuesta NUNCA se devuelve PASAR.
    */
    if (pendingBet) {
      if (!canPlayerRespondToPendingBet(playerId, pendingBet)) {
        return [];
      }

      if (getPendingBetType(pendingBet) === "ordago") {
        return ["querer", "no_querer"];
      }

      return ["envidar", "querer", "no_querer", "ordago"];
    }

    /*
      Solo si NO hay pendingBet usamos el turno normal.
    */
    if (gameState.turnPlayerId !== playerId) {
      return [];
    }

    return ["pasar", "envidar", "ordago"];
  }

  function getActionMinAmount(): number {
    const pendingBet = getCurrentPendingBet();

    if (!pendingBet) {
      return 2;
    }

    const pendingAmount = getPendingBetAmount(pendingBet);

    if (pendingAmount <= 0) {
      return 2;
    }

    return pendingAmount + 1;
  }

  function getPendingBetAmount(pendingBet: unknown): number {
    if (!pendingBet || typeof pendingBet !== "object") {
      return 0;
    }

    const record = pendingBet as Record<string, unknown>;
    const rawAmount =
      record.amount ??
      record.currentAmount ??
      record.pendingAmount ??
      record.betAmount ??
      record.value;

    const amount = Number(rawAmount);

    return Number.isFinite(amount) ? amount : 0;
  }

  function canPlayerRespondToPendingBet(
    playerId: PlayerId,
    pendingBet: unknown
  ): boolean {
    if (!pendingBet || typeof pendingBet !== "object") {
      return false;
    }

    const currentAggressorPlayerId = getPendingBetAggressorPlayerId(pendingBet);

    if (currentAggressorPlayerId === playerId) {
      return false;
    }

    if (pendingTeamResponses[playerId]) {
      return false;
    }

    if (hasPlayerAlreadyRespondedToCurrentPendingBet(playerId)) {
      return false;
    }

    const responderPlayerIds = getPendingBetResponderTeamPlayerIds(pendingBet);

    if (shouldUsePendingBetTeamConversation(pendingBet, responderPlayerIds)) {
      return responderPlayerIds.includes(playerId);
    }

    const currentTurnPlayerId = getCurrentTurnPlayerId();

    if (currentTurnPlayerId) {
      return currentTurnPlayerId === playerId && responderPlayerIds.includes(playerId);
    }

    const explicitResponders = getPendingBetPlayerIds(pendingBet, [
      "respondingPlayerId",
      "responderPlayerId",
      "pendingPlayerId",
      "respondingPlayers",
      "responderPlayers",
      "pendingPlayers",
    ]);

    if (explicitResponders.length > 0) {
      return explicitResponders.includes(playerId);
    }

    return responderPlayerIds.includes(playerId);
  }

  function hasPlayerAlreadyRespondedToCurrentPendingBet(
    playerId: PlayerId
  ): boolean {
    const actions = gameState.hand?.actions;

    if (!Array.isArray(actions)) {
      return false;
    }

    const latestAggressionIndex = getLatestPendingBetAggressionActionIndex(
      actions
    );

    if (latestAggressionIndex < 0) {
      return false;
    }

    for (let index = latestAggressionIndex + 1; index < actions.length; index += 1) {
      const action = actions[index];
      const actionPlayerId = getActionPlayerId(action);

      if (actionPlayerId !== playerId) {
        continue;
      }

      const actionType = getActionTypeFromEvent(action);

      if (actionType === "querer" || actionType === "no_querer") {
        return true;
      }
    }

    return false;
  }

  function getLatestPendingBetAggressionActionIndex(actions: unknown[]): number {
    for (let index = actions.length - 1; index >= 0; index -= 1) {
      const actionType = getActionTypeFromEvent(actions[index]);

      if (actionType === "envidar" || actionType === "ordago") {
        return index;
      }
    }

    return -1;
  }

  function getActionPlayerId(action: unknown): PlayerId | null {
    if (!action || typeof action !== "object") {
      return null;
    }

    const record = action as Record<string, unknown>;
    const playerId = String(
      record.playerId ?? record.actorPlayerId ?? record.byPlayerId ?? ""
    );

    return PLAYER_IDS.includes(playerId as PlayerId)
      ? (playerId as PlayerId)
      : null;
  }

  function getActionTypeFromEvent(action: unknown): ActionType | null {
    if (!action || typeof action !== "object") {
      return null;
    }

    const record = action as Record<string, unknown>;

    return normalizeAgentActionType(
      record.actionType ?? record.type ?? record.name
    );
  }


  function shouldUsePendingBetTeamConversation(
    pendingBet: unknown,
    responderPlayerIds: PlayerId[]
  ): boolean {
    if (responderPlayerIds.length !== 2) {
      return false;
    }

    /*
      Si el backend apunta a un unico respondedor explicito, respetamos ese
      turno individual. Esto evita bloquear lances como pares/juego cuando solo
      uno de los dos tiene jugada.
    */
    if (getExplicitPendingBetResponderPlayerIds(pendingBet).length === 1) {
      return false;
    }

    /*
      Usamos conversacion de equipo tanto en equipo de dos agentes como en
      equipo mixto humano + agente. En el caso mixto, primero se consulta al
      agente y se espera al humano antes de aplicar la respuesta mas fuerte.
    */
    return responderPlayerIds.some((playerId) => isAgentPlayer(playerId));
  }

  function getExplicitPendingBetResponderPlayerIds(
    pendingBet: unknown
  ): PlayerId[] {
    return getPendingBetPlayerIds(pendingBet, [
      "respondingPlayerId",
      "responderPlayerId",
      "pendingPlayerId",
      "respondingPlayers",
      "responderPlayers",
      "pendingPlayers",
    ]);
  }

  function getPendingBetResponderTeamPlayerIds(pendingBet: unknown): PlayerId[] {
    if (!pendingBet || typeof pendingBet !== "object") {
      return [];
    }

    const explicitResponders = getPendingBetPlayerIds(pendingBet, [
      "respondingPlayerId",
      "responderPlayerId",
      "pendingPlayerId",
      "respondingPlayers",
      "responderPlayers",
      "pendingPlayers",
    ]);

    if (explicitResponders.length > 0) {
      const explicitTeam = getPlayerTeamId(explicitResponders[0]);

      if (explicitTeam) {
        return PLAYER_IDS.filter(
          (playerId) => getPlayerTeamId(playerId) === explicitTeam
        );
      }

      return explicitResponders;
    }

    const respondingTeam = getPendingBetRespondingTeam(pendingBet);

    if (respondingTeam) {
      return PLAYER_IDS.filter(
        (playerId) => getPlayerTeamId(playerId) === respondingTeam
      );
    }

    const aggressorPlayerId = getPendingBetAggressorPlayerId(pendingBet);

    if (!aggressorPlayerId) {
      return [];
    }

    const aggressorTeam = getPlayerTeamId(aggressorPlayerId);

    if (!aggressorTeam) {
      return [];
    }

    return PLAYER_IDS.filter(
      (playerId) => getPlayerTeamId(playerId) !== aggressorTeam
    );
  }

  function getPendingBetExecutionPlayerId(
    pendingBet: unknown,
    responderPlayerIds: PlayerId[]
  ): PlayerId | null {
    const currentTurnPlayerId = getCurrentTurnPlayerId();

    if (
      currentTurnPlayerId &&
      responderPlayerIds.includes(currentTurnPlayerId)
    ) {
      return currentTurnPlayerId;
    }

    const explicitResponder = getPendingBetSinglePlayerId(pendingBet, [
      "respondingPlayerId",
      "responderPlayerId",
      "pendingPlayerId",
    ]);

    if (explicitResponder && responderPlayerIds.includes(explicitResponder)) {
      return explicitResponder;
    }

    return responderPlayerIds[0] ?? null;
  }

  async function collectPendingBetAgentResponses(
    agentPlayerIds: PlayerId[]
  ) {
    if (teamResponseConversationRunning) {
      return;
    }

    setTeamResponseConversationRunning(true);
    setAgentActionError(null);

    const collectedViews: PlayerActionView[] = [];

    try {
      for (const playerId of agentPlayerIds) {
        setExecutingAgentPlayerId(playerId);

        const recommendation = await musApi.getAgentAction(
          String(gameState.gameId),
          playerId
        );

        if (!recommendation.success) {
          throw new Error(
            recommendation.errorMessage ??
              "No se pudo obtener la accion del agente"
          );
        }

        const rawActionType = normalizeAgentActionType(
          recommendation.actionType ?? recommendation.type
        );

        if (!rawActionType) {
          throw new Error("El agente no devolvio una accion valida");
        }

        const actionType = normalizePendingBetTeamResponseAction(rawActionType);
        const recommendedAmount = Number(recommendation.amount);
        const amount = getDisplayedActionAmount(
          actionType,
          Number.isFinite(recommendedAmount) ? recommendedAmount : undefined
        );

        const view: PlayerActionView = {
          playerId,
          actionType,
          amount,
          reason: recommendation.reason,
        };

        collectedViews.push(view);

        /*
          Mostramos la respuesta de cada agente en cuanto llega.
          No esperamos a tener las respuestas de todo el equipo para pintar
          el PlayerSeat: mientras el backend responde se ve PENSANDO y,
          al terminar esa llamada, se ve la decision de ese agente.
        */
        setPendingTeamResponses((current) => ({
          ...current,
          [playerId]: view,
        }));
      }
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : "No se pudo consultar la respuesta del equipo rival";

      if (isClosedPhaseAgentError(message)) {
        scheduleDelayedRefresh();
        return;
      }

      setAgentActionError(message);
    } finally {
      setExecutingAgentPlayerId(null);
      setTeamResponseConversationRunning(false);
    }
  }

  async function applyStrongestPendingBetTeamResponse(
    pendingBet: unknown,
    responderPlayerIds: PlayerId[]
  ) {
    if (teamResponseApplying || playerActionMutation.isPending) {
      return;
    }

    const responseViews = responderPlayerIds
      .map((playerId) => pendingTeamResponses[playerId])
      .filter((view): view is PlayerActionView => Boolean(view));

    if (responseViews.length === 0) {
      return;
    }

    const strongestResponse = pickStrongestPendingBetResponse(responseViews);

    /*
      Mantenemos visibles las decisiones de todos los agentes rivales hasta
      que el refresco diferido cambie de fase. La accion ejecutada sigue siendo
      la mas fuerte, pero no ocultamos las respuestas mas debiles antes de que
      el jugador humano pueda verlas.
    */

    const executionPlayerId = getPendingBetExecutionPlayerId(
      pendingBet,
      responderPlayerIds
    );

    if (!executionPlayerId) {
      return;
    }

    const applyKey = [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.phase,
      pendingBetKey,
      executionPlayerId,
      strongestResponse.actionType,
      strongestResponse.amount,
      JSON.stringify(responseViews),
    ].join(":");

    if (pendingTeamResponseApplyRef.current === applyKey) {
      return;
    }

    pendingTeamResponseApplyRef.current = applyKey;
    setTeamResponseApplying(true);
    setSubmittingHumanActionPlayerId(executionPlayerId);

    try {
      await playerActionMutation.mutateAsync({
        playerId: executionPlayerId,
        actionType: strongestResponse.actionType,
        amount:
          strongestResponse.actionType === "envidar"
            ? strongestResponse.amount
            : undefined,
      });
    } finally {
      setTeamResponseApplying(false);
    }
  }

  function keepOnlyStrongestPendingBetTeamResponse(
    responderPlayerIds: PlayerId[],
    strongestResponse: PlayerActionView
  ) {
    setPendingTeamResponses((current) => {
      const next = { ...current };

      for (const playerId of responderPlayerIds) {
        delete next[playerId];
      }

      next[strongestResponse.playerId] = strongestResponse;

      return next;
    });

    setPlayerActionResponses((current) => {
      const next = { ...current };

      for (const playerId of responderPlayerIds) {
        delete next[playerId];
      }

      next[strongestResponse.playerId] = strongestResponse;

      return next;
    });
  }

  function pickStrongestPendingBetResponse(
    responses: PlayerActionView[]
  ): PlayerActionView {
    return [...responses].sort((left, right) => {
      const strengthDiff =
        getPendingBetResponseStrength(right) -
        getPendingBetResponseStrength(left);

      if (strengthDiff !== 0) {
        return strengthDiff;
      }

      return right.amount - left.amount;
    })[0];
  }

  function normalizePendingBetTeamResponseAction(
    actionType: ActionType
  ): ActionType {
    if (actionType === "pasar") {
      return "querer";
    }

    return actionType;
  }

  function getPendingBetResponseStrength(response: PlayerActionView): number {
    if (response.actionType === "ordago") {
      return 4;
    }

    if (response.actionType === "envidar") {
      return 3;
    }

    if (response.actionType === "querer") {
      return 2;
    }

    if (response.actionType === "no_querer") {
      return 1;
    }

    return 0;
  }

  function getPendingBetType(pendingBet: unknown): string {
    if (!pendingBet || typeof pendingBet !== "object") {
      return "";
    }

    return String((pendingBet as { type?: unknown }).type ?? "").toLowerCase();
  }

  function getPendingBetAggressorPlayerId(pendingBet: unknown): PlayerId | null {
    return getPendingBetSinglePlayerId(pendingBet, [
      "aggressorPlayerId",
      "lastAggressorPlayerId",
      "raiserPlayerId",
      "raisedByPlayerId",
      "createdByPlayerId",
      "playerId",
    ]);
  }

  function getPendingBetPlayerIds(
    pendingBet: unknown,
    fieldNames: string[]
  ): PlayerId[] {
    if (!pendingBet || typeof pendingBet !== "object") {
      return [];
    }

    const record = pendingBet as Record<string, unknown>;
    const result: PlayerId[] = [];

    for (const fieldName of fieldNames) {
      const value = record[fieldName];

      if (typeof value === "string" && PLAYER_IDS.includes(value as PlayerId)) {
        if (!result.includes(value as PlayerId)) {
          result.push(value as PlayerId);
        }
      }

      if (Array.isArray(value)) {
        for (const item of value) {
          if (typeof item === "string" && PLAYER_IDS.includes(item as PlayerId)) {
            if (!result.includes(item as PlayerId)) {
              result.push(item as PlayerId);
            }
          }
        }
      }
    }

    return result;
  }

  function getPendingBetSinglePlayerId(
    pendingBet: unknown,
    fieldNames: string[]
  ): PlayerId | null {
    if (!pendingBet || typeof pendingBet !== "object") {
      return null;
    }

    const record = pendingBet as Record<string, unknown>;

    for (const fieldName of fieldNames) {
      const value = record[fieldName];

      if (typeof value === "string" && PLAYER_IDS.includes(value as PlayerId)) {
        return value as PlayerId;
      }
    }

    return null;
  }

  function getPendingBetRespondingTeam(pendingBet: unknown): string {
    if (!pendingBet || typeof pendingBet !== "object") {
      return "";
    }

    const record = pendingBet as Record<string, unknown>;

    return normalizeTeamId(
      record.respondingTeam ?? record.responderTeam ?? record.pendingTeam
    );
  }

  function getPlayerTeamId(playerId: PlayerId): string {
    const player = getPlayerForAgentView(playerId) as
      | ({ team?: unknown; teamId?: unknown; side?: unknown } & Record<
          string,
          unknown
        >)
      | undefined;

    const explicitTeam = normalizeTeamId(
      player?.team ?? player?.teamId ?? player?.side
    );

    if (explicitTeam) {
      return explicitTeam;
    }

    if (playerId === "P1" || playerId === "P3") {
      return "A";
    }

    if (playerId === "P2" || playerId === "P4") {
      return "B";
    }

    return "";
  }

  function normalizeTeamId(value: unknown): string {
    const text = String(value ?? "")
      .trim()
      .toUpperCase()
      .replace(/^TEAM/, "");

    if (text === "A" || text === "B") {
      return text;
    }

    return "";
  }

  function handlePlayerAction(
    playerId: PlayerId,
    actionType: ActionType,
    amount?: number
  ) {
    const pendingBet = getCurrentPendingBet();
    const responseActionType = pendingBet
      ? normalizePendingBetTeamResponseAction(actionType)
      : actionType;
    const responseDisplayedAmount = getDisplayedActionAmount(
      responseActionType,
      amount
    );

    const view: PlayerActionView = {
      playerId,
      actionType: responseActionType,
      amount: responseDisplayedAmount,
    };

    if (
      pendingBet &&
      shouldUsePendingBetTeamConversation(
        pendingBet,
        getPendingBetResponderTeamPlayerIds(pendingBet)
      ) &&
      canPlayerRespondToPendingBet(playerId, pendingBet)
    ) {
      setPendingTeamResponses((current) => ({
        ...current,
        [playerId]: view,
      }));

      setSubmittingHumanActionPlayerId(playerId);
      return;
    }

    setPlayerActionResponses((current) => ({
      ...current,
      [playerId]: view,
    }));

    setSubmittingHumanActionPlayerId(playerId);

    playerActionMutation.mutate({
      playerId,
      actionType,
      amount,
    });
  }

  function getDisplayedActionAmount(
    actionType: ActionType,
    amount?: number
  ): number {
    if (actionType === "ordago") {
      return 999;
    }

    if (actionType === "envidar") {
      return Math.max(actionMinAmount, amount ?? actionAmount);
    }

    return 0;
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

  function canApplyDiscardsAutomatically(): boolean {
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
    if (!isDiscardPhase || !startDiscardPlayerId || isAgentPlayer(playerId)) {
      return false;
    }

    if (!discardConversationStarted) {
      return playerId === startDiscardPlayerId;
    }

    return pendingHumanDecisionPlayerId === playerId;
  }

  function getPlayerActionView(playerId: PlayerId): PlayerActionView | undefined {
    const pendingBet = getCurrentPendingBet();

    if (pendingBet) {
      const responderPlayerIds = getPendingBetResponderTeamPlayerIds(pendingBet);

      if (
        shouldUsePendingBetTeamConversation(pendingBet, responderPlayerIds) &&
        responderPlayerIds.includes(playerId)
      ) {
        return getVisiblePendingBetTeamResponseForPlayer(
          playerId,
          responderPlayerIds
        );
      }
    }

    const view = playerActionResponses[playerId];

    if (!view) {
      return undefined;
    }

    return shouldShowPlayerActionMessage(view.actionType) ? view : undefined;
  }

  function getVisiblePendingBetTeamResponseForPlayer(
    playerId: PlayerId,
    responderPlayerIds: PlayerId[]
  ): PlayerActionView | undefined {
    if (!responderPlayerIds.includes(playerId)) {
      return undefined;
    }

    const view = pendingTeamResponses[playerId];

    if (!view) {
      return undefined;
    }

    return shouldShowPlayerActionMessage(view.actionType) ? view : undefined;
  }

  function shouldShowPlayerActionMessage(actionType: ActionType): boolean {
    return (
      actionType === "pasar" ||
      actionType === "envidar" ||
      actionType === "querer" ||
      actionType === "no_querer" ||
      actionType === "ordago"
    );
  }

  function shouldHighlightPendingBetResponder(playerId: PlayerId): boolean {
    if (isDiscardPhase || isHandClosed || gameState.status === "finished") {
      return false;
    }

    const pendingBet = getCurrentPendingBet();

    if (!pendingBet) {
      return false;
    }

    const responderPlayerIds = getPendingBetResponderTeamPlayerIds(pendingBet);

    return responderPlayerIds.includes(playerId);
  }

  function getHandResultRecord(): Record<string, unknown> {
    const handRecord = gameState.hand as unknown as Record<string, unknown>;
    const gameStateRecord = gameState as unknown as Record<string, unknown>;

    const candidates = [
      handRecord?.result,
      handRecord?.handResult,
      handRecord?.summary,
      gameStateRecord?.handResult,
      gameStateRecord?.lastHandResult,
      gameStateRecord?.result,
    ];

    for (const candidate of candidates) {
      if (candidate && typeof candidate === "object") {
        return candidate as Record<string, unknown>;
      }
    }

    return {};
  }

  function getHandResultWinnerTeam(): string {
    const result = getHandResultRecord();
    const handRecord = gameState.hand as unknown as Record<string, unknown>;

    return normalizeTeamId(
      result.winnerTeam ??
        result.winningTeam ??
        result.team ??
        handRecord.winnerTeam ??
        handRecord.winningTeam ??
        gameState.winnerTeam
    );
  }

  function getHandResultPoints(): number {
    const result = getHandResultRecord();
    const rawPoints =
      result.points ??
      result.totalPoints ??
      result.handPoints ??
      result.score ??
      result.amount;

    const points = Number(rawPoints);

    return Number.isFinite(points) && points > 0 ? points : 0;
  }

  function getHandResultTitle(): string {
    const winnerTeam = getHandResultWinnerTeam();

    if (winnerTeam) {
      return `Gana Equipo ${winnerTeam}`;
    }

    return "Mano finalizada";
  }

  function getHandResultDescription(): string {
    const result = getHandResultRecord();
    const message = String(
      result.message ?? result.reason ?? result.summary ?? ""
    ).trim();

    if (message) {
      return message;
    }

    const points = getHandResultPoints();

    if (points > 0) {
      return `Resultado de la mano: ${points} punto${points === 1 ? "" : "s"}.`;
    }

    return `Marcador: Equipo A ${teamAScore} - Equipo B ${teamBScore}.`;
  }

  function renderPlayerSeat(playerId: PlayerId) {
    const isAgent = isAgentPlayer(playerId);
    const playerActionView = getPlayerActionView(playerId);
    const isLocallySubmittingAction =
      submittingHumanActionPlayerId === playerId;
    const visibleLegalActions =
      isAgent ||
      phaseRefreshPending ||
      isLocallySubmittingAction ||
      Boolean(playerActionView) ||
      teamResponseApplying
        ? []
        : getLegalActionsForPlayer(playerId);

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
        actionControlsEnabled={!isDiscardPhase && !isAgent}
        legalActions={visibleLegalActions}
        actionAmount={actionAmount}
        actionMinAmount={actionMinAmount}
        isSubmittingAction={isLocallySubmittingAction}
        onActionAmountChange={setActionAmount}
        onPlayerAction={(actionType) => handlePlayerAction(playerId, actionType)}
        isAgent={isAgent}
        agentProfile={getAgentProfile(playerId)}
        agentActionEnabled={false}
        agentDiscardDecision={getAgentDiscardDecision(playerId)}
        agentRecommendedDiscards={getAgentRecommendedDiscards(playerId)}
        agentDiscardLoading={
          isDiscardPhase &&
          isAgent &&
          discardConversationRunning &&
          activeDiscardPlayerId === playerId &&
          !agentDiscardResponses[playerId]
        }
        playerActionView={playerActionView}
        isExecutingAgent={executingAgentPlayerId === playerId}
        forceTurnHighlight={shouldHighlightPendingBetResponder(playerId)}
        onExecuteAgent={() => {
          void handleExecuteAgent(playerId);
        }}
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
            {isHandClosed ? (
              <>
                <h2>{getHandResultTitle()}</h2>
                <p>{getHandResultDescription()}</p>

                {canStartNextHand && (
                  <button
                    type="button"
                    className="primary-button"
                    onClick={() => startNextHandMutation.mutate()}
                    disabled={startNextHandMutation.isPending}
                  >
                    {startNextHandMutation.isPending
                      ? "Repartiendo..."
                      : "Repartir"}
                  </button>
                )}
              </>
            ) : (
              <>
                <h2>{phase}</h2>
                <p>Mano {hand?.handNumber ?? gameState.handNumber}</p>

                {gameState.winnerTeam && (
                  <strong>Ganador: Equipo {gameState.winnerTeam}</strong>
                )}
              </>
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

            {agentActionError && (
              <p className="muted-text error-text">
                Error ejecutando agente: {agentActionError}
              </p>
            )}

            {isDiscardPhase && discardPhaseStep === "ready" && hasAnyCut && (
              <p className="muted-text">Un jugador corta MUS. Avanzando fase...</p>
            )}

            {isDiscardPhase && discardPhaseStep === "ready" && !hasAnyCut && (
              <p className="muted-text">
                Descartes preparados. Avanzando fase...
              </p>
            )}

            {isDiscardPhase && discardSelectionEnabled && !hasAnyCut && (
              <p className="muted-text">
                Selecciona cartas para descartar.
              </p>
            )}

          </div>
        </div>

        <div className="seat-area seat-right">{renderPlayerSeat("P4")}</div>

        <div className="seat-area seat-bottom">{renderPlayerSeat("P1")}</div>
      </section>

      <section className="game-side-panels">
        {isHandClosed ? (
          <HandResultPanel
            gameState={gameState}
            canStartNextHand={false}
            isStartingNextHand={false}
            onStartNextHand={() => undefined}
          />
        ) : (
          <PendingBetPanel gameState={gameState} />
        )}

        <EventTimeline actions={gameState.hand?.actions ?? []} />
      </section>
    </main>
  );
}

function normalizeAgentActionType(value: unknown): ActionType | null {
  const actionType = String(value ?? "").toLowerCase();

  if (
    actionType === "pasar" ||
    actionType === "envidar" ||
    actionType === "querer" ||
    actionType === "no_querer" ||
    actionType === "ordago"
  ) {
    return actionType as ActionType;
  }

  return null;
}

function getDiscardStartPlayerId(gameState: GameState): PlayerId {
  /*
    En descartes, el jugador inicial debe ser el que marque el backend
    como turno. En algunos estados de descarte turnPlayerId puede venir
    vacío, así que usamos fallbacks explícitos del estado de la mano antes
    de caer a P1.
  */
  const gameStateRecord = gameState as unknown as Record<string, unknown>;
  const handRecord = gameState.hand as unknown as Record<string, unknown>;

  const candidates = [
    gameState.turnPlayerId,
    handRecord?.turnPlayerId,
    handRecord?.currentTurnPlayerId,
    handRecord?.activePlayerId,
    handRecord?.manoPlayerId,
    handRecord?.startPlayerId,
    gameStateRecord.manoPlayerId,
    gameStateRecord.startPlayerId,
  ];

  for (const candidate of candidates) {
    if (PLAYER_IDS.includes(candidate as PlayerId)) {
      return candidate as PlayerId;
    }
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