import { useCallback, useMemo, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { musApi } from "../../../api/musApi";
import { useTranslation } from "react-i18next";
import type {
  CreateTournamentRequest,
  CreateTournamentTeam,
} from "../../../domain/tournament.types";

const TARGET_SCORE = 40;
const AGENT_PROFILES = ["balanced", "aggressive", "conservative", "bluffer"] as const;

function randomAgentProfile(): string {
  return AGENT_PROFILES[Math.floor(Math.random() * AGENT_PROFILES.length)];
}

export function TournamentSetupPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [name, setName] = useState(t("tournamentSetup.defaultTournamentName"));
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
        humanPlayerName: t("tournamentSetup.humanPlayerName"),
      });

      const generated = response.teams?.length
        ? response.teams
        : buildDefaultTeams(teamCount, t);

      setName(response.tournamentName || name || t("tournamentSetup.defaultTournamentName"));
      setTeams(normalizeHumanFirstTeam(generated, teamCount, t));
      setLastError("");
    } catch (error) {
      setTeams(normalizeHumanFirstTeam(buildDefaultTeams(teamCount, t), teamCount, t));
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
        teams: normalizeHumanFirstTeam(teams, teamCount, t),
      };

      validateTournament(request, t);
      const response = await musApi.createTournament(request);

      const tournamentId =
        response.tournamentId ?? response.tournament?.id ?? response.payload?.id ?? "";

      if (!tournamentId) {
        throw new Error(t("tournamentSetup.errors.missingTournamentId"));
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
            <strong>{t("tournamentSetup.generatingTeams")}</strong>
          </div>
        </div>
      )}

      <button
        type="button"
        className="icon-button ghost tournament-back-button"
        onClick={() => navigate("/tournaments")}
        aria-label={t("tournamentSetup.backAria")}
      >
        {t("tournamentSetup.back")}
      </button>

      <p className="eyebrow">{t("tournamentSetup.titleEyebrow")}</p>
      <h1>{t("tournamentSetup.title")}</h1>

      <section className="tournament-form-card tournament-setup-start-card">
        <div className="tournament-setup-fields-row">
          <label>
            {t("tournamentSetup.tournamentName")}: 
            <input
              size= {32}
              value={name}
              onChange={(event) => {
                setName(event.target.value);
                setTeams([]);
              }}
            />
          </label>

          <label>
            {t("tournamentSetup.teamCount")}: 
            <select
              className="form-select"
              value={teamCount}
              onChange={(event) => handleTeamCountChange(Number(event.target.value))}
            >
              <option value={2}>{t("tournamentSetup.teamCountOption", { count: 2 })}</option>
              <option value={4}>{t("tournamentSetup.teamCountOption", { count: 4 })}</option>
              <option value={8}>{t("tournamentSetup.teamCountOption", { count: 8 })}</option>
              <option value={16}>{t("tournamentSetup.teamCountOption", { count: 16 })}</option>
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
            {isGeneratingTeams ? t("tournamentSetup.generatingTeamsButton") : t("tournamentSetup.generateTeams")}
          </button>
        </div>
      </section>

      {hasGeneratedTeams && (
        <section>
          <h2>{t("tournamentSetup.teams")}</h2>
          <div className="tournament-card-grid">
            {teams.map((team) => (
              <article key={team.seed} className="tournament-card tournament-team-card">
                <div className="readonly-team-name">{team.name}</div>

                <div className="tournament-player-list">
                  {team.players.map((player, playerIndex) => {
                    const isHumanSeat = team.seed === 1 && playerIndex === 0;
                    const profileLabel = isHumanSeat
                      ? t("tournamentSetup.human")
                      : t(`tournamentSetup.profiles.${player.agentProfile || "balanced"}`);

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
        {createTournamentMutation.isPending ? t("tournamentSetup.creatingTournament") : t("tournamentSetup.createTournament")}
      </button>

      {lastError && <p className="error-text">{lastError}</p>}
    </main>
  );
}

function buildDefaultTeams(
  teamCount: number,
  t: (key: string, options?: Record<string, unknown>) => string
): CreateTournamentTeam[] {
  return Array.from({ length: teamCount }, (_, index) => {
    const seed = index + 1;

    return {
      name: seed === 1 ? t("tournamentSetup.humanTeamName") : t("tournamentSetup.pairName", { number: seed }),
      seed,
      players: [
        {
          playerNumber: 1,
          displayName: seed === 1 ? t("tournamentSetup.humanPlayerName") : t("tournamentSetup.playerName", { team: seed, player: 1 }),
          type: seed === 1 ? "human" : "agent",
          agentProfile: seed === 1 ? undefined : randomAgentProfile(),
        },
        {
          playerNumber: 2,
          displayName: seed === 1 ? t("tournamentSetup.partnerName") : t("tournamentSetup.playerName", { team: seed, player: 2 }),
          type: "agent",
          agentProfile: randomAgentProfile(),
        },
      ],
    };
  });
}

function resizeTeams(
  currentTeams: CreateTournamentTeam[],
  nextCount: number,
  t: (key: string, options?: Record<string, unknown>) => string
): CreateTournamentTeam[] {
  if (nextCount <= currentTeams.length) {
    return currentTeams.slice(0, nextCount);
  }

  const extraTeams = buildDefaultTeams(nextCount, t).slice(currentTeams.length);
  return [...currentTeams, ...extraTeams];
}

function normalizeHumanFirstTeam(
  teams: CreateTournamentTeam[],
  teamCount: number,
  t: (key: string, options?: Record<string, unknown>) => string
): CreateTournamentTeam[] {
  const resized = resizeTeams(teams, teamCount, t).slice(0, teamCount);

  return resized.map((team, teamIndex) => ({
    ...team,
    name: team.name?.trim() || t("tournamentSetup.pairName", { number: teamIndex + 1 }),
    seed: teamIndex + 1,
    players: [0, 1].map((playerIndex) => {
      const existing = team.players[playerIndex];
      const isHumanSeat = teamIndex === 0 && playerIndex === 0;

      return {
        playerNumber: playerIndex + 1,
        displayName:
          existing?.displayName ||
          (isHumanSeat
            ? t("tournamentSetup.humanPlayerName")
            : teamIndex === 0 && playerIndex === 1
              ? t("tournamentSetup.partnerName")
              : t("tournamentSetup.playerName", { team: teamIndex + 1, player: playerIndex + 1 })),
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

function validateTournament(
  request: CreateTournamentRequest,
  t: (key: string, options?: Record<string, unknown>) => string
) {
  if (!request.name.trim()) {
    throw new Error(t("tournamentSetup.errors.nameRequired"));
  }

  if (request.targetScore !== TARGET_SCORE) {
    throw new Error(t("tournamentSetup.errors.targetScore", { score: TARGET_SCORE }));
  }

  if (!isPowerOfTwo(request.teams.length)) {
    throw new Error(t("tournamentSetup.errors.powerOfTwo"));
  }

  if (request.teams.length < 2) {
    throw new Error(t("tournamentSetup.errors.minimumTeams"));
  }

  if (request.teams[0]?.players[0]?.type !== "human") {
    throw new Error(t("tournamentSetup.errors.humanFirstTeam"));
  }

  const humanCount = countHumanPlayers(request.teams);
  if (humanCount !== 1) {
    throw new Error(t("tournamentSetup.errors.exactlyOneHuman"));
  }

  const teamNames = new Set<string>();

  for (const team of request.teams) {
    if (!team.name.trim()) {
      throw new Error(t("tournamentSetup.errors.teamWithoutName", { seed: team.seed }));
    }

    if (teamNames.has(team.name.trim().toLowerCase())) {
      throw new Error(t("tournamentSetup.errors.duplicateTeamName", { name: team.name }));
    }

    teamNames.add(team.name.trim().toLowerCase());

    if (team.players.length !== 2) {
      throw new Error(t("tournamentSetup.errors.teamNeedsTwoPlayers", { name: team.name }));
    }

    for (const player of team.players) {
      if (!player.displayName.trim()) {
        throw new Error(t("tournamentSetup.errors.playerWithoutName", { name: team.name }));
      }
    }
  }
}

function isPowerOfTwo(value: number): boolean {
  return value > 0 && (value & (value - 1)) === 0;
}
