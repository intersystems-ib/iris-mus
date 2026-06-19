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

    If cards.%Size() '= 4 {
        Return discards
    }

    Set profile = ##class(Mus.Agent.PlayerProfile).GetProfile(playerId)
    Set style = "balanced"

    If $IsObject(profile) {
        Set style = profile.%Get("style", "balanced")
    }

    Set pares = ##class(Mus.Util.MusRules).AnalyzePares(cards)
    Set juego = ##class(Mus.Util.MusRules).AnalyzeJuego(cards)
    Set punto = ##class(Mus.Util.MusRules).AnalyzePunto(cards)

    /*
      Si hay medias o duples, normalmente no descartamos:
      son jugadas fuertes y no queremos romper estructura.
    */
    If $IsObject(pares), +pares.%Get("hasPares", 0) {
        Set paresType = pares.%Get("type", "")

        If (paresType = "medias") || (paresType = "duples") {
            Return discards
        }

        /*
          Si solo hay una pareja simple, NO rompemos la pareja,
          pero sí podemos descartar cartas sueltas malas.
        */
        If paresType = "pares" {
            Return ..DiscardWeakNonPairCards(cards, style, 1)
        }
    }

    /*
      Con 31 o 32, conservar.
    */
    If $IsObject(juego), +juego.%Get("hasJuego", "false") {
        Set totalJuego = +juego.%Get("total", 0)

        If (totalJuego = 31) || (totalJuego = 32) {
            Return discards
        }

        /*
          Con juego alto no perfecto, permitimos un descarte suave
          si hay carta suelta claramente mala.
        */
        If totalJuego >= 33 {
            Set candidate = ..FindLowestNonPairCard(cards)

            If candidate '= "" {
                Do discards.%Push(candidate)
            }

            Return discards
        }
    }

    If ##class(Mus.Util.MusRules).HasPeterete(cards) {
        Set allCards = []

        For i=0:1:cards.%Size()-1 {
            Do allCards.%Push(cards.%Get(i))
        }

        Return allCards
    }

    /*
      Solo conservar chica si es realmente clara.
    */
    If ..IsClearChicaHand(cards) {
        Return discards
    }

    /*
      Caso normal:
      descartamos cartas bajas/no útiles.
    */
    Return ..DiscardWeakCards(cards, style, punto)
}

ClassMethod DiscardWeakNonPairCards(cards As %DynamicArray, style As %String, maxDiscards As %Integer = 1) As %DynamicArray
{
    Set discards = []

    If maxDiscards <= 0 {
        Set maxDiscards = 1
    }

    /*
      Con una pareja simple:
      - conservador/equilibrado: descarta 1 carta mala
      - agresivo/farolero: puede descartar 2 cartas sueltas
    */
    If (style = "aggressive") || (style = "bluffer") {
        Set maxDiscards = 2
    }

    Set ordered = ..CardsByDiscardPriority(cards)

    For i=0:1:ordered.%Size()-1 {
        If discards.%Size() >= maxDiscards {
            Return discards
        }

        Set candidate = ordered.%Get(i)

        If ..CanDiscardCard(cards, candidate) {
            Do discards.%Push(candidate)
        }
    }

    Return discards
}

ClassMethod IsClearChicaHand(cards As %DynamicArray) As %Boolean
{
    /*
      Solo jugamos a chica si la mano es claramente de chica:
      - al menos 3 cartas bajas
      - ninguna carta claramente alta
    */

    Set lowCount = 0
    Set highCount = 0

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set musValue = ##class(Mus.Util.MusRules).GetMusCardValue(card)

        If musValue <= 4 {
            Set lowCount = lowCount + 1
        }

        If musValue >= 10 {
            Set highCount = highCount + 1
        }
    }

    If (lowCount >= 3) && (highCount = 0) {
        Return 1
    }

    Return 0
}

ClassMethod DiscardWeakCards(cards As %DynamicArray, style As %String, punto As %DynamicObject = "") As %DynamicArray
{
    Set discards = []

    Set maxDiscards = 1

    If (style = "aggressive") || (style = "bluffer") {
        Set maxDiscards = 2
    }

    If style = "conservative" {
        Set maxDiscards = 1
    }

    /*
      Si el punto ya es alto pero no llega a juego,
      no sobre-descartamos.
    */
    If $IsObject(punto) {
        Set total = +punto.%Get("total", 0)

        If total >= 29 {
            Set maxDiscards = 1
        }
    }

    Set ordered = ..CardsByDiscardPriority(cards)

    For i=0:1:ordered.%Size()-1 {
        If discards.%Size() >= maxDiscards {
            Return discards
        }

        Set candidate = ordered.%Get(i)

        If ..CanDiscardCard(cards, candidate) {
            Do discards.%Push(candidate)
        }
    }

    Return discards
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

    If style = "conservative" {
        Return discards
    }

    If total = 32 {
        Return discards
    }

    If total >= 33 {
        Set candidate = ..FindSafestDiscardForJuego(cards)

        If candidate '= "" {
            Do discards.%Push(candidate)
        }
    }

    Return discards
}

