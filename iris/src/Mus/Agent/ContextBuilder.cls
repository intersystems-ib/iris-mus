Class Mus.Agent.ContextBuilder Extends %RegisteredObject
{

ClassMethod BuildForPlayer(gameState As %DynamicObject, playerId As %String) As %DynamicObject
{
    Set context = {}

    If '$IsObject(gameState) {
        Do context.%Set("error", "INVALID_GAME_STATE")
        Do context.%Set("legalActions", [])
        Return context
    }

    Set hand = gameState.%Get("hand", "")
    Set cards = []

    If $IsObject(hand) {
        Set allCards = hand.%Get("cards", "")

        If $IsObject(allCards) {
            Set playerCards = allCards.%Get(playerId, "")

            If $IsObject(playerCards) {
                Set cards = playerCards
            }
        }
    }

    Set team = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, playerId)

    Do context.%Set("playerId", playerId)
    Do context.%Set("team", team)
    Do context.%Set("phase", gameState.%Get("phase", ""))
    Do context.%Set("turnPlayerId", gameState.%Get("turnPlayerId", ""))
    Do context.%Set("status", gameState.%Get("status", ""))
    Do context.%Set("targetScore", +gameState.%Get("targetScore", 40))

    If $IsObject(gameState.%Get("score", "")) {
        Do context.%Set("score", gameState.%Get("score"))
    } Else {
        Do context.%Set("score", {
            "teamA": 0,
            "teamB": 0
        })
    }

    Do context.%Set("cards", cards)

    Set evaluation = {}

    If cards.%Size() > 0 {
        Do evaluation.%Set("grandeVector", ##class(Mus.Util.MusRules).GetGrandeVector(cards))
        Do evaluation.%Set("chicaVector", ##class(Mus.Util.MusRules).GetChicaVector(cards))
        Do evaluation.%Set("pares", ##class(Mus.Util.MusRules).AnalyzePares(cards))
        Do evaluation.%Set("juego", ##class(Mus.Util.MusRules).AnalyzeJuego(cards))
        Do evaluation.%Set("punto", ##class(Mus.Util.MusRules).AnalyzePunto(cards))
    } Else {
        Do evaluation.%Set("grandeVector", [])
        Do evaluation.%Set("chicaVector", [])
        Do evaluation.%Set("pares", {
            "hasPares": 0,
            "type": "none",
            "rank": 0,
            "vector": [0]
        })
        Do evaluation.%Set("juego", {
            "hasJuego": 0,
            "total": 0,
            "rankWeight": 0,
            "vector": [0, 0]
        })
        Do evaluation.%Set("punto", {
            "total": 0,
            "vector": [0]
        })
    }

    Do context.%Set("handEvaluation", evaluation)

    Set currentPhase = gameState.%Get("phase", "")

    If currentPhase = "descartes" {
        Do context.%Set("phaseState", {})
    } ElseIf $IsObject(hand), $IsObject(hand.%Get("phaseState", "")) {
        Do context.%Set("phaseState", hand.%Get("phaseState"))
    } Else {
        Do context.%Set("phaseState", {})
    }

    Do context.%Set("legalActions", ..GetLegalActionsFromState(gameState, playerId))
    Do context.%Set("profile", ##class(Mus.Agent.PlayerProfile).GetProfileForGameState(gameState, playerId))
    Do context.%Set("scorePressure", ..BuildScorePressure(gameState, playerId))

    If currentPhase = "descartes" {
        Do context.%Set("bettingGuidance", {})
        Do context.%Set("discardGuidance", ..BuildDiscardGuidance(cards, evaluation))
    } Else {
        Do context.%Set("bettingGuidance", ..BuildBettingGuidance(gameState, playerId, cards))
    }

    Return context
}

ClassMethod BuildParesSummary(cards As %DynamicArray) As %DynamicObject
{
    Set summary = {}
    Do summary.%Set("hasPares", 0)
    Do summary.%Set("type", "none")
    Do summary.%Set("groups", [])
    Do summary.%Set("message", "No hay pares.")

    If '$IsObject(cards) {
        Return summary
    }

    Set groups = []
    Set pairGroupCount = 0
    Set maxCount = 0
    Set bestPairRank = 0
    Set bestCards = []

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set rank = ..GetCardRank(card)
        Set pairRank = ..GetMusPairRank(rank)

        If rank = 0 {
            Continue
        }

        Set alreadySeen = 0

        For j=0:1:i-1 {
            If ..GetMusPairRank(..GetCardRank(cards.%Get(j))) = pairRank {
                Set alreadySeen = 1
            }
        }

        If alreadySeen {
            Continue
        }

        Set groupCards = []
        Set count = 0

        For k=0:1:cards.%Size()-1 {
            Set otherCard = cards.%Get(k)
            Set otherRank = ..GetCardRank(otherCard)

            If ..GetMusPairRank(otherRank) = pairRank {
                Set count = count + 1
                Do groupCards.%Push(otherCard)
            }
        }

        Set group = {}
        Do group.%Set("pairRank", pairRank)
        Do group.%Set("displayRank", ..GetPairRankDisplay(pairRank))
        Do group.%Set("count", count)
        Do group.%Set("cards", groupCards)

        If count >= 2 {
            Do group.%Set("formsPares", 1)
            Set pairGroupCount = pairGroupCount + 1
        } Else {
            Do group.%Set("formsPares", 0)
        }

        If count > maxCount {
            Set maxCount = count
            Set bestPairRank = pairRank
            Set bestCards = groupCards
        }

        Do groups.%Push(group)
    }

    Do summary.%Set("groups", groups)

    If maxCount < 2 {
        Return summary
    }

    Do summary.%Set("hasPares", 1)
    Do summary.%Set("bestPairRank", bestPairRank)
    Do summary.%Set("bestDisplayRank", ..GetPairRankDisplay(bestPairRank))
    Do summary.%Set("bestCards", bestCards)

    If (pairGroupCount >= 2) {
        Do summary.%Set("type", "duples")
        Do summary.%Set("message", "Tienes duples. En Mus, 1 y 2 son equivalentes para pares, y 3 y 12 tambien.")
        Return summary
    }

    If maxCount >= 3 {
        Do summary.%Set("type", "medias")
        Do summary.%Set("message", "Tienes medias de "_..GetPairRankDisplay(bestPairRank)_". No es una mano floja; cortar MUS es muy razonable.")
        Return summary
    }

    Do summary.%Set("type", "pares")
    Do summary.%Set("message", "Tienes pares de "_..GetPairRankDisplay(bestPairRank)_". No rompas la pareja salvo razon clara.")

    Return summary
}

ClassMethod BuildPairSummaryMessage(pairRanks As %DynamicArray, pairCards As %DynamicArray) As %String
{
    If '$IsObject(pairRanks) || pairRanks.%Size() = 0 {
        Return "No hay pares detectados."
    }

    Set ranksText = ""

    For i=0:1:pairRanks.%Size()-1 {
        If i > 0 {
            Set ranksText = ranksText_", "
        }

        Set pairRank = pairRanks.%Get(i)

        If pairRank = 1 {
            Set ranksText = ranksText_"1/2"
        } ElseIf pairRank = 12 {
            Set ranksText = ranksText_"3/12"
        } Else {
            Set ranksText = ranksText_pairRank
        }
    }

    Set cardsText = ""

    If $IsObject(pairCards) {
        For j=0:1:pairCards.%Size()-1 {
            If j > 0 {
                Set cardsText = cardsText_", "
            }

            Set cardsText = cardsText_pairCards.%Get(j)
        }
    }

    Set message = "Tienes pares de "_ranksText

    If cardsText '= "" {
        Set message = message_" con cartas "_cardsText
    }

    Set message = message_". En Mus, 1 y 2 son equivalentes para pares; 3 y 12 tambien son equivalentes. No rompas esta pareja salvo razon extraordinaria."

    Return message
}

ClassMethod BuildDiscardHandQuality(cards As %DynamicArray, evaluation As %DynamicObject) As %DynamicObject
{
    Set quality = {}
    Do quality.%Set("level", "unknown")
    Do quality.%Set("hasMadeHand", 0)
    Do quality.%Set("hasOnlyContextualProtection", 0)
    Do quality.%Set("musFriendly", 0)
    Do quality.%Set("reason", "No se pudo evaluar la calidad global de la mano.")

    If '$IsObject(cards) {
        Return quality
    }

    Set pares = ""
    Set juego = ""
    Set punto = ""

    If $IsObject(evaluation) {
        Set pares = evaluation.%Get("pares", "")
        Set juego = evaluation.%Get("juego", "")
        Set punto = evaluation.%Get("punto", "")
    }

    Set hasPares = 0
    Set paresType = "none"
    If $IsObject(pares) {
        Set hasPares = +pares.%Get("hasPares", 0)
        Set paresType = pares.%Get("type", "none")
    }

    Set hasJuego = 0
    Set juegoTotal = 0
    If $IsObject(juego) {
        Set hasJuego = +juego.%Get("hasJuego", 0)
        Set juegoTotal = +juego.%Get("total", 0)
    }

    Set puntoTotal = 0
    If $IsObject(punto) {
        Set puntoTotal = +punto.%Get("total", 0)
    }

    If hasJuego || hasPares {
        Do quality.%Set("hasMadeHand", 1)
    }

    If hasJuego && hasPares {
        Do quality.%Set("level", "strong")
        Do quality.%Set("musFriendly", 0)
        Do quality.%Set("reason", "La mano tiene juego y pares; hay valor real que proteger.")
        Return quality
    }

    If hasJuego {
        Do quality.%Set("level", "good")
        Do quality.%Set("musFriendly", 0)
        Do quality.%Set("reason", "La mano tiene juego hecho; normalmente conviene conservar.")
        Return quality
    }

    If hasPares {
        If (paresType = "duples") || (paresType = "medias") {
            Do quality.%Set("level", "strong")
            Do quality.%Set("musFriendly", 0)
            Do quality.%Set("reason", "La mano tiene "_paresType_"; hay una jugada fuerte que proteger.")
            Return quality
        }

        Do quality.%Set("level", "medium")
        Do quality.%Set("musFriendly", 1)
        Do quality.%Set("reason", "La mano tiene par simple; puede pedir MUS si conserva la pareja y mejora cartas sueltas.")
        Return quality
    }

    /*
      Caso clave:
      Sin pares ni juego, aunque haya cartas protegidas individualmente,
      no hay jugada hecha. Cortar suele ser demasiado conservador.
    */
    Do quality.%Set("level", "weak")
    Do quality.%Set("hasOnlyContextualProtection", ..HasOnlyContextualProtection(cards))
    Do quality.%Set("musFriendly", 1)
    Do quality.%Set("reason", "No hay pares ni juego. Aunque haya cartas con valor teorico, no hay jugada hecha que proteger; pedir MUS suele ser razonable.")

    If puntoTotal > 0 {
        Do quality.%Set("puntoTotal", puntoTotal)
    }

    Return quality
}

