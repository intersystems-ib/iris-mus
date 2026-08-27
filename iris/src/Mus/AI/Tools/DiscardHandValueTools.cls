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

        Do result.%Set("normalizedCards", cardArray)
        Do result.%Set("normalizedCardCount", $Select($IsObject(cardArray):cardArray.%Size(), 1:0))

        If '$IsObject(cardArray) || cardArray.%Size() = 0 {
            Do result.%Set("success", 0)
            Do result.%Set("reason", "No cards provided")
            Return result
        }

        If cardArray.%Size() '= 4 {
            Do result.%Set("success", 0)
            Do result.%Set("reason", "Expected exactly 4 normalized cards")
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

        Set gamePoints = ..HandPoints(cardArray)
        Set pairInfo = ..BuildPairInfo(cardArray)
        Set pairType = pairInfo.%Get("pairType", "none")
        Set highestPairRank = +pairInfo.%Get("highestPairRank", 0)

        /*
          cardAnalysis es consumido por MusAgentClient para construir las
          candidatas de descarte. Debe estar siempre presente.
        */
        Set cardAnalysis = ..BuildCardAnalysis(cardArray)

        /*
          FUERZA GLOBAL DE DESCARTE
          -------------------------
          La fuerza global NO se obtiene sumando scores ni por tener un unico
          lance excepcional.

          Se toman los lances realmente jugables:
            - grande y chica siempre;
            - pares solo si la mano tiene pares;
            - juego si hay juego (>=31);
            - punto solo si NO hay juego.

          La fuerza global es la SEGUNDA MEJOR clasificacion entre esos lances.
          Asi hacen falta dos lances que sostengan la mano:

            VS + VS -> very strong
            VS + S  -> strong
            S  + S  -> strong
            VS + N  -> neutral
            S  + N  -> neutral
            N  + N  -> neutral
            N  + W  -> weak
            W  + W  -> weak
            cualquier combinacion cuya segunda mejor sea VW -> very weak

          Esto evita que un 31 aislado convierta toda la mano en very strong.
        */
        Set globalStrength = ..CombineGlobalStrength(
            grande,
            chica,
            pares,
            juego,
            punto,
            gamePoints,
            pairType
        )

        Set strongLanceCount = ..CountAtLeastStrong(grande, chica, pares, juego, punto, gamePoints)
        Set playableLanceCount = ..CountAtLeastNeutral(grande, chica, pares, juego, punto, gamePoints)

        /*
          score queda como diagnostico ordinal, pero NO decide globalStrength.
        */
        Set score = ..GlobalStrengthDiagnosticScore(
            grande,
            chica,
            pares,
            juego,
            punto,
            gamePoints,
            pairType
        )

        Set exceptional = 0
        Set positionAdjustment = "none"

        /*
          La posicion puede modular el bias, pero no cambiar la clasificacion
          mecanica de la mano.
        */
        If +isLastToSpeak && (+rivalMusCount > 0) {
            Set positionAdjustment = "context"
        }

        If +teammateMusCount > 0 {
            Set positionAdjustment = $Select(positionAdjustment="context":"mixed", 1:"context")
        }

        Set recommendedBias = ..BuildRecommendedBias(
            globalStrength,
            score,
            gamePoints,
            pairType,
            highestPairRank,
            strongLanceCount,
            playableLanceCount,
            exceptional,
            +isLastToSpeak,
            +rivalMusCount
        )

        Do components.%Set("pairInfo", pairInfo)

        Do result.%Set("success", 1)
        Do result.%Set("globalStrength", globalStrength)
        Do result.%Set("recommendedBias", recommendedBias)
        Do result.%Set("positionAdjustment", positionAdjustment)
        Do result.%Set("score", score)
        Do result.%Set("handPoints", gamePoints)
        Do result.%Set("pairType", pairType)
        Do result.%Set("highestPairRank", highestPairRank)
        Do result.%Set("cardAnalysis", cardAnalysis)
        Do result.%Set("strongLanceCount", strongLanceCount)
        Do result.%Set("playableLanceCount", playableLanceCount)
        Do result.%Set("exceptionalCutReason", exceptional)
        Do result.%Set("components", components)
        Do result.%Set("reason", ..BuildReason(globalStrength, recommendedBias, score, gamePoints, pairType, highestPairRank, strongLanceCount, playableLanceCount, exceptional, positionAdjustment, +isLastToSpeak, +rivalMusCount, +teammateMusCount))

        Return result
    } Catch ex {
        Do result.%Set("success", 0)
        Do result.%Set("reason", ex.DisplayString())
        Return result
    }
}

