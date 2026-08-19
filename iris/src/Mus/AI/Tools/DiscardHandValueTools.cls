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

    Set startedAt = ##class(Mus.Data.AgentToolLog).NowMs()
    Set toolInput = {
        "cards": (cards),
        "isLastToSpeak": (+isLastToSpeak),
        "rivalMusCount": (+rivalMusCount),
        "teammateMusCount": (+teammateMusCount)
    }

    Try {
        Set cardArray = ..ParseCards(cards)

        If '$IsObject(cardArray) || cardArray.%Size() = 0 {
            Do result.%Set("success", "false")
            Do result.%Set("reason", "No cards provided")
            Return ##class(Mus.Data.AgentToolLog).FinishToolCall("evaluate_discard_hand_value", toolInput, result, startedAt)
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

        Set gamePoints = ..HandPoints(cardArray)
        Set pairInfo = ..BuildPairInfo(cardArray)
        Set pairType = pairInfo.%Get("pairType", "none")
        Set highestPairRank = +pairInfo.%Get("highestPairRank", 0)

        /*
          La decision de descartes no debe ser el maximo de los lances.
          Cortar mus exige una mano con estructura global, o un lance
          excepcional de verdad. Una chica fuerte aislada no basta.
        */
        Set score = 0
        Set score = score + ..StrengthScore(grande)
        Set score = score + ..StrengthScore(chica)
        Set score = score + (1.5 * ..StrengthScore(pares))
        Set score = score + (2 * ..StrengthScore(juego))

        /* Punto solo cuenta si no hay juego. */
        If gamePoints < 31 {
            Set score = score + ..StrengthScore(punto)
        }

        /* Bonos estructurales: solo para juego real o pares realmente fuertes. */
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

        /*
          Un par bajo aislado no debe inflar la fuerza global.
          Ejemplo: 2E,1B,4O,11O tiene par de ases por mus, pero no es mano
          globalmente fuerte para cortar.
        */
        If (pairType = "pares") && (highestPairRank >= 10) {
            Set score = score + 6
        }

        Set strongLanceCount = ..CountAtLeastStrong(grande, chica, pares, juego, punto, gamePoints)
        Set playableLanceCount = ..CountAtLeastNeutral(grande, chica, pares, juego, punto, gamePoints)
        Set exceptional = ..HasExceptionalCutReason(chica, grande, pares, juego, punto, gamePoints, pairType)

        /*
          Penalizacion para manos de una sola dimension:
          una sola fortaleza aislada debe pedir mus salvo posicion muy clara.
        */
        If (strongLanceCount <= 1) && 'exceptional {
            If score > 48 {
                Set score = 48
            }
        }

        Set positionAdjustment = "none"

        /*
          Si soy ultimo y rivales han pedido mus, se puede mejorar un poco una
          mano borderline, pero nunca convertir una mano pobre en strong.
        */
        If +isLastToSpeak && (+rivalMusCount > 0) {
            If score >= 40 {
                Set score = score + (4 * +rivalMusCount)
                Set positionAdjustment = "upgrade"
            }
        }

        /*
          Si mi companero pide mus, cortar debe ser mas conservador.
        */
        If +teammateMusCount > 0 {
            If score < 80 {
                Set score = score - (6 * +teammateMusCount)
                Set positionAdjustment = $Select(positionAdjustment="upgrade":"mixed", 1:"downgrade")
            }
        }

        If score < 0 { Set score = 0 }
        If score > 140 { Set score = 140 }

        Set globalStrength = ..ScoreToGlobalStrength(score, strongLanceCount, playableLanceCount, exceptional)
        Set recommendedBias = ..BuildRecommendedBias(globalStrength, score, gamePoints, pairType, highestPairRank, strongLanceCount, playableLanceCount, exceptional, +isLastToSpeak, +rivalMusCount)

        Do components.%Set("pairInfo", pairInfo)

        Do result.%Set("success", "true")
        Do result.%Set("globalStrength", globalStrength)
        Do result.%Set("recommendedBias", recommendedBias)
        Do result.%Set("positionAdjustment", positionAdjustment)
        Do result.%Set("score", score)
        Do result.%Set("handPoints", gamePoints)
        Do result.%Set("pairType", pairType)
        Do result.%Set("highestPairRank", highestPairRank)
        Do result.%Set("strongLanceCount", strongLanceCount)
        Do result.%Set("playableLanceCount", playableLanceCount)
        Do result.%Set("exceptionalCutReason", exceptional)
        Do result.%Set("components", components)
        Do result.%Set("reason", ..BuildReason(globalStrength, recommendedBias, score, gamePoints, pairType, highestPairRank, strongLanceCount, playableLanceCount, exceptional, positionAdjustment, +isLastToSpeak, +rivalMusCount, +teammateMusCount))

        Return ##class(Mus.Data.AgentToolLog).FinishToolCall("evaluate_discard_hand_value", toolInput, result, startedAt)
    } Catch ex {
        Do result.%Set("success", "false")
        Do result.%Set("reason", ex.DisplayString())
        Return ##class(Mus.Data.AgentToolLog).FinishToolCall("evaluate_discard_hand_value", toolInput, result, startedAt)
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
    If first >= 10 { Return "weak" }
    If (first <= 4) && (second <= 4) && (third <= 4) { Return "very weak" }
    Return "weak"
}

