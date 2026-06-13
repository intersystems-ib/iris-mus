Class Mus.BP.RuleEngine Extends Ens.BusinessProcess
{

Method OnRequest(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status
{
    If pRequest.%IsA("Mus.Msg.ValidateActionRequest") {
        Return ..ValidateAction(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.ResolveActionRequest") {
        Return ..ResolveAction(pRequest, .pResponse)
    }

    Set pResponse = ##class(Mus.Msg.ValidateActionResponse).%New()
    Set pResponse.Success = 0
    Set pResponse.IsLegal = 0
    Set pResponse.StatusCode = 500
    Set pResponse.ErrorCode = "UNSUPPORTED_MESSAGE"
    Set pResponse.ErrorMessage = "Unsupported message type: "_pRequest.%ClassName(1)

    Return $$$OK
}

Method ValidateAction(pRequest As Mus.Msg.ValidateActionRequest, Output pResponse As Mus.Msg.ValidateActionResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.ValidateActionResponse).%New()
    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200

    Try {
        Set state = {}.%FromJSON(pRequest.GameStateJson)
        Set hand = state.%Get("hand", "")

        If '$IsObject(hand) {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "NO_ACTIVE_HAND"
            Set pResponse.ErrorMessage = "No active hand"
            Return $$$OK
        }

        Set phase = hand.%Get("phase", "")

        If phase = "descartes" {
            If pRequest.Phase '= "grande" {
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "INVALID_ACTION_PHASE"
                Set pResponse.ErrorMessage = "Current phase is descartes. Only grande can be started from descartes."
                Return $$$OK
            }
        }

        If pRequest.Phase '= "", phase '= pRequest.Phase {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "INVALID_ACTION_PHASE"
            Set pResponse.ErrorMessage = "Current phase is "_phase_", but action phase is "_pRequest.Phase
            Return $$$OK
        }

        If (phase '= "grande") && (phase '= "chica") && (phase '= "pares") && (phase '= "juego") && (phase '= "punto") {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "PHASE_NOT_IMPLEMENTED"
            Set pResponse.ErrorMessage = "Phase "_phase_" is not implemented yet"
            Return $$$OK
        }

        Set phaseState = ..GetOrBuildPhaseState(state, hand, phase)

        Set turnPlayerId = hand.%Get("turnPlayerId", "")

        If turnPlayerId = "" {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "TURN_NOT_INITIALIZED"
            Set pResponse.ErrorMessage = "The current hand does not have turnPlayerId initialized"
            Return $$$OK
        }

        If turnPlayerId '= pRequest.PlayerId {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "NOT_PLAYER_TURN"
            Set pResponse.ErrorMessage = "It is not this player's turn. Current turn belongs to "_turnPlayerId
            Return $$$OK
        }

        If (phase = "pares") || (phase = "juego") {
            Set participants = phaseState.%Get("participants", "")

            If '$IsObject(participants) {
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "PHASE_PARTICIPANTS_NOT_INITIALIZED"
                Set pResponse.ErrorMessage = "Participants were not initialized for phase "_phase
                Return $$$OK
            }

            If participants.%Size() = 0 {
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "NO_PHASE_PARTICIPANTS"
                Set pResponse.ErrorMessage = "No player can participate in phase "_phase
                Return $$$OK
            }

            If '..ArrayContains(participants, pRequest.PlayerId) {
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "PLAYER_NOT_ALLOWED_IN_PHASE"
                Set pResponse.ErrorMessage = "Player "_pRequest.PlayerId_" cannot play phase "_phase
                Return $$$OK
            }
        }

        Set playerTeam = ##class(Mus.Util.MusRules).GetPlayerTeam(state, pRequest.PlayerId)

        If playerTeam = "" {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "PLAYER_TEAM_NOT_FOUND"
            Set pResponse.ErrorMessage = "Could not find team for player "_pRequest.PlayerId
            Return $$$OK
        }

        Set pendingBet = phaseState.%Get("pendingBet", "")
        Set respondingTeam = phaseState.%Get("respondingTeam", "")

        If $IsObject(pendingBet) {
            Set pendingRespondingTeam = pendingBet.%Get("respondingTeam", "")

            If pendingRespondingTeam '= "" {
                Set respondingTeam = pendingRespondingTeam
            }

            If playerTeam '= respondingTeam {
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "TEAM_NOT_ALLOWED_TO_RESPOND"
                Set pResponse.ErrorMessage = "Only team "_respondingTeam_" can respond to the pending bet"
                Return $$$OK
            }

            If (pRequest.ActionType '= "querer") && (pRequest.ActionType '= "no_querer") && (pRequest.ActionType '= "ordago") {
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 400
                Set pResponse.ErrorCode = "ILLEGAL_RESPONSE_ACTION"
                Set pResponse.ErrorMessage = "A pending bet can only be answered with querer, no_querer or ordago"
                Return $$$OK
            }
        } Else {
            If (pRequest.ActionType = "querer") || (pRequest.ActionType = "no_querer") {
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 400
                Set pResponse.ErrorCode = "NO_PENDING_BET"
                Set pResponse.ErrorMessage = "There is no pending bet"
                Return $$$OK
            }

            If (pRequest.ActionType = "envidar") || (pRequest.ActionType = "ordago") {
                Set respondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)

                Set responderPlayerId = ..GetNextResponderPlayer(
                    state,
                    phaseState,
                    pRequest.PlayerId,
                    respondingTeam
                )

                If responderPlayerId = "" {
                    Set pResponse.IsLegal = 0
                    Set pResponse.StatusCode = 409

                    If pRequest.ActionType = "ordago" {
                        Set pResponse.ErrorCode = "NO_RESPONDER_FOR_ORDAGO"
                        Set pResponse.ErrorMessage = "No player from team "_respondingTeam_" can respond to the ordago in phase "_phase
                    } Else {
                        Set pResponse.ErrorCode = "NO_RESPONDER_FOR_BET"
                        Set pResponse.ErrorMessage = "No player from team "_respondingTeam_" can respond to the bet in phase "_phase
                    }

                    Return $$$OK
                }
            }
        }

        Set legalActions = ..GetLegalActionsForState(hand)

        If '..ContainsAction(legalActions, pRequest.ActionType) {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "ILLEGAL_ACTION"
            Set pResponse.ErrorMessage = "Action is not legal in current state"
            Set pResponse.LegalActionsJson = legalActions.%ToJSON()
            Return $$$OK
        }

        Set pResponse.IsLegal = 1
        Set pResponse.LegalActionsJson = legalActions.%ToJSON()

        Return $$$OK
    }
    Catch ex {
        Set pResponse.Success = 0
        Set pResponse.IsLegal = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "VALIDATE_ACTION_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method ResolveAction(pRequest As Mus.Msg.ResolveActionRequest, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.ResolveActionResponse).%New()

    Try {
        Set gameState = {}.%FromJSON(pRequest.GameStateJson)
        Set hand = gameState.%Get("hand", "")

        If '$IsObject(hand) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "NO_ACTIVE_HAND"
            Set pResponse.ErrorMessage = "No active hand"
            Return $$$OK
        }

        Set phase = hand.%Get("phase", pRequest.Phase)

        If phase '= pRequest.Phase {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "INVALID_ACTION_PHASE"
            Set pResponse.ErrorMessage = "Current phase is "_phase_", but action phase is "_pRequest.Phase
            Return $$$OK
        }

        If (phase '= "grande") && (phase '= "chica") && (phase '= "pares") && (phase '= "juego") && (phase '= "punto") {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "PHASE_NOT_IMPLEMENTED"
            Set pResponse.ErrorMessage = "Phase "_phase_" is not implemented yet"
            Return $$$OK
        }

        Set phaseState = ..GetOrBuildPhaseState(gameState, hand, phase)

        Set playerTeam = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, pRequest.PlayerId)

        If playerTeam = "" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "PLAYER_TEAM_NOT_FOUND"
            Set pResponse.ErrorMessage = "Could not find team for player "_pRequest.PlayerId
            Return $$$OK
        }

        Set actionEvent = {
            "playerId": (pRequest.PlayerId),
            "team": (playerTeam),
            "type": (pRequest.ActionType),
            "phase": (phase),
            "amount": (pRequest.Amount),
            "createdAt": ($ZDATETIME($HOROLOG, 3))
        }

        If pRequest.ActionType = "pasar" {
            Return ..ResolvePass(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
        }

        If pRequest.ActionType = "envidar" {
            Return ..ResolveEnvidar(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
        }

        If pRequest.ActionType = "querer" {
            Return ..ResolveQuerer(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
        }

        If pRequest.ActionType = "no_querer" {
            Return ..ResolveNoQuerer(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
        }

        If pRequest.ActionType = "ordago" {
            Return ..ResolveOrdago(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
        }

        Set pResponse.Success = 0
        Set pResponse.StatusCode = 400
        Set pResponse.ErrorCode = "UNSUPPORTED_ACTION"
        Set pResponse.ErrorMessage = "Unsupported action "_pRequest.ActionType

        Return $$$OK
    }
    Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "RESOLVE_ACTION_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method GetOrBuildPhaseState(gameState As %DynamicObject, hand As %DynamicObject, phase As %String) As %DynamicObject
{
    Set phaseState = hand.%Get("phaseState", "")

    If phase = "pares" {
        If '$IsObject(phaseState) {
            Return ##class(Mus.Util.MusRules).BuildParesPhaseState(gameState)
        }

        Set participants = phaseState.%Get("participants", "")

        If '$IsObject(participants) {
            Return ##class(Mus.Util.MusRules).BuildParesPhaseState(gameState)
        }

        Return phaseState
    }

    If phase = "juego" {
        If '$IsObject(phaseState) {
            Return ##class(Mus.Util.MusRules).BuildJuegoPhaseState(gameState)
        }

        Set participants = phaseState.%Get("participants", "")

        If '$IsObject(participants) {
            Return ##class(Mus.Util.MusRules).BuildJuegoPhaseState(gameState)
        }

        Return phaseState
    }

    If phase = "punto" {
        If '$IsObject(phaseState) {
            Return ##class(Mus.Util.MusRules).BuildPuntoPhaseState(gameState)
        }

        Set participants = phaseState.%Get("participants", "")

        If '$IsObject(participants) {
            Return ##class(Mus.Util.MusRules).BuildPuntoPhaseState(gameState)
        }

        Return phaseState
    }

    If '$IsObject(phaseState) {
        Return ##class(Mus.Util.MusRules).BuildInitialPhaseState(phase)
    }

    Return phaseState
}

