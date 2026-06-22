import { useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type { CreateGamePlayer } from "../../../domain/api.types";
import type { PlayerId } from "../../../domain/game.types";

const DEFAULT_PLAYERS: CreateGamePlayer[] = [
  { id: "P1", name: "Jugador humano", type: "human", team: "A" },
  { id: "P2", name: "Rival agente 1", type: "agent", team: "B", agentProfile: "balanced" },
  { id: "P3", name: "Compañero agente", type: "agent", team: "A", agentProfile: "balanced" },
  { id: "P4", name: "Rival agente 2", type: "agent", team: "B", agentProfile: "balanced" },
];

const AGENT_PROFILES = ["balanced", "aggressive", "conservative"];

export function GameSetupPage() {
  const navigate = useNavigate();
  const [players, setPlayers] = useState(DEFAULT_PLAYERS);
  const [autoStart, setAutoStart] = useState(true);
  const [lastError, setLastError] = useState("");

  const humanPlayerId = useMemo(
    () => players.find((player) => player.type === "human")?.id ?? "",
    [players]
  );

  const createGameMutation = useMutation({
    mutationFn: async () => {
      validatePlayers(players);
      const createResponse = await musApi.createGame({ players });
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

  function setHumanPlayer(playerId: PlayerId) {
    setPlayers((current) =>
      current.map((player) => {
        const isHuman = player.id === playerId;

        return {
          ...player,
          type: isHuman ? "human" : "agent",
          agentProfile: isHuman ? undefined : player.agentProfile ?? "balanced",
        } as CreateGamePlayer;
      })
    );
  }

  function updatePlayer(playerId: PlayerId, patch: Partial<CreateGamePlayer>) {
    setPlayers((current) =>
      current.map((player) =>
        player.id === playerId ? { ...player, ...patch } : player
      )
    );
  }

  return (
    <main className="page game-setup-page">
      <div className="page-heading-row">
        <div>
          <p className="eyebrow">Partida</p>
          <h1>Nueva partida</h1>
          <p className="muted-text">
            Solo se permite un jugador humano. Los otros tres jugadores serán agentes.
          </p>
        </div>

        <Link className="icon-button ghost" to="/tournaments">
          <span aria-hidden="true">←</span>
          Volver
        </Link>
      </div>

      <section className="setup-card human-only-summary">
        <span aria-hidden="true">👤</span>
        <div>
          <strong>Jugador humano único</strong>
          <p>{humanPlayerId || "Selecciona qué asiento ocupará el humano."}</p>
        </div>
      </section>

      <section className="game-player-grid">
        {players.map((player) => {
          const isHuman = player.type === "human";

          return (
            <article key={player.id} className="setup-card player-config-card">
              <div className="player-config-header">
                <h2>{player.id}</h2>
                <span className="tournament-status-pill">Equipo {player.team}</span>
              </div>

              <label>
                <span>Nombre</span>
                <input
                  value={player.name}
                  onChange={(event) => updatePlayer(player.id, { name: event.target.value })}
                />
              </label>

              <label>
                <span>Equipo</span>
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

              <button
                type="button"
                className={isHuman ? "icon-button primary" : "icon-button ghost"}
                onClick={() => setHumanPlayer(player.id)}
              >
                <span aria-hidden="true">{isHuman ? "👤" : "🤖"}</span>
                {isHuman ? "Humano" : "Marcar humano"}
              </button>

              {!isHuman && (
                <label>
                  <span>Perfil agente</span>
                  <select
                    value={player.agentProfile ?? "balanced"}
                    onChange={(event) =>
                      updatePlayer(player.id, { agentProfile: event.target.value })
                    }
                  >
                    {AGENT_PROFILES.map((profile) => (
                      <option key={profile} value={profile}>
                        {profile}
                      </option>
                    ))}
                  </select>
                </label>
              )}
            </article>
          );
        })}
      </section>

      <section className="setup-card">
        <label className="checkbox-row">
          <input
            type="checkbox"
            checked={autoStart}
            onChange={(event) => setAutoStart(event.target.checked)}
          />
          Iniciar partida automáticamente
        </label>
      </section>

      <div className="setup-actions-bar">
        <button
          type="button"
          className="icon-button primary"
          onClick={() => createGameMutation.mutate()}
          disabled={createGameMutation.isPending}
        >
          <span aria-hidden="true">🃏</span>
          {createGameMutation.isPending ? "Creando..." : "Crear partida"}
        </button>
      </div>

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

  const humanCount = players.filter((player) => player.type === "human").length;

  if (humanCount !== 1) {
    throw new Error("Debe haber exactamente un jugador humano.");
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
