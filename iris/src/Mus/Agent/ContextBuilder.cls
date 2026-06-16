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
            "hasPares": false,
            "type": "none",
            "rank": 0,
            "vector": [0]
        })
        Do evaluation.%Set("juego", {
            "hasJuego": false,
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

    If $IsObject(hand), $IsObject(hand.%Get("phaseState", "")) {
        Do context.%Set("phaseState", hand.%Get("phaseState"))
    } Else {
        Do context.%Set("phaseState", {})
    }

    Do context.%Set("legalActions", ..GetLegalActionsFromState(gameState, playerId))
    Do context.%Set("profile", ##class(Mus.Agent.PlayerProfile).GetProfile(playerId))
    Do context.%Set("scorePressure", ..BuildScorePressure(gameState, playerId))
    Do context.%Set("bettingGuidance", ..BuildBettingGuidance(gameState, playerId, cards))

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

    If gameState.%Get("turnPlayerId", "") '= playerId {
        Return actions
    }

    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return actions
    }

    Set phase = gameState.%Get("phase", "")

    If (phase = "") || (phase = "descartes") || (phase = "manoCerrada") {
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

ClassMethod BuildBettingGuidance(gameState As %DynamicObject, playerId As %String, cards As %DynamicArray) As %DynamicObject
{
    Set guidance = {
        "canBetMoreThanTwo": false,
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
        If pares.%Get("hasPares", 0) {
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
        If juego.%Get("hasJuego", 0) {
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
        Do guidance.%Set("canBetMoreThanTwo", "true")
        Do guidance.%Set("suggestedStrongEnvido", 4)
        Do guidance.%Set("suggestedVeryStrongEnvido", 6)
        Do guidance.%Get("notes").%Push("Very strong hand for current phase")
    } ElseIf strengthScore >= 3 {
        Do guidance.%Set("handStrength", "strong")
        Do guidance.%Set("canBetMoreThanTwo", "true")
        Do guidance.%Set("suggestedStrongEnvido", 3)
        Do guidance.%Set("suggestedVeryStrongEnvido", 4)
        Do guidance.%Get("notes").%Push("Strong hand for current phase")
    } ElseIf strengthScore >= 1 {
        Do guidance.%Set("handStrength", "medium")
        Do guidance.%Set("canBetMoreThanTwo", "false")
        Do guidance.%Get("notes").%Push("Medium hand")
    } Else {
        Do guidance.%Set("handStrength", "weak")
        Do guidance.%Set("canBetMoreThanTwo", "false")
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
        "isOpponentNearWin": false,
        "isMyTeamNearWin": false,
        "isEmergency": false,
        "isDesperationMode": false,
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
