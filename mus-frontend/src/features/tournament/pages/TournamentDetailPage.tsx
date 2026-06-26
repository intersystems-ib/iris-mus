import { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useNavigate, useParams } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type { Tournament } from "../../../domain/tournament.types";

export function TournamentDetailPage() {
  const navigate = useNavigate();
  const { tournamentId } = useParams<{ tournamentId: string }>();
  const [startingTableId, setStartingTableId] = useState<string | number | null>(null);

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
      setStartingTableId(tableId);
      return musApi.startTournamentTable(tableId);
    },
    onSuccess: async (response) => {
      const createdGameId = extractGameId(response);

      if (createdGameId > 0) {
        navigate(`/games/${createdGameId}`);
        return;
      }

      await tournamentQuery.refetch();
    },
    onSettled: () => {
      setStartingTableId(null);
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
            : "Error iniciando partida"}
        </p>
      )}

      <section className="tournament-section-card">
        <div className="tournament-section-card-header">
          <h2>Equipos</h2>
        </div>

        <div className="tournament-card-grid">
          {tournament.teams?.map((team) => (
            <article key={String(team.id)} className="tournament-info-card">
              <div className="tournament-info-card-header">
                <div>
                  <h3><StatusIcon status={team.status} /> {team.name}</h3>                  
                </div>
              </div>

              <ul className="tournament-player-list">
                {team.players?.map((player) => (
                  <li key={String(player.id)} className="tournament-player-row">
                    <span
                      className="tournament-player-type-icon"
                      title={player.type === "human" ? "Jugador humano" : "Jugador agente"}
                      aria-label={player.type === "human" ? "Jugador humano" : "Jugador agente"}
                    >
                      {player.type === "human" ? "👤" : "🤖"}
                    </span>
                    <span className="tournament-player-name">{player.displayName}</span>                    
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section className="tournament-section-card">
        <div className="tournament-section-card-header">
          <h2>Fases</h2>
        </div>

        {tournament.rounds?.length ? (
          <div className="tournament-round-card-list">
            {getRoundsNewestFirst(tournament.rounds).map((round) => (
              <article key={String(round.id)} className="tournament-info-card tournament-round-card">
                <div className="tournament-info-card-header">
                  <div>
                    <h3>{round.name}</h3>
                    <StatusIcon status={round.status} />
                  </div>
                </div>

                {round.tables?.length ? (
                  <div className="tournament-table-list">
                    {round.tables.map((table) => {
                      const tableFinished = isTournamentTableFinished(table);
                      const winnerName = getTableWinnerName(table);
                      const tableIsStarting = String(startingTableId ?? "") === String(table.id);

                      return (
                        <div key={String(table.id)} className="tournament-table-row">
                          <div className="tournament-table-main">
                            <strong>Mesa {table.tableNumber}</strong>
                            <p>
                              {formatTeamName(table.teamA?.name, table.teamAId)} vs{" "}
                              {formatTeamName(table.teamB?.name, table.teamBId)}
                            </p>

                            {tableFinished ? (
                              <p className="tournament-winner-text">
                                Ganador: <strong>{winnerName}</strong>
                              </p>
                            ) : (
                              <StatusIcon status={table.status} compact />
                            )}
                          </div>

                          <div className="tournament-table-actions">
                            {tableFinished ? (
                              <span className="tournament-status-pill finished">
                                Finalizada
                              </span>
                            ) : Number(table.gameId) > 0 ? (
                              <button
                                type="button"
                                className="icon-button primary"
                                onClick={() => navigate(`/games/${table.gameId}`)}
                              >
                                Entrar a partida
                              </button>
                            ) : (
                              <button
                                type="button"
                                className="icon-button primary"
                                onClick={() => startTableMutation.mutate(table.id)}
                                disabled={startTableMutation.isPending}
                              >
                                {tableIsStarting ? "Iniciando..." : "Iniciar partida"}
                              </button>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <p>No hay mesas en esta fase.</p>
                )}
              </article>
            ))}
          </div>
        ) : (
          <p>Todavía no hay fases. Inicia el torneo para generarlas.</p>
        )}
      </section>
    </main>
  );
}

function StatusIcon({ status, compact = false }: { status: unknown; compact?: boolean }) {
  const normalizedStatus = String(status ?? "").toLowerCase();

  if (normalizedStatus === "eliminated") {
    return (
      <span className="tournament-status-icon eliminated" title="Eliminado" aria-label="Eliminado">
        ✖
      </span>
    );
  }

  if (normalizedStatus === "winner" || normalizedStatus === "finished") {
    return (
      <span className="tournament-status-icon winner" title="Ganador" aria-label="Ganador">
        🏆
      </span>
    );
  }

  if (normalizedStatus === "active" || normalizedStatus === "playing") {
    return (
      <span
        className={`tournament-status-icon active${compact ? " compact" : ""}`}
        title="Activo"
        aria-label="Activo"
      >
        ⚙️
      </span>
    );
  }

  return null;
}

function getRoundsNewestFirst(rounds: Tournament["rounds"] | undefined) {
  return [...(rounds ?? [])].sort((a, b) => {
    const roundDiff = getNumericValue(b.roundNumber) - getNumericValue(a.roundNumber);

    if (roundDiff !== 0) {
      return roundDiff;
    }

    return getNumericValue(b.id) - getNumericValue(a.id);
  });
}

function isTournamentTableFinished(table: TournamentRoundTable): boolean {
  return (
    String(table.status ?? "").toLowerCase() === "finished" ||
    getNumericValue(table.winnerTeamId) > 0
  );
}

function getTableWinnerName(table: TournamentRoundTable): string {
  const winnerTeamId = getNumericValue(table.winnerTeamId);

  if (winnerTeamId > 0) {
    if (winnerTeamId === getNumericValue(table.teamAId)) {
      return formatTeamName(table.teamA?.name, table.teamAId);
    }

    if (winnerTeamId === getNumericValue(table.teamBId)) {
      return formatTeamName(table.teamB?.name, table.teamBId);
    }
  }

  return "pendiente de sincronizar";
}

function getNumericValue(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

type TournamentRoundTable = NonNullable<
  NonNullable<Tournament["rounds"]>[number]["tables"]
>[number];

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

function extractGameId(response: unknown): number {
  if (!response || typeof response !== "object") {
    return 0;
  }

  const obj = response as Record<string, unknown>;
  const candidates = [
    obj.gameId,
    obj.id,
    (obj.game as Record<string, unknown> | undefined)?.id,
    (obj.game as Record<string, unknown> | undefined)?.gameId,
    (obj.table as Record<string, unknown> | undefined)?.gameId,
    (obj.payload as Record<string, unknown> | undefined)?.gameId,
  ];

  for (const candidate of candidates) {
    const value = getNumericValue(candidate);
    if (value > 0) {
      return value;
    }
  }

  return 0;
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