ClassMethod HasOnlyContextualProtection(cards As %DynamicArray) As %Boolean
{
    If '$IsObject(cards) {
        Return 0
    }

    Set hasAnyAbsolute = 0
    Set hasAnyContextual = 0

    For i=0:1:cards.%Size()-1 {
        Set rank = ..GetCardRank(cards.%Get(i))
        Set countRank = ..CountRank(cards, rank)
        Set level = ..GetProtectionLevel(rank, countRank)

        If (level = "absolute") || (level = "strong") {
            Set hasAnyAbsolute = 1
        }

        If level = "contextual" {
            Set hasAnyContextual = 1
        }
    }

    Return hasAnyContextual && 'hasAnyAbsolute
}

ClassMethod BuildDiscardGuidance(cards As %DynamicArray, evaluation As %DynamicObject) As %DynamicObject
{
    Set guidance = {}

    Do guidance.%Set("decisionType", "discard")
    Do guidance.%Set("availableActions", ["descartar", "cortar_mus"])

    Do guidance.%Set("actionMeanings", {
        "descartar": "Pedir MUS y proponer cartas concretas para descartar.",
        "cortar_mus": "Cortar MUS y conservar la mano actual."
    })

    Do guidance.%Set("outputContract", {
        "actionType": "Debe ser descartar o cortar_mus.",
        "amount": "Debe ser 0.",
        "discards": "Si actionType es descartar, debe contener cartas exactas de cards. Si actionType es cortar_mus, debe ser [].",
        "reason": "Explicacion breve, estrategica y humana.",
        "confidence": "Numero entre 0 y 1."
    })

    Do guidance.%Set("cardValueModel", ..BuildDiscardCardValueModel())
    Do guidance.%Set("madeHands", ..BuildMadeHandsSummary(evaluation, cards))
    Do guidance.%Set("handQuality", ..BuildDiscardHandQuality(cards, evaluation))
    Do guidance.%Set("decisionBias", ..BuildDiscardDecisionBias(cards, evaluation))
    Do guidance.%Set("paresSummary", ..BuildParesSummary(cards))
    Do guidance.%Set("expertPlan", ..BuildDiscardExpertPlan(cards, evaluation))
    Do guidance.%Set("discardCandidates", ..BuildDiscardCandidates(cards))
    Do guidance.%Set("juegoSummary", ..BuildJuegoSummary(cards))
    Do guidance.%Set("juegoBreakAnalysis", ..BuildJuegoBreakAnalysis(cards))
    Do guidance.%Set("strategicAdvice", ..BuildDiscardStrategicAdvice())

    Return guidance
}

ClassMethod BuildJuegoBreakAnalysis(cards As %DynamicArray) As %DynamicObject
{
    Set analysis = {}
    Do analysis.%Set("hasJuego", 0)
    Do analysis.%Set("juegoTotal", 0)
    Do analysis.%Set("is31", 0)
    Do analysis.%Set("hasStrongGrandeCards", 0)
    Do analysis.%Set("hasKingOrHorse", 0)
    Do analysis.%Set("hasPares", 0)
    Do analysis.%Set("paresType", "none")
    Do analysis.%Set("canConsiderBreakingJuego", 0)
    Do analysis.%Set("preferredAction", "cortar_mus")
    Do analysis.%Set("reason", "Sin analisis suficiente.")

    If '$IsObject(cards) {
        Return analysis
    }

    Set juegoTotal = ..GetMusJuegoTotal(cards)
    Do analysis.%Set("juegoTotal", juegoTotal)
    Do analysis.%Set("hasJuego", juegoTotal >= 31)
    Do analysis.%Set("is31", juegoTotal = 31)

    Set paresSummary = ..BuildParesSummary(cards)
    Set hasPares = +paresSummary.%Get("hasPares", 0)
    Set paresType = paresSummary.%Get("type", "none")

    Do analysis.%Set("hasPares", hasPares)
    Do analysis.%Set("paresType", paresType)

    Set hasKingOrHorse = 0
    Set hasStrongGrandeCards = 0
    Set hasKingPair = 0
    Set hasHorsePair = 0

    For i=0:1:cards.%Size()-1 {
        Set rank = ..GetCardRank(cards.%Get(i))
        Set countRank = ..CountRank(cards, rank)

        /*
          Para grande:
          3 y 12 cuentan como reyes.
          11 es caballo.
        */
        If (rank = 3) || (rank = 12) || (rank = 11) {
            Set hasKingOrHorse = 1
        }

        If (rank = 3) || (rank = 12) {
            Set hasStrongGrandeCards = 1

            If countRank >= 2 {
                Set hasKingPair = 1
            }
        }

        If rank = 11 {
            Set hasStrongGrandeCards = 1

            If countRank >= 2 {
                Set hasHorsePair = 1
            }
        }
    }

    Do analysis.%Set("hasKingOrHorse", hasKingOrHorse)
    Do analysis.%Set("hasStrongGrandeCards", hasStrongGrandeCards)
    Do analysis.%Set("hasKingPair", hasKingPair)
    Do analysis.%Set("hasHorsePair", hasHorsePair)

    If juegoTotal < 31 {
        Do analysis.%Set("preferredAction", "descartar")
        Do analysis.%Set("reason", "No hay juego hecho.")
        Return analysis
    }

    If juegoTotal > 31 {
        Do analysis.%Set("preferredAction", "cortar_mus")
        Do analysis.%Set("reason", "Hay juego hecho. Normalmente conviene conservar.")
        Return analysis
    }

    /*
      Juego a 31.
      Es fuerte, pero no siempre intocable.
    */
    If hasKingPair || hasHorsePair {
        Do analysis.%Set("preferredAction", "cortar_mus")
        Do analysis.%Set("canConsiderBreakingJuego", 0)
        Do analysis.%Set("reason", "Juego a 31 con pares de reyes o caballos. Es una mano fuerte en juego, grande y pares; conviene cortar MUS.")
        Return analysis
    }

    If hasPares && ((paresType = "medias") || (paresType = "duples")) {
        Do analysis.%Set("preferredAction", "cortar_mus")
        Do analysis.%Set("canConsiderBreakingJuego", 0)
        Do analysis.%Set("reason", "Juego a 31 con medias o duples. Hay demasiada estructura fuerte que proteger.")
        Return analysis
    }

    If hasPares {
        Do analysis.%Set("preferredAction", "cortar_mus")
        Do analysis.%Set("canConsiderBreakingJuego", 0)
        Do analysis.%Set("reason", "Juego a 31 con pares. Normalmente se conserva la mano.")
        Return analysis
    }

    If 'hasKingOrHorse {
        Do analysis.%Set("preferredAction", "descartar")
        Do analysis.%Set("canConsiderBreakingJuego", 1)
        Do analysis.%Set("reason", "Juego a 31 sin reyes ni caballos y sin pares. Puede considerarse romper el juego para intentar mejorar a grande y pares.")
        Return analysis
    }

    /*
      Tiene 31 y alguna carta alta, pero sin pares fuertes.
      Puede considerarse, aunque cortar sigue siendo muy razonable.
    */
    Do analysis.%Set("preferredAction", "cortar_mus")
    Do analysis.%Set("canConsiderBreakingJuego", 1)
    Do analysis.%Set("reason", "Juego a 31 sin pares fuertes. Cortar MUS es razonable, pero se puede considerar pedir MUS si el objetivo es mejorar grande o pares.")

    Return analysis
}

ClassMethod GetPairRankDisplay(pairRank As %Integer) As %String
{
    If pairRank = 1 {
        Return "1/2"
    }

    If pairRank = 12 {
        Return "3/12"
    }

    Return pairRank
}

