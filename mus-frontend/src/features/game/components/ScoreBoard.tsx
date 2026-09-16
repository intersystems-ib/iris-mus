import { useTranslation } from "react-i18next";
import type { GameState } from "../../../domain/game.types";

interface ScoreBoardProps {
  gameState: GameState;
}

export function ScoreBoard({ gameState }: ScoreBoardProps) {
  const { t } = useTranslation();
  const { score, targetScore, winnerTeam } = gameState;

  return (
    <section className="score-board">
      <div className="score-team">
        <span>{t("scoreBoard.team", { team: "A" })}</span>
        <strong>{score.teamA}</strong>
      </div>

      <div className="score-center">
        <span>{t("scoreBoard.target")}</span>
        <strong>{targetScore}</strong>
        {winnerTeam && <em>{t("scoreBoard.winner", { team: winnerTeam })}</em>}
      </div>

      <div className="score-team">
        <span>{t("scoreBoard.team", { team: "B" })}</span>
        <strong>{score.teamB}</strong>
      </div>
    </section>
  );
}