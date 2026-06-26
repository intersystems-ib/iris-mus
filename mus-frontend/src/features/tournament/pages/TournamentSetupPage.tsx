import { useCallback, useMemo, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type {
  CreateTournamentRequest,
  CreateTournamentTeam,
} from "../../../domain/tournament.types";

const TARGET_SCORE = 40;
const AGENT_PROFILES = ["balanced", "aggressive", "conservative", "bluffer"] as const;
const PROFILE_LABELS: Record<string, string> = {
  balanced: "Equilibrado",
  aggressive: "Agresivo",
  conservative: "Conservador",
  bluffer: "Farolero",
};

function randomAgentProfile(): string {
  return AGENT_PROFILES[Math.floor(Math.random() * AGENT_PROFILES.length)];
}

export function TournamentSetupPage() {
  const navigate = useNavigate();
  const [name, setName] = useState("Torneo de Mus");
  const [teamCount, setTeamCount] = useState(4);
  const [teams, setTeams] = useState<CreateTournamentTeam[]>([]);
  const [lastError, setLastError] = useState("");
  const [isGeneratingTeams, setIsGeneratingTeams] = useState(false);
  const generationInFlightRef = useRef(false);

  const hasGeneratedTeams = teams.length === teamCount;
  const canGenerateTeams = name.trim().length > 0 && teamCount >= 2 && !isGeneratingTeams;

  const canSubmit = useMemo(() => {
    return (
      name.trim().length > 0 &&
      hasGeneratedTeams &&
      teams.every((team) => team.name.trim() && team.players.length === 2) &&
      countHumanPlayers(teams) === 1 &&
      teams[0]?.players[0]?.type === "human"
    );
  }, [hasGeneratedTeams, name, teams]);

  const requestGeneratedTeams = useCallback(async () => {
    if (!canGenerateTeams || generationInFlightRef.current) {
      return;
    }

    generationInFlightRef.current = true;
    setIsGeneratingTeams(true);

    try {
      const response = await musApi.generateTournamentTeams({
        teamCount,
        targetScore: TARGET_SCORE,
        humanPlayerName: "Jugador humano",
      });

      const generated = response.teams?.length
        ? response.teams
        : buildDefaultTeams(teamCount);

      setName(response.tournamentName || name || "Torneo de Mus");
      setTeams(normalizeHumanFirstTeam(generated, teamCount));
      setLastError("");
    } catch (error) {
      setTeams(normalizeHumanFirstTeam(buildDefaultTeams(teamCount), teamCount));
      setLastError(error instanceof Error ? error.message : String(error));
    } finally {
      generationInFlightRef.current = false;
      setIsGeneratingTeams(false);
    }
  }, [canGenerateTeams, name, teamCount]);

  const createTournamentMutation = useMutation({
    mutationFn: async () => {
      const request: CreateTournamentRequest = {
        name,
        format: "singleElimination",
        targetScore: TARGET_SCORE,
        teams: normalizeHumanFirstTeam(teams, teamCount),
      };

      validateTournament(request);
      const response = await musApi.createTournament(request);

      const tournamentId =
        response.tournamentId ?? response.tournament?.id ?? response.payload?.id ?? "";

      if (!tournamentId) {
        throw new Error("El backend no devolvió tournamentId.");
      }

      return String(tournamentId);
    },
    onSuccess: (tournamentId) => {
      setLastError("");
      navigate(`/tournaments/${tournamentId}`);
    },
    onError: (error) => {
      setLastError(error instanceof Error ? error.message : String(error));
    },
  });

  function handleTeamCountChange(nextCount: number) {
    setTeamCount(nextCount);
    setTeams([]);
    setLastError("");
  }

  return (
    <main className="page tournament-setup-page">
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
        aria-label="Volver a torneos"
      >
        <span aria-hidden="true">←</span>
        Volver
      </button>

      <p className="eyebrow">Torneo</p>
      <h1>Nuevo torneo</h1>

      <section className="tournament-form-card tournament-setup-start-card">
        <div className="tournament-setup-fields-row">
          <label>
            Nombre del torneo: 
            <input
              size= "32"
              value={name}
              onChange={(event) => {
                setName(event.target.value);
                setTeams([]);
              }}
            />
          </label>

          <label>
            Número de equipos: 
            <select
              className="form-select"
              value={teamCount}
              onChange={(event) => handleTeamCountChange(Number(event.target.value))}
            >
              <option value={2}>2 equipos</option>
              <option value={4}>4 equipos</option>
              <option value={8}>8 equipos</option>
              <option value={16}>16 equipos</option>
            </select>
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
        onClick={() => createTournamentMutation.mutate()}
        disabled={!canSubmit || createTournamentMutation.isPending}
      >
        {createTournamentMutation.isPending ? "Creando torneo..." : "Crear torneo"}
      </button>

      {lastError && <p className="error-text">{lastError}</p>}
    </main>
  );
}

function buildDefaultTeams(teamCount: number): CreateTournamentTeam[] {
  return Array.from({ length: teamCount }, (_, index) => {
    const seed = index + 1;

    return {
      name: seed === 1 ? "La Cuadrilla Humana" : `Pareja ${seed}`,
      seed,
      players: [
        {
          playerNumber: 1,
          displayName: seed === 1 ? "Jugador humano" : `Jugador ${seed}.1`,
          type: seed === 1 ? "human" : "agent",
          agentProfile: seed === 1 ? undefined : randomAgentProfile(),
        },
        {
          playerNumber: 2,
          displayName: seed === 1 ? "Compañero" : `Jugador ${seed}.2`,
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
    name: team.name?.trim() || `Pareja ${teamIndex + 1}`,
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
              ? "Compañero"
              : `Jugador ${teamIndex + 1}.${playerIndex + 1}`),
        type: isHumanSeat ? ("human" as const) : ("agent" as const),
        agentProfile: isHumanSeat
          ? undefined
          : existing?.agentProfile || randomAgentProfile(),
      };
    }),
  }));
}

