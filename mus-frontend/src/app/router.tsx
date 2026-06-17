import { createBrowserRouter, Link } from "react-router-dom";
import { ApiTestPage } from "../features/game/pages/ApiTestPage";
import { GamePage } from "../features/game/pages/GamePage";
import { GameSetupPage } from "../features/game/pages/GameSetupPage";
import { TournamentSetupPage } from "../features/tournament/pages/TournamentSetupPage";
import { TournamentDetailPage } from "../features/tournament/pages/TournamentDetailPage";

function HomePage() {
  return (
    <main className="page">
      <h1>Mus</h1>
      <p>Frontend inicial conectado al backend de Mus.</p>

      <nav className="home-links">
        <Link to="/new-game">Nueva partida</Link>
        <Link to="/new-tournament">Nuevo torneo</Link>
        <Link to="/api-test">Probar API</Link>
      </nav>
    </main>
  );
}

function TournamentPage() {
  return (
    <main className="page">
      <h1>Torneos</h1>
      <p>Próximo paso: listar torneos.</p>
    </main>
  );
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
    element: <TournamentPage />,
  },
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