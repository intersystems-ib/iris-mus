Class Mus.AI.Helpers.HandStrengthHelper Extends %RegisteredObject
{

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

ClassMethod BuildReason(cards As %DynamicArray, play As %String, score As %Integer, strength As %String) As %String
{
    Set reason = "play="_play_"; strength="_strength_"; score="_score

    If $IsObject(cards) {
        Set reason = reason_"; cards="_cards.%Size()
    }

    If play = "pares", $IsObject(cards) {
        Set pairInfo = ..BuildParesInfo(cards)
        Set reason = reason_"; pairType="_pairInfo.%Get("pairType", "none")
        Set reason = reason_"; highestPairRank="_+pairInfo.%Get("highestPairRank", 0)
        Set reason = reason_"; pairCount="_+pairInfo.%Get("pairCount", 0)
    }

    Return reason
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
    Set info = ..BuildParesInfo(cards)

    Set pairType = info.%Get("pairType", "none")
    Set highestPairRank = +info.%Get("highestPairRank", 0)

    /*
      Calibracion especifica del lance de pares.

      Jerarquia:
      - cuatro iguales: maxima fuerza;
      - medias: muy fuerte;
      - duples: fuerte/muy fuerte;
      - par alto (sotas/caballos/reyes): strong;
      - par medio: neutral;
      - par bajo: weak;
      - sin pares: very weak.
    */
    If pairType = "duples4" {
        Return 100
    }

    If pairType = "medias" {
        Return 90
    }

    If pairType = "duples" {
        Return 85
    }

    If pairType = "pares" {
        /*
          MusRank normaliza:
          3 -> 12 (rey)
          2 -> 1  (as)
        */
        If highestPairRank >= 10 {
            Return 75
        }

        If highestPairRank >= 7 {
            Return 55
        }

        Return 35
    }

    Return 10
}

ClassMethod BuildParesInfo(cards As %DynamicArray) As %DynamicObject
{
    Set info = {
        "pairType": "none",
        "pairCount": 0,
        "highestPairRank": 0,
        "hasThree": 0,
        "hasFour": 0
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

ClassMethod MusPointValue(card As %String) As %Integer
{
    Set rank = ..ExtractRank(card)

    If rank = 3 {
        Return 10
    }

    If rank = 2 {
        Return 1
    }

    If rank >= 10 {
        Return 10
    }

    Return rank
}

ClassMethod HandPoints(cards As %DynamicArray) As %Integer
{
    Set total = 0

    If '$IsObject(cards) {
        Return 0
    }

    For i=0:1:cards.%Size()-1 {
        Set total = total + ..MusPointValue(cards.%Get(i))
    }

    Return total
}

}
