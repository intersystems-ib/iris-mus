import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { musApi } from "../../../api/musApi";
import { Link } from "react-router-dom";

export function ApiTestPage() {
  const [gameId, setGameId] = useState<string>("");
  const [output, setOutput] = useState<unknown>(null);

  const createGameMutation = useMutation({
    mutationFn: () =>
        musApi.createGame({
            players: [
            { id: "P1", name: "Test P1", type: "human", team: "A" },
            { id: "P2", name: "Test P2", type: "agent", team: "B" },
            { id: "P3", name: "Test P3", type: "agent", team: "A" },
            { id: "P4", name: "Test P4", type: "agent", team: "B" },
            ],
        }),
    onSuccess: (data) => {
      setOutput(data);

      const newGameId =
        typeof data.gameId === "string"
          ? data.gameId
          : typeof data.gameId === "number"
            ? String(data.gameId)
            : "";

      if (newGameId) {
        setGameId(newGameId);
      }
    },
    onError: (error) => {
      setOutput({
        error: error instanceof Error ? error.message : String(error),
      });
    },
  });

  const startGameMutation = useMutation({
    mutationFn: () => musApi.startGame(gameId),
    onSuccess: setOutput,
    onError: (error) => {
      setOutput({
        error: error instanceof Error ? error.message : String(error),
      });
    },
  });

  const getStateMutation = useMutation({
    mutationFn: () => musApi.getGameState(gameId),
    onSuccess: setOutput,
    onError: (error) => {
      setOutput({
        error: error instanceof Error ? error.message : String(error),
      });
    },
  });

  return (
    <main className="page">
      <h1>Prueba API Mus</h1>

      <section className="panel">
        <button
          type="button"
          onClick={() => createGameMutation.mutate()}
          disabled={createGameMutation.isPending}
        >
          Crear partida
        </button>

        <input
          value={gameId}
          onChange={(event) => setGameId(event.target.value)}
          placeholder="Game ID"
        />

        {gameId && <Link to={`/games/${gameId}`}>Abrir mesa</Link>}

        <button
          type="button"
          onClick={() => startGameMutation.mutate()}
          disabled={!gameId || startGameMutation.isPending}
        >
          Start game
        </button>

        <button
          type="button"
          onClick={() => getStateMutation.mutate()}
          disabled={!gameId || getStateMutation.isPending}
        >
          Get state
        </button>
      </section>

      <pre className="json-output">
        {JSON.stringify(output, null, 2)}
      </pre>
    </main>
  );
}