Method ResolvePass(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set passedPlayers = phaseState.%Get("passedPlayers", "")

    If '$IsObject(passedPlayers) {
        Set passedPlayers = []
    }

    If '..ArrayContains(passedPlayers, pRequest.PlayerId) {
        Do passedPlayers.%Push(pRequest.PlayerId)
    }

    Do phaseState.%Set("passedPlayers", passedPlayers)

    Set requiredPassCount = ..GetRequiredPassCount(gameState, hand)

    If requiredPassCount = 0 {
        Return ..AdvanceToNextPhaseWithoutPoints(.gameState, .hand, .phaseState, pRequest, .actionEvent, .pResponse, "no_participants")
    }

    If passedPlayers.%Size() >= requiredPassCount {
        Set points = 1

        If hand.%Get("phase", "") = "pares" {
            Set points = ##class(Mus.Util.MusRules).GetWinnerParesCountPoints(gameState)
        }

        If hand.%Get("phase", "") = "juego" {
            Set points = ##class(Mus.Util.MusRules).GetWinnerJuegoCountPoints(gameState)
        }

        If hand.%Get("phase", "") = "punto" {
            Set points = ##class(Mus.Util.MusRules).GetWinnerPuntoCountPoints(gameState)
        }

        Return ..ClosePhase(.gameState, .hand, .phaseState, pRequest, .actionEvent, .pResponse, "all_players_passed", points)
    }

    Set nextPlayerId = ..GetNextTurnPlayer(gameState, hand, pRequest.PlayerId)

    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("turnPlayerId", nextPlayerId)

    Do gameState.%Set("turnPlayerId", nextPlayerId)
    Do gameState.%Set("hand", hand)

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 0
    Set pResponse.NextPlayerId = nextPlayerId

    Return $$$OK
}