ClassMethod FindSafestDiscardForJuego(cards As %DynamicArray) As %String
{
    Set selected = ""
    Set selectedScore = 999999

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)

        If ..IsProtectedCard(cards, card) {
            Continue
        }

        Set score = ..DiscardScore(cards, card)

        If score < selectedScore {
            Set selectedScore = score
            Set selected = card
        }
    }

    Return selected
}

ClassMethod DiscardSeekingImprovement(cards As %DynamicArray, punto As %DynamicObject, style As %String) As %DynamicArray
{
    Set discards = []
    Set total = +punto.%Get("total", 0)

    /*
      Si estamos cerca de buen punto, no tocar demasiado.
    */
    If total >= 29 {
        Return discards
    }

    Set maxDiscards = 1

    If style = "aggressive" {
        Set maxDiscards = 2
    }

    If style = "bluffer" {
        Set maxDiscards = 1
    }

    If style = "conservative" {
        Set maxDiscards = 1
    }

    Set ordered = ..CardsByDiscardPriority(cards)

    For i=0:1:ordered.%Size()-1 {
        If discards.%Size() >= maxDiscards {
            Quit
        }

        Set candidate = ordered.%Get(i)

        If '..IsProtectedCard(cards, candidate) {
            Do discards.%Push(candidate)
        }
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

ClassMethod CardsByDiscardPriority(cards As %DynamicArray) As %DynamicArray
{
    Set result = []
    Set used = {}

    For pass=1:1:cards.%Size() {
        Set selectedIndex = -1
        Set selectedScore = 999999

        For i=0:1:cards.%Size()-1 {
            If used.%Get(i, 0) {
                Continue
            }

            Set card = cards.%Get(i)
            Set score = ..DiscardScore(cards, card)

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

ClassMethod DiscardScore(cards As %DynamicArray, card As %String) As %Integer
{
    Set musValue = ##class(Mus.Util.MusRules).GetMusCardValue(card)
    Set juegoValue = ##class(Mus.Util.MusRules).GetJuegoCardValue(card)

    /*
      Cuanto menor es el score, antes se descarta.
      Ahora las cartas bajas son malas salvo chica clara.
    */
    Set score = 0

    /*
      Las bajas son candidatas principales al descarte.
    */
    Set score = score + (musValue * 10)

    /*
      Cartas que suman poco a juego también son malas.
    */
    Set score = score + (juegoValue * 4)

    /*
      Proteger cartas altas para grande y para juego.
    */
    If musValue >= 10 {
        Set score = score + 300
    }

    /*
      Proteger cualquier carta que forme par/medias/duples.
    */
    If ..CountSameMusValue(cards, card) >= 2 {
        Set score = score + 500
    }

    Return score
}

ClassMethod IsProtectedCard(cards As %DynamicArray, card As %String) As %Boolean
{
    Set musValue = ##class(Mus.Util.MusRules).GetMusCardValue(card)

    If ..CountSameMusValue(cards, card) >= 2 {
        Return 1
    }

    If musValue >= 10 {
        Return 1
    }

    If musValue <= 1 {
        Return 1
    }

    Return 0
}

ClassMethod CardHasPair(cards As %DynamicArray, card As %String) As %Boolean
{
    If ..CountSameMusValue(cards, card) >= 2 {
        Return 1
    }

    Return 0
}

ClassMethod FindLowestNonPairCard(cards As %DynamicArray) As %String
{
    Set selected = ""
    Set selectedValue = 999999

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)

        If ..CountSameMusValue(cards, card) >= 2 {
            Continue
        }

        Set musValue = ##class(Mus.Util.MusRules).GetMusCardValue(card)

        If musValue >= 10 {
            Continue
        }

        If musValue < selectedValue {
            Set selectedValue = musValue
            Set selected = card
        }
    }

    Return selected
}

ClassMethod CanDiscardCard(cards As %DynamicArray, card As %String) As %Boolean
{
    /*
      Nunca descartar una carta que forma pareja, medias o duples.
    */
    If ..CountSameMusValue(cards, card) >= 2 {
        Return 0
    }

    /*
      Proteger figuras/reyes para grande y juego.
    */
    Set musValue = ##class(Mus.Util.MusRules).GetMusCardValue(card)

    If musValue >= 10 {
        Return 0
    }

    Return 1
}

ClassMethod CountSameMusValue(cards As %DynamicArray, card As %String) As %Integer
{
    Set count = 0
    Set targetValue = ##class(Mus.Util.MusRules).GetMusCardValue(card)

    For i=0:1:cards.%Size()-1 {
        Set otherCard = cards.%Get(i)
        Set otherValue = ##class(Mus.Util.MusRules).GetMusCardValue(otherCard)

        If otherValue = targetValue {
            Set count = count + 1
        }
    }

    Return count
}

}
