import { useMutation, useQuery } from "@tanstack/react-query";
import { Link, useParams } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type { Tournament } from "../../../domain/tournament.types";

export function TournamentDetailPage() {
  const { tournamentId } = useParams<{ tournamentId: string }>();

  const tournamentQuery = useQuery({
    queryKey: ["tournament", tournamentId],
    queryFn: async () => {
      if (!tournamentId) {
        throw new Error("No tournamentId provided");
      }

      return musApi.getTournament(tournamentId);
    },
    enabled: Boolean(tournamentId),
    refetchInterval: 5000,
  });

  const startTournamentMutation = useMutation({
    mutationFn: async () => {
      if (!tournamentId) {
        throw new Error("No tournamentId provided");
      }

      return musApi.startTournament(tournamentId);
    },
    onSuccess: () => {
      void tournamentQuery.refetch();
    },
  });

  const tournament = extractTournament(tournamentQuery.data);

  if (!tournamentId) {
    return (
      <main className="page">
        <h1>Torneo</h1>
        <p>No se ha indicado Tournament ID.</p>
        <Link to="/tournaments">Volver</Link>
      </main>
    );
  }

  if (tournamentQuery.isLoading) {
    return (
      <main className="page">
        <h1>Torneo</h1>
        <p>Cargando torneo {tournamentId}...</p>
      </main>
    );
  }

  if (tournamentQuery.isError) {
    return (
      <main className="page">
        <h1>Torneo</h1>
        <p className="error-text">
          {tournamentQuery.error instanceof Error
            ? tournamentQuery.error.message
            : "Error cargando torneo"}
        </p>
      </main>
    );
  }

  if (!tournament) {
    return (
      <main className="page">
        <h1>Torneo</h1>
        <p>No se pudo extraer el torneo de la respuesta.</p>
        <pre className="json-output">
          {JSON.stringify(tournamentQuery.data, null, 2)}
        </pre>
      </main>
    );
  }

  const canStart =
    tournament.status === "created" || tournament.status === "CREATED";

  return (
    <main className="page">
      <header className="tournament-detail-header">
        <div>
          <h1>{tournament.name}</h1>
          <p className="muted-text">
            Estado: <strong>{tournament.status}</strong> · Objetivo:{" "}
            <strong>{tournament.targetScore}</strong>
          </p>
        </div>

        <div className="tournament-header-actions">
          {canStart && (
            <button
              type="button"
              onClick={() => startTournamentMutation.mutate()}
              disabled={startTournamentMutation.isPending}
            >
              {startTournamentMutation.isPending
                ? "Iniciando..."
                : "Iniciar torneo"}
            </button>
          )}

          <button
            type="button"
            onClick={() => {
              void tournamentQuery.refetch();
            }}
            disabled={tournamentQuery.isFetching}
          >
            Refrescar
          </button>

          <Link to="/tournaments">Volver a torneos</Link>
        </div>
      </header>

      {startTournamentMutation.isError && (
        <p className="error-text">
          {startTournamentMutation.error instanceof Error
            ? startTournamentMutation.error.message
            : "Error iniciando torneo"}
        </p>
      )}

      <section className="tournament-detail-grid">
        <article className="tournament-detail-panel">
          <h2>Equipos</h2>

          <div className="tournament-team-list">
            {tournament.teams?.map((team) => (
              <section className="tournament-team-row" key={team.id}>
                <header>
                  <strong>{team.name}</strong>
                  <span>{team.status}</span>
                </header>

                <ul>
                  {team.players?.map((player) => (
                    <li key={player.id}>
                      {player.displayName} · {player.type}
                      {player.agentProfile
                        ? ` · ${player.agentProfile}`
                        : ""}
                    </li>
                  ))}
                </ul>
              </section>
            ))}
          </div>
        </article>

        <article className="tournament-detail-panel">
          <h2>Rondas y mesas</h2>

          {tournament.rounds?.length ? (
            tournament.rounds.map((round) => (
              <section className="tournament-round-card" key={round.id}>
                <header>
                  <strong>{round.name}</strong>
                  <span>{round.status}</span>
                </header>

                {round.tables?.length ? (
                  round.tables.map((table) => (
                    <div className="tournament-table-row" key={table.id}>
                      <div>
                        <span>Mesa {table.tableNumber}</span>
                        <small>
                          {formatTeamName(table.teamA?.name, table.teamAId)} vs{" "}
                          {formatTeamName(table.teamB?.name, table.teamBId)}
                        </small>
                      </div>

                      <strong>{table.status}</strong>

                      {table.gameId ? (
                        <Link to={`/games/${table.gameId}`}>Abrir partida</Link>
                      ) : (
                        <span className="muted-text">Sin partida</span>
                      )}
                    </div>
                  ))
                ) : (
                  <p className="muted-text">No hay mesas en esta ronda.</p>
                )}
              </section>
            ))
          ) : (
            <p className="muted-text">
              Todavía no hay rondas. Inicia el torneo para generarlas.
            </p>
          )}
        </article>
      </section>

      <pre className="json-output">
        {JSON.stringify(tournamentQuery.data, null, 2)}
      </pre>
    </main>
  );
}

function extractTournament(response: unknown): Tournament | null {
  if (!response || typeof response !== "object") {
    return null;
  }

  const obj = response as Record<string, unknown>;

  const candidates = [obj, obj.tournament, obj.payload, obj.state];

  for (const candidate of candidates) {
    if (isTournamentLike(candidate)) {
      return candidate as Tournament;
    }
  }

  return null;
}

function isTournamentLike(value: unknown): boolean {
  if (!value || typeof value !== "object") {
    return false;
  }

  const obj = value as Record<string, unknown>;

  return typeof obj.id !== "undefined" && typeof obj.name === "string";
}

function formatTeamName(
  teamName: string | undefined,
  teamId: string | number | undefined
): string {
  if (teamName) {
    return teamName;
  }

  if (teamId !== undefined && teamId !== null && String(teamId) !== "") {
    return `Equipo ${teamId}`;
  }

  return "-";
}