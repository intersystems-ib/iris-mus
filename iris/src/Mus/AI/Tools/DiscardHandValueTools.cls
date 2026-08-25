Class Mus.AI.Tools.DiscardHandValueTools Extends %AI.Tool
{

ClassMethod EvaluateDiscardHandValue(cards As %String, isLastToSpeak As %Integer = 0, rivalMusCount As %Integer = 0, teammateMusCount As %Integer = 0) As %DynamicObject
{
    Set result = {
        "success": 0,
        "globalStrength": "neutral",
        "recommendedBias": "borderline"
    }

    Try {
        Set cardArray = ##class(Mus.AI.Helpers.DiscardHandValueHelper).ParseCards(cards)

        If '$IsObject(cardArray) || cardArray.%Size() = 0 {
            Do result.%Set("success", 0)
            Return result
        }

        Set components = {}
        Set grande = ##class(Mus.AI.Helpers.DiscardHandValueHelper).EvaluateGrande(cardArray)
        Set chica = ##class(Mus.AI.Helpers.DiscardHandValueHelper).EvaluateChica(cardArray)
        Set pares = ##class(Mus.AI.Helpers.DiscardHandValueHelper).EvaluatePares(cardArray)
        Set juego = ##class(Mus.AI.Helpers.DiscardHandValueHelper).EvaluateJuego(cardArray)
        Set punto = ##class(Mus.AI.Helpers.DiscardHandValueHelper).EvaluatePunto(cardArray)

        Do components.%Set("grande", grande)
        Do components.%Set("chica", chica)
        Do components.%Set("pares", pares)
        Do components.%Set("juego", juego)
        Do components.%Set("punto", punto)

        Set gamePoints = ##class(Mus.AI.Helpers.DiscardHandValueHelper).HandPoints(cardArray)
        Set pairInfo = ##class(Mus.AI.Helpers.DiscardHandValueHelper).BuildPairInfo(cardArray)
        Set pairType = pairInfo.%Get("pairType", "none")
        Set highestPairRank = +pairInfo.%Get("highestPairRank", 0)

        /*
          Analisis objetivo por carta para la segunda sesion LLM.
          No elige descartes ni recomienda una accion concreta.
        */
        Set cardAnalysis = ..BuildCardAnalysis(cardArray)
        Do result.%Set("cardAnalysis", cardAnalysis)

        Set score = 0
        Set score = score + ##class(Mus.AI.Helpers.DiscardHandValueHelper).StrengthScore(grande)
        Set score = score + ##class(Mus.AI.Helpers.DiscardHandValueHelper).StrengthScore(chica)
        Set score = score + (1.5 * ##class(Mus.AI.Helpers.DiscardHandValueHelper).StrengthScore(pares))
        Set score = score + (2 * ##class(Mus.AI.Helpers.DiscardHandValueHelper).StrengthScore(juego))

        If gamePoints < 31 {
            Set score = score + ##class(Mus.AI.Helpers.DiscardHandValueHelper).StrengthScore(punto)
        }

        If gamePoints >= 31 {
            If gamePoints = 31 {
                Set score = score + 18
            } ElseIf gamePoints = 32 {
                Set score = score + 12
            } Else {
                Set score = score + 8
            }
        }

        If (pairType = "duples") || (pairType = "medias") {
            Set score = score + 22
        }

        If (pairType = "pares") && (highestPairRank >= 10) {
            Set score = score + 6
        }

        Set strongLanceCount = ##class(Mus.AI.Helpers.DiscardHandValueHelper).CountAtLeastStrong(grande, chica, pares, juego, punto, gamePoints)
        Set playableLanceCount = ##class(Mus.AI.Helpers.DiscardHandValueHelper).CountAtLeastNeutral(grande, chica, pares, juego, punto, gamePoints)
        Set exceptional = ##class(Mus.AI.Helpers.DiscardHandValueHelper).HasExceptionalCutReason(chica, grande, pares, juego, punto, gamePoints, pairType)

        If (strongLanceCount <= 1) && 'exceptional {
            If score > 48 {
                Set score = 48
            }
        }

        Set positionAdjustment = "none"

        If +isLastToSpeak && (+rivalMusCount > 0) {
            If score >= 40 {
                Set score = score + (4 * +rivalMusCount)
                Set positionAdjustment = "upgrade"
            }
        }

        If +teammateMusCount > 0 {
            If score < 80 {
                Set score = score - (6 * +teammateMusCount)
                Set positionAdjustment = $Select(positionAdjustment="upgrade":"mixed", 1:"downgrade")
            }
        }

        If score < 0 { Set score = 0 }
        If score > 140 { Set score = 140 }

        Set globalStrength = ##class(Mus.AI.Helpers.DiscardHandValueHelper).ScoreToGlobalStrength(score, strongLanceCount, playableLanceCount, exceptional)
        Set recommendedBias = ##class(Mus.AI.Helpers.DiscardHandValueHelper).BuildRecommendedBias(globalStrength, score, gamePoints, pairType, highestPairRank, strongLanceCount, playableLanceCount, exceptional, +isLastToSpeak, +rivalMusCount)

        Do components.%Set("pairInfo", pairInfo)

        Do result.%Set("success", 1)
        Do result.%Set("globalStrength", globalStrength)
        Do result.%Set("recommendedBias", recommendedBias)
        Do result.%Set("score", score)
        Do result.%Set("handPoints", gamePoints)
        Do result.%Set("pairType", pairType)
        Do result.%Set("highestPairRank", highestPairRank)
        Do result.%Set("strongLanceCount", strongLanceCount)
        Do result.%Set("playableLanceCount", playableLanceCount)
        Do result.%Set("exceptionalCutReason", exceptional)

        Return result
    } Catch ex {
        Do result.%Set("success", 0)
        Return result
    }
}

ClassMethod BuildCardAnalysis(cardArray As %DynamicArray) As %DynamicArray
{
    Set out = []

    If '$IsObject(cardArray) {
        Return out
    }

    Kill rankCount

    For i=0:1:cardArray.%Size()-1 {
        Set card = cardArray.%Get(i)
        Set musRank = ..CardMusRank(card)
        Set rankCount(musRank) = $Get(rankCount(musRank)) + 1
    }

    For i=0:1:cardArray.%Size()-1 {
        Set card = cardArray.%Get(i)
        Set rawRank = ..CardRawRank(card)
        Set musRank = ..CardMusRank(card)
        Set pointValue = ..CardPointValue(card)
        Set pairGroupSize = +$Get(rankCount(musRank), 0)

        Set valuableForGrande = 0
        If musRank >= 10 {
            Set valuableForGrande = 1
        }

        Set valuableForChica = 0
        If musRank = 1 {
            Set valuableForChica = 1
        }

        Set partOfPair = $Select(pairGroupSize >= 2:1, 1:0)

        Set item = {
            "card": (card),
            "rawRank": (+rawRank),
            "musRank": (+musRank),
            "cardPointValue": (+pointValue),
            "valuableForGrande": (+valuableForGrande),
            "valuableForChica": (+valuableForChica),
            "partOfPair": (+partOfPair),
            "pairGroupSize": (+pairGroupSize)
        }

        Do out.%Push(item)
    }

    Return out
}

ClassMethod CardRawRank(card As %String) As %Integer
{
    Set card = $ZCONVERT($ZSTRIP(card, "<>W"), "U")
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

    If $Extract(card, 1) = "A" { Return 1 }
    If $Extract(card, 1) = "S" { Return 10 }
    If $Extract(card, 1) = "C" { Return 11 }
    If $Extract(card, 1) = "R" { Return 12 }

    Return 0
}

ClassMethod CardMusRank(card As %String) As %Integer
{
    Set rank = ..CardRawRank(card)

    If rank = 2 {
        Return 1
    }

    If rank = 3 {
        Return 12
    }

    Return rank
}

ClassMethod CardPointValue(card As %String) As %Integer
{
    Set rank = ..CardRawRank(card)

    If (rank = 1) || (rank = 2) {
        Return 1
    }

    If (rank = 3) || (rank >= 10) {
        Return 10
    }

    Return rank
}

}
