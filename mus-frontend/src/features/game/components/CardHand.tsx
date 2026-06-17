interface CardHandProps {
  cards: string[];
  hidden?: boolean;
}

export function CardHand({ cards, hidden = false }: CardHandProps) {
  if (!cards || cards.length === 0) {
    return <div className="card-hand empty">Sin cartas</div>;
  }

  return (
    <div className="card-hand">
      {cards.map((card, index) => (
        <div className="playing-card" key={`${card}-${index}`}>
          {hidden ? "🂠" : card}
        </div>
      ))}
    </div>
  );
}