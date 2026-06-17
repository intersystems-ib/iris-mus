import { useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { musApi } from "../../../api/musApi";
import type { GameState, PlayerId } from "../../../domain/game.types";

interface DiscardPanelProps {
  gameState: GameState;
  onDiscardsSubmitted: () => void;
}

const PLAYER_IDS: PlayerId[] = ["P1", "P2", "P3", "P4"];

export function DiscardPanel({
  gameState,
  onDiscardsSubmitted,
}: DiscardPanelProps) {
  const [selectedCards, setSelectedCards] = useState<Record<PlayerId, string[]>>({
    P1: [],
    P2: [],
    P3: [],
    P4: [],
  });

  const [lastError, setLastError] = useState<string>("");

  const cardsByPlayer = useMemo(
    () => getCardsByPlayer(gameState),
    [gameState]
  );

  const totalSelected = PLAYER_IDS.reduce(
    (total, playerId) => total + (selectedCards[playerId]?.length ?? 0),
    0
 );

  const submitMutation = useMutation({
    mutationFn: () =>
      musApi.submitDiscards(String(gameState.gameId), {
        discards: selectedCards,
      }),
    onSuccess: () => {
      setLastError("");
      setSelectedCards({
        P1: [],
        P2: [],
        P3: [],
        P4: [],
      });
      onDiscardsSubmitted();
    },
    onError: (error) => {
      setLastError(error instanceof Error ? error.message : String(error));
    },
  });

  function toggleCard(playerId: PlayerId, card: string) {
    setSelectedCards((current) => {
      const currentCards = current[playerId] ?? [];
      const exists = currentCards.includes(card);

      return {
        ...current,
        [playerId]: exists
          ? currentCards.filter((item) => item !== card)
          : [...currentCards, card],
      };
    });
  }

  function submitEmptyDiscards() {
    setSelectedCards({
      P1: [],
      P2: [],
      P3: [],
      P4: [],
    });

    submitMutation.mutate();
  }

  return (
    <section className="discard-panel">
      <header className="discard-panel-header">
        <div>
          <h2>Descartes</h2>
          <p>
            Ronda:{" "}
            <strong>
              {gameState.hand?.discardRound ?? gameState.discardRound ?? 0}
            </strong>
          </p>
        </div>

        <div className="discard-counter">
          <span>Seleccionadas</span>
          <strong>{totalSelected}</strong>
        </div>
      </header>

      <div className="discard-players">
        {PLAYER_IDS.map((playerId) => (
          <article className="discard-player" key={playerId}>
            <header>
              <strong>{playerId}</strong>
              <span>{selectedCards[playerId]?.length ?? 0} cartas</span>
            </header>

            <div className="discard-card-list">
              {cardsByPlayer[playerId].length === 0 ? (
                <p className="muted-text">Sin cartas</p>
              ) : (
                cardsByPlayer[playerId].map((card, index) => {
                  const selected = selectedCards[playerId]?.includes(card);

                  return (
                    <button
                      key={`${playerId}-${card}-${index}`}
                      type="button"
                      className={[
                        "discard-card-button",
                        selected ? "selected" : "",
                      ]
                        .filter(Boolean)
                        .join(" ")}
                      onClick={() => toggleCard(playerId, card)}
                    >
                      {card}
                    </button>
                  );
                })
              )}
            </div>
          </article>
        ))}
      </div>

      <div className="discard-actions">
        <button
          type="button"
          onClick={() => submitMutation.mutate()}
          disabled={submitMutation.isPending}
        >
          Enviar descartes
        </button>

        <button
          type="button"
          onClick={submitEmptyDiscards}
          disabled={submitMutation.isPending}
        >
          No descartar y cerrar
        </button>
      </div>

      <p className="muted-text">
        Si todos envían 0 cartas, el backend cierra descartes y pasa a grande.
      </p>

      {submitMutation.isPending && (
        <p className="muted-text">Enviando descartes...</p>
      )}

      {lastError && <p className="error-text">{lastError}</p>}
    </section>
  );
}

function getCardsByPlayer(gameState: GameState): Record<PlayerId, string[]> {
  const cards = gameState.hand?.cards;

  return {
    P1: getCards(cards, "P1"),
    P2: getCards(cards, "P2"),
    P3: getCards(cards, "P3"),
    P4: getCards(cards, "P4"),
  };
}

function getCards(value: unknown, playerId: PlayerId): string[] {
  if (!value || typeof value !== "object") {
    return [];
  }

  const rawCards = (value as Record<string, unknown>)[playerId];

  if (!Array.isArray(rawCards)) {
    return [];
  }

  return rawCards.map(String);
}