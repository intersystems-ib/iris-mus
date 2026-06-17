import { useQuery } from "@tanstack/react-query";
import { Link, useParams } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import { extractGameState } from "../../../api/responseMappers";
import { GameTable } from "../components/GameTable";

export function GamePage() {
  const { gameId } = useParams<{ gameId: string }>();

  const gameQuery = useQuery({
    queryKey: ["game-state", gameId],
    queryFn: async () => {
      if (!gameId) {
        throw new Error("No gameId provided");
      }

      return musApi.getGameState(gameId);
    },
    enabled: Boolean(gameId),
    refetchInterval: 3000,
  });

  const gameState = extractGameState(gameQuery.data);

  if (!gameId) {
    return (
      <main className="page">
        <h1>Mesa de juego</h1>
        <p>No se ha indicado Game ID.</p>
        <Link to="/">Volver</Link>
      </main>
    );
  }

  if (gameQuery.isLoading) {
    return (
      <main className="page">
        <h1>Mesa de juego</h1>
        <p>Cargando partida {gameId}...</p>
      </main>
    );
  }

  if (gameQuery.isError) {
    return (
      <main className="page">
        <h1>Mesa de juego</h1>
        <p className="error-text">
          {gameQuery.error instanceof Error
            ? gameQuery.error.message
            : "Error cargando partida"}
        </p>
        <Link to="/">Volver</Link>
      </main>
    );
  }

  if (!gameState) {
    return (
      <main className="page">
        <h1>Mesa de juego</h1>
        <p>No se pudo extraer GameState de la respuesta.</p>
        <pre className="json-output">
          {JSON.stringify(gameQuery.data, null, 2)}
        </pre>
      </main>
    );
  }

return (
  <GameTable
    gameState={gameState}
    onRefresh={() => {
      void gameQuery.refetch();
    }}
  />
);}