ClassMethod EvaluateChica(cards As %DynamicArray) As %String
{
    Set lowCount = 0
    Set veryLowCount = 0
    Set highCount = 0

    If '$IsObject(cards) { Return "neutral" }

    For i=0:1:cards.%Size()-1 {
        Set value = ##class(Mus.Util.MusRules).GetMusCardValue(cards.%Get(i))

        If value = 1 {
            Set veryLowCount = veryLowCount + 1
            Set lowCount = lowCount + 1
        } ElseIf value <= 4 {
            Set lowCount = lowCount + 1
        } ElseIf value >= 10 {
            Set highCount = highCount + 1
        }
    }

    If veryLowCount >= 3 { Return "very strong" }
    If (veryLowCount >= 2) && (lowCount >= 4) { Return "very strong" }
    If (veryLowCount >= 2) && (lowCount >= 3) { Return "strong" }
    If lowCount >= 3 { Return "strong" }
    If lowCount >= 2 { Return "neutral" }
    If highCount >= 3 { Return "very weak" }
    Return "weak"
}

ClassMethod EvaluatePares(cards As %DynamicArray) As %String
{
    Set pairInfo = ..BuildPairInfo(cards)
    Set pairType = pairInfo.%Get("pairType", "none")
    Set highestPairRank = +pairInfo.%Get("highestPairRank", 0)

    If pairType = "duples" { Return "very strong" }
    If pairType = "medias" { Return "strong" }

    If pairType = "pares" {
        If highestPairRank >= 10 { Return "neutral" }
        Return "weak"
    }

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
    Set info = ..BuildPairInfo(cards)
    Return info.%Get("pairType", "none")
}

ClassMethod BuildPairInfo(cards As %DynamicArray) As %DynamicObject
{
    Set info = {
        "pairType": "none",
        "pairCount": 0,
        "highestPairRank": 0,
        "hasThree": false,
        "hasFour": false
    }

    Kill counts

    If '$IsObject(cards) { Return info }

    For i=0:1:cards.%Size()-1 {
        Set value = ##class(Mus.Util.MusRules).GetMusCardValue(cards.%Get(i))
        Set counts(value) = $Get(counts(value)) + 1
    }

    Set pairCount = 0
    Set highestPairRank = 0
    Set hasThree = 0
    Set hasFour = 0

    Set value = ""
    For {
        Set value = $Order(counts(value))
        Quit:value=""

        If counts(value) >= 2 {
            Set pairCount = pairCount + 1
            If +value > highestPairRank {
                Set highestPairRank = +value
            }
        }

        If counts(value) = 3 {
            Set hasThree = 1
        }

        If counts(value) >= 4 {
            Set hasFour = 1
        }
    }

    Do info.%Set("pairCount", pairCount)
    Do info.%Set("highestPairRank", highestPairRank)
    Do info.%Set("hasThree", hasThree)
    Do info.%Set("hasFour", hasFour)

    If hasFour {
        Do info.%Set("pairType", "duples")
    } ElseIf pairCount >= 2 {
        Do info.%Set("pairType", "duples")
    } ElseIf hasThree {
        Do info.%Set("pairType", "medias")
    } ElseIf pairCount = 1 {
        Do info.%Set("pairType", "pares")
    }

    Return info
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
    If strength = "neutral" { Return 8 }
    If strength = "weak" { Return 3 }
    If strength = "very weak" { Return 0 }
    Return 8
}

