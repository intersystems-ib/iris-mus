import { useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type {
  CreateTournamentPlayer,
  CreateTournamentRequest,
  CreateTournamentTeam,
} from "../../../domain/tournament.types";

const AGENT_PROFILES = ["balanced", "aggressive", "conservative"];
const HUMAN_MARKER = "human";

type HumanSlot = {
  teamIndex: number;
  playerIndex: number;
};

export function TournamentSetupPage() {
  const navigate = useNavigate();
  const [name, setName] = useState("Torneo de Mus");
  const [targetScore, setTargetScore] = useState(40);
  const [teamCount, setTeamCount] = useState(4);
  const [teams, setTeams] = useState<CreateTournamentTeam[]>(
    buildDefaultTeams(4)
  );
  const [lastError, setLastError] = useState("");

  const humanSlot = useMemo(() => getHumanSlot(teams), [teams]);

  const canSubmit = useMemo(() => {
    return (
      teams.length >= 2 &&
      teams.every((team) => team.players.length === 2) &&
      countHumanPlayers(teams) === 1
    );
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
    setTeams((current) => ensureExactlyOneHuman(resizeTeams(current, nextCount)));
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
      ensureExactlyOneHuman(
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
      )
    );
  }

  function setHumanPlayer(teamIndex: number, playerIndex: number) {
    setTeams((current) =>
      current.map((team, currentTeamIndex) => ({
        ...team,
        players: team.players.map((player, currentPlayerIndex) => {
          const isSelected =
            currentTeamIndex === teamIndex && currentPlayerIndex === playerIndex;

          return {
            ...player,
            type: isSelected ? "human" : "agent",
            agentProfile: isSelected ? undefined : player.agentProfile ?? "balanced",
          };
        }),
      }))
    );
  }

  return (
    <main className="page tournament-setup-page">
      <div className="page-heading-row">
        <div>
          <p className="eyebrow">Torneo</p>
          <h1>Nuevo torneo</h1>
          <p className="muted-text">
            De momento solo se permite un jugador humano por torneo. El resto de
            jugadores serán agentes.
          </p>
        </div>

        <Link className="icon-button ghost" to="/tournaments">
          <span aria-hidden="true">←</span>
          Volver
        </Link>
      </div>

      <section className="setup-card">
        <label>
          <span>Nombre del torneo</span>
          <input value={name} onChange={(event) => setName(event.target.value)} />
        </label>

        <label>
          <span>Puntuación objetivo</span>
          <input
            type="number"
            min={1}
            value={targetScore}
            onChange={(event) => setTargetScore(Number(event.target.value))}
          />
        </label>

        <label>
          <span>Número de equipos</span>
          <select
            value={teamCount}
            onChange={(event) => handleTeamCountChange(Number(event.target.value))}
          >
            <option value={2}>2 equipos</option>
            <option value={4}>4 equipos</option>
            <option value={8}>8 equipos</option>
            <option value={16}>16 equipos</option>
          </select>
        </label>

        <div className="human-only-summary">
          <span aria-hidden="true">👤</span>
          <div>
            <strong>Jugador humano único</strong>
            <p>
              {humanSlot
                ? `Equipo ${humanSlot.teamIndex + 1}, jugador ${humanSlot.playerIndex + 1}`
                : "Selecciona un jugador humano."}
            </p>
          </div>
        </div>
      </section>

      <section className="tournament-team-grid">
        {teams.map((team, teamIndex) => (
          <article key={team.seed} className="setup-card tournament-team-card">
            <header className="team-card-heading">
              <h2>Equipo {team.seed}</h2>
              <span className="tournament-status-pill">Seed {team.seed}</span>
            </header>

            <label>
              <span>Nombre del equipo</span>
              <input
                value={team.name}
                onChange={(event) => updateTeam(teamIndex, { name: event.target.value })}
              />
            </label>

            {team.players.map((player, playerIndex) => {
              const isHuman = player.type === HUMAN_MARKER;

              return (
                <div key={player.playerNumber} className="player-config-card">
                  <div className="player-config-header">
                    <h3>Jugador {player.playerNumber}</h3>
                    <button
                      type="button"
                      className={isHuman ? "icon-button primary" : "icon-button ghost"}
                      onClick={() => setHumanPlayer(teamIndex, playerIndex)}
                    >
                      <span aria-hidden="true">{isHuman ? "👤" : "🤖"}</span>
                      {isHuman ? "Humano" : "Marcar humano"}
                    </button>
                  </div>

                  <label>
                    <span>Nombre</span>
                    <input
                      value={player.displayName}
                      onChange={(event) =>
                        updatePlayer(teamIndex, playerIndex, {
                          displayName: event.target.value,
                        })
                      }
                    />
                  </label>

                  {!isHuman && (
                    <label>
                      <span>Perfil agente</span>
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
                </div>
              );
            })}
          </article>
        ))}
      </section>

      <div className="setup-actions-bar">
        <button
          type="button"
          className="icon-button primary"
          onClick={() => createTournamentMutation.mutate()}
          disabled={!canSubmit || createTournamentMutation.isPending}
        >
          <span aria-hidden="true">🏆</span>
          {createTournamentMutation.isPending ? "Creando torneo..." : "Crear torneo"}
        </button>

        <Link className="icon-button" to="/new-game">
          <span aria-hidden="true">🃏</span>
          Nueva partida rápida
        </Link>
      </div>

      {lastError && <p className="error-text">{lastError}</p>}
    </main>
  );
}

function buildDefaultTeams(teamCount: number): CreateTournamentTeam[] {
  return Array.from({ length: teamCount }, (_, index) => {
    const seed = index + 1;

    return {
      name: seed === 1 ? "Tu equipo" : `Pareja agente ${seed}`,
      seed,
      players: [
        {
          playerNumber: 1,
          displayName: seed === 1 ? "Jugador humano" : `Agente ${seed}.1`,
          type: seed === 1 ? "human" : "agent",
          agentProfile: seed === 1 ? undefined : "balanced",
        },
        {
          playerNumber: 2,
          displayName: seed === 1 ? "Compañero agente" : `Agente ${seed}.2`,
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

function ensureExactlyOneHuman(teams: CreateTournamentTeam[]): CreateTournamentTeam[] {
  let humanFound = false;

  const normalized = teams.map((team, teamIndex) => ({
    ...team,
    players: team.players.map((player, playerIndex) => {
      const shouldBeHuman = player.type === "human" && !humanFound;

      if (shouldBeHuman) {
        humanFound = true;
        return { ...player, type: "human" as const, agentProfile: undefined };
      }

      return {
        ...player,
        type: "agent" as const,
        agentProfile: player.agentProfile ?? "balanced",
      };
    }),
  }));

  if (humanFound) {
    return normalized;
  }

  return normalized.map((team, teamIndex) => {
    if (teamIndex !== 0) {
      return team;
    }

    return {
      ...team,
      players: team.players.map((player, playerIndex) =>
        playerIndex === 0
          ? { ...player, type: "human", agentProfile: undefined }
          : { ...player, type: "agent", agentProfile: player.agentProfile ?? "balanced" }
      ),
    };
  });
}

function getHumanSlot(teams: CreateTournamentTeam[]): HumanSlot | null {
  for (let teamIndex = 0; teamIndex < teams.length; teamIndex += 1) {
    const playerIndex = teams[teamIndex].players.findIndex(
      (player) => player.type === "human"
    );

    if (playerIndex >= 0) {
      return { teamIndex, playerIndex };
    }
  }

  return null;
}

function countHumanPlayers(teams: CreateTournamentTeam[]): number {
  return teams.reduce(
    (count, team) =>
      count + team.players.filter((player) => player.type === "human").length,
    0
  );
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