ClassMethod BuildJuegoSummary(cards As %DynamicArray) As %DynamicObject
{
    Set summary = {}
    Do summary.%Set("total", 0)
    Do summary.%Set("hasJuego", 0)
    Do summary.%Set("isBestJuego", 0)
    Do summary.%Set("cardValues", [])
    Do summary.%Set("message", "No se pudo calcular juego.")

    If '$IsObject(cards) {
        Return summary
    }

    Set total = 0
    Set values = []

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set rank = ..GetCardRank(card)
        Set value = ..GetMusJuegoValue(rank)

        Set item = {}
        Do item.%Set("card", card)
        Do item.%Set("rank", rank)
        Do item.%Set("juegoValue", value)

        Do values.%Push(item)

        Set total = total + value
    }

    Do summary.%Set("total", total)
    Do summary.%Set("hasJuego", total >= 31)
    Do summary.%Set("isBestJuego", total = 31)
    Do summary.%Set("cardValues", values)

    If total >= 31 {
        If total = 31 {
            Do summary.%Set("message", "Tiene juego a 31. Es una mano muy fuerte para juego; normalmente debe cortar MUS.")
        } Else {
            Do summary.%Set("message", "Tiene juego. Normalmente debe conservar la mano y cortar MUS.")
        }
    } Else {
        Do summary.%Set("message", "No tiene juego.")
    }

    Return summary
}

ClassMethod BuildContextualDiscardCards(cards As %DynamicArray, maxCount As %Integer = 2) As %DynamicArray
{
    Set result = []

    If '$IsObject(cards) {
        Return result
    }

    /*
      Si no hay cartas claramente descartables, permitimos cartas de proteccion contextual.
      Preferimos 10/11 antes que 1/2 o 3/12, porque 1/2 pueden servir a chica
      y 3/12 son reyes.
    */
    For selected=1:1:maxCount {
        Set bestCard = ""
        Set bestScore = 999999

        For i=0:1:cards.%Size()-1 {
            Set card = cards.%Get(i)

            If ..ArrayContains(result, card) {
                Continue
            }

            Set rank = ..GetCardRank(card)
            Set countRank = ..CountRank(cards, rank)

            If countRank >= 2 {
                Continue
            }

            /*
              No tocar 3 ni 12 salvo otra iteracion futura.
            */
            If (rank = 3) || (rank = 12) {
                Continue
            }

            Set score = ..GetContextualDiscardScore(rank)

            If score < bestScore {
                Set bestScore = score
                Set bestCard = card
            }
        }

        If bestCard = "" {
            Quit
        }

        Do result.%Push(bestCard)
    }

    Return result
}

ClassMethod GetContextualDiscardScore(rank As %Integer) As %Integer
{
    /*
      Menor score = mas descartable cuando todo esta protegido.
      10/11 son sacrificables antes que 1/2 si la chica tiene algun valor.
      1/2 se tocan solo despues.
    */
    If rank = 10 {
        Return 20
    }

    If rank = 11 {
        Return 21
    }

    If rank = 2 {
        Return 35
    }

    If rank = 1 {
        Return 36
    }

    If rank = 4 {
        Return 10
    }

    If rank = 5 {
        Return 11
    }

    If rank = 6 {
        Return 12
    }

    If rank = 7 {
        Return 13
    }

    Return 999
}

ClassMethod BuildDiscardExpertPlan(cards As %DynamicArray, evaluation As %DynamicObject) As %DynamicObject
{
    Set plan = {}
    Do plan.%Set("recommendedAction", "neutral")
    Do plan.%Set("mustFollow", 0)
    Do plan.%Set("category", "unknown")
    Do plan.%Set("recommendedDiscards", [])
    Do plan.%Set("forbiddenDiscards", [])
    Do plan.%Set("keepCards", [])
    Do plan.%Set("summary", "Evalua la mano completa antes de decidir.")
    Do plan.%Set("confidence", 0.5)

    If '$IsObject(cards) {
        Do plan.%Set("recommendedAction", "cortar_mus")
        Do plan.%Set("mustFollow", 1)
        Do plan.%Set("category", "invalid_cards")
        Do plan.%Set("summary", "No hay cartas disponibles para planificar descarte.")
        Do plan.%Set("confidence", 0.2)
        Return plan
    }

    Set pares = ""
    Set juego = ""
    Set punto = ""

    If $IsObject(evaluation) {
        Set pares = evaluation.%Get("pares", "")
        Set juego = evaluation.%Get("juego", "")
        Set punto = evaluation.%Get("punto", "")
    }

    Set hasPares = 0
    Set paresType = "none"

    If $IsObject(pares) {
        Set hasPares = +pares.%Get("hasPares", 0)
        Set paresType = pares.%Get("type", "none")
    } Else {
        /*
          Fallback por si AnalyzePares no reconoce equivalencias 1/2 o 3/12.
        */
        Set paresInfo = ..BuildEquivalentParesInfo(cards)
        Set hasPares = +paresInfo.%Get("hasPares", 0)
        Set paresType = paresInfo.%Get("type", "none")
    }

    Set hasJuego = 0
    Set juegoTotal = 0

    If $IsObject(cards) {
        Set computedJuegoTotal = ..GetMusJuegoTotal(cards)

        If computedJuegoTotal >= 31 {
            Set hasJuego = 1
            Set juegoTotal = computedJuegoTotal
        }

        Set computedPares = ..BuildParesSummary(cards)

        If +computedPares.%Get("hasPares", 0) {
            Set hasPares = 1
            Set paresType = computedPares.%Get("type", "none")
        }
    }

    If $IsObject(juego) {
        Set hasJuego = +juego.%Get("hasJuego", 0)
        Set juegoTotal = +juego.%Get("total", 0)
    }

    /*
      CASO DOMINANTE:
      Juego + pares/medias/duples => cortar siempre como recomendacion experta.
    */
    If hasJuego && hasPares {
        Do plan.%Set("recommendedAction", "cortar_mus")
        Do plan.%Set("mustFollow", 1)
        Do plan.%Set("category", "juego_and_pares")
        Do plan.%Set("recommendedDiscards", [])
        Do plan.%Set("forbiddenDiscards", ..CopyCards(cards))
        Do plan.%Set("keepCards", ..CopyCards(cards))
        Do plan.%Set("summary", "Tienes juego y pares. Es una mano hecha en varios lances; pedir MUS o descartar seria una mala decision.")
        Do plan.%Set("confidence", 0.98)
        Do plan.%Set("juegoTotal", juegoTotal)
        Do plan.%Set("paresType", paresType)
        Return plan
    }

    /*
      Juego hecho sin pares: tambien es una mano que normalmente se conserva.
    */
    If hasJuego {
        Set breakAnalysis = ..BuildJuegoBreakAnalysis(cards)
        Set canBreakJuego = +breakAnalysis.%Get("canConsiderBreakingJuego", 0)
        Set preferredBreakAction = breakAnalysis.%Get("preferredAction", "cortar_mus")

        If canBreakJuego && (juegoTotal = 31) && (preferredBreakAction = "descartar") {
            Set discardables = ..BuildDiscardableCards(cards, 1)

            If '$IsObject(discardables) || (discardables.%Size() = 0) {
                Set discardables = ..BuildContextualJuegoBreakDiscards(cards, 1)
            }

            Do plan.%Set("recommendedAction", "descartar")
            Do plan.%Set("mustFollow", 0)
            Do plan.%Set("category", "breakable_31")
            Do plan.%Set("recommendedDiscards", discardables)
            Do plan.%Set("forbiddenDiscards", ..BuildStrongProtectedCards(cards))
            Do plan.%Set("keepCards", ..BuildKeepCards(cards))
            Do plan.%Set("summary", "Hay juego a 31, pero no hay pares fuertes ni reyes/caballos que hagan la mano completa. Puede pedirse MUS de forma agresiva para intentar mejorar grande y pares.")
            Do plan.%Set("confidence", 0.66)
            Do plan.%Set("juegoTotal", juegoTotal)
            Do plan.%Set("juegoBreakReason", breakAnalysis.%Get("reason", ""))
            Return plan
        }

        Do plan.%Set("recommendedAction", "cortar_mus")
        Do plan.%Set("mustFollow", $Select(hasPares:1, 1:0))
        Do plan.%Set("category", "juego")
        Do plan.%Set("recommendedDiscards", [])
        Do plan.%Set("forbiddenDiscards", ..CopyCards(cards))
        Do plan.%Set("keepCards", ..CopyCards(cards))
        Do plan.%Set("summary", "Tienes juego hecho. La recomendacion experta es cortar MUS y conservar la mano.")
        Do plan.%Set("confidence", 0.9)
        Do plan.%Set("juegoTotal", juegoTotal)
        Do plan.%Set("juegoBreakReason", breakAnalysis.%Get("reason", ""))
        Return plan
    }

    /*
      Medias o duples sin juego: jugada fuerte de pares.
    */
    If hasPares && ((paresType = "medias") || (paresType = "duples")) {
        Do plan.%Set("recommendedAction", "cortar_mus")
        Do plan.%Set("mustFollow", 0)
        Do plan.%Set("category", paresType)
        Do plan.%Set("recommendedDiscards", [])
        Do plan.%Set("forbiddenDiscards", ..BuildPairCards(cards))
        Do plan.%Set("keepCards", ..BuildKeepCards(cards))
        Do plan.%Set("summary", "Tienes "_paresType_". Cortar MUS es una decision muy razonable; pedir MUS solo tendria sentido si buscas mejorar una carta suelta sin tocar la jugada.")
        Do plan.%Set("confidence", $Select(paresType="duples":0.96, 1:0.9))
        Return plan
    }

    /*
      Par simple sin juego: puede pedir MUS, pero sin romper la pareja.
    */
    If hasPares {
        Set discardables = ..BuildDiscardableCards(cards, 2)

        If $IsObject(discardables), discardables.%Size() > 0 {
            Do plan.%Set("recommendedAction", "descartar")
            Do plan.%Set("mustFollow", 0)
            Do plan.%Set("category", "simple_pair")
            Do plan.%Set("recommendedDiscards", discardables)
            Do plan.%Set("forbiddenDiscards", ..BuildPairCards(cards))
            Do plan.%Set("keepCards", ..BuildKeepCards(cards))
            Do plan.%Set("summary", "Tienes par simple sin juego. Puedes pedir MUS, pero conservando la pareja y descartando solo cartas sueltas peores.")
            Do plan.%Set("confidence", 0.76)
            Return plan
        }

        Do plan.%Set("recommendedAction", "cortar_mus")
        Do plan.%Set("mustFollow", 0)
        Do plan.%Set("category", "simple_pair_no_safe_discard")
        Do plan.%Set("recommendedDiscards", [])
        Do plan.%Set("forbiddenDiscards", ..BuildPairCards(cards))
        Do plan.%Set("keepCards", ..BuildKeepCards(cards))
        Do plan.%Set("summary", "Tienes par simple, pero no hay descartes seguros claros.")
        Do plan.%Set("confidence", 0.68)
        Return plan
    }

    /*
      Sin pares ni juego: pedir MUS suele ser natural.
    */
    Set discardables = ..BuildDiscardableCards(cards, 2)

    If $IsObject(discardables), discardables.%Size() > 0 {
        Do plan.%Set("recommendedAction", "descartar")
        Do plan.%Set("mustFollow", 0)
        Do plan.%Set("category", "weak_hand")
        Do plan.%Set("recommendedDiscards", discardables)
        Do plan.%Set("forbiddenDiscards", ..BuildStrongProtectedCards(cards))
        Do plan.%Set("keepCards", ..BuildKeepCards(cards))
        Do plan.%Set("summary", "No tienes pares ni juego. La mano no tiene estructura fuerte que proteger; pedir MUS suele ser lo mas realista.")
        Do plan.%Set("confidence", 0.82)
        Return plan
    }

    Do plan.%Set("recommendedAction", "cortar_mus")
    Do plan.%Set("mustFollow", 0)
    Do plan.%Set("category", "no_clear_discard")
    Do plan.%Set("recommendedDiscards", [])
    Do plan.%Set("forbiddenDiscards", ..BuildStrongProtectedCards(cards))
    Do plan.%Set("keepCards", ..BuildKeepCards(cards))
    Do plan.%Set("summary", "No hay descarte seguro claro.")
    Do plan.%Set("confidence", 0.55)

    Return plan
}

