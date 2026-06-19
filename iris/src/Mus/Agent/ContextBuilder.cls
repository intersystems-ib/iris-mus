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
    Do context.%Set("profile", ##class(Mus.Agent.PlayerProfile).GetProfile(playerId))
    Do context.%Set("scorePressure", ..BuildScorePressure(gameState, playerId))

    If currentPhase = "descartes" {
        Do context.%Set("bettingGuidance", {})
        Do context.%Set("discardGuidance", ..BuildDiscardGuidance(cards, evaluation))
    } Else {
        Do context.%Set("bettingGuidance", ..BuildBettingGuidance(gameState, playerId, cards))
    }

    Return context
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
      En fase de descartes la decision se consulta por jugador,
      no por turnPlayerId. Por eso esta rama va antes del control
      de turno.
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

    If gameState.%Get("turnPlayerId", "") '= playerId {
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

    Set pendingBet = phaseState.%Get("pendingBet", "")

    If $IsObject(pendingBet) {
        Set respondingTeam = pendingBet.%Get("respondingTeam", "")

        If respondingTeam = "" {
            Set respondingTeam = phaseState.%Get("respondingTeam", "")
        }

        If playerTeam = respondingTeam {
            Do actions.%Push("querer")
            Do actions.%Push("no_querer")

            Set currentAmount = +pendingBet.%Get("amount", 0)
            Set raiseCount = +pendingBet.%Get("raiseCount", 0)
            Set pendingType = pendingBet.%Get("type", "")

            /*
            Evita guerras infinitas de subidas entre agentes.
            Permitimos algunas subidas, pero no indefinidamente.
            */
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

    Do actions.%Push("pasar")

    Set respondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)

    If ..HasResponderForBet(gameState, hand, phaseState, playerId, respondingTeam) {
        Do actions.%Push("envidar")
        Do actions.%Push("ordago")
    }

    Return actions
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
    Do guidance.%Set("madeHands", ..BuildMadeHandsSummary(evaluation))
    Do guidance.%Set("decisionBias", ..BuildDiscardDecisionBias(cards, evaluation))
    Do guidance.%Set("discardCandidates", ..BuildDiscardCandidates(cards))
    Do guidance.%Set("strategicAdvice", ..BuildDiscardStrategicAdvice())

    Return guidance
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
        "Con mano floja sin pares ni juego, el riesgo real suele ser cortar y quedarse con una mano mala."
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

    If hasJuego {
        Do bias.%Set("preferredAction", "cortar_mus")
        Do bias.%Set("strength", "high")
        Do bias.%Set("reason", "La mano ya tiene juego; pedir MUS puede destruir una mano competitiva.")
        Do bias.%Set("humanHeuristic", "Con juego hecho, muchos jugadores cortan MUS salvo plan muy claro.")
        Do bias.%Set("juegoTotal", juegoTotal)
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

    Return bias
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

ClassMethod BuildMadeHandsSummary(evaluation As %DynamicObject) As %DynamicObject
{
    Set summary = {}
    Do summary.%Set("hasPares", 0)
    Do summary.%Set("paresType", "none")
    Do summary.%Set("paresRank", 0)
    Do summary.%Set("hasJuego", 0)
    Do summary.%Set("juegoTotal", 0)
    Do summary.%Set("juegoRankWeight", 0)
    Do summary.%Set("puntoTotal", 0)

    If '$IsObject(evaluation) {
        Return summary
    }

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

    Return summary
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

        Set candidate = {}
        Do candidate.%Set("card", card)
        Do candidate.%Set("rank", rank)
        Do candidate.%Set("musValueRank", ..GetMusValueRank(rank))
        Do candidate.%Set("sameRankCount", countRank)
        Do candidate.%Set("isPartOfPares", countRank >= 2)
        Do candidate.%Set("isProtected", ..IsStrategicallyProtectedRank(rank))
        Do candidate.%Set("avoidDiscard", ..ShouldAvoidDiscardRank(rank, countRank))
        Do candidate.%Set("discardRisk", ..GetDiscardRisk(rank, countRank))
        Do candidate.%Set("discardWarning", ..GetDiscardWarning(rank, countRank))
        Do candidate.%Set("reason", ..GetDiscardCandidateReason(rank, countRank))

        Do candidates.%Push(candidate)
    }

    Return candidates
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

    For i=0:1:cards.%Size()-1 {
        If ..GetCardRank(cards.%Get(i)) = rank {
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
        If grandeVector.%Get(0) >= 10 {
            Set strengthScore = strengthScore + 2
        }

        If grandeVector.%Get(1) >= 9 {
            Set strengthScore = strengthScore + 1
        }

        If grandeVector.%Get(2) >= 7 {
            Set strengthScore = strengthScore + 1
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

ClassMethod ArrayContains(array As %DynamicArray, value As %String) As %Boolean
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
