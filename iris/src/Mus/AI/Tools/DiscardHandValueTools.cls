Class Mus.AI.Tools.DiscardHandValueTools Extends %AI.Tool
{

ClassMethod EvaluateDiscardHandValue(cards As %String, isLastToSpeak As %Boolean = 0, rivalMusCount As %Integer = 0, teammateMusCount As %Integer = 0) As %DynamicObject
{
    Set result = {
        "success": false,
        "globalStrength": "neutral",
        "recommendedBias": "borderline",
        "positionAdjustment": "none",
        "reason": "",
        "isLastToSpeak": (+isLastToSpeak),
        "rivalMusCount": (+rivalMusCount),
        "teammateMusCount": (+teammateMusCount),
        "components": {}
    }

    Try {
        Set cardArray = ..ParseCards(cards)

        If '$IsObject(cardArray) || cardArray.%Size() = 0 {
            Do result.%Set("success", "false")
            Do result.%Set("reason", "No cards provided")
            Return result
        }

        Set components = {}
        Set grande = ..EvaluateGrande(cardArray)
        Set chica = ..EvaluateChica(cardArray)
        Set pares = ..EvaluatePares(cardArray)
        Set juego = ..EvaluateJuego(cardArray)
        Set punto = ..EvaluatePunto(cardArray)

        Do components.%Set("grande", grande)
        Do components.%Set("chica", chica)
        Do components.%Set("pares", pares)
        Do components.%Set("juego", juego)
        Do components.%Set("punto", punto)
        Do result.%Set("components", components)

        Set score = 0
        Set score = score + ..StrengthScore(grande)
        Set score = score + ..StrengthScore(chica)
        Set score = score + (2 * ..StrengthScore(pares))
        Set score = score + (2 * ..StrengthScore(juego))

        /* punto only matters when there is no juego */
        If ..HandPoints(cardArray) < 31 {
            Set score = score + ..StrengthScore(punto)
        }

        Set gamePoints = ..HandPoints(cardArray)
        Set pairType = ..PairType(cardArray)

        If gamePoints >= 31 {
            Set score = score + 25
        }

        If (pairType = "duples") || (pairType = "medias") {
            Set score = score + 30
        } ElseIf pairType = "pares" {
            Set score = score + 12
        }

        Set positionAdjustment = "none"

        If +isLastToSpeak && (+rivalMusCount > 0) {
            If score >= 45 {
                Set score = score + (8 * +rivalMusCount)
                Set positionAdjustment = "upgrade"
            }
        }

        If +teammateMusCount > 0 {
            If score < 80 {
                Set score = score - (4 * +teammateMusCount)
                Set positionAdjustment = $Select(positionAdjustment="upgrade":"mixed", 1:"downgrade")
            }
        }

        If score < 0 { Set score = 0 }
        If score > 140 { Set score = 140 }

        Set globalStrength = ..ScoreToGlobalStrength(score)
        Set recommendedBias = ..BuildRecommendedBias(globalStrength, gamePoints, pairType, +isLastToSpeak, +rivalMusCount)

        Do result.%Set("success", "true")
        Do result.%Set("globalStrength", globalStrength)
        Do result.%Set("recommendedBias", recommendedBias)
        Do result.%Set("positionAdjustment", positionAdjustment)
        Do result.%Set("score", score)
        Do result.%Set("handPoints", gamePoints)
        Do result.%Set("pairType", pairType)
        Do result.%Set("reason", ..BuildReason(globalStrength, recommendedBias, gamePoints, pairType, positionAdjustment, +isLastToSpeak, +rivalMusCount, +teammateMusCount))

        Return result
    } Catch ex {
        Do result.%Set("success", "false")
        Do result.%Set("reason", ex.DisplayString())
        Return result
    }
}

ClassMethod ParseCards(cards As %String) As %DynamicArray
{
    Set arr = []

    If cards = "" {
        Return arr
    }

    Try {
        Set parsed = [].%FromJSON(cards)
        If $IsObject(parsed) {
            Return parsed
        }
    } Catch exJson {
    }

    For i=1:1:$Length(cards, ",") {
        Set card = $ZStrip($Piece(cards, ",", i), "<>W")
        If card '= "" {
            Do arr.%Push(card)
        }
    }

    Return arr
}

ClassMethod EvaluateGrande(cards As %DynamicArray) As %String
{
    If '$IsObject(cards) { Return "neutral" }
    If cards.%Size() = 0 { Return "neutral" }

    Set vector = ##class(Mus.Util.MusRules).GetGrandeVector(cards)
    Set first = +vector.%Get(0)
    Set second = +vector.%Get(1)
    Set third = +vector.%Get(2)

    If (first >= 10) && (second >= 10) && (third >= 9) { Return "very strong" }
    If (first >= 10) && (second >= 10) { Return "strong" }
    If (first >= 10) && (second >= 9) && (third >= 8) { Return "strong" }
    If first >= 10 { Return "neutral" }
    If (first <= 4) && (second <= 4) && (third <= 4) { Return "weak" }
    Return "neutral"
}

