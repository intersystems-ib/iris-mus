import { useEffect, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import type { ActionType, GameState, PlayerId } from "../../../domain/game.types";
import { musApi } from "../../../api/musApi";
import { EventTimeline } from "./EventTimeline";
import { PlayerSeat } from "./PlayerSeat";
import { HandResultPanel } from "./HandResultPanel";

interface GameTableProps {
  gameState: GameState;
  perspectivePlayerId?: PlayerId;
  onRefresh: () => void;
}

const PLAYER_IDS: PlayerId[] = ["P1", "P2", "P3", "P4"];
const PHASE_CHANGE_DELAY_MS = 2000;
const PHASE_DECLARATION_DELAY_MS = 900;
const PHASE_DECLARATION_ACTION_DELAY_MS = 2000;
const PIEDRA_ICON_SRC = "/src/assets/points/piedra.png";
const AMARRACO_ICON_SRC = "/src/assets/points/amarraco.png";

const EMPTY_DISCARDS: Record<PlayerId, string[]> = {
  P1: [],
  P2: [],
  P3: [],
  P4: [],
};

type AgentDiscardDecision = "discard" | "cut" | "peterete";
type DiscardPhaseStep = "waiting" | "musDecision" | "discardCount" | "ready";
type LanceDeclarationPhase = "pares" | "juego";
type LanceDeclarationText = "TENGO" | "NO LLEVO";

interface AgentDiscardView {
  playerId: PlayerId;
  decision: AgentDiscardDecision;
  discards: string[];
  cutsMus: boolean;
}

interface LanceDeclarationView {
  playerId: PlayerId;
  phase: LanceDeclarationPhase;
  text: LanceDeclarationText;
  hasLance: boolean;
}

interface PlayerActionView {
  playerId: PlayerId;
  actionType: ActionType;
  amount: number;
  reason?: string;
}

interface PlayerViewInfo {
  playerId: PlayerId;
  name: string;
  teamId: ScoreTokenTeamId | "";
  teamName: string;
}

interface HandScoreColumn {
  key: string;
  label: string;
  teamA: number;
  teamB: number;
}

export function GameTable({
  gameState,
  perspectivePlayerId,
  onRefresh,
}: GameTableProps) {
  const navigate = useNavigate();
  const [historyModalOpen, setHistoryModalOpen] = useState(false);
  const [handResultModalOpen, setHandResultModalOpen] = useState(false);
  const [winnerModalOpen, setWinnerModalOpen] = useState(false);
  const [autoContinueSecondsLeft, setAutoContinueSecondsLeft] = useState(5);
  const handResultModalShownKeyRef = useRef("");
  const winnerModalShownKeyRef = useRef("");
  const automaticNextHandKeyRef = useRef("");
  const autoContinueTimeoutRef = useRef<number | null>(null);
  const autoContinueIntervalRef = useRef<number | null>(null);

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

  const [lanceDeclarationResponses, setLanceDeclarationResponses] = useState<
    Partial<Record<PlayerId, LanceDeclarationView>>
  >({});

  const [lanceDeclarationRunning, setLanceDeclarationRunning] =
    useState(false);

  const [activeLanceDeclarationPlayerId, setActiveLanceDeclarationPlayerId] =
    useState<PlayerId | null>(null);

  const [actionAmount, setActionAmount] = useState(2);

  const [executingAgentPlayerId, setExecutingAgentPlayerId] =
    useState<PlayerId | null>(null);

  const [submittingHumanActionPlayerId, setSubmittingHumanActionPlayerId] =
    useState<PlayerId | null>(null);

  const [phaseRefreshPending, setPhaseRefreshPending] = useState(false);

  const [pendingTeamResponses, setPendingTeamResponses] = useState<
    Partial<Record<PlayerId, PlayerActionView>>
  >({});

  const lanceDeclarationCompletedKeyRef = useRef("");
  const lanceDeclarationRunningRef = useRef(false);

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
  const pendingBetAgentActionRequestsRef = useRef<Record<string, true>>({});
  const pendingBetTeamConversationKeyRef = useRef("");
  const pendingBetTeamConversationCompleteKeyRef = useRef("");
  const pendingBetAgentCollectionRunningRef = useRef(false);
  const delayedRefreshTimeoutRef = useRef<number | null>(null);
  const pendingBetTeamResponseApplyingRef = useRef(false);
  const pendingBetResolvedTransitionRef = useRef("");
  const pendingTeamResponsesRef = useRef<
    Partial<Record<PlayerId, PlayerActionView>>
  >({});

  const phase = gameState.phase;
  const hand = gameState.hand;

  const isDiscardPhase = gameState.phase === "descartes";
  const startDiscardPlayerId = getDiscardStartPlayerId(gameState);
  const peteretePlayerIds = isDiscardPhase
    ? PLAYER_IDS.filter((playerId) => hasPeterete(playerId))
    : [];
  const hasAnyPeterete = peteretePlayerIds.length > 0;
  const petereteKey = peteretePlayerIds
    .map((playerId) => `${playerId}:${getPetereteDiscards(playerId).join(",")}`)
    .join("|");

  const hasAnyCut =
    isDiscardPhase &&
    !hasAnyPeterete &&
    (PLAYER_IDS.some((playerId) => musVotes[playerId] === false) ||
      PLAYER_IDS.some(
        (playerId) => agentDiscardResponses[playerId]?.cutsMus === true
      ));

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
  const allPlayersAreAgents = PLAYER_IDS.every((playerId) => isAgentPlayer(playerId));
  const winnerTeamId = normalizeTeamIdForGameTable(gameState.winnerTeam);
  const hasGameWinner = Boolean(winnerTeamId);
  const winnerTeamName = winnerTeamId
    ? getTeamDisplayNameForGameTable(gameState, winnerTeamId)
    : "";

  const canStartNextHand =
    isHandClosed &&
    gameState.status !== "finished" &&
    !gameState.winnerTeam &&
    teamAScore < targetScore &&
    teamBScore < targetScore;

  const handResultModalKey = getHandResultModalKey(gameState);
  const winnerModalKey = getWinnerModalKey(gameState);
  const agentAutoContinueEnabled = allPlayersAreAgents && canStartNextHand;

  const handActionCount = gameState.hand?.actions?.length ?? 0;
  const currentPendingBet = getCurrentPendingBet();
  const pendingBetKey = getStablePendingBetKey(currentPendingBet);
  const pendingBetRoundKey = getPendingBetRoundKey(currentPendingBet);
  const lanceDeclarationKey = getLanceDeclarationKey();
  const actionMinAmount = getActionMinAmount();

  const startNextHandMutation = useMutation({
    mutationFn: () => musApi.startNextHand(String(gameState.gameId)),
    onSuccess: () => {
      onRefresh();
    },
  });

  useEffect(() => {
    if (!isHandClosed || hasGameWinner) {
      handResultModalShownKeyRef.current = "";
      setHandResultModalOpen(false);
      return;
    }

    if (handResultModalShownKeyRef.current !== handResultModalKey) {
      handResultModalShownKeyRef.current = handResultModalKey;
      setHandResultModalOpen(true);
    }
  }, [handResultModalKey, hasGameWinner, isHandClosed]);

  useEffect(() => {
    if (!hasGameWinner) {
      winnerModalShownKeyRef.current = "";
      setWinnerModalOpen(false);
      return;
    }

    setHandResultModalOpen(false);

    if (winnerModalShownKeyRef.current !== winnerModalKey) {
      winnerModalShownKeyRef.current = winnerModalKey;
      setWinnerModalOpen(true);
    }
  }, [hasGameWinner, winnerModalKey]);

  useEffect(() => {
    if (!agentAutoContinueEnabled || !handResultModalOpen) {
      clearAutoContinueTimers();
      setAutoContinueSecondsLeft(5);
      return;
    }

    setAutoContinueSecondsLeft(5);
    clearAutoContinueTimers();

    autoContinueIntervalRef.current = window.setInterval(() => {
      setAutoContinueSecondsLeft((current) => Math.max(0, current - 1));
    }, 1000);

    autoContinueTimeoutRef.current = window.setTimeout(() => {
      handleContinueToNextHand();
    }, 5000);

    return () => {
      clearAutoContinueTimers();
    };
  }, [agentAutoContinueEnabled, handResultModalKey, handResultModalOpen]);

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
    setLanceDeclarationResponses({});
    setLanceDeclarationRunning(false);
    setActiveLanceDeclarationPlayerId(null);
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
    pendingBetAgentActionRequestsRef.current = {};
    pendingBetTeamConversationKeyRef.current = "";
    pendingBetAgentCollectionRunningRef.current = false;
    pendingBetTeamResponseApplyingRef.current = false;
    pendingBetResolvedTransitionRef.current = "";
    pendingTeamResponsesRef.current = {};
    lanceDeclarationCompletedKeyRef.current = "";
    lanceDeclarationRunningRef.current = false;

    if (delayedRefreshTimeoutRef.current !== null) {
      window.clearTimeout(delayedRefreshTimeoutRef.current);
      delayedRefreshTimeoutRef.current = null;
    }

    clearAutoContinueTimers();
    automaticNextHandKeyRef.current = "";
    setAutoContinueSecondsLeft(5);
  }, [gameState.currentHandId, gameState.discardRound]);

  useEffect(() => {
    if (isDiscardPhase) {
      return;
    }

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
    humanDecisionResolversRef.current = {};
    automaticDiscardSubmitRef.current = "";
  }, [
    isDiscardPhase,
    gameState.currentHandId,
    gameState.handNumber,
    gameState.hand?.handNumber,
    gameState.discardRound,
  ]);

  useEffect(() => {
    return () => {
      if (delayedRefreshTimeoutRef.current !== null) {
        window.clearTimeout(delayedRefreshTimeoutRef.current);
      }

      clearAutoContinueTimers();
    };
  }, []);

  useEffect(() => {
    setPlayerActionResponses({});
    setLanceDeclarationResponses({});
    setLanceDeclarationRunning(false);
    setActiveLanceDeclarationPlayerId(null);
    lanceDeclarationCompletedKeyRef.current = "";
    lanceDeclarationRunningRef.current = false;
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
    pendingBetAgentActionRequestsRef.current = {};
    pendingBetTeamConversationKeyRef.current = "";
    pendingBetTeamConversationCompleteKeyRef.current = "";
    pendingBetAgentCollectionRunningRef.current = false;
    if (pendingBetRoundKey !== "no-pending-bet") {
        pendingBetTeamResponseApplyingRef.current = false;
        pendingBetResolvedTransitionRef.current = "";
    }

    pendingTeamResponsesRef.current = {};
  }, [pendingBetRoundKey]);

  useEffect(() => {
    pendingBetTeamResponseApplyingRef.current = false;
    pendingBetResolvedTransitionRef.current = "";
  }, [gameState.currentHandId, gameState.phase, gameState.discardRound, handActionCount]);

  useEffect(() => {
    if (!shouldStartLanceDeclaration()) {
      return;
    }

    void runLanceDeclarationConversation();
  }, [
    gameState.gameId,
    gameState.currentHandId,
    gameState.phase,
    gameState.discardRound,
    handActionCount,
    lanceDeclarationKey,
    isDiscardPhase,
    isHandClosed,
    gameState.status,
    phaseRefreshPending,
    playerActionMutation.isPending,
    teamResponseConversationRunning,
    teamResponseApplying,
    pendingBetKey,
    lanceDeclarationResponses,
    lanceDeclarationRunning,
  ]);

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
    if (!isDiscardPhase || !hasAnyPeterete) {
      return;
    }

    const nextDiscards: Record<PlayerId, string[]> = {
      P1: [],
      P2: [],
      P3: [],
      P4: [],
    };
    const nextConfirmed: Partial<Record<PlayerId, boolean>> = {};
    const nextMusVotes: Partial<Record<PlayerId, boolean>> = {};
    const nextDiscardResponses: Partial<Record<PlayerId, AgentDiscardView>> = {};
    const nextVisibleDiscardCounts: Partial<Record<PlayerId, boolean>> = {};

    for (const playerId of peteretePlayerIds) {
      const discards = getPetereteDiscards(playerId);

      if (discards.length === 0) {
        continue;
      }

      nextDiscards[playerId] = discards;
      nextConfirmed[playerId] = true;
      nextMusVotes[playerId] = true;
      nextVisibleDiscardCounts[playerId] = true;
      nextDiscardResponses[playerId] = {
        playerId,
        decision: "peterete",
        discards,
        cutsMus: false,
      };
    }

    setSelectedDiscards(nextDiscards);
    setConfirmedDiscards(nextConfirmed);
    setMusVotes(nextMusVotes);
    setAgentDiscardResponses(nextDiscardResponses);
    setVisibleDiscardCounts(nextVisibleDiscardCounts);
    setAgentDiscardError(null);
    setDiscardConversationStarted(true);
    setDiscardConversationRunning(false);
    setDiscardPhaseStep("ready");
    setActiveDiscardPlayerId(null);
    setPendingHumanDecisionPlayerId(null);
  }, [
    isDiscardPhase,
    hasAnyPeterete,
    petereteKey,
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
      phaseRefreshPending ||
      shouldBlockActionsForLanceDeclaration()
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
      pendingBetResolvedTransitionRef.current === getPendingBetResolvedTransitionKey()
    ) {
      return;
    }

    if (
      executingAgentPlayerId ||
      playerActionMutation.isPending ||
      teamResponseConversationRunning ||
      teamResponseApplying ||
      pendingBetTeamResponseApplyingRef.current ||
      pendingBetResolvedTransitionRef.current === getPendingBetResolvedTransitionKey()
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
    pendingBetRoundKey,
    lanceDeclarationKey,
    lanceDeclarationRunning,
    lanceDeclarationResponses,
    executingAgentPlayerId,
    playerActionMutation.isPending,
    teamResponseConversationRunning,
    teamResponseApplying,
  ]);

  function getCurrentLanceDeclarationPhase(): LanceDeclarationPhase | null {
    const handRecord = gameState.hand as unknown as Record<string, unknown>;
    const gameStateRecord = gameState as unknown as Record<string, unknown>;
    const phaseState = getNestedValue(handRecord, ["phaseState"]) as
      | Record<string, unknown>
      | undefined;

    const candidates = [
      gameState.phase,
      handRecord?.phase,
      handRecord?.currentPhase,
      handRecord?.bettingPhase,
      handRecord?.lance,
      handRecord?.currentLance,
      handRecord?.bettingRound,
      handRecord?.currentBettingRound,
      gameStateRecord.currentPhase,
      gameStateRecord.bettingPhase,
      gameStateRecord.lance,
      gameStateRecord.currentLance,
      gameStateRecord.betPhase,
      gameStateRecord.betRound,
      gameStateRecord.bettingRound,
      gameStateRecord.currentBettingRound,
      phaseState?.phase,
      phaseState?.currentPhase,
      phaseState?.bettingPhase,
      phaseState?.lance,
      phaseState?.currentLance,
      phaseState?.betPhase,
      phaseState?.betRound,
      phaseState?.bettingRound,
      phaseState?.currentBettingRound,
      phaseState?.type,
    ];

    for (const candidate of candidates) {
      const normalizedPhase = normalizeLancePhaseText(candidate);

      if (normalizedPhase.includes("pares") || normalizedPhase.includes("pair")) {
        return "pares";
      }

      if (normalizedPhase.includes("juego") || normalizedPhase.includes("game")) {
        return "juego";
      }
    }

    const pendingBet = getCurrentPendingBet();
    const pendingBetType = normalizeLancePhaseText(getPendingBetType(pendingBet));

    if (pendingBetType.includes("pares") || pendingBetType.includes("pair")) {
      return "pares";
    }

    if (pendingBetType.includes("juego") || pendingBetType.includes("game")) {
      return "juego";
    }

    /*
      Fallback importante:
      cuando solo un equipo tiene juego, algunos estados del backend pueden no
      exponer la fase textual como "juego" ni crear todavía un pendingBet de
      juego. Aun así suelen incluir señales explícitas como playersWithJuego,
      juegoPlayers o flags hasJuego por jugador. Si existe cualquiera de esas
      señales, forzamos la fase visual de declaración de juego para que todos
      digan TENGO / NO LLEVO antes de continuar.
    */
    if (hasExplicitLanceDeclarationSignal("juego")) {
      return "juego";
    }

    if (hasExplicitLanceDeclarationSignal("pares")) {
      return "pares";
    }


    return null;
  }

  function normalizeLancePhaseText(value: unknown): string {
    return String(value ?? "")
      .trim()
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[\s_-]+/g, "");
  }

  function getLanceDeclarationKey(): string {
    const declarationPhase = getCurrentLanceDeclarationPhase();

    if (!declarationPhase) {
      return "no-lance-declaration";
    }

    return [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.discardRound ?? "",
      declarationPhase,
      getLanceCardsSignature(),
    ].join(":");
  }

  function getLanceCardsSignature(): string {
    return PLAYER_IDS.map((playerId) => {
      const cards = getPlayerCardsForLanceDeclaration(playerId);
      return `${playerId}=${cards.join(",")}`;
    }).join("|");
  }

  function shouldUseLanceDeclaration(): boolean {
    const declarationPhase = getCurrentLanceDeclarationPhase();

    if (!declarationPhase) {
      return false;
    }

    /*
      En pares y juego siempre mostramos la declaración previa para todos los
      jugadores. Aunque solo uno o ninguno tenga lance, necesitamos visualizar
      TENGO / NO LLEVO antes de permitir que el flujo avance o se cierre.
      No dependemos de currentPendingBet ni del historial de acciones: algunos
      estados del backend pueden arrastrar acciones/envites del lance anterior
      al entrar en juego y eso hacia que se saltara esta fase visual.
    */
    return true;
  }

  function shouldStartLanceDeclaration(): boolean {
    if (
      isDiscardPhase ||
      isHandClosed ||
      gameState.status === "finished" ||
      phaseRefreshPending ||
      playerActionMutation.isPending ||
      teamResponseConversationRunning ||
      teamResponseApplying ||
      pendingBetTeamResponseApplyingRef.current ||
      lanceDeclarationRunning ||
      lanceDeclarationRunningRef.current
    ) {
      return false;
    }

    if (!shouldUseLanceDeclaration()) {
      return false;
    }

    return lanceDeclarationCompletedKeyRef.current !== lanceDeclarationKey;
  }

  function shouldBlockActionsForLanceDeclaration(): boolean {
    if (!shouldUseLanceDeclaration()) {
      return false;
    }

    return lanceDeclarationCompletedKeyRef.current !== lanceDeclarationKey;
  }

  async function runLanceDeclarationConversation() {
    const declarationPhase = getCurrentLanceDeclarationPhase();

    if (!declarationPhase || !shouldStartLanceDeclaration()) {
      return;
    }

    const declarationKey = lanceDeclarationKey;
    const orderedPlayers = getLanceDeclarationOrder();

    lanceDeclarationRunningRef.current = true;
    setLanceDeclarationRunning(true);
    setActiveLanceDeclarationPlayerId(null);
    setLanceDeclarationResponses({});

    try {
      for (const playerId of orderedPlayers) {
        setActiveLanceDeclarationPlayerId(playerId);

        await wait(PHASE_DECLARATION_DELAY_MS);

        const hasLance = playerHasCurrentLance(playerId, declarationPhase);
        const view: LanceDeclarationView = {
          playerId,
          phase: declarationPhase,
          hasLance,
          text: hasLance ? "TENGO" : "NO LLEVO",
        };

        setLanceDeclarationResponses((current) => ({
          ...current,
          [playerId]: view,
        }));
      }

      /*
        Cuando todos han declarado, mantenemos TENGO / NO LLEVO visibles durante
        2 segundos. Después limpiamos los mensajes de los PlayerSeat y solo
        entonces desbloqueamos las invocaciones de acciones al LLM.
      */
      setActiveLanceDeclarationPlayerId(null);
      await wait(PHASE_DECLARATION_ACTION_DELAY_MS);

      /*
        El backend ya no debe cerrar automaticamente pares/juego al abrir la
        fase de declaracion. Cuando termina la visualizacion, limpiamos los
        mensajes y confirmamos al backend que puede continuar/resolver el lance.
        Mientras esta funcion sigue en curso, lanceDeclarationRunningRef mantiene
        bloqueadas las invocaciones automaticas al LLM.
      */
      setLanceDeclarationResponses({});
      lanceDeclarationCompletedKeyRef.current = declarationKey;
      await confirmLanceDeclarationPhase(declarationPhase);
    } finally {
      setActiveLanceDeclarationPlayerId(null);
      setLanceDeclarationRunning(false);
      lanceDeclarationRunningRef.current = false;
    }
  }

  function getLanceDeclarationOrder(): PlayerId[] {
    return getPlayerOrderFrom(getHandStartPlayerId(gameState));
  }

  async function confirmLanceDeclarationPhase(
    declarationPhase: LanceDeclarationPhase
  ) {
    const confirmationPlayerId =
      getCurrentTurnPlayerId() ?? getHandStartPlayerId(gameState) ?? "P1";

    await musApi.playerAction(String(gameState.gameId), {
      playerId: confirmationPlayerId,
      phase: declarationPhase,
      actionType: "confirmar_declaracion" as ActionType,
      amount: 0,
    });

    scheduleDelayedRefresh();
  }


  function playerHasCurrentLance(
    playerId: PlayerId,
    declarationPhase: LanceDeclarationPhase
  ): boolean {
    const explicitPlayers = getExplicitLancePlayerIds(declarationPhase);

    if (explicitPlayers.length > 0) {
      return explicitPlayers.includes(playerId);
    }

    const explicitValue = getExplicitPlayerLanceValue(playerId, declarationPhase);

    if (explicitValue !== null) {
      return explicitValue;
    }

    const cards = getPlayerCardsForLanceDeclaration(playerId);

    if (cards.length === 0) {
      return false;
    }

    return declarationPhase === "pares"
      ? hasPares(cards)
      : hasJuego(cards);
  }

  function hasExplicitLanceDeclarationSignal(
    declarationPhase: LanceDeclarationPhase
  ): boolean {
    if (getExplicitLancePlayerIds(declarationPhase).length > 0) {
      return true;
    }

    return PLAYER_IDS.some(
      (playerId) => getExplicitPlayerLanceValue(playerId, declarationPhase) !== null
    );
  }

  function getExplicitLancePlayerIds(
    declarationPhase: LanceDeclarationPhase
  ): PlayerId[] {
    const handRecord = gameState.hand as unknown as Record<string, unknown>;
    const gameStateRecord = gameState as unknown as Record<string, unknown>;
    const phaseState = getNestedValue(handRecord, ["phaseState"]) as
      | Record<string, unknown>
      | undefined;

    const fieldNames = declarationPhase === "pares"
      ? [
          "playersWithPares",
          "paresPlayers",
          "playersWithPairs",
          "pairPlayers",
          "eligibleParesPlayers",
          "eligiblePairPlayers",
        ]
      : [
          "playersWithJuego",
          "juegoPlayers",
          "playersWithGame",
          "gamePlayers",
          "eligibleJuegoPlayers",
          "eligibleGamePlayers",
        ];

    const result: PlayerId[] = [];

    for (const source of [handRecord, gameStateRecord, phaseState]) {
      if (!source || typeof source !== "object") {
        continue;
      }

      for (const fieldName of fieldNames) {
        const value = (source as Record<string, unknown>)[fieldName];

        for (const playerId of getPlayerIdsFromUnknown(value)) {
          if (!result.includes(playerId)) {
            result.push(playerId);
          }
        }
      }
    }

    return result;
  }

  function getExplicitPlayerLanceValue(
    playerId: PlayerId,
    declarationPhase: LanceDeclarationPhase
  ): boolean | null {
    const player = getPlayerForAgentView(playerId) as Record<string, unknown> | undefined;
    const handRecord = gameState.hand as unknown as Record<string, unknown>;

    const candidates: unknown[] = [];

    if (player) {
      candidates.push(
        declarationPhase === "pares"
          ? player.hasPares ?? player.hasPairs ?? player.pares ?? player.pairs
          : player.hasJuego ?? player.hasGame ?? player.juego ?? player.game
      );
    }

    const playerState = getNestedValue(handRecord, ["players", playerId]) as
      | Record<string, unknown>
      | undefined;

    if (playerState) {
      candidates.push(
        declarationPhase === "pares"
          ? playerState.hasPares ?? playerState.hasPairs ?? playerState.pares ?? playerState.pairs
          : playerState.hasJuego ?? playerState.hasGame ?? playerState.juego ?? playerState.game
      );
    }

    for (const value of candidates) {
      if (typeof value === "boolean") {
        return value;
      }

      if (typeof value === "string") {
        const normalized = value.trim().toLowerCase();

        if (["true", "yes", "si", "sí", "tengo"].includes(normalized)) {
          return true;
        }

        if (["false", "no", "no llevo", "none"].includes(normalized)) {
          return false;
        }
      }
    }

    return null;
  }

  function getPlayerIdsFromUnknown(value: unknown): PlayerId[] {
    if (!value) {
      return [];
    }

    if (typeof value === "string") {
      return PLAYER_IDS.includes(value as PlayerId) ? [value as PlayerId] : [];
    }

    if (Array.isArray(value)) {
      return value.flatMap((item) => getPlayerIdsFromUnknown(item));
    }

    if (typeof value === "object") {
      return Object.entries(value as Record<string, unknown>)
        .filter(([key, item]) =>
          PLAYER_IDS.includes(key as PlayerId) && Boolean(item)
        )
        .map(([key]) => key as PlayerId);
    }

    return [];
  }

  function getPlayerCardsForLanceDeclaration(playerId: PlayerId): string[] {
    const player = getPlayerForAgentView(playerId) as Record<string, unknown> | undefined;
    const handRecord = gameState.hand as unknown as Record<string, unknown>;
    const gameStateRecord = gameState as unknown as Record<string, unknown>;

    const candidates = [
      player?.cards,
      player?.hand,
      player?.handCards,
      player?.currentHand,
      getNestedValue(handRecord, ["cards", playerId]),
      getNestedValue(handRecord, ["playerCards", playerId]),
      getNestedValue(handRecord, ["hands", playerId]),
      getNestedValue(handRecord, ["players", playerId, "cards"]),
      getNestedValue(handRecord, ["players", playerId, "hand"]),
      getNestedValue(gameStateRecord, ["cards", playerId]),
      getNestedValue(gameStateRecord, ["playerCards", playerId]),
      getNestedValue(gameStateRecord, ["hands", playerId]),
    ];

    for (const candidate of candidates) {
      const cards = normalizeCards(candidate);

      if (cards.length > 0) {
        return cards;
      }
    }

    return [];
  }


  function hasPeterete(playerId: PlayerId): boolean {
    const ranks = getPlayerCardsForLanceDeclaration(playerId)
      .map((card) => getCardRank(card))
      .sort((left, right) => left - right);

    return (
      ranks.length === 4 &&
      ranks[0] === 4 &&
      ranks[1] === 5 &&
      ranks[2] === 6 &&
      ranks[3] === 7
    );
  }

  function getPetereteDiscards(playerId: PlayerId): string[] {
    return hasPeterete(playerId) ? getPlayerCardsForLanceDeclaration(playerId) : [];
  }

  function getPeteretePlayerNames(): string {
    const names = peteretePlayerIds.map((playerId) =>
      getPlayerDisplayNameForGameTable(gameState, playerId)
    );

    return names.join(", ");
  }

  function normalizeCards(value: unknown): string[] {
    if (!value) {
      return [];
    }

    if (Array.isArray(value)) {
      return value
        .map((card) => normalizeCard(card))
        .filter((card): card is string => Boolean(card));
    }

    if (typeof value === "object") {
      const record = value as Record<string, unknown>;
      const possibleCards = record.cards ?? record.hand ?? record.items;

      if (Array.isArray(possibleCards)) {
        return normalizeCards(possibleCards);
      }
    }

    const card = normalizeCard(value);
    return card ? [card] : [];
  }

  function normalizeCard(card: unknown): string | null {
    if (typeof card === "string") {
      return card;
    }

    if (typeof card === "number") {
      return String(card);
    }

    if (card && typeof card === "object") {
      const record = card as Record<string, unknown>;
      const value = record.code ?? record.card ?? record.id ?? record.name ?? record.label;

      if (value !== undefined && value !== null) {
        return String(value);
      }

      const rank = record.rank ?? record.value ?? record.number;
      const suit = record.suit ?? record.palo ?? "";

      if (rank !== undefined && rank !== null) {
        return `${rank}${suit}`;
      }
    }

    return null;
  }

  function hasPares(cards: string[]): boolean {
    const counts = new Map<number, number>();

    for (const card of cards) {
      const value = getMusPairValue(card);
      counts.set(value, (counts.get(value) ?? 0) + 1);
    }

    return [...counts.values()].some((count) => count >= 2);
  }

  function hasJuego(cards: string[]): boolean {
    const total = cards.reduce(
      (sum, card) => sum + getMusJuegoValue(card),
      0
    );

    return total >= 31;
  }

  function getMusPairValue(card: string): number {
    const rank = getCardRank(card);

    if (rank === 3) {
      return 12;
    }

    if (rank === 2) {
      return 1;
    }

    return rank;
  }

  function getMusJuegoValue(card: string): number {
    const rank = getCardRank(card);

    if (rank === 12 || rank === 11 || rank === 10 || rank === 3) {
      return 10;
    }

    if (rank === 2 || rank === 1) {
      return 1;
    }

    return rank;
  }

  function getCardRank(card: string): number {
    const match = String(card).match(/\d+/);

    if (!match) {
      return 0;
    }

    const rank = Number(match[0]);

    return Number.isFinite(rank) ? rank : 0;
  }

  function wait(milliseconds: number): Promise<void> {
    return new Promise((resolve) => {
      window.setTimeout(resolve, milliseconds);
    });
  }

  useEffect(() => {
    const pendingBet = getCurrentPendingBet();

    if (!pendingBet) {
      pendingBetTeamConversationKeyRef.current = "";
      return;
    }

    /*
      La declaración visual de pares/juego tiene prioridad absoluta sobre
      cualquier respuesta a pendingBet. En juego, el backend puede llegar ya
      con un pendingBet preparado para el lance; si no bloqueamos este efecto,
      se lanza la consulta al LLM antes de que los jugadores hayan dicho
      TENGO / NO LLEVO.
    */
    if (shouldBlockActionsForLanceDeclaration()) {
      return;
    }

    if (
      isDiscardPhase ||
      isHandClosed ||
      gameState.status === "finished" ||
      phaseRefreshPending ||
      playerActionMutation.isPending ||
      teamResponseConversationRunning ||
      teamResponseApplying ||
      pendingBetAgentCollectionRunningRef.current ||
      pendingBetTeamResponseApplyingRef.current
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

    const conversationKey = getPendingBetTeamConversationKey(
      responderPlayerIds
    );

    const responseMap = pendingTeamResponsesRef.current;

    const missingAgentPlayerIds = responderPlayerIds.filter(
      (playerId) =>
        isAgentPlayer(playerId) &&
        !responseMap[playerId] &&
        !hasPlayerAlreadyRespondedToCurrentPendingBet(playerId) &&
        !hasRequestedPendingBetAgentAction(playerId)
    );

    /*
      En equipos mixtos humano + agente, consultamos al agente primero para
      mostrar su respuesta, pero no aplicamos nada hasta que el humano responda.
      Asi podemos comparar ambas respuestas y mostrar solo la mas fuerte.
    */
    if (missingAgentPlayerIds.length > 0) {
      if (
        pendingBetTeamConversationKeyRef.current === conversationKey ||
        pendingBetTeamConversationCompleteKeyRef.current === conversationKey
      ) {
        return;
      }

      pendingBetTeamConversationKeyRef.current = conversationKey;
      void collectPendingBetAgentResponses(missingAgentPlayerIds);
      return;
    }

    const missingHumanPlayerIds = responderPlayerIds.filter(
      (playerId) =>
        !isAgentPlayer(playerId) &&
        !responseMap[playerId] &&
        !hasPlayerAlreadyRespondedToCurrentPendingBet(playerId)
    );

    if (missingHumanPlayerIds.length > 0) {
      return;
    }

    if (responderPlayerIds.every((playerId) => responseMap[playerId])) {
      pendingBetTeamConversationCompleteKeyRef.current = conversationKey;
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
    pendingBetRoundKey,
    lanceDeclarationKey,
    lanceDeclarationRunning,
    lanceDeclarationResponses,
    pendingTeamResponses,
    playerActionMutation.isPending,
    teamResponseConversationRunning,
    teamResponseApplying,
  ]);

  function clearAutoContinueTimers() {
    if (autoContinueTimeoutRef.current !== null) {
      window.clearTimeout(autoContinueTimeoutRef.current);
      autoContinueTimeoutRef.current = null;
    }

    if (autoContinueIntervalRef.current !== null) {
      window.clearInterval(autoContinueIntervalRef.current);
      autoContinueIntervalRef.current = null;
    }
  }

  function handleContinueToNextHand() {
    if (!canStartNextHand || startNextHandMutation.isPending) {
      return;
    }

    const nextHandKey = [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.handNumber ?? "",
      handResultModalKey,
    ].join(":");

    if (automaticNextHandKeyRef.current === nextHandKey) {
      return;
    }

    automaticNextHandKeyRef.current = nextHandKey;
    clearAutoContinueTimers();
    setHandResultModalOpen(false);
    startNextHandMutation.mutate();
  }

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
    if (
      !isDiscardPhase ||
      !startDiscardPlayerId ||
      isAgentPlayer(playerId) ||
      hasAnyPeterete
    ) {
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
    if (
      !isDiscardPhase ||
      !startDiscardPlayerId ||
      isAgentPlayer(playerId) ||
      hasAnyPeterete
    ) {
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

        if (hasPeterete(playerId)) {
          const discards = getPetereteDiscards(playerId);
          const view: AgentDiscardView = {
            playerId,
            decision: "peterete",
            discards,
            cutsMus: false,
          };

          collectedAgentResponses[playerId] = view;
          setAgentDiscardResponses((current) => ({
            ...current,
            [playerId]: view,
          }));
          setMusVotes((current) => ({
            ...current,
            [playerId]: true,
          }));

          continue;
        }

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
      isAgentPlayer(playerId) ||
      hasPeterete(playerId)
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
      isAgentPlayer(playerId) ||
      hasPeterete(playerId)
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

  function getStablePendingBetKey(pendingBet: unknown): string {
    if (!pendingBet || typeof pendingBet !== "object") {
      return "no-pending-bet";
    }

    const amount = getPendingBetAmount(pendingBet);
    const type = getPendingBetType(pendingBet);
    const aggressorPlayerId = getPendingBetAggressorPlayerId(pendingBet) ?? "";
    const respondingTeam = getPendingBetRespondingTeam(pendingBet);
    const explicitResponders = getExplicitPendingBetResponderPlayerIds(
      pendingBet
    ).join(",");

    return [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.phase,
      type,
      amount,
      aggressorPlayerId,
      respondingTeam,
      explicitResponders,
    ].join(":");
  }

  function getPendingBetRoundKey(pendingBet: unknown): string {
    if (!pendingBet || typeof pendingBet !== "object") {
      return "no-pending-bet";
    }

    const actions = gameState.hand?.actions;

    if (Array.isArray(actions)) {
      const latestAggressionIndex = getLatestPendingBetAggressionActionIndex(
        actions
      );

      if (latestAggressionIndex >= 0) {
        const latestAggression = actions[latestAggressionIndex];

        return [
          gameState.gameId,
          gameState.currentHandId ?? "",
          gameState.phase,
          "aggression",
          latestAggressionIndex,
          getActionPlayerId(latestAggression) ?? "",
          getActionTypeFromEvent(latestAggression) ?? "",
          getActionAmountFromEvent(latestAggression),
        ].join(":");
      }
    }

    return [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.phase,
      "pending",
      getPendingBetAggressorPlayerId(pendingBet) ?? "",
      getPendingBetType(pendingBet),
      getPendingBetAmount(pendingBet),
    ].join(":");
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
      phaseRefreshPending ||
      shouldBlockActionsForLanceDeclaration()
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

    if (pendingTeamResponsesRef.current[playerId] || pendingTeamResponses[playerId]) {
      return false;
    }

    if (hasPlayerAlreadyRespondedToCurrentPendingBet(playerId)) {
      return false;
    }

    const responderPlayerIds = getPendingBetResponderTeamPlayerIds(pendingBet);

    if (shouldUsePendingBetTeamConversation(pendingBet, responderPlayerIds)) {
      return responderPlayerIds.includes(playerId);
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

    const currentTurnPlayerId = getCurrentTurnPlayerId();

    /*
      Si el backend todavía devuelve como turno al agresor justo después de crear
      el pendingBet, no debemos usar ese turnPlayerId para bloquear al equipo
      respondedor. En ese caso caemos al equipo calculado desde el pendingBet.
    */
    if (
      currentTurnPlayerId &&
      currentTurnPlayerId !== currentAggressorPlayerId &&
      responderPlayerIds.includes(currentTurnPlayerId)
    ) {
      return currentTurnPlayerId === playerId;
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
 
  function getActionAmountFromEvent(action: unknown): number {
    if (!action || typeof action !== "object") {
      return 0;
    }

    const record = action as Record<string, unknown>;
    const amount = Number(
      record.amount ?? record.value ?? record.points ?? record.betAmount
    );

    return Number.isFinite(amount) ? amount : 0;
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

  function getPendingBetAgentActionRequestKey(playerId: PlayerId): string {
    return [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.phase,
      pendingBetKey,
      playerId,
    ].join(":");
  }

  function hasRequestedPendingBetAgentAction(playerId: PlayerId): boolean {
    return (
      pendingBetAgentActionRequestsRef.current[
        getPendingBetAgentActionRequestKey(playerId)
      ] === true
    );
  }

  function markPendingBetAgentActionRequested(playerId: PlayerId) {
    pendingBetAgentActionRequestsRef.current[
      getPendingBetAgentActionRequestKey(playerId)
    ] = true;
  }

  function getPendingBetTeamConversationKey(
    responderPlayerIds: PlayerId[]
  ): string {
    return [pendingBetRoundKey, responderPlayerIds.join(",")].join(":");
  }

  function getPendingBetResolvedTransitionKey(): string {
    return [
      gameState.gameId,
      gameState.currentHandId ?? "",
      gameState.phase,
      gameState.turnPlayerId ?? "",
      handActionCount,
    ].join(":");
  }

  function setPendingTeamResponseView(view: PlayerActionView) {
    pendingTeamResponsesRef.current = {
      ...pendingTeamResponsesRef.current,
      [view.playerId]: view,
    };

    setPendingTeamResponses((current) => ({
      ...current,
      [view.playerId]: view,
    }));
  }

  async function collectPendingBetAgentResponses(
    agentPlayerIds: PlayerId[]
  ) {
    const pendingBet = getCurrentPendingBet();

    if (!pendingBet) {
      return;
    }

    if (shouldBlockActionsForLanceDeclaration()) {
      return;
    }

    if (pendingBetAgentCollectionRunningRef.current) {
      return;
    }

    const responderPlayerIds = getPendingBetResponderTeamPlayerIds(pendingBet);
    const conversationKey = getPendingBetTeamConversationKey(responderPlayerIds);

    if (pendingBetTeamConversationCompleteKeyRef.current === conversationKey) {
      return;
    }

    const playerIdsToRequest = agentPlayerIds.filter(
      (playerId) =>
        !pendingTeamResponsesRef.current[playerId] &&
        !hasRequestedPendingBetAgentAction(playerId)
    );

    if (playerIdsToRequest.length === 0 || teamResponseConversationRunning) {
      return;
    }

    pendingBetTeamConversationKeyRef.current = conversationKey;
    pendingBetAgentCollectionRunningRef.current = true;

    for (const playerId of playerIdsToRequest) {
      markPendingBetAgentActionRequested(playerId);
    }

    setTeamResponseConversationRunning(true);
    setAgentActionError(null);

    try {
      for (const playerId of playerIdsToRequest) {
        if (pendingTeamResponsesRef.current[playerId]) {
          continue;
        }
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


        /*
          Mostramos la respuesta de cada agente en cuanto llega.
          No esperamos a tener las respuestas de todo el equipo para pintar
          el PlayerSeat: mientras el backend responde se ve PENSANDO y,
          al terminar esa llamada, se ve la decision de ese agente.
          Guard síncrono: registramos la respuesta en un ref antes de disparar
          el setState. Si el segundo agente responde no_querer y React re-renderiza
          antes de aplicar la accion, el efecto ya ve el equipo completo y no
          vuelve a consultar al primero/segundo agente.
        */
        setPendingTeamResponseView(view);

        if (responderPlayerIds.every((id) => pendingTeamResponsesRef.current[id])) {
          pendingBetTeamConversationCompleteKeyRef.current = conversationKey;
        }
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
      pendingBetAgentCollectionRunningRef.current = false;
    }
  }

  async function applyStrongestPendingBetTeamResponse(
    pendingBet: unknown,
    responderPlayerIds: PlayerId[]
  ) {
    if (
      teamResponseApplying ||
      pendingBetTeamResponseApplyingRef.current ||
      playerActionMutation.isPending
    ) {
      return;
    }

    const responseMap = pendingTeamResponsesRef.current;
    const responseViews = responderPlayerIds
      .map((playerId) => responseMap[playerId] ?? pendingTeamResponses[playerId])
      .filter((view): view is PlayerActionView => Boolean(view));

    if (responseViews.length < responderPlayerIds.length) {
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
      pendingBetRoundKey,
      executionPlayerId,
      strongestResponse.actionType,
      strongestResponse.amount,
      JSON.stringify(responseViews),
    ].join(":");

    if (pendingTeamResponseApplyRef.current === applyKey) {
      return;
    }

    pendingTeamResponseApplyRef.current = applyKey;
    pendingBetTeamResponseApplyingRef.current = true;
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
      pendingBetResolvedTransitionRef.current = getPendingBetResolvedTransitionKey();
    } finally {
      setTeamResponseApplying(false);

      pendingBetTeamResponseApplyingRef.current = false;
    }
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
      setPendingTeamResponseView(view);

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
    if (!isDiscardPhase) {
      return undefined;
    }

    return agentDiscardResponses[playerId]?.decision;
  }

  function getAgentRecommendedDiscards(playerId: PlayerId): string[] {
    if (!isDiscardPhase || !visibleDiscardCounts[playerId]) {
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

    if (hasAnyPeterete) {
      return peteretePlayerIds.every(
        (playerId) =>
          confirmedDiscards[playerId] === true &&
          selectedDiscards[playerId]?.length === getPetereteDiscards(playerId).length
      );
    }

    if (hasAnyCut) {
      return true;
    }

    return PLAYER_IDS.every((playerId) => {
      if (isAgentPlayer(playerId)) {
        const response = agentDiscardResponses[playerId];

        if (!response) {
          return false;
        }

        return !response.cutsMus;
      }

      return confirmedDiscards[playerId] === true;
    });
  }

  function shouldEnableHumanMusActions(playerId: PlayerId): boolean {
    if (
      !isDiscardPhase ||
      !startDiscardPlayerId ||
      isAgentPlayer(playerId) ||
      hasAnyPeterete
    ) {
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

      /*
        Si hay pendingBet, el jugador respondedor no debe quedar bloqueado por una
        acción local anterior de la misma fase, especialmente un PASAR previo.
        Caso típico: humano pasa, agente rival envida, y sigue vivo
        playerActionResponses[humano] = pasar. Eso ocultaba la botonera.
      */
      if (responderPlayerIds.includes(playerId)) {
        const view = playerActionResponses[playerId];

        if (!view || !isPendingBetResponseAction(view.actionType)) {
          return undefined;
        }

        return shouldShowPlayerActionMessage(view.actionType) ? view : undefined;
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

    const view = pendingTeamResponses[playerId] ?? pendingTeamResponsesRef.current[playerId];

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

  function isPendingBetResponseAction(actionType: ActionType): boolean {
    return (
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


  function renderScoreTokenStrip(
    team: ScoreTokenTeamId,
    kind: "piedra" | "amarraco",
    placement: "left" | "top" | "right" | "bottom"
  ) {
    const totalScore = getScoreForTeam(gameState, team);
    const { amarracos, piedras } = getScoreTokenCounts(totalScore);
    const count = kind === "piedra" ? piedras : amarracos;
    const tokenLabel = kind === "piedra" ? "piedra" : "amarraco";

    return (
      <div
        className={`mus-score-token-strip mus-score-token-strip-${placement}`}
        aria-label={`${getTeamDisplayNameForGameTable(gameState, team)}: ${count} ${tokenLabel}${count === 1 ? "" : "s"}`}
      >
        {renderScoreTokenIcons(kind, count)}
      </div>
    );
  }

  function renderScoreTokenIcons(kind: "piedra" | "amarraco", count: number) {
    const safeCount = Math.max(0, count);
    const src = kind === "piedra" ? PIEDRA_ICON_SRC : AMARRACO_ICON_SRC;
    const alt = kind === "piedra" ? "Piedra" : "Amarraco";

    if (safeCount === 0) {
      return null;
    }

    return Array.from({ length: safeCount }, (_, index) => (
      <img
        key={`${kind}-${index}`}
        className={`mus-score-token-icon mus-score-token-icon-${kind}`}
        src={src}
        alt={alt}
        width={12}
        height={12}
      />
    ));
  }

  function renderPlayerSeat(playerId: PlayerId) {
    const isAgent = isAgentPlayer(playerId);
    const playerViewInfo = getPlayerViewInfo(gameState, playerId);
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
        forceHideCards={isAgent && !isHandClosed && !allPlayersAreAgents}
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
        lanceDeclarationView={lanceDeclarationResponses[playerId]}
        isDeclaringLance={
          activeLanceDeclarationPlayerId === playerId &&
          !lanceDeclarationResponses[playerId]
        }
        isExecutingAgent={executingAgentPlayerId === playerId}
        forceTurnHighlight={shouldHighlightPendingBetResponder(playerId)}
        playerDisplayName={playerViewInfo.name}
        teamDisplayName={playerViewInfo.teamName}
        onExecuteAgent={() => {
          void handleExecuteAgent(playerId);
        }}
      />
    );
  }

  const isSubmittingDiscards = applyDiscardsMutation.isPending;

  return (
    <main className="game-table-page">
      <div className="game-table-top-bar game-table-top-bar-balanced">
        <div className="game-table-top-left">
          <button
            type="button"
            className="secondary-button game-back-button"
            onClick={() => navigate(-1)}
          >
            Volver
          </button>
        </div>

        <div className="game-table-score-area game-table-score-area-centered">
          <GameTableScoreSummary gameState={gameState} />
        </div>

        <div className="game-table-toolbar game-table-toolbar-right">
          <button
            type="button"
            className="secondary-button game-history-button"
            onClick={() => setHistoryModalOpen(true)}
          >
            Histórico
          </button>
        </div>
      </div>

      <section className="table-layout">
        <div className="seat-area seat-top">{renderPlayerSeat("P3")}</div>

        <div className="seat-area seat-left">{renderPlayerSeat("P2")}</div>

        <div className="table-center">
          <div className="table-felt">
            {renderScoreTokenStrip("B", "piedra", "left")}
            {renderScoreTokenStrip("A", "amarraco", "top")}
            {renderScoreTokenStrip("B", "amarraco", "right")}
            {renderScoreTokenStrip("A", "piedra", "bottom")}

            {isHandClosed ? (
              <>
                <h2>Mano cerrada</h2>
                <p className="muted-text">
                </p>

                {canStartNextHand && !allPlayersAreAgents && (
                  <button
                    type="button"
                    className="primary-button table-next-hand-button"
                    onClick={() => startNextHandMutation.mutate()}
                    disabled={startNextHandMutation.isPending}
                  >
                    {startNextHandMutation.isPending
                      ? "Repartiendo..."
                      : "Repartir nueva mano"}
                  </button>
                )}
              </>
            ) : (
              <>
                <h2>{phase}</h2>
                <p>Mano {hand?.handNumber ?? gameState.handNumber}</p>

                {gameState.winnerTeam && (
                  <strong>
                    Ganador: {getTeamDisplayNameForGameTable(gameState, gameState.winnerTeam)}
                  </strong>
                )}
              </>
            )}


            {isDiscardPhase && discardPhaseStep === "waiting" && (
              <p className="muted-text">
                {isAgentPlayer(startDiscardPlayerId)
                  ? "El agente inicial está decidiendo si quiere MUS..."
                  : `${getPlayerDisplayNameForGameTable(
                      gameState,
                      startDiscardPlayerId
                    )} decide si pide MUS o corta.`}
              </p>
            )}

            {isDiscardPhase && discardPhaseStep === "musDecision" && (
              <p className="muted-text">
                {activeDiscardPlayerId
                  ? `${getPlayerDisplayNameForGameTable(
                      gameState,
                      activeDiscardPlayerId
                    )} está decidiendo si quiere MUS...`
                  : "Los jugadores están decidiendo si quieren MUS..."}
              </p>
            )}

            {isDiscardPhase && discardPhaseStep === "discardCount" && (
              <p className="muted-text">
                {activeDiscardPlayerId
                  ? `${getPlayerDisplayNameForGameTable(
                      gameState,
                      activeDiscardPlayerId
                    )} confirma su decisión de MUS...`
                  : "Los jugadores confirman sus decisiones de MUS..."}
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

            {isDiscardPhase && discardPhaseStep === "ready" && hasAnyPeterete && (
              <p className="muted-text">
                Peterete: descarte obligatorio para {getPeteretePlayerNames()}.
              </p>
            )}

            {isDiscardPhase && discardPhaseStep === "ready" && !hasAnyPeterete && hasAnyCut && (
              <p className="muted-text">Un jugador corta MUS.</p>
            )}

            {isDiscardPhase && discardPhaseStep === "ready" && !hasAnyPeterete && !hasAnyCut && (
              <p className="muted-text">
                Descartes preparados.
              </p>
            )}

            {isDiscardPhase && discardSelectionEnabled && !hasAnyCut && (
              <p className="muted-text">
                Selecciona tus descartes.
              </p>
            )}

          </div>
        </div>

        <div className="seat-area seat-right">{renderPlayerSeat("P4")}</div>

        <div className="seat-area seat-bottom">{renderPlayerSeat("P1")}</div>
      </section>

      {handResultModalOpen && isHandClosed && !hasGameWinner && (
        <div
          className="hand-result-modal-backdrop"
          role="presentation"
        >
          <section
            className="hand-result-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="hand-result-modal-title"
          >
            <HandResultPanel
              gameState={gameState}
              titleId="hand-result-modal-title"
            />

            <footer className="hand-result-modal-footer">
              {agentAutoContinueEnabled ? (
                <button
                  type="button"
                  className="secondary-button hand-result-continue-button"
                  onClick={handleContinueToNextHand}
                  disabled={startNextHandMutation.isPending}
                >
                  <span
                    className="hand-result-continue-spinner"
                    aria-hidden="true"
                  />
                  {startNextHandMutation.isPending
                    ? "Repartiendo..."
                    : `Continuar (${autoContinueSecondsLeft}s)`}
                </button>
              ) : (
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => setHandResultModalOpen(false)}
                >
                  Cerrar
                </button>
              )}
            </footer>
          </section>
        </div>
      )}

      {winnerModalOpen && hasGameWinner && (
        <div
          className="hand-result-modal-backdrop"
          role="presentation"
        >
          <section
            className="hand-result-modal game-winner-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="game-winner-modal-title"
          >
            <div className="game-winner-modal-content">
              <p className="eyebrow">Partida finalizada</p>
              <h2 id="game-winner-modal-title">Ganador: {winnerTeamName}</h2>
              <p className="muted-text">
                Resultado final: {getTeamDisplayNameForGameTable(gameState, "A")} {teamAScore} - {teamBScore} {getTeamDisplayNameForGameTable(gameState, "B")}
              </p>
            </div>

            <footer className="hand-result-modal-footer">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setWinnerModalOpen(false)}
              >
                Cerrar
              </button>
            </footer>
          </section>
        </div>
      )}

      {historyModalOpen && (
        <div
          className="game-history-modal-backdrop"
          role="presentation"
          onClick={() => setHistoryModalOpen(false)}
        >
          <section
            className="game-history-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="game-history-title"
            onClick={(event) => event.stopPropagation()}
          >
            <header className="game-history-modal-header">
              <h2 id="game-history-title">Histórico de la mano</h2>
              <button
                type="button"
                className="secondary-button"
                onClick={() => setHistoryModalOpen(false)}
              >
                Cerrar
              </button>
            </header>

            <EventTimeline actions={gameState.hand?.actions ?? []} />
          </section>
        </div>
      )}
    </main>
  );
}



function GameTableScoreSummary({ gameState }: { gameState: GameState }) {
  const teamAName = getTeamDisplayNameForGameTable(gameState, "A");
  const teamBName = getTeamDisplayNameForGameTable(gameState, "B");
  const teamAScore = getScoreForTeam(gameState, "A");
  const teamBScore = getScoreForTeam(gameState, "B");
  const handScoreColumns = getHandScoreColumns(gameState);

  return (
    <section className="game-score-summary" aria-label="Marcador de la partida">
      <div className="game-score-total game-score-total-a">
        <span className="game-score-team-name">{teamAName}</span>
        <strong>{teamAScore}</strong>
      </div>

      <div className="game-hand-results-card">
        <div className="game-hand-results-title">Manos</div>
        <div className="game-hand-results-table-wrap">
          <table className="game-hand-results-table">
            <thead>
              <tr>
                <th scope="col">Equipo</th>
                {handScoreColumns.length > 0 ? (
                  handScoreColumns.map((column) => (
                    <th key={column.key} scope="col">
                      {column.label}
                    </th>
                  ))
                ) : (
                  <th scope="col"></th>
                )}
              </tr>
            </thead>
            <tbody>
              <tr>
                <th scope="row">{teamAName}</th>
                {handScoreColumns.length > 0 ? (
                  handScoreColumns.map((column) => (
                    <td key={`${column.key}-A`}>{column.teamA}</td>
                  ))
                ) : (
                  <td></td>
                )}
              </tr>
              <tr>
                <th scope="row">{teamBName}</th>
                {handScoreColumns.length > 0 ? (
                  handScoreColumns.map((column) => (
                    <td key={`${column.key}-B`}>{column.teamB}</td>
                  ))
                ) : (
                  <td></td>
                )}
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div className="game-score-total game-score-total-b">
        <span className="game-score-team-name">{teamBName}</span>
        <strong>{teamBScore}</strong>
      </div>
    </section>
  );
}

function getHandScoreColumns(gameState: GameState): HandScoreColumn[] {
  const handRecords = getHandRecordsForScoreHistory(gameState);
  const columns: HandScoreColumn[] = [];
  const seenIdentities = new Set<string>();

  for (const handRecord of handRecords) {
    if (!handRecord || typeof handRecord !== "object") {
      continue;
    }

    const hand = handRecord as Record<string, unknown>;
    const score = getHandScoreDelta(hand);

    /*
      Las manos históricas no siempre traen status/phase cerrado, así que no
      filtramos aquí por isClosedHandRecord. El filtro de mano actual abierta se
      hace en getHandRecordsForScoreHistory.
    */
    if (!hasAnyHandScore(score) && !isClosedHandRecord(hand)) {
      continue;
    }

    const identity = getHandScoreColumnIdentity(hand, columns.length);

    if (seenIdentities.has(identity)) {
      continue;
    }

    seenIdentities.add(identity);
    columns.push({
      key: getHandScoreColumnKey(hand, columns.length),
      label: getHandScoreColumnLabel(hand, columns.length + 1),
      teamA: score.teamA,
      teamB: score.teamB,
    });
  }

  return columns.sort(
    (left, right) => getHandColumnSortValue(left) - getHandColumnSortValue(right)
  );
}

function getHandRecordsForScoreHistory(gameState: GameState): Record<string, unknown>[] {
  const state = gameState as unknown as Record<string, unknown>;

  const handHistory = collectHandRecords(state.handHistory);

  if (handHistory.length > 0) {
    return handHistory;
  }

  const historicalCandidates = [
    state.hands,
    state.previousHands,
    state.rounds,
    state.handResults,
    state.completedHands,
  ];

  const result: Record<string, unknown>[] = [];

  for (const candidate of historicalCandidates) {
    appendHandRecords(result, candidate);
  }

  /*
    Importante:
    state.hand representa normalmente la mano actual. Sólo debe usarse para el
    marcador histórico si ya está cerrada. Esto evita que la primera mano en
    juego aparezca como resultado antes de terminar.
  */
  if (result.length === 0 && state.hand && typeof state.hand === "object") {
    const currentHand = state.hand as Record<string, unknown>;

    if (isClosedHandRecord(currentHand)) {
      appendHandRecords(result, currentHand);
    }
  }

  return result;
}

function collectHandRecords(value: unknown): Record<string, unknown>[] {
  const result: Record<string, unknown>[] = [];
  appendHandRecords(result, value);
  return result;
}

function appendHandRecords(result: Record<string, unknown>[], value: unknown) {
  if (!value) {
    return;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      appendHandRecords(result, item);
    }

    return;
  }

  if (typeof value !== "object") {
    return;
  }

  const record = value as Record<string, unknown>;

  if (Array.isArray(record.hands)) {
    appendHandRecords(result, record.hands);
    return;
  }

  if (Array.isArray(record.handHistory)) {
    appendHandRecords(result, record.handHistory);
    return;
  }

  if (Array.isArray(record.handResults)) {
    appendHandRecords(result, record.handResults);
    return;
  }

  result.push(record);
}

function getHandScoreDelta(hand: Record<string, unknown>): { teamA: number; teamB: number } {
  const explicitScore = getExplicitHandScore(hand);

  if (hasAnyHandScore(explicitScore)) {
    return explicitScore;
  }

  const phaseScore = sumHandScorePhases(hand.phases ?? hand.completedPhases);

  if (hasAnyHandScore(phaseScore)) {
    return phaseScore;
  }

  const directScore = getTeamScoreFromPossibleContainers(hand, [
    "scoreDelta",
    "handScore",
    "handScores",
    "pointsDelta",
    "awardedPoints",
    "result",
  ]);

  if (hasAnyHandScore(directScore)) {
    return directScore;
  }

  const eventScore = sumHandScoreEvents([
    hand.settledPoints,
    hand.handEndSettledPoints,
    hand.pointsAwarded,
    hand.actions,
    hand.events,
  ]);

  if (hasAnyHandScore(eventScore)) {
    return eventScore;
  }

  return { teamA: 0, teamB: 0 };
}

function getExplicitHandScore(hand: Record<string, unknown>): { teamA: number; teamB: number } {
  const teamA = getNumericValue(hand.teamA ?? hand.teamAScore ?? hand.scoreA ?? hand.pointsA);
  const teamB = getNumericValue(hand.teamB ?? hand.teamBScore ?? hand.scoreB ?? hand.pointsB);

  return { teamA, teamB };
}

function getTeamScoreFromPossibleContainers(
  source: Record<string, unknown>,
  fieldNames: string[]
): { teamA: number; teamB: number } {
  for (const fieldName of fieldNames) {
    const value = source[fieldName];
    const score = getTeamScoreFromContainer(value);

    if (hasAnyHandScore(score)) {
      return score;
    }
  }

  return { teamA: 0, teamB: 0 };
}

function getTeamScoreFromContainer(value: unknown): { teamA: number; teamB: number } {
  if (!value || typeof value !== "object") {
    return { teamA: 0, teamB: 0 };
  }

  const record = value as Record<string, unknown>;
  const teamA = getNumericValue(
    record.teamA ?? record.A ?? record.a ?? record.scoreA ?? record.pointsA
  );
  const teamB = getNumericValue(
    record.teamB ?? record.B ?? record.b ?? record.scoreB ?? record.pointsB
  );

  return { teamA, teamB };
}

function sumHandScorePhases(value: unknown): { teamA: number; teamB: number } {
  const score = { teamA: 0, teamB: 0 };

  if (!value || typeof value !== "object") {
    return score;
  }

  const phaseContainer = value as Record<string, unknown>;

  for (const phaseName of ["grande", "chica", "pares", "juego", "punto"]) {
    const phase = phaseContainer[phaseName];

    if (!phase || typeof phase !== "object") {
      continue;
    }

    const phaseRecord = phase as Record<string, unknown>;
    const explicitPhaseScore = getExplicitHandScore(phaseRecord);

    if (hasAnyHandScore(explicitPhaseScore)) {
      score.teamA += explicitPhaseScore.teamA;
      score.teamB += explicitPhaseScore.teamB;
      continue;
    }

    const winnerTeam = normalizeTeamIdForGameTable(phaseRecord.winnerTeam);
    const pointsAwarded = getNumericValue(phaseRecord.pointsAwarded);

    if (winnerTeam && pointsAwarded > 0) {
      addScoreToTeam(score, winnerTeam, pointsAwarded);
    }

    const teamCountPoints = getTeamScoreFromContainer(phaseRecord.teamCountPoints);
    score.teamA += teamCountPoints.teamA;
    score.teamB += teamCountPoints.teamB;
  }

  return score;
}

function sumHandScoreEvents(values: unknown[]): { teamA: number; teamB: number } {
  const score = { teamA: 0, teamB: 0 };

  for (const value of values) {
    for (const event of flattenUnknownArray(value)) {
      if (!event || typeof event !== "object") {
        continue;
      }

      const record = event as Record<string, unknown>;
      const type = String(record.type ?? record.actionType ?? "").toLowerCase();

      if (type === "fase_auto_resuelta" || type === "fase_saltada") {
        continue;
      }

      if (type === "valores_cartas_liquidados") {
        addCardValueEventScore(score, record);
        continue;
      }

      const winnerTeam = normalizeTeamIdForGameTable(record.winnerTeam);
      const awardedPoints = getNumericValue(record.pointsAwarded);

      if (winnerTeam && awardedPoints > 0) {
        addScoreToTeam(score, winnerTeam, awardedPoints);
        continue;
      }

      /*
        Eventos de settledPoints pueden venir como { phase, team, points }.
        No usamos amount/value de acciones normales porque los envites tambien
        llevan amount y eso inflaba la última mano.
      */
      const team = normalizeTeamIdForGameTable(record.team ?? record.teamId ?? record.targetTeam);
      const points = getNumericValue(record.points);

      if (team && points > 0) {
        addScoreToTeam(score, team, points);
      }
    }
  }

  return score;
}

function addCardValueEventScore(
  score: { teamA: number; teamB: number },
  record: Record<string, unknown>
) {
  let addedFromBreakdown = false;
  const breakdown = record.breakdown;

  if (Array.isArray(breakdown)) {
    for (const item of breakdown) {
      if (!item || typeof item !== "object") {
        continue;
      }

      const itemRecord = item as Record<string, unknown>;
      const team = normalizeTeamIdForGameTable(itemRecord.team);
      const points = getNumericValue(itemRecord.points);

      if (team && points > 0) {
        addScoreToTeam(score, team, points);
        addedFromBreakdown = true;
      }
    }
  }

  if (addedFromBreakdown) {
    return;
  }

  const team = normalizeTeamIdForGameTable(record.team ?? record.winnerTeam);
  const points = getNumericValue(record.points);

  if (team && points > 0) {
    addScoreToTeam(score, team, points);
  }
}

function addScoreToTeam(
  score: { teamA: number; teamB: number },
  team: ScoreTokenTeamId,
  points: number
) {
  if (team === "A") {
    score.teamA += points;
  } else {
    score.teamB += points;
  }
}

function flattenUnknownArray(value: unknown): unknown[] {
  if (!value) {
    return [];
  }

  if (Array.isArray(value)) {
    return value.flatMap((item) => flattenUnknownArray(item));
  }

  return [value];
}

function getNumericValue(value: unknown): number {
  const numberValue = typeof value === "number" ? value : Number(value ?? 0);

  return Number.isFinite(numberValue) ? Math.trunc(numberValue) : 0;
}

function hasAnyHandScore(score: { teamA: number; teamB: number }): boolean {
  return score.teamA !== 0 || score.teamB !== 0;
}

function isClosedHandRecord(hand: Record<string, unknown>): boolean {
  const status = String(hand.status ?? hand.phase ?? "").toLowerCase();
  return status === "closed" || status === "finished" || status === "manocerrada";
}

function getHandScoreColumnIdentity(hand: Record<string, unknown>, index: number): string {
  const handNumber = getHandNumberForScoreColumn(hand);

  if (handNumber > 0) {
    return `hand-number:${handNumber}`;
  }

  return `hand-key:${getHandScoreColumnKey(hand, index)}`;
}

function getHandScoreColumnKey(hand: Record<string, unknown>, index: number): string {
  const handNumber = getHandNumberForScoreColumn(hand);

  if (handNumber > 0) {
    return `hand-${handNumber}`;
  }

  return String(hand.id ?? hand.handId ?? hand.currentHandId ?? hand.number ?? index);
}

function getHandScoreColumnLabel(hand: Record<string, unknown>, fallbackNumber: number): string {
  const handNumber = getHandNumberForScoreColumn(hand);

  if (handNumber > 0) {
    return `M${handNumber}`;
  }

  return `M${fallbackNumber}`;
}

function getHandNumberForScoreColumn(hand: Record<string, unknown>): number {
  const rawNumber = hand.handNumber ?? hand.number ?? hand.roundNumber;
  const numberValue = Number(rawNumber);

  return Number.isFinite(numberValue) && numberValue > 0
    ? Math.trunc(numberValue)
    : 0;
}

function getHandColumnSortValue(column: HandScoreColumn): number {
  const match = column.label.match(/\d+/);

  if (!match) {
    return Number.MAX_SAFE_INTEGER;
  }

  return Number(match[0]);
}


function getPlayerDisplayNameForGameTable(
  gameState: GameState,
  playerId: PlayerId
): string {
  return getPlayerViewInfo(gameState, playerId).name;
}

function getPlayerViewInfo(
  gameState: GameState,
  playerId: PlayerId
): PlayerViewInfo {
  const state = gameState as unknown as Record<string, unknown>;
  const teamId = getSeatTeamId(playerId);
  const teamName = getTeamDisplayNameForGameTable(gameState, teamId);
  const teamPlayerIndex = getSeatTeamPlayerIndex(playerId);

  const directPlayer = getPlayerObjectBySeatIdForGameTable(
    state.players,
    playerId,
    teamId,
    teamPlayerIndex
  );
  const directName = getPlayerNameFromUnknownForGameTable(directPlayer);

  if (directName) {
    return { playerId, name: directName, teamId, teamName };
  }

  const namedFromMap = getPlayerNameFromPlayerNamesMap(state.playerNames, playerId);
  if (namedFromMap) {
    return { playerId, name: namedFromMap, teamId, teamName };
  }

  const teamObject = getTeamObjectForGameTable(state, teamId);
  const nameFromTeam = getPlayerNameFromTeamForGameTable(
    teamObject,
    teamPlayerIndex
  );

  return {
    playerId,
    name: nameFromTeam || playerId,
    teamId,
    teamName,
  };
}

function getSeatTeamId(playerId: PlayerId): ScoreTokenTeamId | "" {
  if (playerId === "P1" || playerId === "P3") {
    return "A";
  }

  if (playerId === "P2" || playerId === "P4") {
    return "B";
  }

  return "";
}

function getSeatTeamPlayerIndex(playerId: PlayerId): number {
  return playerId === "P3" || playerId === "P4" ? 1 : 0;
}

function getTeamDisplayNameForGameTable(
  gameState: GameState,
  team: unknown
): string {
  const teamId = normalizeTeamIdForGameTable(team);

  if (!teamId) {
    return "Equipo";
  }

  const state = gameState as unknown as Record<string, unknown>;
  const directName = getTeamNameFromDirectFieldsForGameTable(state, teamId);
  if (directName) {
    return directName;
  }

  const nameFromMap = getTeamNameFromMapForGameTable(state.teamNames, teamId);
  if (nameFromMap) {
    return nameFromMap;
  }

  const teamObject = getTeamObjectForGameTable(state, teamId);
  const nameFromTeam = getTeamNameFromUnknownForGameTable(teamObject);
  if (nameFromTeam) {
    return nameFromTeam;
  }

  const nameFromPlayers = getTeamNameFromPlayersForGameTable(state.players, teamId);
  if (nameFromPlayers) {
    return nameFromPlayers;
  }

  return `Equipo ${teamId}`;
}

function getPlayerObjectBySeatIdForGameTable(
  value: unknown,
  playerId: PlayerId,
  teamId: string,
  teamPlayerIndex: number
): unknown {
  const seatNumber = teamPlayerIndex + 1;

  if (Array.isArray(value)) {
    const directPlayer = value.find((item) => isPlayerSeatMatch(item, playerId));
    if (directPlayer) {
      return directPlayer;
    }

    return value.find((item) => {
      if (!item || typeof item !== "object") {
        return false;
      }

      const player = item as Record<string, unknown>;
      const rawTeam = normalizeTeamIdForGameTable(player.team ?? player.teamId ?? player.side);
      const rawNumber = Number(
        player.teamPlayerNumber ??
          player.playerNumber ??
          player.position ??
          player.order ??
          player.index
      );

      return rawTeam === teamId && rawNumber === seatNumber;
    });
  }

  if (value && typeof value === "object") {
    const players = value as Record<string, unknown>;
    return players[playerId] ?? players[playerId.toLowerCase()];
  }

  return null;
}

function isPlayerSeatMatch(value: unknown, playerId: PlayerId): boolean {
  if (!value || typeof value !== "object") {
    return false;
  }

  const player = value as Record<string, unknown>;
  return (
    String(
      player.id ?? player.playerId ?? player.seatId ?? player.code ?? player.key ?? ""
    ) === playerId
  );
}

function getPlayerNameFromPlayerNamesMap(
  value: unknown,
  playerId: PlayerId
): string {
  if (!value || typeof value !== "object") {
    return "";
  }

  const playerNames = value as Record<string, unknown>;
  return getPlayerNameFromUnknownForGameTable(
    playerNames[playerId] ?? playerNames[playerId.toLowerCase()]
  );
}

function getPlayerNameFromTeamForGameTable(
  rawTeam: unknown,
  teamPlayerIndex: number
): string {
  if (!rawTeam || typeof rawTeam !== "object") {
    return "";
  }

  const team = rawTeam as Record<string, unknown>;
  const players = team.players ?? team.members ?? team.teamPlayers;

  if (!Array.isArray(players)) {
    return "";
  }

  return getPlayerNameFromUnknownForGameTable(players[teamPlayerIndex]);
}

function getPlayerNameFromUnknownForGameTable(value: unknown): string {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }

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

  return typeof name === "string" && name.trim() ? name.trim() : "";
}

function getTeamNameFromPlayersForGameTable(
  playersValue: unknown,
  teamId: ScoreTokenTeamId
): string {
  const candidates = getPlayerObjectsForGameTable(playersValue).filter((player) => {
    const rawTeam = normalizeTeamIdForGameTable(
      player.team ?? player.teamId ?? player.side
    );

    return rawTeam === teamId;
  });

  for (const player of candidates) {
    const name = getTeamNameFromPlayerForGameTable(player);

    if (name) {
      return name;
    }
  }

  return "";
}

function getPlayerObjectsForGameTable(value: unknown): Record<string, unknown>[] {
  if (!value) {
    return [];
  }

  if (Array.isArray(value)) {
    return value.filter(
      (item): item is Record<string, unknown> => Boolean(item) && typeof item === "object"
    );
  }

  if (typeof value === "object") {
    return Object.values(value as Record<string, unknown>).filter(
      (item): item is Record<string, unknown> => Boolean(item) && typeof item === "object"
    );
  }

  return [];
}

function getTeamNameFromPlayerForGameTable(player: Record<string, unknown>): string {
  const candidate =
    player.teamDisplayName ??
    player.teamName ??
    player.tournamentTeamName ??
    player.tournamentTeamDisplayName ??
    player.clubName ??
    player.sideName;

  return typeof candidate === "string" && candidate.trim() ? candidate.trim() : "";
}

function getTeamObjectForGameTable(
  state: Record<string, unknown>,
  teamId: string
): unknown {
  const directField = teamId === "A" ? state.teamA : state.teamB;
  if (directField) {
    return directField;
  }

  const teams = state.teams;

  if (Array.isArray(teams)) {
    const matchedTeam = teams.find((rawTeam) =>
      isTeamMatchForGameTable(rawTeam, teamId)
    );

    if (matchedTeam) {
      return matchedTeam;
    }

    return teams[teamId === "A" ? 0 : 1] ?? null;
  }

  if (teams && typeof teams === "object") {
    const teamsRecord = teams as Record<string, unknown>;
    const directTeam =
      teamsRecord[teamId] ??
      teamsRecord[teamId.toUpperCase()] ??
      teamsRecord[teamId.toLowerCase()];

    if (directTeam) {
      return directTeam;
    }

    return Object.entries(teamsRecord).find(([fallbackId, rawTeam]) =>
      isTeamMatchForGameTable(rawTeam, teamId, fallbackId)
    )?.[1];
  }

  return null;
}

function isTeamMatchForGameTable(
  value: unknown,
  teamId: string,
  fallbackId?: string
): boolean {
  if (!value || typeof value !== "object") {
    return false;
  }

  const team = value as Record<string, unknown>;
  const rawId = team.id ?? team.teamId ?? team.code ?? team.key ?? team.letter ?? fallbackId;

  return normalizeTeamIdForGameTable(rawId) === teamId;
}

function getTeamNameFromDirectFieldsForGameTable(
  state: Record<string, unknown>,
  teamId: string
): string {
  const fields =
    teamId === "A"
      ? ["teamAName", "teamNameA"]
      : ["teamBName", "teamNameB"];

  for (const field of fields) {
    const value = state[field];

    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }

  return "";
}

function getTeamNameFromMapForGameTable(value: unknown, teamId: string): string {
  if (!value || typeof value !== "object") {
    return "";
  }

  const teamNames = value as Record<string, unknown>;
  const prefixedKey = teamId === "A" ? "teamA" : "teamB";
  const nameKey = teamId === "A" ? "teamAName" : "teamBName";
  const alternateNameKey = teamId === "A" ? "teamNameA" : "teamNameB";
  const candidate =
    teamNames[teamId] ??
    teamNames[teamId.toUpperCase()] ??
    teamNames[teamId.toLowerCase()] ??
    teamNames[prefixedKey] ??
    teamNames[prefixedKey.toUpperCase()] ??
    teamNames[prefixedKey.toLowerCase()] ??
    teamNames[nameKey] ??
    teamNames[alternateNameKey];

  return getTeamNameFromUnknownForGameTable(candidate);
}

function getTeamNameFromUnknownForGameTable(value: unknown): string {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }

  if (!value || typeof value !== "object") {
    return "";
  }

  const team = value as Record<string, unknown>;
  const name = team.name ?? team.displayName ?? team.teamName ?? team.label;

  return typeof name === "string" && name.trim() ? name.trim() : "";
}

function normalizeTeamIdForGameTable(value: unknown): ScoreTokenTeamId | "" {
  const text = String(value ?? "")
    .trim()
    .toUpperCase()
    .replace(/^TEAM/, "");

  if (text === "A" || text === "B") {
    return text;
  }

  return "";
}

type ScoreTokenTeamId = "A" | "B";

function getScoreForTeam(gameState: GameState, team: ScoreTokenTeamId): number {
  const score = (gameState as unknown as { score?: Record<string, unknown> }).score;
  const key = team === "A" ? "teamA" : "teamB";
  const rawValue = score?.[key];
  const value = typeof rawValue === "number" ? rawValue : Number(rawValue ?? 0);

  return Number.isFinite(value) && value > 0 ? Math.trunc(value) : 0;
}

function getScoreTokenCounts(score: number): { amarracos: number; piedras: number } {
  const safeScore = Math.max(0, Math.trunc(score));

  return {
    amarracos: Math.floor(safeScore / 5),
    piedras: safeScore % 5,
  };
}

function getHandResultModalKey(gameState: GameState): string {
  const gameStateRecord = gameState as unknown as Record<string, unknown>;
  const handRecord = gameState.hand as unknown as Record<string, unknown> | undefined;

  const gameId = String(gameState.gameId ?? "");
  const handId =
    getStringFromRecord(gameStateRecord, "currentHandId") ||
    getStringFromRecord(handRecord, "id") ||
    getStringFromRecord(handRecord, "handId") ||
    String(gameState.handNumber ?? handRecord?.handNumber ?? "");

  return `${gameId}:${handId}`;
}

function getWinnerModalKey(gameState: GameState): string {
  const winnerTeam = normalizeTeamIdForGameTable(gameState.winnerTeam);
  const teamAScore = getScoreForTeam(gameState, "A");
  const teamBScore = getScoreForTeam(gameState, "B");

  return [gameState.gameId ?? "", winnerTeam, teamAScore, teamBScore].join(":");
}

function getStringFromRecord(
  source: Record<string, unknown> | undefined,
  key: string
): string {
  if (!source) {
    return "";
  }

  const value = source[key];

  if (typeof value === "string") {
    return value;
  }

  if (typeof value === "number") {
    return String(value);
  }

  return "";
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
    En descartes, mantenemos el comportamiento existente: el jugador inicial
    debe ser el que marque el backend como turno. Si no viene inicializado,
    caemos al jugador mano de la mano actual.
  */
  const gameStateRecord = gameState as unknown as Record<string, unknown>;
  const handRecord = gameState.hand as unknown as Record<string, unknown>;

  const candidates = [
    gameState.turnPlayerId,
    handRecord?.turnPlayerId,
    handRecord?.currentTurnPlayerId,
    handRecord?.activePlayerId,
    ...getHandStartPlayerCandidates(gameStateRecord, handRecord),
  ];

  for (const candidate of candidates) {
    if (PLAYER_IDS.includes(candidate as PlayerId)) {
      return candidate as PlayerId;
    }
  }

  return "P1";
}

function getHandStartPlayerId(gameState: GameState): PlayerId {
  /*
    Para las jugadas/lances, la interfaz debe empezar siempre por la mano,
    no por el siguiente jugador que aparezca como turno activo. Esto evita
    que las declaraciones visuales arranquen una posición desplazadas.
  */
  const gameStateRecord = gameState as unknown as Record<string, unknown>;
  const handRecord = gameState.hand as unknown as Record<string, unknown>;

  const candidates = [
    ...getHandStartPlayerCandidates(gameStateRecord, handRecord),
    gameState.turnPlayerId,
    handRecord?.turnPlayerId,
    handRecord?.currentTurnPlayerId,
    handRecord?.activePlayerId,
  ];

  for (const candidate of candidates) {
    if (PLAYER_IDS.includes(candidate as PlayerId)) {
      return candidate as PlayerId;
    }
  }

  return "P1";
}

function getHandStartPlayerCandidates(
  gameStateRecord: Record<string, unknown>,
  handRecord: Record<string, unknown>
): unknown[] {
  return [
    handRecord?.manoPlayerId,
    handRecord?.handPlayerId,
    handRecord?.startPlayerId,
    handRecord?.initialTurnPlayerId,
    handRecord?.leadPlayerId,
    gameStateRecord.manoPlayerId,
    gameStateRecord.handPlayerId,
    gameStateRecord.startPlayerId,
    gameStateRecord.initialTurnPlayerId,
    gameStateRecord.leadPlayerId,
  ];
}

function getPlayerOrderFrom(startPlayerId: PlayerId): PlayerId[] {
  const index = PLAYER_IDS.indexOf(startPlayerId);

  if (index < 0) {
    return PLAYER_IDS;
  }

  return [...PLAYER_IDS.slice(index), ...PLAYER_IDS.slice(0, index)];
}