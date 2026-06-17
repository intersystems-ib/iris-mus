import type { GameState } from "../../../domain/game.types";

interface ScoreBoardProps {
  gameState: GameState;
}

export function ScoreBoard({ gameState }: ScoreBoardProps) {
  const { score, targetScore, winnerTeam } = gameState;

  return (
    <section className="score-board">
      <div className="score-team">
        <span>Equipo A</span>
        <strong>{score.teamA}</strong>
      </div>

      <div className="score-center">
        <span>Objetivo</span>
        <strong>{targetScore}</strong>
        {winnerTeam && <em>Ganador: Equipo {winnerTeam}</em>}
      </div>

      <div className="score-team">
        <span>Equipo B</span>
        <strong>{score.teamB}</strong>
      </div>
    </section>
  );
}