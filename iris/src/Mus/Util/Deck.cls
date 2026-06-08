Class Mus.Util.Deck
{

ClassMethod BuildSpanishDeck() As %DynamicArray
{
    Set deck = []
    Set suits = ["O", "C", "E", "B"]

    For s=0:1:suits.%Size()-1 {
        Set suit = suits.%Get(s)

        For rank=1:1:12 {
            If rank '= 8, rank '= 9 {
                Do deck.%Push(rank_suit)
            }
        }
    }

    Return deck
}

ClassMethod Shuffle(deck As %DynamicArray) As %DynamicArray
{
    Set shuffled = []
    Set temp = []

    For i=0:1:deck.%Size()-1 {
        Do temp.%Push(deck.%Get(i))
    }

    While temp.%Size() > 0 {
        Set idx = $Random(temp.%Size())
        Do shuffled.%Push(temp.%Get(idx))
        Do temp.%Remove(idx)
    }

    Return shuffled
}

ClassMethod DealFourPlayers() As %DynamicObject
{
    Set result = ..DealFourPlayersWithRemainingDeck()
    Return result.%Get("cards")
}

ClassMethod DealFourPlayersWithRemainingDeck() As %DynamicObject
{
    Set deck = ..Shuffle(..BuildSpanishDeck())

    Set cards = {}
    Do cards.%Set("P1", [])
    Do cards.%Set("P2", [])
    Do cards.%Set("P3", [])
    Do cards.%Set("P4", [])

    For i=0:1:3 {
        Do cards.%Get("P1").%Push(deck.%Get((i*4)+0))
        Do cards.%Get("P2").%Push(deck.%Get((i*4)+1))
        Do cards.%Get("P3").%Push(deck.%Get((i*4)+2))
        Do cards.%Get("P4").%Push(deck.%Get((i*4)+3))
    }

    Set remainingDeck = []

    For i=16:1:deck.%Size()-1 {
        Do remainingDeck.%Push(deck.%Get(i))
    }

    Set result = {
        "cards": (cards),
        "remainingDeck": (remainingDeck)
    }

    Return result
}

}
