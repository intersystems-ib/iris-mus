import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type { CreateGamePlayer } from "../../../domain/api.types";
import type { PlayerId } from "../../../domain/game.types";

const DEFAULT_PLAYERS: CreateGamePlayer[] = [
  {
    id: "P1",
    name: "Jugador 1",
    type: "human",
    team: "A",
  },
  {
    id: "P2",
    name: "Jugador 2",
    type: "agent",
    team: "B",
    agentProfile: "balanced",
  },
  {
    id: "P3",
    name: "Jugador 3",
    type: "agent",
    team: "A",
    agentProfile: "balanced",
  },
  {
    id: "P4",
    name: "Jugador 4",
    type: "agent",
    team: "B",
    agentProfile: "balanced",
  },
];

export function GameSetupPage() {
  const navigate = useNavigate();

  const [players, setPlayers] = useState<CreateGamePlayer[]>(DEFAULT_PLAYERS);
  const [autoStart, setAutoStart] = useState(true);
  const [lastError, setLastError] = useState("");

  const createGameMutation = useMutation({
    mutationFn: async () => {
      validatePlayers(players);

      const createResponse = await musApi.createGame({
        players,
      });

      const gameId = String(createResponse.gameId ?? "");

      if (!gameId) {
        throw new Error("El backend no devolvió gameId al crear la partida.");
      }

      if (autoStart) {
        await musApi.startGame(gameId);
      }

      return gameId;
    },
    onSuccess: (gameId) => {
      setLastError("");
      navigate(`/games/${gameId}`);
    },
    onError: (error) => {
      setLastError(error instanceof Error ? error.message : String(error));
    },
  });

  function updatePlayer(
    playerId: PlayerId,
    patch: Partial<CreateGamePlayer>
  ) {
    setPlayers((current) =>
      current.map((player) =>
        player.id === playerId ? { ...player, ...patch } : player
      )
    );
  }

  return (
    <main className="page">
      <h1>Nueva partida</h1>
      <p className="muted-text">
        Configura los jugadores y equipos antes de crear la partida.
      </p>

      <section className="setup-grid">
        {players.map((player) => (
          <article className="setup-player-card" key={player.id}>
            <header>
              <strong>{player.id}</strong>
              <span>Equipo {player.team}</span>
            </header>

            <label>
              Nombre
              <input
                value={player.name}
                onChange={(event) =>
                  updatePlayer(player.id, { name: event.target.value })
                }
              />
            </label>

            <label>
              Tipo
              <select
                value={player.type}
                onChange={(event) =>
                  updatePlayer(player.id, {
                    type: event.target.value as CreateGamePlayer["type"],
                  })
                }
              >
                <option value="human">Humano</option>
                <option value="agent">Agente</option>
              </select>
            </label>

            <label>
              Equipo
              <select
                value={player.team}
                onChange={(event) =>
                  updatePlayer(player.id, {
                    team: event.target.value as CreateGamePlayer["team"],
                  })
                }
              >
                <option value="A">Equipo A</option>
                <option value="B">Equipo B</option>
              </select>
            </label>

            {player.type === "agent" && (
              <label>
                Perfil agente
                <select
                  value={player.agentProfile ?? "balanced"}
                  onChange={(event) =>
                    updatePlayer(player.id, {
                      agentProfile: event.target.value,
                    })
                  }
                >
                  <option value="balanced">Balanced</option>
                  <option value="aggressive">Aggressive</option>
                  <option value="conservative">Conservative</option>
                </select>
              </label>
            )}
          </article>
        ))}
      </section>

      <section className="setup-options">
        <label className="checkbox-row">
          <input
            type="checkbox"
            checked={autoStart}
            onChange={(event) => setAutoStart(event.target.checked)}
          />
          Iniciar partida automáticamente
        </label>
      </section>

      <section className="panel">
        <button
          type="button"
          onClick={() => createGameMutation.mutate()}
          disabled={createGameMutation.isPending}
        >
          {createGameMutation.isPending ? "Creando..." : "Crear partida"}
        </button>
      </section>

      {lastError && <p className="error-text">{lastError}</p>}
    </main>
  );
}

function validatePlayers(players: CreateGamePlayer[]) {
  if (players.length !== 4) {
    throw new Error("La partida necesita exactamente 4 jugadores.");
  }

  const emptyName = players.find((player) => !player.name.trim());

  if (emptyName) {
    throw new Error(`El jugador ${emptyName.id} no tiene nombre.`);
  }

  const teamAPlayers = players.filter((player) => player.team === "A");
  const teamBPlayers = players.filter((player) => player.team === "B");

  if (teamAPlayers.length !== 2 || teamBPlayers.length !== 2) {
    throw new Error("Debe haber exactamente 2 jugadores en Equipo A y 2 en Equipo B.");
  }

  const ids = new Set(players.map((player) => player.id));

  if (ids.size !== 4) {
    throw new Error("Los IDs de jugador deben ser únicos.");
  }
}