ClassMethod BuildContextualJuegoBreakDiscards(cards As %DynamicArray, maxCount As %Integer = 1) As %DynamicArray
{
    Set result = []

    If '$IsObject(cards) {
        Return result
    }

    For selected=1:1:maxCount {
        Set bestCard = ""
        Set bestScore = 999999

        For i=0:1:cards.%Size()-1 {
            Set card = cards.%Get(i)

            If ..ArrayContains(result, card) {
                Continue
            }

            Set rank = ..GetCardRank(card)
            Set countRank = ..CountRank(cards, rank)

            If countRank >= 2 {
                Continue
            }

            /*
              No romper 3/12 salvo que se quiera una version aun mas agresiva.
              Preferimos sacrificar 10 u 11 antes que rey/3.
            */
            If (rank = 3) || (rank = 12) {
                Continue
            }

            Set score = ..GetJuegoBreakDiscardScore(rank)

            If score < bestScore {
                Set bestScore = score
                Set bestCard = card
            }
        }

        If bestCard = "" {
            Quit
        }

        Do result.%Push(bestCard)
    }

    Return result
}

ClassMethod GetJuegoBreakDiscardScore(rank As %Integer) As %Integer
{
    /*
      Menor score = mejor carta para romper 31.
      Si queremos mejorar grande/pares, normalmente sacrificamos la carta
      de menor aporte estructural.
    */
    If rank = 10 {
        Return 10
    }

    If rank = 11 {
        Return 15
    }

    If rank = 1 {
        Return 30
    }

    If rank = 2 {
        Return 31
    }

    If rank = 4 {
        Return 20
    }

    If rank = 5 {
        Return 21
    }

    If rank = 6 {
        Return 22
    }

    If rank = 7 {
        Return 23
    }

    Return 999
}

ClassMethod CopyCards(cards As %DynamicArray) As %DynamicArray
{
    Set result = []

    If '$IsObject(cards) {
        Return result
    }

    For i=0:1:cards.%Size()-1 {
        Do result.%Push(cards.%Get(i))
    }

    Return result
}

ClassMethod BuildEquivalentParesInfo(cards As %DynamicArray) As %DynamicObject
{
    Set info = {}
    Do info.%Set("hasPares", 0)
    Do info.%Set("type", "none")
    Do info.%Set("maxCount", 0)

    If '$IsObject(cards) {
        Return info
    }

    Set maxCount = 0
    Set pairGroups = 0

    For i=0:1:cards.%Size()-1 {
        Set rank = ..GetCardRank(cards.%Get(i))
        Set pairRank = ..GetMusPairRank(rank)

        Set alreadySeen = 0

        For j=0:1:i-1 {
            If ..GetMusPairRank(..GetCardRank(cards.%Get(j))) = pairRank {
                Set alreadySeen = 1
            }
        }

        If alreadySeen {
            Continue
        }

        Set count = ..CountRank(cards, rank)

        If count >= 2 {
            Set pairGroups = pairGroups + 1
        }

        If count > maxCount {
            Set maxCount = count
        }
    }

    Do info.%Set("maxCount", maxCount)

    If maxCount >= 2 {
        Do info.%Set("hasPares", 1)

        If (maxCount >= 2) && (pairGroups >= 2) {
            Do info.%Set("type", "duples")
        } ElseIf maxCount >= 3 {
            Do info.%Set("type", "medias")
        } Else {
            Do info.%Set("type", "pares")
        }
    }

    Return info
}

ClassMethod BuildPairCards(cards As %DynamicArray) As %DynamicArray
{
    Set result = []

    If '$IsObject(cards) {
        Return result
    }

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set rank = ..GetCardRank(card)

        If ..CountRank(cards, rank) >= 2 {
            Do result.%Push(card)
        }
    }

    Return result
}

ClassMethod BuildStrongProtectedCards(cards As %DynamicArray) As %DynamicArray
{
    Set result = []

    If '$IsObject(cards) {
        Return result
    }

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set rank = ..GetCardRank(card)
        Set countRank = ..CountRank(cards, rank)

        If countRank >= 2 {
            Do result.%Push(card)
            Continue
        }

        If (rank = 3) || (rank = 12) {
            Do result.%Push(card)
        }
    }

    Return result
}

ClassMethod GetDiscardCandidateScore(rank As %Integer) As %Integer
{
    If rank = 4 {
        Return 10
    }

    If rank = 5 {
        Return 11
    }

    If rank = 6 {
        Return 12
    }

    If rank = 7 {
        Return 13
    }

    /*
      10 y 11 tienen valor para juego, pero si no hay alternativa
      pueden ser menos criticas que 3/12 o parejas.
    */
    If rank = 10 {
        Return 30
    }

    If rank = 11 {
        Return 31
    }

    /*
      1 y 2 se preservan por chica, salvo no haya nada mejor.
    */
    If rank = 2 {
        Return 40
    }

    If rank = 1 {
        Return 41
    }

    Return 999
}

ClassMethod BuildKeepCards(cards As %DynamicArray) As %DynamicArray
{
    Set keep = []

    If '$IsObject(cards) {
        Return keep
    }

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set rank = ..GetCardRank(card)
        Set sameRankCount = ..CountRank(cards, rank)

        If ..ShouldAvoidDiscardRank(rank, sameRankCount) {
            Do keep.%Push(card)
        }
    }

    Return keep
}

ClassMethod BuildDiscardableCards(cards As %DynamicArray, maxCount As %Integer = 2) As %DynamicArray
{
    Set result = []

    If '$IsObject(cards) {
        Return result
    }

    For selected=1:1:maxCount {
        Set bestCard = ""
        Set bestScore = 999999

        For i=0:1:cards.%Size()-1 {
            Set card = cards.%Get(i)

            If ..ArrayContains(result, card) {
                Continue
            }

            Set rank = ..GetCardRank(card)
            Set sameRankCount = ..CountRank(cards, rank)

            If ..ShouldAvoidDiscardRank(rank, sameRankCount) {
                Continue
            }

            Set score = ..GetDiscardCandidateScore(rank)

            If score < bestScore {
                Set bestScore = score
                Set bestCard = card
            }
        }

        If bestCard = "" {
            Quit
        }

        Do result.%Push(bestCard)
    }

    Return result
}

