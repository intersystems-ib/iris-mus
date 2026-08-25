Class Mus.AI.Helpers.DiscardHandValueHelper Extends %RegisteredObject
{

ClassMethod ParseCards(cards As %String) As %DynamicArray
{
    Set arr = []

    If cards = "" {
        Return arr
    }

    /*
      Primero intentamos JSON real:
      ["7C","4C","5E","2O"]
    */
    Try {
        Set parsed = [].%FromJSON(cards)
        If $IsObject(parsed) {
            Return parsed
        }
    } Catch exJson {
    }

    /*
      Algunos modelos envian el array como string con sintaxis Python:
      ['7C','4C','5E','2O']

      El parser anterior separaba por comas pero conservaba [, ], ' y ",
      provocando que GetMusCardValue recibiera valores como "['7C'".
      Eso devolvia 0 para todas las cartas:
        - HandPoints = 0
        - counts(0) = 4
        - pairType = duples
        - highestPairRank = 0

      Aqui normalizamos solo el transporte; no hacemos ninguna evaluacion
      estrategica.
    */
    Set normalized = $ZStrip(cards, "<>W")

    If $Extract(normalized, 1) = "[" {
        Set normalized = $Extract(normalized, 2, *)
    }

    If $Extract(normalized, *) = "]" {
        Set normalized = $Extract(normalized, 1, $Length(normalized)-1)
    }

    For i=1:1:$Length(normalized, ",") {
        Set card = $ZStrip($Piece(normalized, ",", i), "<>W")

        If ($Extract(card, 1) = "'") || ($Extract(card, 1) = """") {
            Set card = $Extract(card, 2, *)
        }

        If ($Extract(card, *) = "'") || ($Extract(card, *) = """") {
            Set card = $Extract(card, 1, $Length(card)-1)
        }

        Set card = $ZConvert($ZStrip(card, "<>W"), "U")

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

    /*
      Construimos el vector con equivalencias reales de Mus:
      3 = rey (12), 2 = as (1).
      Asi esta evaluacion queda alineada con cardAnalysis y pares.
    */
    Set vector = ..BuildGrandeVector(cards)
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
        Set value = ..CardMusRank(cards.%Get(i))

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
        "hasThree": 0,
        "hasFour": 0
    }

    Kill counts

    If '$IsObject(cards) { Return info }

    /*
      Los pares deben usar el rango de Mus, no el valor de puntos:
      - 2 cuenta como as
      - 3 cuenta como rey
      - 10/11/12 conservan su rango para comparar pares
    */
    For i=0:1:cards.%Size()-1 {
        Set value = ..CardMusRank(cards.%Get(i))
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
        Set total = total + ..CardPointValue(cards.%Get(i))
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

    /*
      30 es el mejor punto, pero por si solo no debe convertir una mano
      globalmente pobre en "exceptional". Exigimos estructura adicional.
    */
    If (handPoints = 30) {
        If ..IsAtLeastNeutral(pares) || ..IsAtLeastNeutral(grande) || ..IsAtLeastNeutral(chica) {
            Return 1
        }
    }

    Return 0
}

ClassMethod ScoreToGlobalStrength(score As %Integer, strongLanceCount As %Integer = 0, playableLanceCount As %Integer = 0, exceptional As %Boolean = 0) As %String
{
    If +exceptional && (score >= 90) { Return "very strong" }
    If +exceptional && (score >= 70) { Return "strong" }

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

ClassMethod BuildGrandeVector(cards As %DynamicArray) As %DynamicArray
{
    Set vector = []

    If '$IsObject(cards) {
        Return vector
    }

    Kill values

    For i=0:1:cards.%Size()-1 {
        Set values(i+1) = ..CardMusRank(cards.%Get(i))
    }

    /*
      Solo hay cuatro cartas; ordenacion simple descendente para mantener
      el helper autocontenido y evitar depender de una conversion distinta.
    */
    For i=1:1:4 {
        Set maxIndex = 0
        Set maxValue = -1

        For j=1:1:cards.%Size() {
            If $Data(values(j)) {
                If values(j) > maxValue {
                    Set maxValue = values(j)
                    Set maxIndex = j
                }
            }
        }

        If maxIndex > 0 {
            Do vector.%Push(maxValue)
            Kill values(maxIndex)
        }
    }

    Return vector
}

ClassMethod CardRawRank(card As %String) As %Integer
{
    Set card = $ZConvert($ZStrip(card, "<>W"), "U")
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

    /* Equivalencias de Mus. */
    If rank = 2 { Return 1 }
    If rank = 3 { Return 12 }

    Return rank
}

ClassMethod CardPointValue(card As %String) As %Integer
{
    Set rank = ..CardRawRank(card)

    If (rank = 1) || (rank = 2) { Return 1 }
    If (rank = 3) || (rank >= 10) { Return 10 }

    Return rank
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