ClassMethod CountAtLeastStrong(grande As %String, chica As %String, pares As %String, juego As %String, punto As %String, handPoints As %Integer) As %Integer
{
    Set count = 0

    If ..IsAtLeastStrong(grande) { Set count = count + 1 }
    If ..IsAtLeastStrong(chica) { Set count = count + 1 }
    If ..IsAtLeastStrong(pares) { Set count = count + 1 }
    If ..IsAtLeastStrong(juego) { Set count = count + 1 }

    If handPoints < 31 {
        If ..IsAtLeastStrong(punto) { Set count = count + 1 }
    }

    Return count
}

ClassMethod CountAtLeastNeutral(grande As %String, chica As %String, pares As %String, juego As %String, punto As %String, handPoints As %Integer) As %Integer
{
    Set count = 0

    If ..IsAtLeastNeutral(grande) { Set count = count + 1 }
    If ..IsAtLeastNeutral(chica) { Set count = count + 1 }
    If ..IsAtLeastNeutral(pares) { Set count = count + 1 }
    If ..IsAtLeastNeutral(juego) { Set count = count + 1 }

    If handPoints < 31 {
        If ..IsAtLeastNeutral(punto) { Set count = count + 1 }
    }

    Return count
}

ClassMethod IsAtLeastStrong(strength As %String) As %Boolean
{
    Set strength = $ZConvert(strength, "L")
    Return (strength = "strong") || (strength = "very strong")
}

ClassMethod IsAtLeastNeutral(strength As %String) As %Boolean
{
    Set strength = $ZConvert(strength, "L")
    Return (strength = "neutral") || (strength = "strong") || (strength = "very strong")
}

ClassMethod HasExceptionalCutReason(chica As %String, grande As %String, pares As %String, juego As %String, punto As %String, handPoints As %Integer, pairType As %String) As %Boolean
{
    If juego = "very strong" { Return 1 }
    If (pairType = "duples") || (pairType = "medias") { Return 1 }
    If (grande = "very strong") && ..IsAtLeastNeutral(pares) { Return 1 }
    If (chica = "very strong") && (..IsAtLeastNeutral(pares) || ..IsAtLeastNeutral(punto)) { Return 1 }
    If (handPoints = 30) { Return 1 }
    Return 0
}

ClassMethod ScoreToGlobalStrength(score As %Integer, strongLanceCount As %Integer = 0, playableLanceCount As %Integer = 0, exceptional As %Boolean = 0) As %String
{
    If +exceptional && (score >= 70) { Return "strong" }
    If +exceptional && (score >= 90) { Return "very strong" }

    If score >= 95 {
        If strongLanceCount >= 2 { Return "very strong" }
        Return "strong"
    }

    If score >= 72 {
        If (strongLanceCount >= 2) || (+exceptional) { Return "strong" }
        Return "neutral"
    }

    If score >= 48 {
        Return "neutral"
    }

    If score >= 25 {
        Return "weak"
    }

    Return "very weak"
}

ClassMethod BuildRecommendedBias(globalStrength As %String, score As %Integer, handPoints As %Integer, pairType As %String, highestPairRank As %Integer, strongLanceCount As %Integer, playableLanceCount As %Integer, exceptional As %Boolean, isLastToSpeak As %Boolean, rivalMusCount As %Integer) As %String
{
    If globalStrength = "very strong" {
        Return "cut_mus"
    }

    If globalStrength = "strong" {
        If (strongLanceCount >= 2) || (+exceptional) {
            Return "cut_mus"
        }
        Return "borderline_cut"
    }

    If globalStrength = "neutral" {
        If +isLastToSpeak && (+rivalMusCount > 0) && (score >= 55) {
            Return "borderline_cut"
        }
        Return "borderline"
    }

    Return "ask_mus"
}

ClassMethod BuildReason(globalStrength As %String, recommendedBias As %String, score As %Integer, handPoints As %Integer, pairType As %String, highestPairRank As %Integer, strongLanceCount As %Integer, playableLanceCount As %Integer, exceptional As %Boolean, positionAdjustment As %String, isLastToSpeak As %Boolean, rivalMusCount As %Integer, teammateMusCount As %Integer) As %String
{
    Set reason = "globalStrength="_globalStrength_"; recommendedBias="_recommendedBias
    Set reason = reason_"; score="_score_"; points="_handPoints_"; pairType="_pairType
    Set reason = reason_"; highestPairRank="_highestPairRank
    Set reason = reason_"; strongLances="_strongLanceCount_"; playableLances="_playableLanceCount

    If +exceptional {
        Set reason = reason_"; exceptionalCutReason=1"
    }

    If positionAdjustment '= "none" {
        Set reason = reason_"; positionAdjustment="_positionAdjustment
    }

    Return reason
}

}
