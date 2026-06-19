interface CardHandProps {
  cards: string[];
  hidden?: boolean;
}

const cardImages = import.meta.glob("../../../assets/cards/*.png", {
  eager: true,
  query: "?url",
  import: "default",
}) as Record<string, string>;

export function CardHand({ cards, hidden = false }: CardHandProps) {
  if (!cards || cards.length === 0) {
    return <div className="card-hand empty">Sin cartas</div>;
  }

  return (
    <div className="card-hand">
      {cards.map((card, index) => {
        const visibleCard = hidden ? "BACK" : card;
        const imageUrl = getCardImageUrl(visibleCard);

        return (
          <span key={`${visibleCard}-${index}`} className="playing-card">
            {imageUrl ? (
              <img
                className="playing-card-image"
                src={imageUrl}
                alt={hidden ? "Carta oculta" : card}
              />
            ) : (
              <span className="playing-card playing-card-fallback">
                {visibleCard}
              </span>
            )}
          </span>
        );
      })}
    </div>
  );
}

export function getCardImageUrl(card: string): string {
  const fileName = `${card}.png`;
  const match = Object.entries(cardImages).find(([path]) =>
    path.endsWith(`/${fileName}`)
  );

  return match?.[1] ?? "";
}