ClassMethod BuildDiscardStrategicAdvice() As %DynamicArray
{
    Set advice = []

    Do advice.%Push("No estas obligado a descartar: cortar MUS es una decision valida si hay valor que proteger.")
    Do advice.%Push("Si no tienes pares ni juego, pedir MUS suele ser mas natural que cortar, porque la mano actual es floja.")
    Do advice.%Push("Con mano debil, el riesgo principal es cortar MUS y quedarte con una mano mala.")
    Do advice.%Push("Pedir MUS es razonable si hay cartas mejorables y no hay una jugada hecha que proteger.")
    Do advice.%Push("Si la mano ya tiene juego, pares fuertes, medias o duples, cortar MUS suele ser razonable.")
    Do advice.%Push("Tener pares simples no impide descartar cartas sueltas malas, pero no rompas la pareja.")
    Do advice.%Push("El 3 equivale al rey: evita descartarlo igual que evitarias descartar un rey.")
    Do advice.%Push("Las sotas, caballos y reyes valen 10 para juego; evita descartarlos salvo mejora muy clara.")
    Do advice.%Push("El 1 y el 2 tienen valor para chica; evita descartarlos salvo mejora clara.")
    Do advice.%Push("No descartes cartas con avoidDiscard = 1 salvo una mejora excepcional y claramente explicada.")
    Do advice.%Push("Si tu descarte incluye un 3, una sota, un caballo o un rey, tu razon debe justificar por que merece la pena perder una carta valiosa.")
    Do advice.%Push("Si la mejor opcion de descarte implica tirar una carta protegida, considera seriamente cortar MUS.")
    Do advice.%Push("Si eliges descartar, explica que mejora buscas.")
    Do advice.%Push("Si eliges cortar, explica que valor estas protegiendo.")
    Do advice.%Push("Una carta protegida individualmente no siempre justifica cortar MUS si la mano global es mala.")
    Do advice.%Push("Si no hay pares ni juego, y solo hay protecciones teoricas, pedir MUS puede ser mejor que cortar.")
    Do advice.%Push("No confundas cartas con valor potencial con una jugada hecha.")
    Do advice.%Push("En Mus, 1 y 2 son equivalentes para pares: una mano con 1 y 2 tiene pares.")
    Do advice.%Push("En Mus, 3 y 12 son equivalentes para pares: una mano con 3 y 12 tiene pares.")
    Do advice.%Push("No rompas pares formados por equivalencias 1/2 o 3/12.")
    Do advice.%Push("Juego a 31 normalmente se conserva, pero no siempre es intocable.")
    Do advice.%Push("Si tienes 31 sin pares fuertes y sin reyes/caballos, puedes considerar pedir MUS para mejorar grande y pares.")
    Do advice.%Push("No rompas 31 si tambien tienes pares, medias, duples, reyes o caballos fuertes.")
    Do advice.%Push("Romper 31 es una linea agresiva: debe explicarse como busqueda de mejora a grande o pares.")

    Return advice
}

ClassMethod GetDiscardWarning(rank As %Integer, sameRankCount As %Integer) As %String
{
    If sameRankCount >= 3 {
        Return "NO descartes esta carta salvo razon extraordinaria: forma parte de medias o duples."
    }

    If sameRankCount = 2 {
        Return "NO descartes esta carta salvo razon extraordinaria: rompe una pareja."
    }

    If rank = 3 {
        Return "EVITAR DESCARTE: el 3 equivale al rey en Mus y debe protegerse como carta alta."
    }

    If rank = 12 {
        Return "EVITAR DESCARTE: rey, carta alta y vale 10 para juego."
    }

    If rank = 11 {
        Return "EVITAR DESCARTE: caballo, vale 10 para juego."
    }

    If rank = 10 {
        Return "EVITAR DESCARTE: sota, vale 10 para juego."
    }

    If rank = 1 {
        Return "Evita descartarla: as valioso para chica."
    }

    If rank = 2 {
        Return "Evita descartarla: dos valioso para chica."
    }

    Return ""
}

ClassMethod GetDiscardCandidateReason(rank As %Integer, sameRankCount As %Integer) As %String
{
    If sameRankCount >= 3 {
        Return "Forma parte de medias o duples. Descartarla rompe una jugada fuerte."
    }

    If sameRankCount = 2 {
        Return "Forma parte de una pareja. Descartarla rompe pares."
    }

    If rank = 3 {
        Return "El 3 equivale al rey. Es carta alta, no carta baja."
    }

    If rank = 12 {
        Return "Rey. Carta alta para grande y vale 10 para juego."
    }

    If rank = 11 {
        Return "Caballo. Vale 10 para juego y ayuda a construir o conservar juego."
    }

    If rank = 10 {
        Return "Sota. Vale 10 para juego y ayuda a construir o conservar juego."
    }

    If rank = 1 {
        Return "As. Muy valioso para chica."
    }

    If rank = 2 {
        Return "Dos. Valioso para chica."
    }

    If (rank >= 4) && (rank <= 7) {
        Return "Carta media, potencialmente mejorable si no forma jugada."
    }

    Return "Evalua segun el conjunto de la mano."
}

ClassMethod BuildDiscardCardValueModel() As %DynamicObject
{
    Set model = {}

    Do model.%Set("rankEquivalences", {
        "3": "king",
        "12": "king"
    })

    Do model.%Set("gameValueCards", [
        {
            "rank": 3,
            "reason": "Tres. Equivale al rey en Mus y debe valorarse como carta alta."
        },
        {
            "rank": 10,
            "reason": "Sota. Vale 10 puntos para juego."
        },
        {
            "rank": 11,
            "reason": "Caballo. Vale 10 puntos para juego."
        },
        {
            "rank": 12,
            "reason": "Rey. Vale 10 puntos para juego y es carta alta."
        }
    ])

    Do model.%Set("pairEquivalences", {
        "1": "2",
        "2": "1",
        "3": "12",
        "12": "3"
    })

    Do model.%Set("pairRules", [
        "Para pares, el 1 y el 2 son equivalentes.",
        "Para pares, el 3 y el 12 son equivalentes.",
        "Una mano con 1 y 2 tiene pares.",
        "Una mano con 3 y 12 tiene pares.",
        "No rompas parejas formadas por cartas equivalentes."
    ])

    Do model.%Set("juegoValueRules", [
        "Para juego, 1 y 2 valen 1.",
        "Para juego, 3, 10, 11 y 12 valen 10.",
        "Una mano 2 + 10 + 11 + 12 suma 31 y tiene juego.",
        "Una mano con juego a 31 normalmente debe cortar MUS."
    ])

    Do model.%Set("protectedRanks", [
        {
            "rank": 1,
            "reason": "Valioso para chica. Evita descartarlo salvo mejora muy clara."
        },
        {
            "rank": 2,
            "reason": "Valioso para chica. Evita descartarlo salvo mejora muy clara."
        },
        {
            "rank": 3,
            "reason": "Equivale al rey en Mus. Protegido como carta alta. Evita descartarlo."
        },
        {
            "rank": 10,
            "reason": "Sota. Vale 10 para juego. Evita descartarla salvo mejora muy clara."
        },
        {
            "rank": 11,
            "reason": "Caballo. Vale 10 para juego. Evita descartarlo salvo mejora muy clara."
        },
        {
            "rank": 12,
            "reason": "Rey. Carta alta y vale 10 para juego. Evita descartarlo."
        }
    ])

    Do model.%Set("hardPreferences", [
        "Evita descartar 3 salvo situacion excepcional y claramente justificada.",
        "Trata el 3 como rey, no como carta baja.",
        "Evita descartar sotas, caballos y reyes porque valen 10 para juego.",
        "Las cartas 10, 11 y 12 son utiles para construir o conservar juego.",
        "Las cartas con avoidDiscard = 1 son cartas protegidas.",
        "Si una carta tiene avoidDiscard = 1, solo deberias descartarla si explicas una mejora muy superior.",
        "Si dudas entre descartar una carta protegida y cortar MUS, normalmente corta MUS.",
        "Si no tienes pares ni juego, pedir MUS suele ser mas natural que cortar."
    ])

    Do model.%Set("notes", [
        "El 3 equivale al rey y debe evaluarse como carta alta.",
        "El 3 no es una carta baja aunque su numero sea 3.",
        "El 1 y el 2 son importantes para chica.",
        "Las cartas 10, 11, 12 y 3 suelen ser utiles para grande y juego.",
        "Las sotas, caballos y reyes valen 10 puntos para juego.",
        "Descartar 10, 11 o 12 puede dificultar llegar a juego.",
        "Las cartas 4, 5, 6 y 7 pueden ser mejorables si no forman jugada.",
        "Tener pares no obliga a cortar MUS, pero no se debe romper la pareja sin razon clara.",
        "Tener juego, medias o duples aumenta mucho el valor de cortar MUS.",
        "Con mano floja sin pares ni juego, el riesgo real suele ser cortar y quedarse con una mano mala.",
        "En Mus, 1 y 2 son equivalentes para pares.",
        "En Mus, 3 y 12 son equivalentes para pares.",
        "Si tienes 1 y 2, tienes pares y no debes romperlos salvo razon extraordinaria.",
        "Si tienes 3 y 12, tienes pares y no debes romperlos salvo razon extraordinaria.",
        "Para juego, el 2 vale como 1.",
        "2 + 10 + 11 + 12 suma 31: es juego a 31.",
        "Juego a 31 es una mano muy fuerte y normalmente se corta MUS."
    ])

    Return model
}