Method ResolveEnvidar(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set amount = pRequest.Amount

    If amount <= 0 {
        Set amount = 2
    }

    Do actionEvent.%Set("amount", amount)

    Set respondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)

    Set nextPlayerId = ..GetNextResponderPlayer(
        gameState,
        phaseState,
        pRequest.PlayerId,
        respondingTeam
    )

    If nextPlayerId = "" {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 409
        Set pResponse.ErrorCode = "NO_RESPONDER_FOR_BET"
        Set pResponse.ErrorMessage = "No player from team "_respondingTeam_" can respond to the bet in phase "_pRequest.Phase
        Return $$$OK
    }

    Set pendingBet = {
        "type": "envidar",
        "amount": (amount),
        "playerId": (pRequest.PlayerId),
        "team": (playerTeam),
        "respondingTeam": (respondingTeam),
        "createdAt": ($ZDATETIME($HOROLOG, 3))
    }

    Do phaseState.%Set("pendingBet", pendingBet)
    Do phaseState.%Set("lastAggressorPlayerId", pRequest.PlayerId)
    Do phaseState.%Set("lastAggressorTeam", playerTeam)
    Do phaseState.%Set("respondingTeam", respondingTeam)

    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("turnPlayerId", nextPlayerId)

    Do gameState.%Set("turnPlayerId", nextPlayerId)
    Do gameState.%Set("hand", hand)

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 0
    Set pResponse.NextPlayerId = nextPlayerId

    Return $$$OK
}

