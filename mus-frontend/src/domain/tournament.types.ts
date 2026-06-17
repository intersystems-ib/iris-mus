export interface TournamentPlayer {
  id: string;
  playerNumber: number;
  displayName: string;
  type: "human" | "agent";
  agentProfile?: string;
}

export interface TournamentTeam {
  id: string;
  name: string;
  status: "active" | "winner" | "eliminated" | string;
  seed: number;
  players: TournamentPlayer[];
}

export interface TournamentTable {
  id: number | string;
  tableNumber: number;
  status: "created" | "playing" | "finished" | string;
  teamAId?: number | string;
  teamBId?: number | string;
  winnerTeamId?: number | string;
  gameId?: number | string;
  teamA?: TournamentTeam;
  teamB?: TournamentTeam;
  winnerTeam?: TournamentTeam;
}

export interface TournamentRound {
  id: string;
  roundNumber: number;
  name: string;
  status: "created" | "playing" | "finished" | string;
  tables: TournamentTable[];
}

export interface Tournament {
  id: string;
  name: string;
  format: "singleElimination" | string;
  targetScore: number;
  status: "created" | "playing" | "finished" | string;
  createdAt?: string;
  startedAt?: string;
  finishedAt?: string;
  teams: TournamentTeam[];
  rounds: TournamentRound[];
}

export interface CreateTournamentPlayer {
  playerNumber: number;
  displayName: string;
  type: "human" | "agent";
  agentProfile?: string;
}

export interface CreateTournamentTeam {
  name: string;
  seed: number;
  players: CreateTournamentPlayer[];
}

export interface CreateTournamentRequest {
  name: string;
  format: "singleElimination";
  targetScore: number;
  teams: CreateTournamentTeam[];
}