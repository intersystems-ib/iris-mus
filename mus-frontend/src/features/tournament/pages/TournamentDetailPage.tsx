import { useMutation, useQuery } from "@tanstack/react-query";
import { useNavigate, useParams } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type { Tournament } from "../../../domain/tournament.types";

export function TournamentDetailPage() {
  const navigate = useNavigate();
  const { tournamentId } = useParams<{ tournamentId: string }>();

  const tournamentQuery = useQuery({
    queryKey: ["tournament", tournamentId],
    queryFn: async () => {
      if (!tournamentId) {
        throw new Error("No tournamentId provided");
      }

      /*
        El backend sincroniza automaticamente las mesas cuyas partidas ya han
        terminado cuando se carga el torneo. Mantener la carga centralizada aqui
        hace que entrar/refrescar esta pantalla genere la siguiente ronda si
        todas las mesas de la ronda actual estan cerradas.
      */
      return musApi.getTournament(tournamentId);
    },
    enabled: Boolean(tournamentId),

    /*
      Sin polling: la pantalla se actualiza al entrar, al volver a montarse
      desde una partida y cuando el usuario pulsa Refrescar. Evitamos que el
      GET /tournaments/:id dispare sincronizaciones de estado cada 5 segundos.
    */
    refetchOnMount: "always",
    refetchOnWindowFocus: true,
  });

  const startTableMutation = useMutation({
    mutationFn: async (tableId: string | number) => {
      return musApi.startTournamentTable(tableId);
    },
    onSuccess: () => {
      void tournamentQuery.refetch();
    },
  });

  const tournament = extractTournament(tournamentQuery.data);

  if (!tournamentId) {
    return (
      <main className="page tournament-detail-page">
        <h1>Torneo</h1>
        <p>No se ha indicado Tournament ID.</p>
        <button
          type="button"
          className="icon-button"
          onClick={() => navigate("/tournaments")}
        >
          Volver
        </button>
      </main>
    );
  }

  if (tournamentQuery.isLoading) {
    return (
      <main className="page tournament-detail-page">
        <h1>Torneo</h1>
        <p>Cargando torneo {tournamentId}...</p>
      </main>
    );
  }

  if (tournamentQuery.isError) {
    return (
      <main className="page tournament-detail-page">
        <h1>Torneo</h1>
        <p className="error-text">
          {tournamentQuery.error instanceof Error
            ? tournamentQuery.error.message
            : "Error cargando torneo"}
        </p>
        <button
          type="button"
          className="icon-button"
          onClick={() => navigate("/tournaments")}
        >
          Volver a torneos
        </button>
      </main>
    );
  }

  if (!tournament) {
    return (
      <main className="page tournament-detail-page">
        <h1>Torneo</h1>
        <p>No se pudo extraer el torneo de la respuesta.</p>
        <pre>{JSON.stringify(tournamentQuery.data, null, 2)}</pre>
        <button
          type="button"
          className="icon-button"
          onClick={() => navigate("/tournaments")}
        >
          Volver a torneos
        </button>
      </main>
    );
  }

  return (
    <main className="page tournament-detail-page">
      <header className="tournament-detail-header">
        <div>
          <p className="eyebrow">Torneo</p>
          <h1>{tournament.name}</h1>
          <p className="muted-text">
            Estado: {tournament.status} · Objetivo: {tournament.targetScore}
          </p>
        </div>

        <div className="tournament-detail-actions">
          <button
            type="button"
            className="icon-button ghost"
            onClick={() => void tournamentQuery.refetch()}
            disabled={tournamentQuery.isFetching}
          >
            {tournamentQuery.isFetching ? "Actualizando..." : "Refrescar"}
          </button>

          <button
            type="button"
            className="icon-button"
            onClick={() => navigate("/tournaments")}
          >
            Volver a torneos
          </button>
        </div>
      </header>

      {startTableMutation.isError && (
        <p className="error-text">
          {startTableMutation.error instanceof Error
            ? startTableMutation.error.message
            : "Error creando partida de mesa"}
        </p>
      )}

      <section>
        <h2>Equipos</h2>
        <div className="tournament-card-grid">
          {tournament.teams?.map((team) => (
            <article key={String(team.id)} className="tournament-card">
              <div className="tournament-card-header">
                <div>
                  <h3>{team.name}</h3>
                  <p>{team.status}</p>
                </div>
              </div>

              <ul>
                {team.players?.map((player) => (
                  <li key={String(player.id)}>
                    {player.displayName} · {player.type}
                    {player.agentProfile ? ` · ${player.agentProfile}` : ""}
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section>
        <h2>Rondas y mesas</h2>
        {tournament.rounds?.length ? (
          tournament.rounds.map((round) => (
            <article key={String(round.id)} className="tournament-card">
              <div className="tournament-card-header">
                <div>
                  <h3>{round.name}</h3>
                  <p>{round.status}</p>
                </div>
              </div>

              {round.tables?.length ? (
                <div className="tournament-table-list">
                  {round.tables.map((table) => (
                    <div key={String(table.id)} className="tournament-table-row">
                      <div>
                        <strong>Mesa {table.tableNumber}</strong>
                        <p>
                          {formatTeamName(table.teamA?.name, table.teamAId)} vs{" "}
                          {formatTeamName(table.teamB?.name, table.teamBId)}
                        </p>
                        <p className="muted-text">{table.status}</p>
                      </div>

                      <div className="tournament-table-actions">
                        {Number(table.gameId) > 0 ? (
                          <button
                            type="button"
                            className="icon-button primary"
                            onClick={() => navigate(`/games/${table.gameId}`)}
                          >
                            Abrir partida
                          </button>
                        ) : (
                          <button
                            type="button"
                            className="icon-button primary"
                            onClick={() => startTableMutation.mutate(table.id)}
                            disabled={startTableMutation.isPending}
                          >
                            {startTableMutation.isPending
                              ? "Creando..."
                              : "Crear partida"}
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p>No hay mesas en esta ronda.</p>
              )}
            </article>
          ))
        ) : (
          <p>Todavía no hay rondas. Inicia el torneo para generarlas.</p>
        )}
      </section>
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