ClassMethod EvaluateChica(cards As %DynamicArray) As %String
{
    Set lowCount = 0
    Set veryLowCount = 0
    Set highCount = 0

    If '$IsObject(cards) { Return "neutral" }

    For i=0:1:cards.%Size()-1 {
        Set value = ##class(Mus.Util.MusRules).GetMusCardValue(cards.%Get(i))

        If (value = 1) || (value = 2) {
            Set veryLowCount = veryLowCount + 1
            Set lowCount = lowCount + 1
        } ElseIf value <= 4 {
            Set lowCount = lowCount + 1
        } ElseIf value >= 10 {
            Set highCount = highCount + 1
        }
    }

    If veryLowCount >= 3 { Return "very strong" }
    If (veryLowCount >= 2) && (lowCount >= 3) { Return "very strong" }
    If veryLowCount >= 2 { Return "strong" }
    If lowCount >= 3 { Return "strong" }
    If lowCount >= 2 { Return "neutral" }
    If highCount >= 3 { Return "very weak" }
    Return "weak"
}

ClassMethod EvaluatePares(cards As %DynamicArray) As %String
{
    Set pairType = ..PairType(cards)

    If pairType = "duples" { Return "very strong" }
    If pairType = "medias" { Return "very strong" }
    If pairType = "pares" { Return "strong" }
    Return "very weak"
}

ClassMethod EvaluateJuego(cards As %DynamicArray) As %String
{
    Set points = ..HandPoints(cards)

    If points = 31 { Return "very strong" }
    If points = 32 { Return "strong" }
    If points >= 33 { Return "strong" }
    Return "very weak"
}

ClassMethod EvaluatePunto(cards As %DynamicArray) As %String
{
    Set points = ..HandPoints(cards)

    If points >= 31 { Return "neutral" }
    If points = 30 { Return "very strong" }
    If points = 29 { Return "strong" }
    If points = 28 { Return "strong" }
    If points >= 26 { Return "neutral" }
    If points >= 24 { Return "weak" }
    Return "very weak"
}

ClassMethod PairType(cards As %DynamicArray) As %String
{
    Kill counts

    If '$IsObject(cards) { Return "none" }

    For i=0:1:cards.%Size()-1 {
        Set value = ##class(Mus.Util.MusRules).GetMusCardValue(cards.%Get(i))
        Set counts(value) = $Get(counts(value)) + 1
    }

    Set pairCount = 0
    Set hasThree = 0
    Set hasFour = 0

    Set value = ""
    For {
        Set value = $Order(counts(value))
        Quit:value=""

        If counts(value) >= 2 {
            Set pairCount = pairCount + 1
        }
        If counts(value) = 3 {
            Set hasThree = 1
        }
        If counts(value) >= 4 {
            Set hasFour = 1
        }
    }

    If hasFour { Return "duples" }
    If pairCount >= 2 { Return "duples" }
    If hasThree { Return "medias" }
    If pairCount = 1 { Return "pares" }
    Return "none"
}

ClassMethod HandPoints(cards As %DynamicArray) As %Integer
{
    Set total = 0

    If '$IsObject(cards) { Return 0 }

    For i=0:1:cards.%Size()-1 {
        Set value = ##class(Mus.Util.MusRules).GetMusCardValue(cards.%Get(i))
        If value >= 10 {
            Set total = total + 10
        } Else {
            Set total = total + value
        }
    }

    Return total
}

ClassMethod StrengthScore(strength As %String) As %Integer
{
    Set strength = $ZConvert(strength, "L")

    If strength = "very strong" { Return 25 }
    If strength = "strong" { Return 18 }
    If strength = "neutral" { Return 10 }
    If strength = "weak" { Return 4 }
    If strength = "very weak" { Return 0 }
    Return 10
}

ClassMethod ScoreToGlobalStrength(score As %Integer) As %String
{
    If score >= 95 { Return "very strong" }
    If score >= 70 { Return "strong" }
    If score >= 45 { Return "neutral" }
    If score >= 25 { Return "weak" }
    Return "very weak"
}

ClassMethod BuildRecommendedBias(globalStrength As %String, handPoints As %Integer, pairType As %String, isLastToSpeak As %Boolean, rivalMusCount As %Integer) As %String
{
    If (globalStrength = "very strong") || (globalStrength = "strong") {
        Return "cut_mus"
    }

    If (handPoints >= 31) && ((pairType = "pares") || (pairType = "medias") || (pairType = "duples")) {
        Return "cut_mus"
    }

    If (globalStrength = "neutral") {
        If +isLastToSpeak && (+rivalMusCount > 0) {
            Return "borderline_cut"
        }
        Return "borderline"
    }

    Return "ask_mus"
}

ClassMethod BuildReason(globalStrength As %String, recommendedBias As %String, handPoints As %Integer, pairType As %String, positionAdjustment As %String, isLastToSpeak As %Boolean, rivalMusCount As %Integer, teammateMusCount As %Integer) As %String
{
    Set reason = "Global hand strength is "_globalStrength_"; recommended bias is "_recommendedBias_"."
    Set reason = reason_" Hand points: "_handPoints_"; pairs: "_pairType_"."

    If positionAdjustment = "upgrade" {
        Set reason = reason_" Position upgrade: player speaks last and rivals asked mus."
    } ElseIf positionAdjustment = "downgrade" {
        Set reason = reason_" Position downgrade: teammate asked mus, reducing confidence in cutting."
    } ElseIf positionAdjustment = "mixed" {
        Set reason = reason_" Mixed position signals: rivals and teammate asked mus."
    }

    Return reason
}

}
