Class Mus.AI.Tools.HandStrengthTools Extends %AI.Tool
{

ClassMethod EvaluatePlayStrength(cards As %String, play As %String) As %DynamicObject
{
    Set startedAt = ##class(Mus.Data.AgentToolLog).NowMs()
    Set toolInput = {
        "cards": (cards),
        "play": (play)
    }

    Set result = {
        "success": false,
        "strength": "neutral",
        "play": (play),
        "reason": ""
    }

    Try {
        Set play = $ZCONVERT(play, "L")
        Do result.%Set("play", play)

        Set cardsArray = ..ParseCards(cards)

        If '$IsObject(cardsArray) || cardsArray.%Size() = 0 {
            Do result.%Set("strength", "very weak")
            Do result.%Set("reason", "No cards provided")
            Return ##class(Mus.Data.AgentToolLog).FinishToolCall(
                "evaluate_play_strength",
                toolInput,
                result,
                startedAt
            )
        }

        If (play '= "grande") && (play '= "chica") && (play '= "pares") && (play '= "juego") && (play '= "punto") {
            Do result.%Set("strength", "very weak")
            Do result.%Set("reason", "Unsupported play")
            Return ##class(Mus.Data.AgentToolLog).FinishToolCall(
                "evaluate_play_strength",
                toolInput,
                result,
                startedAt
            )
        }

        Set score = ..Score(cardsArray, play)
        Set strength = ..ScoreToStrength(score)

        Do result.%Set("success", "true")
        Do result.%Set("strength", strength)
        Do result.%Set("score", score)
        Do result.%Set("reason", ..BuildReason(cardsArray, play, score, strength))

        If play = "pares" {
            Set pairInfo = ..BuildParesInfo(cardsArray)
            Do result.%Set("pairType", pairInfo.%Get("pairType", "none"))
            Do result.%Set("highestPairRank", +pairInfo.%Get("highestPairRank", 0))
            Do result.%Set("pairCount", +pairInfo.%Get("pairCount", 0))
        }

        Return ##class(Mus.Data.AgentToolLog).FinishToolCall(
            "evaluate_play_strength",
            toolInput,
            result,
            startedAt
        )
    } Catch ex {
        Do result.%Set("success", "false")
        Do result.%Set("reason", ex.DisplayString())

        Return ##class(Mus.Data.AgentToolLog).FinishToolCall(
            "evaluate_play_strength",
            toolInput,
            result,
            startedAt
        )
    }
}

ClassMethod ParseCards(cards As %String) As %DynamicArray
{
    If cards = "" {
        Return []
    }

    Try {
        Set parsed = [].%FromJSON(cards)
        Return parsed
    } Catch ex {
        Set arr = []

        For i=1:1:$Length(cards, ",") {
            Set card = $ZSTRIP($Piece(cards, ",", i), "<>W")
            If card '= "" {
                Do arr.%Push(card)
            }
        }

        Return arr
    }
}

ClassMethod Score(cards As %DynamicArray, play As %String) As %Integer
{
    Set play = $ZCONVERT(play, "L")

    If play = "grande" {
        Return ..ScoreGrande(cards)
    }

    If play = "chica" {
        Return ..ScoreChica(cards)
    }

    If play = "pares" {
        Return ..ScorePares(cards)
    }

    If play = "juego" {
        Return ..ScoreJuego(cards)
    }

    If play = "punto" {
        Return ..ScorePunto(cards)
    }

    Return 10
}

ClassMethod ScoreToStrength(score As %Integer) As %String
{
    If score >= 85 {
        Return "very strong"
    }

    If score >= 70 {
        Return "strong"
    }

    If score >= 45 {
        Return "neutral"
    }

    If score >= 25 {
        Return "weak"
    }

    Return "very weak"
}

ClassMethod ScoreGrande(cards As %DynamicArray) As %Integer
{
    Set total = 0

    For i=0:1:cards.%Size()-1 {
        Set rank = ..MusRank(cards.%Get(i))

        If rank >= 10 {
            Set total = total + 25
        } ElseIf rank >= 8 {
            Set total = total + 18
        } ElseIf rank >= 6 {
            Set total = total + 10
        } Else {
            Set total = total + 3
        }
    }

    If total > 100 {
        Set total = 100
    }

    Return total
}

ClassMethod ScoreChica(cards As %DynamicArray) As %Integer
{
    Set total = 0

    For i=0:1:cards.%Size()-1 {
        Set rank = ..MusRank(cards.%Get(i))

        If rank <= 1 {
            Set total = total + 25
        } ElseIf rank <= 3 {
            Set total = total + 18
        } ElseIf rank <= 5 {
            Set total = total + 10
        } Else {
            Set total = total + 3
        }
    }

    If total > 100 {
        Set total = 100
    }

    Return total
}