Method ResolveQuerer(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set pendingBet = phaseState.%Get("pendingBet", "")

    If '$IsObject(pendingBet) {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 409
        Set pResponse.ErrorCode = "NO_PENDING_BET"
        Set pResponse.ErrorMessage = "There is no pending bet to accept"
        Return $$$OK
    }

    Set betType = pendingBet.%Get("type", "")

    If betType = "ordago" {
        Return ..ResolveAcceptedOrdago(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
    }

    Set acceptedAmount = +pendingBet.%Get("amount", 2)

    Set acceptedBet = {
        "amount": (acceptedAmount),
        "acceptedByPlayerId": (pRequest.PlayerId),
        "acceptedByTeam": (playerTeam),
        "originalBet": (pendingBet)
    }

    Do phaseState.%Set("acceptedBet", acceptedBet)
    Do phaseState.%Set("pendingBet", "")

    Return ..ClosePhase(.gameState, .hand, .phaseState, pRequest, .actionEvent, .pResponse, "accepted_bet", acceptedAmount)
}

Method ResolveNoQuerer(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set pendingBet = phaseState.%Get("pendingBet", "")

    If '$IsObject(pendingBet) {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 409
        Set pResponse.ErrorCode = "NO_PENDING_BET"
        Set pResponse.ErrorMessage = "There is no pending bet to reject"
        Return $$$OK
    }

    Set bettorTeam = pendingBet.%Get("team")
    Set currentPhase = hand.%Get("phase", pRequest.Phase)
    Set points = 1

    Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, bettorTeam, points)

    Do phaseState.%Set("status", "closed")
    Do phaseState.%Set("pendingBet", "")
    Do phaseState.%Set("winnerTeam", bettorTeam)
    Do phaseState.%Set("pointsAwarded", points)

    Set pointsAwarded = {
        "phase": (currentPhase),
        "team": (bettorTeam),
        "points": (points),
        "reason": "bet_rejected",
        "betType": (pendingBet.%Get("type", ""))
    }

    Return ..AdvanceToNextPhase(.gameState, .hand, .phaseState, pRequest, .actionEvent, .pResponse, pointsAwarded)
}

Method ResolveOrdago(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set respondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)

    Set nextPlayerId = ..GetNextResponderPlayer(
        gameState,
        phaseState,
        pRequest.PlayerId,
        respondingTeam
    )

    If nextPlayerId = "" {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 409
        Set pResponse.ErrorCode = "NO_RESPONDER_FOR_ORDAGO"
        Set pResponse.ErrorMessage = "No player from team "_respondingTeam_" can respond to the ordago in phase "_pRequest.Phase
        Return $$$OK
    }

    Set pendingBet = {
        "type": "ordago",
        "amount": 999,
        "playerId": (pRequest.PlayerId),
        "team": (playerTeam),
        "respondingTeam": (respondingTeam),
        "createdAt": ($ZDATETIME($HOROLOG, 3))
    }

    Do phaseState.%Set("pendingBet", pendingBet)
    Do phaseState.%Set("lastAggressorPlayerId", pRequest.PlayerId)
    Do phaseState.%Set("lastAggressorTeam", playerTeam)
    Do phaseState.%Set("respondingTeam", respondingTeam)

    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("turnPlayerId", nextPlayerId)

    Do gameState.%Set("turnPlayerId", nextPlayerId)
    Do gameState.%Set("hand", hand)

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 0
    Set pResponse.NextPlayerId = nextPlayerId

    Return $$$OK
}