ClassMethod ParseCards(cards) As %DynamicArray
{
    Set arr = []

    /*
      La tool puede recibir cards como:
        - %DynamicArray real
        - JSON: ["10O","12C","2C","11O"]
        - string estilo Python generado por llama.cpp:
          ['10O', '12C', '2C', '11O']

      La normalizacion es puramente mecanica.
    */
    If $IsObject(cards) {
        For i=0:1:cards.%Size()-1 {
            Set card = ..NormalizeSingleCard(cards.%Get(i))
            If card '= "" {
                Do arr.%Push(card)
            }
        }
        Return arr
    }

    Set cards = $ZStrip(cards, "<>W")

    If cards = "" {
        Return arr
    }

    /*
      Primero intentamos JSON correcto.
    */
    Try {
        Set parsed = [].%FromJSON(cards)

        If $IsObject(parsed) {
            For i=0:1:parsed.%Size()-1 {
                Set card = ..NormalizeSingleCard(parsed.%Get(i))
                If card '= "" {
                    Do arr.%Push(card)
                }
            }

            Return arr
        }
    } Catch exJson {
    }

    /*
      Fallback para representacion tipo Python.
    */
    Set normalized = cards

    If $Extract(normalized, 1) = "[" {
        Set normalized = $Extract(normalized, 2, *)
    }

    If $Extract(normalized, *) = "]" {
        Set normalized = $Extract(normalized, 1, *-1)
    }

    For i=1:1:$Length(normalized, ",") {
        Set card = $Piece(normalized, ",", i)
        Set card = ..NormalizeSingleCard(card)

        If card '= "" {
            Do arr.%Push(card)
        }
    }

    Return arr
}

ClassMethod NormalizeSingleCard(card As %String) As %String
{
    Set card = $ZStrip(card, "<>W")

    /*
      Quitamos comillas simples/dobles externas que llegan en listas Python.
    */
    If ($Extract(card,1) = "'") && ($Extract(card,*) = "'") {
        Set card = $Extract(card,2,*-1)
    }

    If ($Extract(card,1) = """") && ($Extract(card,*) = """") {
        Set card = $Extract(card,2,*-1)
    }

    Set card = $ZStrip(card, "<>W")
    Set card = $ZConvert(card, "U")

    Return card
}

ClassMethod EvaluateGrande(cards As %DynamicArray) As %String
{
    Return ##class(Mus.AI.Helpers.HandStrengthHelper).EvaluateStrength(cards, "grande")
}

ClassMethod EvaluateChica(cards As %DynamicArray) As %String
{
    Return ##class(Mus.AI.Helpers.HandStrengthHelper).EvaluateStrength(cards, "chica")
}

ClassMethod EvaluatePares(cards As %DynamicArray) As %String
{
    Set score = ##class(Mus.AI.Helpers.HandStrengthHelper).Score(cards, "pares")
    Return ##class(Mus.AI.Helpers.HandStrengthHelper).ScoreToStrength(score, "pares")
}

ClassMethod EvaluateJuego(cards As %DynamicArray) As %String
{
    Set score = ##class(Mus.AI.Helpers.HandStrengthHelper).Score(cards, "juego")
    Return ##class(Mus.AI.Helpers.HandStrengthHelper).ScoreToStrength(score, "juego")
}

ClassMethod EvaluatePunto(cards As %DynamicArray) As %String
{
    Set score = ##class(Mus.AI.Helpers.HandStrengthHelper).Score(cards, "punto")
    Return ##class(Mus.AI.Helpers.HandStrengthHelper).ScoreToStrength(score, "punto")
}

ClassMethod BuildCardAnalysis(cards As %DynamicArray) As %DynamicArray
{
    Set analysis = []

    If '$IsObject(cards) {
        Return analysis
    }

    /*
      Primero contamos rangos equivalentes de Mus para detectar pareja,
      medias y duples. 2=As y 3=Rey.
    */
    Kill counts

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set musRank = ##class(Mus.AI.Helpers.HandStrengthHelper).MusRank(card)
        Set counts(musRank) = $Get(counts(musRank)) + 1
    }

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set rawRank = ##class(Mus.AI.Helpers.HandStrengthHelper).ExtractRank(card)
        Set musRank = ##class(Mus.AI.Helpers.HandStrengthHelper).MusRank(card)
        Set pointValue = ##class(Mus.AI.Helpers.HandStrengthHelper).MusPointValue(card)
        Set groupSize = +$Get(counts(musRank), 1)

        /*
          Estas banderas no calculan estrategia final; describen propiedades
          mecanicas que MusAgentClient ya utiliza para proteger cartas.

          Grande:
            figuras 10/11/Rey-3 se consideran cartas valiosas.

          Chica:
            As/2 se considera carta valiosa.
        */
        Set valuableForGrande = $Select(musRank>=10:1, 1:0)
        Set valuableForChica = $Select(musRank=1:1, 1:0)
        Set partOfPair = $Select(groupSize>=2:1, 1:0)

        Set item = {}
        Do item.%Set("card", card)
        Do item.%Set("rawRank", rawRank)
        Do item.%Set("musRank", musRank)
        Do item.%Set("cardPointValue", pointValue)
        Do item.%Set("valuableForGrande", valuableForGrande)
        Do item.%Set("valuableForChica", valuableForChica)
        Do item.%Set("partOfPair", partOfPair)
        Do item.%Set("pairGroupSize", groupSize)

        Do analysis.%Push(item)
    }

    Return analysis
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