/*
  Scoring especifico para pares.

  Regla clave:
  - Un par aislado bajo o medio NO es neutral. Es weak.
  - Solo un par alto aislado es neutral.
  - Duples y medias ya son fuertes.
*/
ClassMethod ScorePares(cards As %DynamicArray) As %Integer
{
    Set info = ..BuildParesInfo(cards)

    Set pairType = info.%Get("pairType", "none")
    Set highestPairRank = +info.%Get("highestPairRank", 0)

    If pairType = "duples4" {
        Return 100
    }

    If pairType = "medias" {
        Return 90
    }

    If pairType = "duples" {
        Return 80
    }

    If pairType = "pares" {
        /*
          Par alto aislado: defendible, pero no fuerte.
          Pares bajos o medios: mano pobre para pares.
          Ejemplo 4C,12C,7C,4O -> par de 4 -> 30 -> weak.
        */
        If highestPairRank >= 10 {
            Return 55
        }

        If highestPairRank >= 7 {
            Return 40
        }

        Return 30
    }

    Return 10
}

ClassMethod BuildParesInfo(cards As %DynamicArray) As %DynamicObject
{
    Set info = {
        "pairType": "none",
        "pairCount": 0,
        "highestPairRank": 0,
        "hasThree": false,
        "hasFour": false
    }

    If '$IsObject(cards) {
        Return info
    }

    Kill counts

    For i=0:1:cards.%Size()-1 {
        Set rank = ..MusRank(cards.%Get(i))
        Set counts(rank) = $Get(counts(rank)) + 1
    }

    Set pairCount = 0
    Set highestPairRank = 0
    Set hasThree = 0
    Set hasFour = 0

    Set rank = ""
    For {
        Set rank = $Order(counts(rank))
        Quit:rank=""

        If counts(rank) >= 2 {
            Set pairCount = pairCount + 1

            If +rank > highestPairRank {
                Set highestPairRank = +rank
            }
        }

        If counts(rank) = 3 {
            Set hasThree = 1
        }

        If counts(rank) >= 4 {
            Set hasFour = 1
        }
    }

    Do info.%Set("pairCount", pairCount)
    Do info.%Set("highestPairRank", highestPairRank)
    Do info.%Set("hasThree", hasThree)
    Do info.%Set("hasFour", hasFour)

    If hasFour {
        Do info.%Set("pairType", "duples4")
    } ElseIf hasThree {
        Do info.%Set("pairType", "medias")
    } ElseIf pairCount >= 2 {
        Do info.%Set("pairType", "duples")
    } ElseIf pairCount = 1 {
        Do info.%Set("pairType", "pares")
    }

    Return info
}

ClassMethod ScoreJuego(cards As %DynamicArray) As %Integer
{
    Set points = ..HandPoints(cards)

    If points >= 31 {
        If points = 31 {
            Return 100
        }

        If points = 32 {
            Return 90
        }

        If points = 40 {
            Return 85
        }

        If points >= 33 {
            Return 75
        }

        Return 70
    }

    Return 15
}

ClassMethod ScorePunto(cards As %DynamicArray) As %Integer
{
    Set points = ..HandPoints(cards)

    If points = 30 {
        Return 100
    }

    If points = 29 {
        Return 85
    }

    If points = 28 {
        Return 70
    }

    If points >= 26 {
        Return 55
    }

    If points >= 24 {
        Return 40
    }

    Return 20
}

ClassMethod MusRank(card As %String) As %Integer
{
    Set rank = ..ExtractRank(card)

    /*
      Mus con 8 reyes y 8 ases:
      3 cuenta como rey para grande/pares.
      2 cuenta como as para chica/pares.
    */
    If rank = 3 {
        Return 12
    }

    If rank = 2 {
        Return 1
    }

    Return rank
}

ClassMethod ExtractRank(card As %String) As %Integer
{
    Set card = $ZCONVERT(card, "U")
    Set digits = ""

    For i=1:1:$Length(card) {
        Set ch = $Extract(card, i)

        If ch?1N {
            Set digits = digits_ch
        } Else {
            Quit
        }
    }

    If digits '= "" {
        Return +digits
    }

    /*
      Por si en algun sitio aparecen letras.
    */
    If $Extract(card, 1) = "A" {
        Return 1
    }

    If $Extract(card, 1) = "S" {
        Return 10
    }

    If $Extract(card, 1) = "C" {
        Return 11
    }

    If $Extract(card, 1) = "R" {
        Return 12
    }

    Return 0
}

ClassMethod HandPoints(cards As %DynamicArray) As %Integer
{
    Set total = 0

    For i=0:1:cards.%Size()-1 {
        Set rank = ..ExtractRank(cards.%Get(i))

        If rank >= 10 {
            Set total = total + 10
        } Else {
            Set total = total + rank
        }
    }

    Return total
}

ClassMethod BuildReason(cards As %DynamicArray, play As %String, score As %Integer, strength As %String) As %String
{
    If play = "pares" {
        Set info = ..BuildParesInfo(cards)
        Set pairType = info.%Get("pairType", "none")
        Set highestPairRank = +info.%Get("highestPairRank", 0)

        If pairType = "none" {
            Return "pares=none; score="_score_"; strength="_strength
        }

        If pairType = "pares" {
            If highestPairRank >= 10 {
                Return "pares=high pair; score="_score_"; strength="_strength
            }

            Return "pares=low isolated pair; score="_score_"; strength="_strength
        }

        Return "pares="_pairType_"; score="_score_"; strength="_strength
    }

    If play = "juego" {
        Return "points="_..HandPoints(cards)_"; score="_score_"; strength="_strength
    }

    If play = "punto" {
        Return "points="_..HandPoints(cards)_"; score="_score_"; strength="_strength
    }

    Return play_" score="_score_"; strength="_strength
}

}
