import { useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { musApi } from "../../../api/musApi";
import { useTranslation } from "react-i18next";
import type {
  ActionType,
  GameState,
  PlayerId,
} from "../../../domain/game.types";

interface ActionPanelProps {
  gameState: GameState;
  selectedPlayerId: PlayerId;
  onSelectedPlayerChange: (playerId: PlayerId) => void;
  onActionExecuted: () => void;
}

const PLAYER_IDS: PlayerId[] = ["P1", "P2", "P3", "P4"];


export function ActionPanel({
  gameState,
  selectedPlayerId,
  onSelectedPlayerChange,
  onActionExecuted,
}: ActionPanelProps) {
  const { t } = useTranslation();
  const [amount, setAmount] = useState<number>(2);
  const [lastError, setLastError] = useState<string>("");

  const legalActions = useMemo(
    () => getLegalActionsForPlayer(gameState, selectedPlayerId),
    [gameState, selectedPlayerId]
  );

  const actionMutation = useMutation({
    mutationFn: (actionType: ActionType) => {
      const resolvedAmount = resolveActionAmount(actionType, amount);

      return musApi.playerAction(String(gameState.gameId), {
        playerId: selectedPlayerId,
        phase: gameState.phase,
        actionType,
        amount: resolvedAmount,
      });
    },
    onSuccess: () => {
      setLastError("");
      onActionExecuted();
    },
    onError: (error) => {
      setLastError(error instanceof Error ? error.message : String(error));
    },
  });

  const canAct =
    gameState.status !== "finished" &&
    gameState.phase !== "manoCerrada" &&
    legalActions.length > 0;

  return (
    <section className="action-panel">
      <header className="action-panel-header">
        <div>
          <h2>{t("actions.title")}</h2>
          <p>
            {t("actions.currentTurn")}: <strong>{gameState.turnPlayerId || t("common.unknown")}</strong>
          </p>
        </div>

        <label className="player-select-label">
          {t("actions.playAs")}
          <select
            value={selectedPlayerId}
            onChange={(event) =>
              onSelectedPlayerChange(event.target.value as PlayerId)
            }
          >
            {PLAYER_IDS.map((playerId) => (
              <option key={playerId} value={playerId}>
                {playerId}
              </option>
            ))}
          </select>
        </label>
      </header>

      <div className="action-meta">
        <Info label={t("actions.phase")} value={t(`phases.${gameState.phase}`)} />
        <Info label={t("actions.status")} value={t(`statuses.${gameState.status}`)} />
        <Info label={t("actions.legalActions")} value={legalActions.map((action) => t(`actions.labels.${action}`)).join(", ") || t("common.unknown")} />
      </div>

      {legalActions.includes("envidar") && (
        <label className="amount-field">
          {t("actions.betAmount")}
          <input
            type="number"
            min={1}
            value={amount}
            onChange={(event) => setAmount(Number(event.target.value))}
          />
        </label>
      )}

      <div className="action-buttons">
        {(["pasar", "envidar", "querer", "no_querer", "ordago"] as ActionType[]).map(
          (actionType) => {
            const enabled =
              canAct &&
              legalActions.includes(actionType) &&
              !actionMutation.isPending;

            return (
              <button
                key={actionType}
                type="button"
                disabled={!enabled}
                onClick={() => actionMutation.mutate(actionType)}
                className={actionType === "ordago" ? "danger-action" : ""}
              >
                {t(`actions.labels.${actionType}`)}
              </button>
            );
          }
        )}
      </div>

      {!canAct && (
        <p className="muted-text">
          {t("actions.noActions")}
        </p>
      )}

      {actionMutation.isPending && (
        <p className="muted-text">{t("actions.sending")}</p>
      )}

      {lastError && <p className="error-text">{lastError}</p>}
    </section>
  );
}

interface InfoProps {
  label: string;
  value: string | number;
}

function Info({ label, value }: InfoProps) {
  return (
    <div className="action-info">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function resolveActionAmount(actionType: ActionType, amount: number): number {
  if (actionType === "ordago") {
    return 999;
  }

  if (actionType === "envidar") {
    return Number.isFinite(amount) && amount > 0 ? amount : 2;
  }

  return 0;
}

function getLegalActionsForPlayer(
  gameState: GameState,
  playerId: PlayerId
): ActionType[] {
  if (gameState.status === "finished") {
    return [];
  }

  if (gameState.phase === "manoCerrada") {
    return [];
  }

  const pendingBet = getPendingBet(gameState);

  if (pendingBet) {
    const respondingPlayers = Array.isArray(pendingBet.respondingPlayers)
      ? pendingBet.respondingPlayers
      : [];

    const isResponder =
      respondingPlayers.includes(playerId) ||
      pendingBet.respondingPlayerId === playerId;

    if (!isResponder) {
      return [];
    }

    if (pendingBet.type === "ordago") {
      return ["querer", "no_querer"];
    }

    return ["querer", "no_querer", "envidar", "ordago"];
  }

  if (gameState.turnPlayerId !== playerId) {
    return [];
  }

  return ["pasar", "envidar", "ordago"];
}

function getPendingBet(gameState: GameState):
  | {
      type?: "envidar" | "ordago";
      respondingPlayerId?: PlayerId;
      respondingPlayers?: PlayerId[];
    }
  | null {
  const handPendingBet = gameState.hand?.pendingBet;

  if (handPendingBet && typeof handPendingBet === "object") {
    return handPendingBet;
  }

  const phaseState = gameState.hand?.phaseState as Record<string, unknown> | undefined;
  const phasePendingBet = phaseState?.pendingBet;

  if (phasePendingBet && typeof phasePendingBet === "object") {
    return phasePendingBet as {
      type?: "envidar" | "ordago";
      respondingPlayerId?: PlayerId;
      respondingPlayers?: PlayerId[];
    };
  }

  return null;
}