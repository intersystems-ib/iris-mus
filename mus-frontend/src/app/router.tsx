import { createBrowserRouter } from "react-router-dom";
import { ApiTestPage } from "../features/game/pages/ApiTestPage";
import { GamePage } from "../features/game/pages/GamePage";
import { GameSetupPage } from "../features/game/pages/GameSetupPage";
import { TournamentSetupPage } from "../features/tournament/pages/TournamentSetupPage";
import { TournamentDetailPage } from "../features/tournament/pages/TournamentDetailPage";
import { TournamentsHomePage } from "../features/tournament/pages/TournamentsHomePage";

function HomePage() {
  return <TournamentsHomePage />;
}

export const router = createBrowserRouter([
  {
    path: "/",
    element: <HomePage />,
  },
  {
    path: "/api-test",
    element: <ApiTestPage />,
  },
  {
    path: "/games/:gameId",
    element: <GamePage />,
  },
  { 
    path: "/tournaments", 
    element: <TournamentsHomePage /> },
  {
    path: "/new-game",
    element: <GameSetupPage />,
  },
  {
  path: "/new-tournament",
    element: <TournamentSetupPage />,
  },
  {
    path: "/tournaments/:tournamentId",
    element: <TournamentDetailPage />,
  },
]);