import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import type { Tournament } from "../../../domain/tournament.types";

const ACTIVE_TOURNAMENT_STATUSES = new Set(["created", "playing", "active"]);

export function TournamentsHomePage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const tournamentsQuery = useQuery({
    queryKey: ["tournaments"],
    queryFn: async () => musApi.listTournaments(),
  });

  const deleteTournamentMutation = useMutation({
    mutationFn: (tournamentId: string) => musApi.deleteTournament(tournamentId),
    onSuccess: () => {
      setDeleteError(null);
      void queryClient.invalidateQueries({ queryKey: ["tournaments"] });
    },
    onError: (error) => {
      setDeleteError(
        error instanceof Error ? error.message : "No se pudo eliminar el torneo"
      );
    },
  });

  const tournaments = useMemo(
    () => normalizeTournaments(tournamentsQuery.data),
    [tournamentsQuery.data]
  );

  const activeTournaments = tournaments.filter((tournament) =>
    ACTIVE_TOURNAMENT_STATUSES.has(String(tournament.status ?? "").toLowerCase())
  );

  function handleDeleteTournament(tournament: Tournament) {
    const confirmed = window.confirm(
      `¿Eliminar el torneo "${tournament.name}"? Esta acción no se puede deshacer.`
    );

    if (!confirmed) {
      return;
    }

    deleteTournamentMutation.mutate(String(tournament.id));
  }

  return (
    <main className="page tournament-home-page">
      <header className="tournament-home-hero">
        <div>
          <p className="eyebrow">Mus</p>
          <h1>Torneos activos</h1>
          <p className="muted-text">
            Abre un torneo en curso, crea uno nuevo o inicia una partida rápida.
          </p>
        </div>

        <div className="tournament-home-actions">
          <Link className="icon-button primary" to="/new-tournament">
            <span aria-hidden="true">➕</span>
            Crear torneo
          </Link>
          <Link className="icon-button" to="/new-game">
            <span aria-hidden="true"></span>
            Nueva partida
          </Link>
          <button
            type="button"
            className="icon-button ghost"
            onClick={() => tournamentsQuery.refetch()}
            disabled={tournamentsQuery.isFetching}
          >
            <span aria-hidden="true"></span>
            {tournamentsQuery.isFetching ? "Actualizando..." : "Actualizar"}
          </button>
        </div>
      </header>

      {deleteError && <p className="error-text">{deleteError}</p>}

      {tournamentsQuery.isLoading && (
        <section className="tournament-empty-state">
          <span aria-hidden="true">⏳</span>
          <h2>Cargando torneos...</h2>
        </section>
      )}

      {tournamentsQuery.isError && (
        <section className="tournament-empty-state error">
          <span aria-hidden="true">⚠️</span>
          <h2>No se pudieron cargar los torneos</h2>
          <p>
            {tournamentsQuery.error instanceof Error
              ? tournamentsQuery.error.message
              : "Error desconocido"}
          </p>
        </section>
      )}

      {!tournamentsQuery.isLoading &&
        !tournamentsQuery.isError &&
        activeTournaments.length === 0 && (
          <section className="tournament-empty-state">
            <span aria-hidden="true"></span>
            <h2>No hay torneos activos</h2>
            <p>Crea un torneo nuevo o lanza una partida rápida.</p>
            <div className="tournament-empty-actions">
              <Link className="icon-button primary" to="/new-tournament">
                <span aria-hidden="true">➕</span>
                Crear torneo
              </Link>
              <Link className="icon-button" to="/new-game">
                <span aria-hidden="true"></span>
                Nueva partida
              </Link>
            </div>
          </section>
        )}

      {activeTournaments.length > 0 && (
        <section className="tournament-card-grid" aria-label="Torneos activos">
          {activeTournaments.map((tournament) => (
            <article key={String(tournament.id)} className="tournament-card">
              <div className="tournament-card-header">
                <div>
                  <h2>{tournament.name}</h2>
                  <p>
                    {getTournamentStatusLabel(tournament.status)} · Objetivo{" "}
                    {tournament.targetScore}
                  </p>
                </div>

                <span className="tournament-status-pill">
                  {getTournamentStatusIcon(tournament.status)}{" "}
                  {getTournamentStatusLabel(tournament.status)}
                </span>
              </div>

              <dl className="tournament-meta-grid">
                <div>
                  <dt>Equipos</dt>
                  <dd>{getTournamentTeamCount(tournament)}</dd>
                </div>

                <div>
                  <dt>Rondas</dt>
                  <dd>{getTournamentRoundCount(tournament)}</dd>
                </div>

                <div>
                  <dt>Formato</dt>
                  <dd>{getFormatLabel(tournament.format)}</dd>
                </div>
              </dl>

              <div className="tournament-card-actions">
                <button
                  type="button"
                  className="icon-button primary"
                  onClick={() => navigate(`/tournaments/${tournament.id}`)}
                >
                  <span aria-hidden="true"></span>
                  Abrir
                </button>
                <button
                  type="button"
                  className="icon-button danger"
                  onClick={() => handleDeleteTournament(tournament)}
                  disabled={deleteTournamentMutation.isPending}
                >
                  <span aria-hidden="true">️</span>
                  Eliminar
                </button>
              </div>
            </article>
          ))}
        </section>
      )}
    </main>
  );
}