ClassMethod BuildDiscardDecisionBias(cards As %DynamicArray, evaluation As %DynamicObject) As %DynamicObject
{
    Set bias = {}
    Do bias.%Set("preferredAction", "neutral")
    Do bias.%Set("strength", "medium")
    Do bias.%Set("reason", "Evalua la mano completa antes de decidir.")
    Do bias.%Set("humanHeuristic", "")

    If '$IsObject(evaluation) {
        Do bias.%Set("preferredAction", "descartar")
        Do bias.%Set("strength", "medium")
        Do bias.%Set("reason", "Sin evaluacion fiable, pedir MUS suele ser mas natural que cortar con informacion incompleta.")
        Do bias.%Set("humanHeuristic", "Si no sabes que la mano sea buena, no cortes demasiado pronto.")
        Return bias
    }

    Set pares = evaluation.%Get("pares", "")
    Set juego = evaluation.%Get("juego", "")
    Set punto = evaluation.%Get("punto", "")

    Set hasPares = 0
    Set paresType = "none"

    If $IsObject(pares) {
        Set hasPares = +pares.%Get("hasPares", 0)
        Set paresType = pares.%Get("type", "none")
    }

    Set hasJuego = 0
    Set juegoTotal = 0

    If $IsObject(juego) {
        Set hasJuego = +juego.%Get("hasJuego", 0)
        Set juegoTotal = +juego.%Get("total", 0)
    }

    Set puntoTotal = 0

    If $IsObject(punto) {
        Set puntoTotal = +punto.%Get("total", 0)
    }

    Do bias.%Set("puntoTotal", puntoTotal)

    If $IsObject(cards) {
        Set computedJuegoTotal = ..GetMusJuegoTotal(cards)

        If computedJuegoTotal >= 31 {
            Set hasJuego = 1
            Set juegoTotal = computedJuegoTotal
        }

        Set computedPares = ..BuildParesSummary(cards)

        If +computedPares.%Get("hasPares", 0) {
            Set hasPares = 1
            Set paresType = computedPares.%Get("type", "none")
        }
    }

    If hasJuego {
        Set breakAnalysis = ..BuildJuegoBreakAnalysis(cards)
        Set canBreakJuego = +breakAnalysis.%Get("canConsiderBreakingJuego", 0)
        Set preferredBreakAction = breakAnalysis.%Get("preferredAction", "cortar_mus")

        If canBreakJuego && (juegoTotal = 31) && (preferredBreakAction = "descartar") {
            Do bias.%Set("preferredAction", "descartar")
            Do bias.%Set("strength", "medium")
            Do bias.%Set("reason", "Hay juego a 31, pero sin pares fuertes ni reyes/caballos que protejan grande. Se puede considerar pedir MUS para mejorar a grande y pares.")
            Do bias.%Set("humanHeuristic", "Juego a 31 es fuerte, pero no siempre intocable si la mano no tiene apoyo en pares ni grande.")
            Do bias.%Set("juegoTotal", juegoTotal)
            Do bias.%Set("juegoBreakReason", breakAnalysis.%Get("reason", ""))
            Return bias
        }

        Do bias.%Set("preferredAction", "cortar_mus")
        Do bias.%Set("strength", $Select(hasPares:"veryHigh", 1:"high"))

        If hasPares {
            Do bias.%Set("reason", "La mano tiene juego y pares. Es una mano hecha en varios lances; pedir MUS suele ser un error.")
            Do bias.%Set("humanHeuristic", "Con juego y pares, un jugador real normalmente corta MUS.")
        } ElseIf canBreakJuego {
            Do bias.%Set("reason", "La mano tiene juego a 31. Cortar MUS es razonable, aunque existe una linea alternativa de pedir MUS para mejorar grande o pares.")
            Do bias.%Set("humanHeuristic", "Con 31 sin pares fuertes, cortar es seguro; pedir MUS es una opcion agresiva pero defendible.")
        } Else {
            Do bias.%Set("reason", "La mano ya tiene juego; pedir MUS puede destruir una mano competitiva.")
            Do bias.%Set("humanHeuristic", "Con juego hecho, muchos jugadores cortan MUS salvo plan muy claro.")
        }

        Do bias.%Set("juegoTotal", juegoTotal)
        Do bias.%Set("juegoBreakReason", breakAnalysis.%Get("reason", ""))

        Return bias
    }

    If hasPares {
        If paresType = "duples" {
            Do bias.%Set("preferredAction", "cortar_mus")
            Do bias.%Set("strength", "veryHigh")
            Do bias.%Set("reason", "Duples es una jugada fuerte; no conviene arriesgarla.")
            Do bias.%Set("humanHeuristic", "Con duples se suele cortar MUS.")
            Return bias
        }

        If paresType = "medias" {
            Do bias.%Set("preferredAction", "cortar_mus")
            Do bias.%Set("strength", "high")
            Do bias.%Set("reason", "Medias es una jugada fuerte; solo se pediria MUS con una razon clara.")
            Do bias.%Set("humanHeuristic", "Con medias normalmente se conserva la mano.")
            Return bias
        }

        Do bias.%Set("preferredAction", "descartar")
        Do bias.%Set("strength", "medium")
        Do bias.%Set("reason", "Tener una pareja no obliga a cortar; puede ser razonable proteger la pareja y mejorar cartas sueltas.")
        Do bias.%Set("humanHeuristic", "Con par simple y malas cartas sueltas, se puede pedir MUS sin romper la pareja.")
        Return bias
    }

    Do bias.%Set("preferredAction", "descartar")
    Do bias.%Set("strength", "high")
    Do bias.%Set("reason", "No hay pares ni juego: la mano no tiene estructura fuerte que proteger. Pedir MUS suele ser la decision mas natural.")
    Do bias.%Set("humanHeuristic", "Con mano floja, el riesgo esta en cortar y quedarte como estas; pedir MUS busca mejorar.")

    If ..HasOnlyContextualProtection(cards) {
        Do bias.%Set("contextualProtectionNote", "Todas o casi todas las cartas tienen valor teorico, pero no hay jugada hecha. No cortes MUS solo porque las cartas sean protegidas individualmente.")
    }

    Return bias
}

ClassMethod GetMusPairRank(rank As %Integer) As %Integer
{
    /*
      En Mus, para pares, el 1 y el 2 son equivalentes.
      Se agrupan como rango 1.
    */
    If (rank = 1) || (rank = 2) {
        Return 1
    }

    /*
      El 3 equivale al rey.
      Para pares, 3 y 12 tambien deben agruparse.
    */
    If (rank = 3) || (rank = 12) {
        Return 12
    }

    Return rank
}

ClassMethod HasResponderForBet(gameState As %DynamicObject, hand As %DynamicObject, phaseState As %DynamicObject, aggressorPlayerId As %String, respondingTeam As %String) As %Boolean
{
    If respondingTeam = "" {
        Return 0
    }

    Set participants = phaseState.%Get("participants", "")

    Set startPlayerId = ##class(Mus.Util.MusRules).GetNextPlayerId(aggressorPlayerId)
    Set orderedPlayers = ##class(Mus.Util.MusRules).GetPlayerOrderFrom(startPlayerId)

    For i=0:1:orderedPlayers.%Size()-1 {
        Set candidate = orderedPlayers.%Get(i)

        If $IsObject(participants) {
            If '..ArrayContains(participants, candidate) {
                Continue
            }
        }

        Set candidateTeam = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, candidate)

        If candidateTeam = respondingTeam {
            Return 1
        }
    }

    Return 0
}

ClassMethod BuildMadeHandsSummary(evaluation As %DynamicObject, cards As %DynamicArray = "") As %DynamicObject
{
    Set summary = {}
    Do summary.%Set("hasPares", 0)
    Do summary.%Set("paresType", "none")
    Do summary.%Set("paresRank", 0)
    Do summary.%Set("hasJuego", 0)
    Do summary.%Set("juegoTotal", 0)
    Do summary.%Set("juegoRankWeight", 0)
    Do summary.%Set("puntoTotal", 0)

    If $IsObject(evaluation) {
        Set pares = evaluation.%Get("pares", "")
        If $IsObject(pares) {
            Do summary.%Set("hasPares", +pares.%Get("hasPares", 0))
            Do summary.%Set("paresType", pares.%Get("type", "none"))
            Do summary.%Set("paresRank", +pares.%Get("rank", 0))
        }

        Set juego = evaluation.%Get("juego", "")
        If $IsObject(juego) {
            Do summary.%Set("hasJuego", +juego.%Get("hasJuego", 0))
            Do summary.%Set("juegoTotal", +juego.%Get("total", 0))
            Do summary.%Set("juegoRankWeight", +juego.%Get("rankWeight", 0))
        }

        Set punto = evaluation.%Get("punto", "")
        If $IsObject(punto) {
            Do summary.%Set("puntoTotal", +punto.%Get("total", 0))
        }
    }

    /*
      Recalculo defensivo según reglas de Mus.
      Evita que el LLM o AnalyzeJuego interpreten mal 2, 3, 10, 11, 12.
    */
    If $IsObject(cards) {
        Set computedPares = ..BuildParesSummary(cards)

        If +computedPares.%Get("hasPares", 0) {
            Do summary.%Set("hasPares", 1)
            Do summary.%Set("paresType", computedPares.%Get("type", "none"))
            Do summary.%Set("computedPares", 1)
            Do summary.%Set("computedParesRule", "Para pares, 1/2 son equivalentes y 3/12 son equivalentes.")
        }

        Set computedJuegoTotal = ..GetMusJuegoTotal(cards)

        If computedJuegoTotal >= 31 {
            Do summary.%Set("hasJuego", 1)
            Do summary.%Set("juegoTotal", computedJuegoTotal)
            Do summary.%Set("computedJuego", 1)
            Do summary.%Set("computedJuegoRule", "1/2 valen 1; 3/10/11/12 valen 10.")
        }
    }

    Return summary
}

ClassMethod GetProtectionLevel(rank As %Integer, sameRankCount As %Integer) As %String
{
    If sameRankCount >= 3 {
        Return "absolute"
    }

    If sameRankCount = 2 {
        Return "absolute"
    }

    /*
      El 3 equivale al rey: proteccion fuerte.
    */
    If rank = 3 {
        Return "strong"
    }

    If rank = 12 {
        Return "strong"
    }

    /*
      10 y 11 ayudan a juego, pero si no hay juego hecho
      son proteccion contextual, no absoluta.
    */
    If (rank = 10) || (rank = 11) {
        Return "contextual"
    }

    /*
      1 y 2 ayudan a chica, pero si la mano no es buena a chica
      tambien son proteccion contextual.
    */
    If (rank = 1) || (rank = 2) {
        Return "contextual"
    }

    Return "none"
}