Method ResolveAcceptedOrdago(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set currentPhase = hand.%Get("phase", pRequest.Phase)

    Set winner = ##class(Mus.Util.MusRules).ResolvePhaseWinner(gameState, currentPhase)
    Set winnerTeam = winner.%Get("team", "")

    If winnerTeam = "" {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "ORDAGO_WINNER_TEAM_NOT_FOUND"
        Set pResponse.ErrorMessage = "Could not resolve winner team for ordago in phase "_currentPhase
        Return $$$OK
    }

    Set acceptedBet = {
        "acceptedByPlayerId": (pRequest.PlayerId),
        "acceptedByTeam": (playerTeam),
        "type": "ordago"
    }

    Do phaseState.%Set("acceptedBet", acceptedBet)
    Do phaseState.%Set("pendingBet", "")
    Do phaseState.%Set("status", "closed")
    Do phaseState.%Set("winner", winner)
    Do phaseState.%Set("winnerTeam", winnerTeam)
    Do phaseState.%Set("pointsAwarded", "ordago")

    Set completedPhases = hand.%Get("completedPhases", "")

    If '$IsObject(completedPhases) {
        Set completedPhases = {}
    }

    Do completedPhases.%Set(currentPhase, phaseState)

    Do hand.%Set("completedPhases", completedPhases)
    Do hand.%Set("phase", "manoCerrada")
    Do hand.%Set("status", "closed")
    Do hand.%Set("phaseState", {})
    Do hand.%Set("turnPlayerId", "")

    Set gameState = ##class(Mus.Util.MusRules).FinishGameForTeam(gameState, winnerTeam)

    Do gameState.%Set("phase", "manoCerrada")
    Do gameState.%Set("turnPlayerId", "")
    Do gameState.%Set("hand", hand)

    Set pointsAwarded = {
        "phase": (currentPhase),
        "team": (winnerTeam),
        "points": "ordago",
        "reason": "ordago_accepted",
        "winner": (winner)
    }

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 1
    Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()
    Set pResponse.NextPlayerId = ""

    Return $$$OK
}

Method ClosePhase(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse, reason As %String, points As %Integer) As %Status
{
    Set currentPhase = hand.%Get("phase", pRequest.Phase)

    Set winner = ##class(Mus.Util.MusRules).ResolvePhaseWinner(gameState, currentPhase)
    Set winnerTeam = winner.%Get("team", "")

    If winnerTeam = "" {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "WINNER_TEAM_NOT_FOUND"
        Set pResponse.ErrorMessage = "Could not resolve winner team for phase "_currentPhase
        Return $$$OK
    }

    If currentPhase = "pares", reason = "all_players_passed" {
        Set points = ##class(Mus.Util.MusRules).GetWinnerParesCountPoints(gameState)
    }

    If currentPhase = "juego", reason = "all_players_passed" {
        Set points = ##class(Mus.Util.MusRules).GetWinnerJuegoCountPoints(gameState)
    }

    If currentPhase = "punto", reason = "all_players_passed" {
        Set points = ##class(Mus.Util.MusRules).GetWinnerPuntoCountPoints(gameState)
    }

    Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, winnerTeam, points)

    Do phaseState.%Set("status", "closed")
    Do phaseState.%Set("winner", winner)
    Do phaseState.%Set("pointsAwarded", points)

    Set pointsAwarded = {
        "phase": (currentPhase),
        "team": (winnerTeam),
        "points": (points),
        "reason": (reason),
        "winner": (winner)
    }

    Return ..AdvanceToNextPhase(.gameState, .hand, .phaseState, pRequest, .actionEvent, .pResponse, pointsAwarded)
}