function countHumanPlayers(teams: CreateTournamentTeam[]): number {
  return teams.reduce(
    (count, team) => count + team.players.filter((player) => player.type === "human").length,
    0
  );
}

function validateTournament(request: CreateTournamentRequest) {
  if (!request.name.trim()) {
    throw new Error("El torneo necesita un nombre.");
  }

  if (request.targetScore !== TARGET_SCORE) {
    throw new Error(`El Mus se juega siempre a ${TARGET_SCORE} puntos.`);
  }

  if (!isPowerOfTwo(request.teams.length)) {
    throw new Error("El número de equipos debe ser potencia de 2.");
  }

  if (request.teams.length < 2) {
    throw new Error("El torneo necesita al menos 2 equipos.");
  }

  if (request.teams[0]?.players[0]?.type !== "human") {
    throw new Error("El jugador humano debe estar en el primer equipo.");
  }

  const humanCount = countHumanPlayers(request.teams);
  if (humanCount !== 1) {
    throw new Error("El torneo debe tener exactamente un jugador humano.");
  }

  const teamNames = new Set<string>();

  for (const team of request.teams) {
    if (!team.name.trim()) {
      throw new Error(`El equipo ${team.seed} no tiene nombre.`);
    }

    if (teamNames.has(team.name.trim().toLowerCase())) {
      throw new Error(`El nombre de equipo "${team.name}" está duplicado.`);
    }

    teamNames.add(team.name.trim().toLowerCase());

    if (team.players.length !== 2) {
      throw new Error(`El equipo ${team.name} debe tener 2 jugadores.`);
    }

    for (const player of team.players) {
      if (!player.displayName.trim()) {
        throw new Error(`Un jugador del equipo ${team.name} no tiene nombre.`);
      }
    }
  }
}

function isPowerOfTwo(value: number): boolean {
  return value > 0 && (value & (value - 1)) === 0;
}
