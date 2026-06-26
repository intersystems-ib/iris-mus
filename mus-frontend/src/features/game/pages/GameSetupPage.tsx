import { useCallback, useMemo, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type { CreateGamePlayer } from "../../../domain/api.types";
import type { CreateTournamentTeam } from "../../../domain/tournament.types";

const TARGET_SCORE = 40;
const GAME_TEAM_COUNT = 2;
const AGENT_PROFILES = ["balanced", "aggressive", "conservative", "bluffer"] as const;
const PROFILE_LABELS: Record<string, string> = {
  balanced: "Equilibrado",
  aggressive: "Agresivo",
  conservative: "Conservador",
  bluffer: "Farolero",
};

type GameSetupTeam = CreateTournamentTeam;

function randomAgentProfile(): string {
  return AGENT_PROFILES[Math.floor(Math.random() * AGENT_PROFILES.length)];
}

export function GameSetupPage() {
  const navigate = useNavigate();
  const [teams, setTeams] = useState<GameSetupTeam[]>([]);
  const [autoStart, setAutoStart] = useState(true);
  const [lastError, setLastError] = useState("");
  const [isGeneratingTeams, setIsGeneratingTeams] = useState(false);
  const generationInFlightRef = useRef(false);

  const hasGeneratedTeams = teams.length === GAME_TEAM_COUNT;
  const canGenerateTeams = !isGeneratingTeams;

  const canSubmit = useMemo(() => {
    return (
      hasGeneratedTeams &&
      teams.every((team) => team.name.trim() && team.players.length === 2) &&
      countHumanPlayers(teams) === 1 &&
      teams[0]?.players[0]?.type === "human"
    );
  }, [hasGeneratedTeams, teams]);

  const humanPlayerName = useMemo(
    () => teams[0]?.players[0]?.displayName || "Jugador humano",
    [teams]
  );

  const requestGeneratedTeams = useCallback(async () => {
    if (!canGenerateTeams || generationInFlightRef.current) {
      return;
    }

    generationInFlightRef.current = true;
    setIsGeneratingTeams(true);

    try {
      const response = await musApi.generateTournamentTeams({
        teamCount: GAME_TEAM_COUNT,
        targetScore: TARGET_SCORE,
        humanPlayerName: "Jugador humano",
      });

      const generated = response.teams?.length
        ? response.teams
        : buildDefaultTeams(GAME_TEAM_COUNT);

      setTeams(normalizeHumanFirstTeam(generated, GAME_TEAM_COUNT));
      setLastError("");
    } catch (error) {
      setTeams(normalizeHumanFirstTeam(buildDefaultTeams(GAME_TEAM_COUNT), GAME_TEAM_COUNT));
      setLastError(error instanceof Error ? error.message : String(error));
    } finally {
      generationInFlightRef.current = false;
      setIsGeneratingTeams(false);
    }
  }, [canGenerateTeams]);

  const createGameMutation = useMutation({
    mutationFn: async () => {
      const normalizedTeams = normalizeHumanFirstTeam(teams, GAME_TEAM_COUNT);
      const players = buildCreateGamePlayers(normalizedTeams);
      const createGamePayload = buildCreateGamePayload(normalizedTeams, players);

      validatePlayers(players);
      const createResponse = await musApi.createGame(createGamePayload);
      const gameId = String(createResponse.gameId ?? "");

      if (!gameId) {
        throw new Error("El backend no devolvio gameId al crear la partida.");
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

  return (
    <main className="page tournament-setup-page game-setup-page">
      {isGeneratingTeams && (
        <div className="tournament-loading-overlay" role="status" aria-live="polite">
          <div className="tournament-loading-card">
            <span className="tournament-loading-spinner" aria-hidden="true" />
            <strong>Generando equipos</strong>
          </div>
        </div>
      )}

      <button
        type="button"
        className="icon-button ghost tournament-back-button"
        onClick={() => navigate("/tournaments")}
        aria-label="Volver"
      >
        Volver
      </button>

      <p className="eyebrow">Partida</p>
      <h1>Nueva partida</h1>

      <section className="tournament-form-card tournament-setup-start-card">
        <div className="tournament-setup-fields-row">
          <div>
            <strong>Jugador humano unico</strong>
            <p className="muted-text">
              {hasGeneratedTeams
                ? humanPlayerName
                : "Genera los equipos para crear una partida con un jugador humano y tres agentes."}
            </p>
          </div>

          <label className="checkbox-row">
            <input
              type="checkbox"
              checked={autoStart}
              onChange={(event) => setAutoStart(event.target.checked)}
            />
            Iniciar partida automaticamente
          </label>
        </div>

        <div className="tournament-detail-actions">
          <button
            type="button"
            className="icon-button primary"
            onClick={() => void requestGeneratedTeams()}
            disabled={!canGenerateTeams}
          >
            {isGeneratingTeams ? "Generando equipos..." : "Genera equipos"}
          </button>
        </div>
      </section>

      {hasGeneratedTeams && (
        <section>
          <h2>Equipos</h2>
          <div className="tournament-card-grid">
            {teams.map((team) => (
              <article key={team.seed} className="tournament-card tournament-team-card">
                <div className="readonly-team-name">{team.name}</div>

                <div className="tournament-player-list">
                  {team.players.map((player, playerIndex) => {
                    const isHumanSeat = team.seed === 1 && playerIndex === 0;
                    const profileLabel = isHumanSeat
                      ? "Humano"
                      : PROFILE_LABELS[player.agentProfile || "balanced"] ?? player.agentProfile;

                    return (
                      <div key={player.playerNumber} className="readonly-player-row">
                        <span className="readonly-player-name">{player.displayName}</span>
                        <span className="readonly-player-profile">{profileLabel}</span>
                      </div>
                    );
                  })}
                </div>
              </article>
            ))}
          </div>
        </section>
      )}

      <button
        type="button"
        className="icon-button primary"
        onClick={() => createGameMutation.mutate()}
        disabled={!canSubmit || createGameMutation.isPending}
      >
        <span aria-hidden="true">🃏</span>
        {createGameMutation.isPending ? "Creando partida..." : "Crear partida"}
      </button>

      {lastError && <p className="error-text">{lastError}</p>}
    </main>
  );
}

function buildDefaultTeams(teamCount: number): CreateTournamentTeam[] {
  return Array.from({ length: teamCount }, (_, index) => {
    const seed = index + 1;

    return {
      name: seed === 1 ? "La Cuadrilla Humana" : "Los Rivales del Norte",
      seed,
      players: [
        {
          playerNumber: 1,
          displayName: seed === 1 ? "Jugador humano" : "Rival agente 1",
          type: seed === 1 ? "human" : "agent",
          agentProfile: seed === 1 ? undefined : randomAgentProfile(),
        },
        {
          playerNumber: 2,
          displayName: seed === 1 ? "Companero agente" : "Rival agente 2",
          type: "agent",
          agentProfile: randomAgentProfile(),
        },
      ],
    };
  });
}

function resizeTeams(
  currentTeams: CreateTournamentTeam[],
  nextCount: number
): CreateTournamentTeam[] {
  if (nextCount <= currentTeams.length) {
    return currentTeams.slice(0, nextCount);
  }

  const extraTeams = buildDefaultTeams(nextCount).slice(currentTeams.length);
  return [...currentTeams, ...extraTeams];
}

function normalizeHumanFirstTeam(
  teams: CreateTournamentTeam[],
  teamCount: number
): CreateTournamentTeam[] {
  const resized = resizeTeams(teams, teamCount).slice(0, teamCount);

  return resized.map((team, teamIndex) => ({
    ...team,
    name: team.name?.trim() || (teamIndex === 0 ? "La Cuadrilla Humana" : "Los Rivales del Norte"),
    seed: teamIndex + 1,
    players: [0, 1].map((playerIndex) => {
      const existing = team.players[playerIndex];
      const isHumanSeat = teamIndex === 0 && playerIndex === 0;

      return {
        playerNumber: playerIndex + 1,
        displayName:
          existing?.displayName ||
          (isHumanSeat
            ? "Jugador humano"
            : teamIndex === 0 && playerIndex === 1
              ? "Companero agente"
              : `Rival agente ${playerIndex + 1}`),
        type: isHumanSeat ? ("human" as const) : ("agent" as const),
        agentProfile: isHumanSeat
          ? undefined
          : existing?.agentProfile || randomAgentProfile(),
      };
    }),
  }));
}

function buildCreateGamePlayers(teams: CreateTournamentTeam[]): CreateGamePlayer[] {
  const teamA = teams[0] ?? buildDefaultTeams(GAME_TEAM_COUNT)[0];
  const teamB = teams[1] ?? buildDefaultTeams(GAME_TEAM_COUNT)[1];
  const teamAPlayer1 = teamA.players[0];
  const teamAPlayer2 = teamA.players[1];
  const teamBPlayer1 = teamB.players[0];
  const teamBPlayer2 = teamB.players[1];

  return [
    {
      id: "P1",
      name: teamAPlayer1.displayName,
      type: "human",
      team: "A",
    },
    {
      id: "P2",
      name: teamBPlayer1.displayName,
      type: "agent",
      team: "B",
      agentProfile: teamBPlayer1.agentProfile || "balanced",
    },
    {
      id: "P3",
      name: teamAPlayer2.displayName,
      type: "agent",
      team: "A",
      agentProfile: teamAPlayer2.agentProfile || "balanced",
    },
    {
      id: "P4",
      name: teamBPlayer2.displayName,
      type: "agent",
      team: "B",
      agentProfile: teamBPlayer2.agentProfile || "balanced",
    },
  ];
}

function buildCreateGamePayload(
  teams: CreateTournamentTeam[],
  players: CreateGamePlayer[]
): Parameters<typeof musApi.createGame>[0] {
  const teamAName = teams[0]?.name?.trim() || "Equipo A";
  const teamBName = teams[1]?.name?.trim() || "Equipo B";

  return {
    players,
    teamNames: {
      A: teamAName,
      B: teamBName,
      teamA: teamAName,
      teamB: teamBName,
    },
    teams: [
      { id: "A", name: teamAName },
      { id: "B", name: teamBName },
    ],
  } as Parameters<typeof musApi.createGame>[0];
}

function countHumanPlayers(teams: CreateTournamentTeam[]): number {
  return teams.reduce(
    (count, team) => count + team.players.filter((player) => player.type === "human").length,
    0
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
    throw new Error("Los IDs de jugador deben ser unicos.");
  }
}