Method AdvanceToNextPhase(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef closedPhaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse, pointsAwarded As %DynamicObject) As %Status
{
    Set currentPhase = hand.%Get("phase", pRequest.Phase)
    Set nextPhase = ##class(Mus.Util.MusRules).GetNextPhase(currentPhase)

    If nextPhase = "" {
        Set nextPhase = "manoCerrada"
    }

    Set completedPhases = hand.%Get("completedPhases", "")

    If '$IsObject(completedPhases) {
        Set completedPhases = {}
    }

    Do completedPhases.%Set(currentPhase, closedPhaseState)
    Do hand.%Set("completedPhases", completedPhases)

    If nextPhase = "manoCerrada" {
        Do hand.%Set("phase", "manoCerrada")
        Do hand.%Set("status", "closed")
        Do hand.%Set("phaseState", {})
        Do hand.%Set("turnPlayerId", "")

        Do gameState.%Set("phase", "manoCerrada")
        Do gameState.%Set("turnPlayerId", "")
        Do gameState.%Set("hand", hand)

        If ##class(Mus.Util.MusRules).IsGameFinished(gameState) {
            Set winningTeam = ##class(Mus.Util.MusRules).GetWinningTeam(gameState)

            Do gameState.%Set("status", "finished")
            Do gameState.%Set("winnerTeam", winningTeam)
            Do gameState.%Set("finishedAt", $ZDATETIME($HOROLOG, 3))
            Do gameState.%Set("nextAction", "")
        } Else {
            Do gameState.%Set("status", "handClosed")
            Do gameState.%Set("nextAction", "startNextHand")
        }

        Set pResponse.NextPlayerId = ""
    } ElseIf nextPhase = "pares" {
        Set nextPhaseState = ##class(Mus.Util.MusRules).BuildParesPhaseState(gameState)
        Set participants = nextPhaseState.%Get("participants", "")

        If '$IsObject(participants) {
            Set participants = []
        }

        If participants.%Size() = 0 {
            Set skippedParesState = nextPhaseState
            Do skippedParesState.%Set("status", "skipped")
            Do skippedParesState.%Set("reason", "no_players_with_pares")

            Do completedPhases.%Set("pares", skippedParesState)
            Do hand.%Set("completedPhases", completedPhases)

            Set afterParesPhase = ##class(Mus.Util.MusRules).GetNextPhase("pares")

            If afterParesPhase = "" {
                Set afterParesPhase = "manoCerrada"
            }

            Set sc = ..OpenPhase(.gameState, .hand, afterParesPhase, .pResponse)
            If $$$ISERR(sc) {
                Return sc
            }
        } Else {
            Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)
            Set orderedParticipants = ##class(Mus.Util.MusRules).OrderParticipantsFrom(participants, initialTurnPlayerId)
            Do nextPhaseState.%Set("participants", orderedParticipants)
            Set firstParticipant = orderedParticipants.%Get(0)

            Do hand.%Set("phase", "pares")
            Do hand.%Set("phaseState", nextPhaseState)
            Do hand.%Set("turnPlayerId", firstParticipant)

            Do gameState.%Set("phase", "pares")
            Do gameState.%Set("turnPlayerId", firstParticipant)
            Do gameState.%Set("hand", hand)

            Set pResponse.NextPlayerId = firstParticipant
        }
    } ElseIf nextPhase = "juego" {
        Set nextPhaseState = ##class(Mus.Util.MusRules).BuildJuegoPhaseState(gameState)
        Set participants = nextPhaseState.%Get("participants", "")

        If '$IsObject(participants) {
            Set participants = []
        }

        If participants.%Size() = 0 {
            Set skippedJuegoState = nextPhaseState
            Do skippedJuegoState.%Set("status", "skipped")
            Do skippedJuegoState.%Set("reason", "no_players_with_juego")

            Do completedPhases.%Set("juego", skippedJuegoState)
            Do hand.%Set("completedPhases", completedPhases)

            Set puntoState = ##class(Mus.Util.MusRules).BuildPuntoPhaseState(gameState)
            Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)

            Do hand.%Set("phase", "punto")
            Do hand.%Set("phaseState", puntoState)
            Do hand.%Set("turnPlayerId", initialTurnPlayerId)

            Do gameState.%Set("phase", "punto")
            Do gameState.%Set("turnPlayerId", initialTurnPlayerId)
            Do gameState.%Set("hand", hand)

            Set pResponse.NextPlayerId = initialTurnPlayerId
        } Else {
            Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)
            Set orderedParticipants = ##class(Mus.Util.MusRules).OrderParticipantsFrom(participants, initialTurnPlayerId)
            Do nextPhaseState.%Set("participants", orderedParticipants)
            Set firstParticipant = orderedParticipants.%Get(0)

            Do hand.%Set("phase", "juego")
            Do hand.%Set("phaseState", nextPhaseState)
            Do hand.%Set("turnPlayerId", firstParticipant)

            Do gameState.%Set("phase", "juego")
            Do gameState.%Set("turnPlayerId", firstParticipant)
            Do gameState.%Set("hand", hand)

            Set pResponse.NextPlayerId = firstParticipant
        }
    } ElseIf nextPhase = "punto" {
        Set puntoState = ##class(Mus.Util.MusRules).BuildPuntoPhaseState(gameState)
        Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)

        Do hand.%Set("phase", "punto")
        Do hand.%Set("phaseState", puntoState)
        Do hand.%Set("turnPlayerId", initialTurnPlayerId)

        Do gameState.%Set("phase", "punto")
        Do gameState.%Set("turnPlayerId", initialTurnPlayerId)
        Do gameState.%Set("hand", hand)

        Set pResponse.NextPlayerId = initialTurnPlayerId
    } Else {
        Set nextPhaseState = ##class(Mus.Util.MusRules).BuildInitialPhaseState(nextPhase)
        Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)

        Do hand.%Set("phase", nextPhase)
        Do hand.%Set("phaseState", nextPhaseState)
        Do hand.%Set("turnPlayerId", initialTurnPlayerId)

        Do gameState.%Set("phase", nextPhase)
        Do gameState.%Set("turnPlayerId", initialTurnPlayerId)
        Do gameState.%Set("hand", hand)

        Set pResponse.NextPlayerId = initialTurnPlayerId
    }

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 1
    Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()

    Return $$$OK
}