ClassMethod BuildDiscardCandidates(cards As %DynamicArray) As %DynamicArray
{
    Set candidates = []

    If '$IsObject(cards) {
        Return candidates
    }

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set rank = ..GetCardRank(card)
        Set countRank = ..CountRank(cards, rank)
        Set pairRank = ..GetMusPairRank(rank)

        Set candidate = {}
        Do candidate.%Set("card", card)
        Do candidate.%Set("rank", rank)
        Do candidate.%Set("pairRank", pairRank)
        Do candidate.%Set("musValueRank", ..GetMusValueRank(rank))
        Do candidate.%Set("sameRankCount", countRank)
        Do candidate.%Set("isPartOfPares", countRank >= 2)
        Do candidate.%Set("isProtected", ..IsStrategicallyProtectedRank(rank))
        Do candidate.%Set("avoidDiscard", ..ShouldAvoidDiscardRank(rank, countRank))
        Do candidate.%Set("protectionLevel", ..GetProtectionLevel(rank, countRank))
        Do candidate.%Set("discardRisk", ..GetDiscardRisk(rank, countRank))
        Do candidate.%Set("discardWarning", ..GetDiscardWarning(rank, countRank))
        Do candidate.%Set("reason", ..GetDiscardCandidateReason(rank, countRank))

        Do candidates.%Push(candidate)
    }

    Return candidates
}

ClassMethod GetMusJuegoValue(rank As %Integer) As %Integer
{
    /*
      Valor para juego en Mus:
      - 1 y 2 valen 1.
      - 3, 10, 11 y 12 valen 10.
      - 4,5,6,7 valen su valor.
    */
    If (rank = 1) || (rank = 2) {
        Return 1
    }

    If (rank = 3) || (rank = 10) || (rank = 11) || (rank = 12) {
        Return 10
    }

    Return rank
}

ClassMethod GetMusJuegoTotal(cards As %DynamicArray) As %Integer
{
    Set total = 0

    If '$IsObject(cards) {
        Return total
    }

    For i=0:1:cards.%Size()-1 {
        Set rank = ..GetCardRank(cards.%Get(i))
        Set total = total + ..GetMusJuegoValue(rank)
    }

    Return total
}

ClassMethod HasMusJuego(cards As %DynamicArray) As %Boolean
{
    Set total = ..GetMusJuegoTotal(cards)

    Return total >= 31
}

ClassMethod GetCardRank(card As %String) As %Integer
{
    Set rankText = ""

    For i=1:1:$Length(card) {
        Set ch = $Extract(card, i)

        If ch?1N {
            Set rankText = rankText_ch
        } Else {
            Quit
        }
    }

    If rankText = "" {
        Return 0    
    }

    Return +rankText
}

ClassMethod CountRank(cards As %DynamicArray, rank As %Integer) As %Integer
{
    Set count = 0

    If '$IsObject(cards) {
        Return count
    }

    Set targetPairRank = ..GetMusPairRank(rank)

    For i=0:1:cards.%Size()-1 {
        Set currentRank = ..GetCardRank(cards.%Get(i))

        If ..GetMusPairRank(currentRank) = targetPairRank {
            Set count = count + 1
        }
    }

    Return count
}

ClassMethod GetMusValueRank(rank As %Integer) As %Integer
{
    /*
      En Mus, el 3 equivale al rey.
      Lo elevamos al mismo valor estrategico que el 12.
    */
    If rank = 3 {
        Return 12
    }

    Return rank
}

ClassMethod IsStrategicallyProtectedRank(rank As %Integer) As %Boolean
{
    /*
      1 y 2 se protegen por chica.
      3 se protege porque equivale al rey.
      10, 11 y 12 se protegen porque valen 10 para juego.
    */
    Return (rank = 1) || (rank = 2) || (rank = 3) || (rank = 10) || (rank = 11) || (rank = 12)
}

ClassMethod ShouldAvoidDiscardRank(rank As %Integer, sameRankCount As %Integer) As %Boolean
{
    If sameRankCount >= 2 {
        Return 1
    }

    If (rank = 1) || (rank = 2) {
        Return 1
    }

    If rank = 3 {
        Return 1
    }

    If (rank = 10) || (rank = 11) || (rank = 12) {
        Return 1
    }

    Return 0
}

ClassMethod GetDiscardRisk(rank As %Integer, sameRankCount As %Integer) As %String
{
    If sameRankCount >= 3 {
        Return "veryHigh"
    }

    If sameRankCount = 2 {
        Return "high"
    }

    If rank = 3 {
        Return "high"
    }

    If rank = 12 {
        Return "high"
    }

    If (rank = 10) || (rank = 11) {
        Return "mediumHigh"
    }

    If (rank = 1) || (rank = 2) {
        Return "mediumHigh"
    }

    If (rank >= 4) && (rank <= 7) {
        Return "low"
    }

    Return "medium"
}

ClassMethod BuildBettingGuidance(gameState As %DynamicObject, playerId As %String, cards As %DynamicArray) As %DynamicObject
{
    Set guidance = {
        "canBetMoreThanTwo": 0,
        "suggestedMinEnvido": 2,
        "suggestedStrongEnvido": 3,
        "suggestedVeryStrongEnvido": 5,
        "handStrength": "unknown",
        "notes": []
    }

    If '$IsObject(cards) || cards.%Size() = 0 {
        Do guidance.%Set("handStrength", "unknown")
        Do guidance.%Get("notes").%Push("No cards available")
        Return guidance
    }

    Set phase = gameState.%Get("phase", "")

    Set pares = ##class(Mus.Util.MusRules).AnalyzePares(cards)
    Set juego = ##class(Mus.Util.MusRules).AnalyzeJuego(cards)
    Set punto = ##class(Mus.Util.MusRules).AnalyzePunto(cards)
    Set grandeVector = ##class(Mus.Util.MusRules).GetGrandeVector(cards)
    Set chicaVector = ##class(Mus.Util.MusRules).GetChicaVector(cards)

    Set strengthScore = 0

    If phase = "grande" {
        Set first = +grandeVector.%Get(0)
        Set second = +grandeVector.%Get(1)
        Set third = +grandeVector.%Get(2)

        If first >= 10 { Set strengthScore = strengthScore + 2 }

        If second >= 10 {
            Set strengthScore = strengthScore + 2
        } ElseIf second >= 9 {
            Set strengthScore = strengthScore + 1
        }

        If third >= 9 {
            Set strengthScore = strengthScore + 1
        } ElseIf third >= 7 {
            Set strengthScore = strengthScore + 1
        }

        If (first >= 10) && (second >= 10) {
            Do guidance.%Get("notes").%Push("Two king-equivalent cards for grande")
        }
    }

    If phase = "chica" {
        If chicaVector.%Get(0) <= 1 {
            Set strengthScore = strengthScore + 2
        }

        If chicaVector.%Get(1) <= 3 {
            Set strengthScore = strengthScore + 1
        }

        If chicaVector.%Get(2) <= 5 {
            Set strengthScore = strengthScore + 1
        }
    }

    If phase = "pares" {
        If +pares.%Get("hasPares", 0) {
            Set strengthScore = strengthScore + pares.%Get("rank", 0)

            If pares.%Get("type", "") = "duples" {
                Set strengthScore = strengthScore + 2
            }

            If pares.%Get("type", "") = "medias" {
                Set strengthScore = strengthScore + 1
            }
        }
    }

    If phase = "juego" {
        If +juego.%Get("hasJuego", 0) {
            Set total = juego.%Get("total", 0)

            If total = 31 {
                Set strengthScore = strengthScore + 5
            } ElseIf total = 32 {
                Set strengthScore = strengthScore + 4
            } ElseIf total >= 33 {
                Set strengthScore = strengthScore + 2
            }
        }
    }

    If phase = "punto" {
        Set total = punto.%Get("total", 0)

        If total >= 29 {
            Set strengthScore = strengthScore + 4
        } ElseIf total >= 27 {
            Set strengthScore = strengthScore + 2
        }
    }

    If strengthScore >= 5 {
        Do guidance.%Set("handStrength", "veryStrong")
        Do guidance.%Set("canBetMoreThanTwo", 1)
        Do guidance.%Set("suggestedStrongEnvido", 4)
        Do guidance.%Set("suggestedVeryStrongEnvido", 6)
        Do guidance.%Get("notes").%Push("Very strong hand for current phase")
    } ElseIf strengthScore >= 3 {
        Do guidance.%Set("handStrength", "strong")
        Do guidance.%Set("canBetMoreThanTwo", 1)
        Do guidance.%Set("suggestedStrongEnvido", 3)
        Do guidance.%Set("suggestedVeryStrongEnvido", 4)
        Do guidance.%Get("notes").%Push("Strong hand for current phase")
    } ElseIf strengthScore >= 1 {
        Do guidance.%Set("handStrength", "medium")
        Do guidance.%Set("canBetMoreThanTwo", 0)
        Do guidance.%Get("notes").%Push("Medium hand")
    } Else {
        Do guidance.%Set("handStrength", "weak")
        Do guidance.%Set("canBetMoreThanTwo", 0)
        Do guidance.%Get("notes").%Push("Weak hand")
    }

    Set scorePressure = ..BuildScorePressure(gameState, playerId)
    Do guidance.%Set("scorePressure", scorePressure)

    Set aggressionMultiplier = +scorePressure.%Get("aggressionMultiplier", 1.0)
    Set ordagoPressure = scorePressure.%Get("ordagoPressure", "none")

    If aggressionMultiplier > 1.0 {
        Do guidance.%Set("scoreAggressionMultiplier", aggressionMultiplier)
        Do guidance.%Get("notes").%Push("Score pressure increases aggression")
    }

    If ordagoPressure '= "none" {
        Do guidance.%Set("ordagoPressure", ordagoPressure)
        Do guidance.%Get("notes").%Push("Ordago becomes more reasonable due to score pressure")
    }

    If aggressionMultiplier > 1.0 {
        Set suggestedStrong = +guidance.%Get("suggestedStrongEnvido", 3)
        Set suggestedVeryStrong = +guidance.%Get("suggestedVeryStrongEnvido", 5)

        Set suggestedStrong = $Select(
            aggressionMultiplier >= 1.65: suggestedStrong + 2,
            aggressionMultiplier >= 1.35: suggestedStrong + 1,
            1: suggestedStrong
        )

        Set suggestedVeryStrong = $Select(
            aggressionMultiplier >= 1.65: suggestedVeryStrong + 3,
            aggressionMultiplier >= 1.35: suggestedVeryStrong + 2,
            1: suggestedVeryStrong
        )

        If suggestedStrong > 8 {
            Set suggestedStrong = 8
        }

        If suggestedVeryStrong > 12 {
            Set suggestedVeryStrong = 12
        }

        Do guidance.%Set("suggestedStrongEnvido", suggestedStrong)
        Do guidance.%Set("suggestedVeryStrongEnvido", suggestedVeryStrong)
    }

    Return guidance
}

