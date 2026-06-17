import type { GameAction } from "../../../domain/game.types";

interface EventTimelineProps {
  actions: GameAction[];
}

export function EventTimeline({ actions }: EventTimelineProps) {
  const recentActions = [...(actions ?? [])].slice(-12).reverse();

  return (
    <section className="event-timeline">
      <h2>Historial</h2>

      {recentActions.length === 0 ? (
        <p className="muted-text">No hay acciones todavía.</p>
      ) : (
        <ol>
          {recentActions.map((action, index) => (
            <li key={`${action.createdAt ?? "event"}-${index}`}>
              <strong>{action.playerId ?? "ALL"}</strong>{" "}
              <span>{action.type}</span>{" "}
              <em>{action.phase}</em>
              {typeof action.amount === "number" && action.amount > 0 && (
                <small> · {action.amount}</small>
              )}
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}