Method OpenPhase(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, phase As %String, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)

    If phase = "juego" {
        Set phaseState = ##class(Mus.Util.MusRules).BuildJuegoPhaseState(gameState)
        Set participants = phaseState.%Get("participants", "")

        If '$IsObject(participants) {
            Set participants = []
        }

        If participants.%Size() = 0 {
            Set completedPhases = hand.%Get("completedPhases", "")

            If '$IsObject(completedPhases) {
                Set completedPhases = {}
            }

            Do phaseState.%Set("status", "skipped")
            Do phaseState.%Set("reason", "no_players_with_juego")
            Do completedPhases.%Set("juego", phaseState)
            Do hand.%Set("completedPhases", completedPhases)

            Set puntoState = ##class(Mus.Util.MusRules).BuildPuntoPhaseState(gameState)
            Set puntoParticipants = puntoState.%Get("participants", "")

            If $IsObject(puntoParticipants) {
                Set orderedParticipants = ##class(Mus.Util.MusRules).OrderParticipantsFrom(puntoParticipants, initialTurnPlayerId)
                Do puntoState.%Set("participants", orderedParticipants)
            }

            Do hand.%Set("phase", "punto")
            Do hand.%Set("phaseState", puntoState)
            Do hand.%Set("turnPlayerId", initialTurnPlayerId)

            Do gameState.%Set("phase", "punto")
            Do gameState.%Set("turnPlayerId", initialTurnPlayerId)
            Do gameState.%Set("hand", hand)

            Set pResponse.NextPlayerId = initialTurnPlayerId

            Return $$$OK
        }

        Set orderedParticipants = ##class(Mus.Util.MusRules).OrderParticipantsFrom(participants, initialTurnPlayerId)
        Do phaseState.%Set("participants", orderedParticipants)

        Set firstParticipant = orderedParticipants.%Get(0)

        Do hand.%Set("phase", "juego")
        Do hand.%Set("phaseState", phaseState)
        Do hand.%Set("turnPlayerId", firstParticipant)

        Do gameState.%Set("phase", "juego")
        Do gameState.%Set("turnPlayerId", firstParticipant)
        Do gameState.%Set("hand", hand)

        Set pResponse.NextPlayerId = firstParticipant

        Return $$$OK
    }

    If phase = "punto" {
        Set phaseState = ##class(Mus.Util.MusRules).BuildPuntoPhaseState(gameState)
        Set participants = phaseState.%Get("participants", "")

        If $IsObject(participants) {
            Set orderedParticipants = ##class(Mus.Util.MusRules).OrderParticipantsFrom(participants, initialTurnPlayerId)
            Do phaseState.%Set("participants", orderedParticipants)
        }

        Do hand.%Set("phase", "punto")
        Do hand.%Set("phaseState", phaseState)
        Do hand.%Set("turnPlayerId", initialTurnPlayerId)

        Do gameState.%Set("phase", "punto")
        Do gameState.%Set("turnPlayerId", initialTurnPlayerId)
        Do gameState.%Set("hand", hand)

        Set pResponse.NextPlayerId = initialTurnPlayerId

        Return $$$OK
    }

    If phase = "manoCerrada" {
        Do hand.%Set("phase", "manoCerrada")
        Do hand.%Set("status", "closed")
        Do hand.%Set("phaseState", {})
        Do hand.%Set("turnPlayerId", "")

        Do gameState.%Set("phase", "manoCerrada")
        Do gameState.%Set("turnPlayerId", "")
        Do gameState.%Set("hand", hand)

        If ##class(Mus.Util.MusRules).IsGameFinished(gameState) {
            Set winningTeam = ##class(Mus.Util.MusRules).GetWinningTeam(gameState)

            Do gameState.%Set("status", "finished")
            Do gameState.%Set("winnerTeam", winningTeam)
            Do gameState.%Set("finishedAt", $ZDATETIME($HOROLOG, 3))
            Do gameState.%Set("nextAction", "")
        } Else {
            Do gameState.%Set("status", "handClosed")
            Do gameState.%Set("nextAction", "startNextHand")
        }

        Set pResponse.NextPlayerId = ""

        Return $$$OK
    }

    Do hand.%Set("phase", phase)
    Do hand.%Set("phaseState", ##class(Mus.Util.MusRules).BuildInitialPhaseState(phase))
    Do hand.%Set("turnPlayerId", initialTurnPlayerId)

    Do gameState.%Set("phase", phase)
    Do gameState.%Set("turnPlayerId", initialTurnPlayerId)
    Do gameState.%Set("hand", hand)

    Set pResponse.NextPlayerId = initialTurnPlayerId

    Return $$$OK
}