ClassMethod StrengthRank(strength As %String) As %Integer
{
    Set strength = $ZConvert(strength, "L")

    If strength = "very strong" { Return 4 }
    If strength = "strong" { Return 3 }
    If strength = "neutral" { Return 2 }
    If strength = "weak" { Return 1 }
    Return 0
}

ClassMethod StrengthFromRank(rank As %Integer) As %String
{
    If rank >= 4 { Return "very strong" }
    If rank = 3 { Return "strong" }
    If rank = 2 { Return "neutral" }
    If rank = 1 { Return "weak" }
    Return "very weak"
}

ClassMethod CombineGlobalStrength(
    grande As %String,
    chica As %String,
    pares As %String,
    juego As %String,
    punto As %String,
    handPoints As %Integer,
    pairType As %String
) As %String
{
    /*
      Fuerza global:
        - Grande siempre
        - Chica siempre
        - Pares solo si existen
        - Juego solo si existe (handPoints >= 31)
        - Punto NO participa nunca en globalStrength

      Punto se mantiene como diagnostico del lance individual, pero no debe
      elevar la valoracion estructural de la mano para decidir cortar Mus.
    */
    Set ranks = []

    Do ranks.%Push(..StrengthRank(grande))
    Do ranks.%Push(..StrengthRank(chica))

    If pairType '= "none" {
        Do ranks.%Push(..StrengthRank(pares))
    }

    If handPoints >= 31 {
        Do ranks.%Push(..StrengthRank(juego))
    }

    Do ..SortRanksDescending(ranks)

    If ranks.%Size() < 2 {
        Return "very weak"
    }

    Set best = +ranks.%Get(0)
    Set second = +ranks.%Get(1)

    /*
      Ranks:
        4 = very strong
        3 = strong
        2 = neutral
        1 = weak
        0 = very weak
    */
    If best = 4 {
        If second = 4 { Return "very strong" }
        If second = 3 { Return "strong" }
        If second = 2 { Return "strong" }
        Return "neutral"
    }

    If best = 3 {
        If second = 3 { Return "strong" }
        If second = 2 { Return "neutral" }
        Return "weak"
    }

    If best = 2 {
        If second = 2 { Return "neutral" }
        If second = 1 { Return "weak" }
        Return "very weak"
    }

    If best = 1 {
        If second = 1 { Return "weak" }
        Return "very weak"
    }

    Return "very weak"
}

ClassMethod SortRanksDescending(ranks As %DynamicArray)
{
    If '$IsObject(ranks) {
        Return
    }

    For i=0:1:ranks.%Size()-2 {
        For j=i+1:1:ranks.%Size()-1 {
            If +ranks.%Get(j) > +ranks.%Get(i) {
                Set tmp = ranks.%Get(i)
                Do ranks.%Set(i, ranks.%Get(j))
                Do ranks.%Set(j, tmp)
            }
        }
    }
}

ClassMethod GlobalStrengthDiagnosticScore(
    grande As %String,
    chica As %String,
    pares As %String,
    juego As %String,
    punto As %String,
    handPoints As %Integer,
    pairType As %String
) As %Integer
{
    /*
      Solo diagnostico ordinal de los lances que participan en globalStrength.
      Punto queda excluido incluso cuando no hay Juego.
    */
    Set total = ..StrengthRank(grande) + ..StrengthRank(chica)

    If pairType '= "none" {
        Set total = total + ..StrengthRank(pares)
    }

    If handPoints >= 31 {
        Set total = total + ..StrengthRank(juego)
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

    If handPoints >= 31 {
        If ..IsAtLeastStrong(juego) { Set count = count + 1 }
    }

    Return count
}

ClassMethod CountAtLeastNeutral(grande As %String, chica As %String, pares As %String, juego As %String, punto As %String, handPoints As %Integer) As %Integer
{
    Set count = 0

    If ..IsAtLeastNeutral(grande) { Set count = count + 1 }
    If ..IsAtLeastNeutral(chica) { Set count = count + 1 }
    If ..IsAtLeastNeutral(pares) { Set count = count + 1 }

    If handPoints >= 31 {
        If ..IsAtLeastNeutral(juego) { Set count = count + 1 }
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
    /*
      El bias parte exclusivamente de la fuerza global combinada.
      Ningun lance aislado (incluido 31) puede forzar cut_mus.
    */
    If globalStrength = "very strong" {
        Return "cut_mus"
    }

    If globalStrength = "strong" {
        Return "cut_mus"
    }

    If globalStrength = "neutral" {
        If +isLastToSpeak && (+rivalMusCount > 0) {
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
