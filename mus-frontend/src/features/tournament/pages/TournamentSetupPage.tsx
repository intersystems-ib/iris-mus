import { useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type {
  CreateTournamentPlayer,
  CreateTournamentRequest,
  CreateTournamentTeam,
} from "../../../domain/tournament.types";

const AGENT_PROFILES = ["balanced", "aggressive", "conservative"];

export function TournamentSetupPage() {
  const navigate = useNavigate();

  const [name, setName] = useState("Torneo de Mus");
  const [targetScore, setTargetScore] = useState(40);
  const [teamCount, setTeamCount] = useState(4);
  const [teams, setTeams] = useState<CreateTournamentTeam[]>(
    buildDefaultTeams(4)
  );
  const [lastError, setLastError] = useState("");

  const canSubmit = useMemo(() => {
    return teams.length >= 2 && teams.every((team) => team.players.length === 2);
  }, [teams]);

  const createTournamentMutation = useMutation({
    mutationFn: async () => {
      const request: CreateTournamentRequest = {
        name,
        format: "singleElimination",
        targetScore,
        teams,
      };

      validateTournament(request);

      const response = await musApi.createTournament(request);

      const tournamentId =
        response.tournamentId ??
        response.tournament?.id ??
        response.payload?.id ??
        "";

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
    setTeams((current) => resizeTeams(current, nextCount));
  }

  function updateTeam(index: number, patch: Partial<CreateTournamentTeam>) {
    setTeams((current) =>
      current.map((team, teamIndex) =>
        teamIndex === index ? { ...team, ...patch } : team
      )
    );
  }

  function updatePlayer(
    teamIndex: number,
    playerIndex: number,
    patch: Partial<CreateTournamentPlayer>
  ) {
    setTeams((current) =>
      current.map((team, currentTeamIndex) => {
        if (currentTeamIndex !== teamIndex) {
          return team;
        }

        return {
          ...team,
          players: team.players.map((player, currentPlayerIndex) =>
            currentPlayerIndex === playerIndex
              ? { ...player, ...patch }
              : player
          ),
        };
      })
    );
  }

  return (
    <main className="page">
      <h1>Nuevo torneo</h1>
      <p className="muted-text">
        Configura los equipos participantes. Cada equipo necesita exactamente
        dos jugadores.
      </p>

      <section className="tournament-form-panel">
        <label>
          Nombre del torneo
          <input
            value={name}
            onChange={(event) => setName(event.target.value)}
          />
        </label>

        <label>
          Puntuación objetivo
          <input
            type="number"
            min={1}
            value={targetScore}
            onChange={(event) => setTargetScore(Number(event.target.value))}
          />
        </label>

        <label>
          Número de equipos
          <select
            value={teamCount}
            onChange={(event) =>
              handleTeamCountChange(Number(event.target.value))
            }
          >
            <option value={2}>2 equipos</option>
            <option value={4}>4 equipos</option>
            <option value={8}>8 equipos</option>
            <option value={16}>16 equipos</option>
          </select>
        </label>
      </section>

      <section className="tournament-teams-grid">
        {teams.map((team, teamIndex) => (
          <article className="tournament-team-card" key={team.seed}>
            <header>
              <strong>Equipo {team.seed}</strong>
              <span>Seed {team.seed}</span>
            </header>

            <label>
              Nombre del equipo
              <input
                value={team.name}
                onChange={(event) =>
                  updateTeam(teamIndex, { name: event.target.value })
                }
              />
            </label>

            <div className="tournament-player-list">
              {team.players.map((player, playerIndex) => (
                <section
                  className="tournament-player-card"
                  key={`${team.seed}-${player.playerNumber}`}
                >
                  <h3>Jugador {player.playerNumber}</h3>

                  <label>
                    Nombre
                    <input
                      value={player.displayName}
                      onChange={(event) =>
                        updatePlayer(teamIndex, playerIndex, {
                          displayName: event.target.value,
                        })
                      }
                    />
                  </label>

                  <label>
                    Tipo
                    <select
                      value={player.type}
                      onChange={(event) =>
                        updatePlayer(teamIndex, playerIndex, {
                          type: event.target
                            .value as CreateTournamentPlayer["type"],
                          agentProfile:
                            event.target.value === "agent"
                              ? player.agentProfile ?? "balanced"
                              : undefined,
                        })
                      }
                    >
                      <option value="human">Humano</option>
                      <option value="agent">Agente</option>
                    </select>
                  </label>

                  {player.type === "agent" && (
                    <label>
                      Perfil agente
                      <select
                        value={player.agentProfile ?? "balanced"}
                        onChange={(event) =>
                          updatePlayer(teamIndex, playerIndex, {
                            agentProfile: event.target.value,
                          })
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
                </section>
              ))}
            </div>
          </article>
        ))}
      </section>

      <section className="panel">
        <button
          type="button"
          disabled={!canSubmit || createTournamentMutation.isPending}
          onClick={() => createTournamentMutation.mutate()}
        >
          {createTournamentMutation.isPending
            ? "Creando torneo..."
            : "Crear torneo"}
        </button>
      </section>

      {lastError && <p className="error-text">{lastError}</p>}
    </main>
  );
}

function buildDefaultTeams(teamCount: number): CreateTournamentTeam[] {
  return Array.from({ length: teamCount }, (_, index) => {
    const seed = index + 1;

    return {
      name: `Equipo ${seed}`,
      seed,
      players: [
        {
          playerNumber: 1,
          displayName: `Equipo ${seed} - Jugador 1`,
          type: seed === 1 ? "human" : "agent",
          agentProfile: seed === 1 ? undefined : "balanced",
        },
        {
          playerNumber: 2,
          displayName: `Equipo ${seed} - Jugador 2`,
          type: "agent",
          agentProfile: "balanced",
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

function validateTournament(request: CreateTournamentRequest) {
  if (!request.name.trim()) {
    throw new Error("El torneo necesita un nombre.");
  }

  if (request.targetScore <= 0) {
    throw new Error("La puntuación objetivo debe ser mayor que 0.");
  }

  if (!isPowerOfTwo(request.teams.length)) {
    throw new Error("El número de equipos debe ser potencia de 2.");
  }

  if (request.teams.length < 2) {
    throw new Error("El torneo necesita al menos 2 equipos.");
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