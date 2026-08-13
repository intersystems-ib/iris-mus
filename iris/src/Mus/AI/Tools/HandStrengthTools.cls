Class Mus.AI.Tools.HandStrengthTools Extends %AI.Tool
{

ClassMethod EvaluatePlayStrength(cards As %String, play As %String) As %DynamicObject
{
    Set result = {
        "success": false,
        "strength": "neutral",
        "play": (play),
        "reason": ""
    }

    Try {
        Set play = $ZCONVERT(play, "L")

        Set cardsArray = ..ParseCards(cards)

        If '$IsObject(cardsArray) || cardsArray.%Size() = 0 {
            Do result.%Set("reason", "No cards provided")
            Return result
        }

        If (play '= "grande") && (play '= "chica") && (play '= "pares") && (play '= "juego") && (play '= "punto") {
            Do result.%Set("reason", "Unsupported play")
            Return result
        }

        Set score = ..Score(cardsArray, play)
        Set strength = ..ScoreToStrength(score)

        Do result.%Set("success", "true")
        Do result.%Set("strength", strength)
        Do result.%Set("score", score)
        Do result.%Set("reason", ..BuildReason(cardsArray, play, score, strength))

        Return result
    } Catch ex {
        Do result.%Set("reason", ex.DisplayString())
        Return result
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

    Return 50
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

ClassMethod ScorePares(cards As %DynamicArray) As %Integer
{
    Kill counts

    For i=0:1:cards.%Size()-1 {
        Set rank = ..MusRank(cards.%Get(i))
        Set counts(rank) = $Get(counts(rank)) + 1
    }

    Set hasPair = 0
    Set pairCount = 0
    Set hasThree = 0
    Set hasFour = 0

    Set rank = ""
    For {
        Set rank = $Order(counts(rank))
        Quit:rank=""

        If counts(rank) >= 2 {
            Set hasPair = 1
            Set pairCount = pairCount + 1
        }

        If counts(rank) = 3 {
            Set hasThree = 1
        }

        If counts(rank) >= 4 {
            Set hasFour = 1
        }
    }

    If hasFour {
        Return 100
    }

    If hasThree {
        Return 90
    }

    If pairCount >= 2 {
        Return 80
    }

    If hasPair {
        Return 60
    }

    Return 10
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

ClassMethod BuildRankCounts(cards As %DynamicArray)
{
    Kill counts

    For i=0:1:cards.%Size()-1 {
        Set rank = ..MusRank(cards.%Get(i))
        Set counts(rank) = $Get(counts(rank)) + 1
    }

    Return "counts"
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
      Por si en algún sitio aparecen letras.
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
    If play = "juego" {
        Return "Hand points: "_..HandPoints(cards)_"; strength: "_strength
    }

    If play = "punto" {
        Return "Point value: "_..HandPoints(cards)_"; strength: "_strength
    }

    Return "Estimated "_play_" score: "_score_"; strength: "_strength
}

}
