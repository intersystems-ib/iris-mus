import { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useNavigate, useParams } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import { useTranslation } from "react-i18next";
import type { Tournament } from "../../../domain/tournament.types";

export function TournamentDetailPage() {
  const { t } = useTranslation();
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
        <h1>{t("tournamentDetail.title")}</h1>
        <p>{t("tournamentDetail.missingId")}</p>
        <button
          type="button"
          className="icon-button"
          onClick={() => navigate("/tournaments")}
        >
          {t("tournamentDetail.back")}
        </button>
      </main>
    );
  }

  if (tournamentQuery.isLoading) {
    return (
      <main className="page tournament-detail-page">
        <h1>{t("tournamentDetail.title")}</h1>
        <p>{t("tournamentDetail.loading", { id: tournamentId })}</p>
      </main>
    );
  }

  if (tournamentQuery.isError) {
    return (
      <main className="page tournament-detail-page">
        <h1>{t("tournamentDetail.title")}</h1>
        <p className="error-text">
          {tournamentQuery.error instanceof Error
            ? tournamentQuery.error.message
            : t("tournamentDetail.loadError")}
        </p>
        <button
          type="button"
          className="icon-button"
          onClick={() => navigate("/tournaments")}
        >
          {t("tournamentDetail.backToTournaments")}
        </button>
      </main>
    );
  }

  if (!tournament) {
    return (
      <main className="page tournament-detail-page">
        <h1>{t("tournamentDetail.title")}</h1>
        <p>{t("tournamentDetail.extractError")}</p>
        <pre>{JSON.stringify(tournamentQuery.data, null, 2)}</pre>
        <button
          type="button"
          className="icon-button"
          onClick={() => navigate("/tournaments")}
        >
          {t("tournamentDetail.backToTournaments")}
        </button>
      </main>
    );
  }

  return (
    <main className="page tournament-detail-page">
      <header className="tournament-detail-header">
        <div>
          <p className="eyebrow">{t("tournamentDetail.title")}</p>
          <h1>{tournament.name}</h1>
          <p className="muted-text">
            {t("tournamentDetail.statusTarget", { status: tournament.status, target: tournament.targetScore })}
          </p>
        </div>

        <div className="tournament-detail-actions">
          <button
            type="button"
            className="icon-button ghost"
            onClick={() => void tournamentQuery.refetch()}
            disabled={tournamentQuery.isFetching}
          >
            {tournamentQuery.isFetching ? t("tournamentDetail.refreshing") : t("tournamentDetail.refresh")}
          </button>

          <button
            type="button"
            className="icon-button"
            onClick={() => navigate("/tournaments")}
          >
            {t("tournamentDetail.backToTournaments")}
          </button>
        </div>
      </header>

      {startTableMutation.isError && (
        <p className="error-text">
          {startTableMutation.error instanceof Error
            ? startTableMutation.error.message
            : t("tournamentDetail.startGameError")}
        </p>
      )}

      <section className="tournament-section-card">
        <div className="tournament-section-card-header">
          <h2>{t("tournamentDetail.teams")}</h2>
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
                      title={player.type === "human" ? t("tournamentDetail.humanPlayer") : t("tournamentDetail.agentPlayer")}
                      aria-label={player.type === "human" ? t("tournamentDetail.humanPlayer") : t("tournamentDetail.agentPlayer")}
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
          <h2>{t("tournamentDetail.rounds")}</h2>
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
                      const winnerName = getTableWinnerName(table, t);
                      const tableIsStarting = String(startingTableId ?? "") === String(table.id);

                      return (
                        <div key={String(table.id)} className="tournament-table-row">
                          <div className="tournament-table-main">
                            <strong>{t("tournamentDetail.table", { number: table.tableNumber })}</strong>
                            <p>
                              {formatTeamName(table.teamA?.name, table.teamAId, t)} vs{" "}
                              {formatTeamName(table.teamB?.name, table.teamBId, t)}
                            </p>

                            {tableFinished ? (
                              <p className="tournament-winner-text">
                                {t("tournamentDetail.winner", { name: winnerName })}
                              </p>
                            ) : (
                              <StatusIcon status={table.status} compact />
                            )}
                          </div>

                          <div className="tournament-table-actions">
                            {tableFinished ? (
                              <span className="tournament-status-pill finished">
                                {t("tournamentDetail.finished")}
                              </span>
                            ) : Number(table.gameId) > 0 ? (
                              <button
                                type="button"
                                className="icon-button primary"
                                onClick={() => navigate(`/games/${table.gameId}`)}
                              >
                                {t("tournamentDetail.enterGame")}
                              </button>
                            ) : (
                              <button
                                type="button"
                                className="icon-button primary"
                                onClick={() => startTableMutation.mutate(table.id)}
                                disabled={startTableMutation.isPending}
                              >
                                {tableIsStarting ? t("tournamentDetail.starting") : t("tournamentDetail.startGame")}
                              </button>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <p>{t("tournamentDetail.noTables")}</p>
                )}
              </article>
            ))}
          </div>
        ) : (
          <p>{t("tournamentDetail.noRounds")}</p>
        )}
      </section>
    </main>
  );
}

function StatusIcon({ status, compact = false }: { status: unknown; compact?: boolean }) {
  const { t } = useTranslation();
  const normalizedStatus = String(status ?? "").toLowerCase();

  if (normalizedStatus === "eliminated") {
    return (
      <span className="tournament-status-icon eliminated" title={t("tournamentDetail.statuses.eliminated")} aria-label={t("tournamentDetail.statuses.eliminated")}>
        ✖
      </span>
    );
  }

  if (normalizedStatus === "winner" || normalizedStatus === "finished") {
    return (
      <span className="tournament-status-icon winner" title={t("tournamentDetail.statuses.winner")} aria-label={t("tournamentDetail.statuses.winner")}>
        🏆
      </span>
    );
  }

  if (normalizedStatus === "active" || normalizedStatus === "playing") {
    return (
      <span
        className={`tournament-status-icon active${compact ? " compact" : ""}`}
        title={t("tournamentDetail.statuses.active")}
        aria-label={t("tournamentDetail.statuses.active")}
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

function getTableWinnerName(
  table: TournamentRoundTable,
  t: (key: string, options?: Record<string, unknown>) => string
): string {
  const winnerTeamId = getNumericValue(table.winnerTeamId);

  if (winnerTeamId > 0) {
    if (winnerTeamId === getNumericValue(table.teamAId)) {
      return formatTeamName(table.teamA?.name, table.teamAId, t);
    }

    if (winnerTeamId === getNumericValue(table.teamBId)) {
      return formatTeamName(table.teamB?.name, table.teamBId, t);
    }
  }

  return t("tournamentDetail.syncPending");
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
  teamId: string | number | undefined,
  t: (key: string, options?: Record<string, unknown>) => string
): string {
  if (teamName) {
    return teamName;
  }

  if (teamId !== undefined && teamId !== null && String(teamId) !== "") {
    return t("tournamentDetail.teamFallback", { id: teamId });
  }

  return "-";
}