function normalizeTournaments(value: unknown): Tournament[] {
  if (Array.isArray(value)) {
    return value as Tournament[];
  }

  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;

    if (Array.isArray(record.tournaments)) {
      return record.tournaments as Tournament[];
    }

    if (Array.isArray(record.items)) {
      return record.items as Tournament[];
    }

    if (Array.isArray(record.data)) {
      return record.data as Tournament[];
    }
  }

  return [];
}

function getTournamentStatusLabel(status: unknown): string {
  const value = String(status ?? "").toLowerCase();

  if (value === "created") {
    return "Creado";
  }

  if (value === "playing" || value === "active") {
    return "En juego";
  }

  if (value === "finished") {
    return "Finalizado";
  }

  return String(status ?? "Sin estado");
}

function getTournamentStatusIcon(status: unknown): string {
  const value = String(status ?? "").toLowerCase();

  if (value === "created") {
    return "";
  }

  if (value === "playing" || value === "active") {
    return "▶️";
  }

  if (value === "finished") {
    return "✅";
  }

  return "";
}

function getFormatLabel(format: unknown): string {
  if (format === "singleElimination") {
    return "Eliminatoria";
  }

  return String(format ?? "-");
}

function getTournamentTeamCount(tournament: Tournament): number {
  const record = tournament as unknown as Record<string, unknown>;

  return firstPositiveInteger([
    countCollection(record.teams),
    countCollection(record.teamList),
    countCollection(record.participants),
    countCollection(record.entries),
    toPositiveInteger(record.teamCount),
    toPositiveInteger(record.teamsCount),
    toPositiveInteger(record.numberOfTeams),
    toPositiveInteger(record.numTeams),
    countTeamsFromRounds(record.rounds),
  ]);
}

function getTournamentRoundCount(tournament: Tournament): number {
  const record = tournament as unknown as Record<string, unknown>;

  return firstPositiveInteger([
    countCollection(record.rounds),
    countCollection(record.roundList),
    toPositiveInteger(record.roundCount),
    toPositiveInteger(record.roundsCount),
    toPositiveInteger(record.numberOfRounds),
    toPositiveInteger(record.numRounds),
    countRoundsFromTables(record.tables),
  ]);
}

function firstPositiveInteger(values: number[]): number {
  return values.find((value) => value > 0) ?? 0;
}

function countCollection(value: unknown): number {
  if (Array.isArray(value)) {
    return value.length;
  }

  if (value && typeof value === "object") {
    return Object.keys(value as Record<string, unknown>).length;
  }

  return 0;
}

function toPositiveInteger(value: unknown): number {
  const numberValue = Number(value);

  return Number.isInteger(numberValue) && numberValue > 0 ? numberValue : 0;
}

function countTeamsFromRounds(value: unknown): number {
  const teamIds = new Set<string>();
  const rounds = toArray(value);

  for (const round of rounds) {
    if (!round || typeof round !== "object") {
      continue;
    }

    const tables = toArray((round as Record<string, unknown>).tables);

    for (const table of tables) {
      if (!table || typeof table !== "object") {
        continue;
      }

      const record = table as Record<string, unknown>;
      addIdToSet(teamIds, record.teamAId);
      addIdToSet(teamIds, record.teamBId);
      addIdToSet(teamIds, getNestedId(record.teamA));
      addIdToSet(teamIds, getNestedId(record.teamB));
    }
  }

  return teamIds.size;
}

function countRoundsFromTables(value: unknown): number {
  const tables = toArray(value);
  const roundIds = new Set<string>();

  for (const table of tables) {
    if (!table || typeof table !== "object") {
      continue;
    }

    const record = table as Record<string, unknown>;
    addIdToSet(roundIds, record.roundId);
    addIdToSet(roundIds, record.roundNumber);
  }

  return roundIds.size;
}

function toArray(value: unknown): unknown[] {
  if (Array.isArray(value)) {
    return value;
  }

  if (value && typeof value === "object") {
    return Object.values(value as Record<string, unknown>);
  }

  return [];
}

function getNestedId(value: unknown): unknown {
  if (!value || typeof value !== "object") {
    return undefined;
  }

  return (value as Record<string, unknown>).id;
}

function addIdToSet(target: Set<string>, value: unknown) {
  const id = String(value ?? "").trim();

  if (id) {
    target.add(id);
  }
}
