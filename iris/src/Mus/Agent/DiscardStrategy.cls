Class Mus.Agent.DiscardStrategy Extends %RegisteredObject
{

ClassMethod RecommendDiscards(gameState As %DynamicObject, playerId As %String) As %DynamicArray
{
    Set discards = []

    If '$IsObject(gameState) {
        Return discards
    }

    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return discards
    }

    Set cardsByPlayer = hand.%Get("cards", "")
    If '$IsObject(cardsByPlayer) {
        Return discards
    }

    Set cards = cardsByPlayer.%Get(playerId, "")
    If '$IsObject(cards) {
        Return discards
    }

    Set profile = ##class(Mus.Agent.PlayerProfile).GetProfile(playerId)
    Set style = profile.%Get("style", "balanced")

    Set pares = ##class(Mus.Util.MusRules).AnalyzePares(cards)
    Set juego = ##class(Mus.Util.MusRules).AnalyzeJuego(cards)
    Set punto = ##class(Mus.Util.MusRules).AnalyzePunto(cards)

    If pares.%Get("hasPares", 0) {
        Return ..DiscardKeepingPairs(cards, pares, style)
    }

    If juego.%Get("hasJuego", 0) {
        Return ..DiscardWithJuego(cards, juego, style)
    }

    Return ..DiscardSeekingImprovement(cards, punto, style)
}

ClassMethod DiscardKeepingPairs(cards As %DynamicArray, pares As %DynamicObject, style As %String) As %DynamicArray
{
    Set discards = []

    Set counts = {}
    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set value = ##class(Mus.Util.MusRules).GetMusCardValue(card)
        Set current = +counts.%Get(value, 0)
        Do counts.%Set(value, current + 1)
    }

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set value = ##class(Mus.Util.MusRules).GetMusCardValue(card)
        Set count = +counts.%Get(value, 0)

        If count < 2 {
            If style = "aggressive" {
                Do discards.%Push(card)
            } ElseIf style = "bluffer" {
                Do discards.%Push(card)
            }
        }
    }

    If style = "conservative", discards.%Size() > 1 {
        Set one = discards.%Get(0)
        Set discards = []
        Do discards.%Push(one)
    }

    Return discards
}

ClassMethod DiscardWithJuego(cards As %DynamicArray, juego As %DynamicObject, style As %String) As %DynamicArray
{
    Set discards = []
    Set total = +juego.%Get("total", 0)

    If total = 31 {
        Return discards
    }

    If total = 32 {
        If style = "aggressive" {
            Set lowCard = ..FindLowestJuegoCard(cards)
            If lowCard '= "" {
                Do discards.%Push(lowCard)
            }
        }

        Return discards
    }

    If total >= 33 {
        If style '= "conservative" {
            Set lowCard = ..FindLowestJuegoCard(cards)
            If lowCard '= "" {
                Do discards.%Push(lowCard)
            }
        }
    }

    Return discards
}

ClassMethod DiscardSeekingImprovement(cards As %DynamicArray, punto As %DynamicObject, style As %String) As %DynamicArray
{
    Set discards = []
    Set total = +punto.%Get("total", 0)

    If total >= 29 {
        Return discards
    }

    Set maxDiscards = 1

    If style = "aggressive" {
        Set maxDiscards = 2
    }

    If style = "bluffer" {
        Set maxDiscards = 2
    }

    Set ordered = ..CardsByWeakness(cards)

    For i=0:1:ordered.%Size()-1 {
        If discards.%Size() >= maxDiscards {
            Quit
        }

        Do discards.%Push(ordered.%Get(i))
    }

    Return discards
}

ClassMethod FindLowestJuegoCard(cards As %DynamicArray) As %String
{
    Set selected = ""
    Set selectedValue = 999

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set value = ##class(Mus.Util.MusRules).GetJuegoCardValue(card)

        If value < selectedValue {
            Set selectedValue = value
            Set selected = card
        }
    }

    Return selected
}

ClassMethod CardsByWeakness(cards As %DynamicArray) As %DynamicArray
{
    Set result = []

    Set used = {}

    For pass=1:1:cards.%Size() {
        Set selectedIndex = -1
        Set selectedScore = 999

        For i=0:1:cards.%Size()-1 {
            If used.%Get(i, 0) {
                Continue
            }

            Set card = cards.%Get(i)
            Set score = ..CardKeepScore(card)

            If score < selectedScore {
                Set selectedScore = score
                Set selectedIndex = i
            }
        }

        If selectedIndex >= 0 {
            Do used.%Set(selectedIndex, 1)
            Do result.%Push(cards.%Get(selectedIndex))
        }
    }

    Return result
}

ClassMethod CardKeepScore(card As %String) As %Integer
{
    Set musValue = ##class(Mus.Util.MusRules).GetMusCardValue(card)
    Set juegoValue = ##class(Mus.Util.MusRules).GetJuegoCardValue(card)

    Set score = musValue + juegoValue

    If musValue = 10 {
        Set score = score + 5
    }

    If musValue = 1 {
        Set score = score + 3
    }

    Return score
}

}