Method AdvanceToNextPhaseWithoutPoints(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse, reason As %String) As %Status
{
    Set pointsAwarded = {
        "phase": (hand.%Get("phase", pRequest.Phase)),
        "team": "",
        "points": 0,
        "reason": (reason)
    }

    Return ..AdvanceToNextPhase(.gameState, .hand, .phaseState, pRequest, .actionEvent, .pResponse, pointsAwarded)
}

Method GetLegalActionsForState(hand As %DynamicObject) As %DynamicArray
{
    Set actions = []

    Set phaseState = hand.%Get("phaseState", "")

    If '$IsObject(phaseState) {
        Do actions.%Push("pasar")
        Do actions.%Push("envidar")
        Do actions.%Push("ordago")
        Return actions
    }

    Set pendingBet = phaseState.%Get("pendingBet", "")

    If '$IsObject(pendingBet) {
        Do actions.%Push("pasar")
        Do actions.%Push("envidar")
        Do actions.%Push("ordago")
        Return actions
    }

    Do actions.%Push("querer")
    Do actions.%Push("no_querer")
    Do actions.%Push("ordago")

    Return actions
}

Method GetPhaseParticipants(gameState As %DynamicObject, hand As %DynamicObject) As %DynamicArray
{
    Set phase = hand.%Get("phase", "")

    If phase = "pares" {
        Set phaseState = hand.%Get("phaseState", "")

        If '$IsObject(phaseState) {
            Set phaseState = ##class(Mus.Util.MusRules).BuildParesPhaseState(gameState)
        } Else {
            Set participants = phaseState.%Get("participants", "")

            If '$IsObject(participants) {
                Set phaseState = ##class(Mus.Util.MusRules).BuildParesPhaseState(gameState)
            }
        }

        Set participants = phaseState.%Get("participants", "")

        If $IsObject(participants) {
            Return participants
        }

        Return []
    }

    If phase = "juego" {
        Set phaseState = hand.%Get("phaseState", "")

        If '$IsObject(phaseState) {
            Set phaseState = ##class(Mus.Util.MusRules).BuildJuegoPhaseState(gameState)
        } Else {
            Set participants = phaseState.%Get("participants", "")

            If '$IsObject(participants) {
                Set phaseState = ##class(Mus.Util.MusRules).BuildJuegoPhaseState(gameState)
            }
        }

        Set participants = phaseState.%Get("participants", "")

        If $IsObject(participants) {
            Return participants
        }

        Return []
    }

    If phase = "punto" {
        Set phaseState = hand.%Get("phaseState", "")

        If '$IsObject(phaseState) {
            Set phaseState = ##class(Mus.Util.MusRules).BuildPuntoPhaseState(gameState)
        }

        Set participants = phaseState.%Get("participants", "")

        If $IsObject(participants) {
            Return participants
        }

        Return ["P1", "P2", "P3", "P4"]
    }

    Return ["P1", "P2", "P3", "P4"]
}

Method GetNextTurnPlayer(gameState As %DynamicObject, hand As %DynamicObject, currentPlayerId As %String) As %String
{
    Set participants = ..GetPhaseParticipants(gameState, hand)

    If participants.%Size() = 0 {
        Return ""
    }

    For i=0:1:participants.%Size()-1 {
        If participants.%Get(i) = currentPlayerId {
            Set nextIndex = i + 1

            If nextIndex >= participants.%Size() {
                Set nextIndex = 0
            }

            Return participants.%Get(nextIndex)
        }
    }

    Return participants.%Get(0)
}

Method GetNextResponderPlayer(gameState As %DynamicObject, phaseState As %DynamicObject, aggressorPlayerId As %String, respondingTeam As %String) As %String
{
    If respondingTeam = "" {
        Return ""
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
            Return candidate
        }
    }

    Return ""
}

Method GetRequiredPassCount(gameState As %DynamicObject, hand As %DynamicObject) As %Integer
{
    Set participants = ..GetPhaseParticipants(gameState, hand)

    Return participants.%Size()
}

Method ContainsAction(actions As %DynamicArray, actionType As %String) As %Boolean
{
    For i=0:1:actions.%Size()-1 {
        If actions.%Get(i) = actionType {
            Return 1
        }
    }

    Return 0
}

Method ArrayContains(array As %DynamicArray, value As %String) As %Boolean
{
    For i=0:1:array.%Size()-1 {
        If array.%Get(i) = value {
            Return 1
        }
    }

    Return 0
}

Method GetInitialTurnPlayerId(gameState As %DynamicObject) As %String
{
    Return ##class(Mus.Util.MusRules).GetInitialTurnPlayerIdForGameState(gameState)
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