ClassMethod BuildScorePressure(gameState As %DynamicObject, playerId As %String) As %DynamicObject
{
    Set pressure = {
        "targetScore": 40,
        "playerTeam": "",
        "myTeamScore": 0,
        "opponentTeamScore": 0,
        "myTeamDistanceToTarget": 40,
        "opponentDistanceToTarget": 40,
        "isOpponentNearWin": 0,
        "isMyTeamNearWin": 0,
        "isEmergency": 0,
        "isDesperationMode": 0,
        "aggressionMultiplier": 1.0,
        "ordagoPressure": "none",
        "notes": []
    }

    If '$IsObject(gameState) {
        Return pressure
    }

    Set targetScore = ##class(Mus.Util.MusRules).GetTargetScore(gameState)
    If targetScore <= 0 {
        Set targetScore = 40
    }

    Set playerTeam = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, playerId)
    If playerTeam = "" {
        Return pressure
    }

    Set score = gameState.%Get("score", "")
    If '$IsObject(score) {
        Return pressure
    }

    Set teamAScore = +score.%Get("teamA", 0)
    Set teamBScore = +score.%Get("teamB", 0)

    If playerTeam = "A" {
        Set myScore = teamAScore
        Set opponentScore = teamBScore
    } Else {
        Set myScore = teamBScore
        Set opponentScore = teamAScore
    }

    Set myDistance = targetScore - myScore
    Set opponentDistance = targetScore - opponentScore

    If myDistance < 0 {
        Set myDistance = 0
    }

    If opponentDistance < 0 {
        Set opponentDistance = 0
    }

    Do pressure.%Set("targetScore", targetScore)
    Do pressure.%Set("playerTeam", playerTeam)
    Do pressure.%Set("myTeamScore", myScore)
    Do pressure.%Set("opponentTeamScore", opponentScore)
    Do pressure.%Set("myTeamDistanceToTarget", myDistance)
    Do pressure.%Set("opponentDistanceToTarget", opponentDistance)

    Set isOpponentNearWin = 0
    Set isMyTeamNearWin = 0
    Set isEmergency = 0
    Set isDesperationMode = 0
    Set aggressionMultiplier = 1.0
    Set ordagoPressure = "none"

    If opponentDistance <= 5 {
        Set isOpponentNearWin = 1
        Set aggressionMultiplier = 1.35
        Set ordagoPressure = "elevated"
        Do pressure.%Get("notes").%Push("Opponent team is near target score")
    }

    If opponentDistance <= 3 {
        Set isEmergency = 1
        Set aggressionMultiplier = 1.65
        Set ordagoPressure = "high"
        Do pressure.%Get("notes").%Push("Emergency: opponent is within three points of victory")
    }

    If opponentDistance <= 1 {
        Set isDesperationMode = 1
        Set aggressionMultiplier = 2.0
        Set ordagoPressure = "desperation"
        Do pressure.%Get("notes").%Push("Desperation mode: opponent can win with one point")
    }

    If myDistance <= 5 {
        Set isMyTeamNearWin = 1
        Do pressure.%Get("notes").%Push("My team is also near target score")
    }

    /*
      Si ambos equipos están cerca, se permite agresividad,
      pero no suicida: la mano debe justificar el riesgo.
    */
    If isOpponentNearWin && isMyTeamNearWin {
        If aggressionMultiplier > 1.5 {
            Set aggressionMultiplier = 1.5
        }

        If ordagoPressure = "desperation" {
            Set ordagoPressure = "high"
        }

        Do pressure.%Get("notes").%Push("Both teams are near victory; avoid reckless ordago")
    }

    Do pressure.%Set("isOpponentNearWin", isOpponentNearWin)
    Do pressure.%Set("isMyTeamNearWin", isMyTeamNearWin)
    Do pressure.%Set("isEmergency", isEmergency)
    Do pressure.%Set("isDesperationMode", isDesperationMode)
    Do pressure.%Set("aggressionMultiplier", aggressionMultiplier)
    Do pressure.%Set("ordagoPressure", ordagoPressure)

    Return pressure
}

ClassMethod GetLegalActionsFromState(gameState As %DynamicObject, playerId As %String) As %DynamicArray
{
    Set actions = []

    If '$IsObject(gameState) {
        Return actions
    }

    If gameState.%Get("status", "") = "finished" {
        Return actions
    }

    Set hand = gameState.%Get("hand", "")

    If '$IsObject(hand) {
        Return actions
    }

    Set phase = gameState.%Get("phase", "")

    If phase = "" {
        Return actions
    }

    If phase = "manoCerrada" {
        Return actions
    }

    /*
      En descartes la decision se consulta por jugador, no por turnPlayerId.
      Por eso esta rama debe quedar antes del control de turno.
    */
    If phase = "descartes" {
        Set allCards = hand.%Get("cards", "")

        If '$IsObject(allCards) {
            Return actions
        }

        Set playerCards = allCards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Return actions
        }

        If playerCards.%Size() '= 4 {
            Return actions
        }

        Do actions.%Push("descartar")
        Do actions.%Push("cortar_mus")

        Return actions
    }

    Set phaseState = hand.%Get("phaseState", "")

    If '$IsObject(phaseState) {
        Return actions
    }

    Set playerTeam = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, playerId)

    If playerTeam = "" {
        Return actions
    }

    /*
      Envite pendiente: el turno interno puede senalar al primer respondedor,
      pero la respuesta pertenece al equipo. Cualquier miembro incluido en
      pendingBet.respondingPlayers puede recomendar/contestar aunque no sea el
      turnPlayerId actual.
    */
    Set pendingBet = phaseState.%Get("pendingBet", "")

    If $IsObject(pendingBet) {
        Set respondingTeam = pendingBet.%Get("respondingTeam", "")

        If respondingTeam = "" {
            Set respondingTeam = phaseState.%Get("respondingTeam", "")
        }

        If (playerTeam = respondingTeam) && ..IsPendingBetResponder(pendingBet, playerId) {
            Do actions.%Push("querer")
            Do actions.%Push("no_querer")

            Set currentAmount = +pendingBet.%Get("amount", 0)
            Set raiseCount = +pendingBet.%Get("raiseCount", 0)
            Set pendingType = pendingBet.%Get("type", "")

            If pendingType '= "ordago" {
                If (raiseCount < 3) && (currentAmount < 8) {
                    Do actions.%Push("envidar")
                }

                If currentAmount < 8 {
                    Do actions.%Push("ordago")
                }
            }
        }

        Return actions
    }

    If gameState.%Get("turnPlayerId", "") '= playerId {
        Return actions
    }

    If gameState.%Get("turnPlayerId", "") '= playerId {
        Return actions
    }

    Do actions.%Push("pasar")

    Set respondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)

    If ..HasResponderForBet(gameState, hand, phaseState, playerId, respondingTeam) {
        Do actions.%Push("envidar")
        Do actions.%Push("ordago")
    }

    Return actions
}

ClassMethod IsPendingBetResponder(pendingBet As %DynamicObject, playerId As %String) As %Boolean
{
    If '$IsObject(pendingBet) {
        Return 0
    }

    If playerId = "" {
        Return 0
    }

    Set respondingPlayers = pendingBet.%Get("respondingPlayers", "")

    If $IsObject(respondingPlayers) {
        For i=0:1:respondingPlayers.%Size()-1 {
            If respondingPlayers.%Get(i) = playerId {
                Return 1
            }
        }
    }

    If pendingBet.%Get("respondingPlayerId", "") = playerId {
        Return 1
    }

    Return 0
}

ClassMethod ArrayContains(array As %DynamicArray, value) As %Boolean
{
    If '$IsObject(array) {
        Return 0
    }

    For i=0:1:array.%Size()-1 {
        If array.%Get(i) = value {
            Return 1
        }
    }

    Return 0
}

}
