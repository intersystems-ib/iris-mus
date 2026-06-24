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

        If pRequest.ActionType = "confirmar_declaracion" {
            If phaseState.%Get("status", "") '= "declarationPending" {
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "NO_DECLARATION_PENDING"
                Set pResponse.ErrorMessage = "There is no pending declaration to confirm in phase "_phase
                Set legalActions = ["confirmar_declaracion"]
                Set pResponse.LegalActionsJson = legalActions.%ToJSON()
                Return $$$OK
            }

            Set pResponse.IsLegal = 1
            Set pResponse.StatusCode = 200
            Set legalActions = ["confirmar_declaracion"]
            Set pResponse.LegalActionsJson = legalActions.%ToJSON()
            Return $$$OK
        }

        If phaseState.%Get("status", "") = "declarationPending" {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "DECLARATION_CONFIRMATION_REQUIRED"
            Set pResponse.ErrorMessage = "Phase "_phase_" is waiting for declaration confirmation"
            Set legalActions = ["confirmar_declaracion"]
            Set pResponse.LegalActionsJson = legalActions.%ToJSON()
            Return $$$OK
        }

        Set turnPlayerId = hand.%Get("turnPlayerId", "")

        If turnPlayerId = "" {
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "TURN_NOT_INITIALIZED"
            Set pResponse.ErrorMessage = "The current hand does not have turnPlayerId initialized"
            Return $$$OK
        }

        Set phasePendingBet = phaseState.%Get("pendingBet", "")
        Set allowOutOfTurnPendingResponse = 0

        If $IsObject(phasePendingBet) {
            If (pRequest.ActionType = "querer") || (pRequest.ActionType = "no_querer") {
                If ..IsPendingBetResponder(phasePendingBet, pRequest.PlayerId) {
                    Set allowOutOfTurnPendingResponse = 1
                }
            }
        }

        If (turnPlayerId '= pRequest.PlayerId) && 'allowOutOfTurnPendingResponse {
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
            Set pendingLegalActions = ["querer", "no_querer"]

            If pendingBet.%Get("type", "") '= "ordago" {
                Do pendingLegalActions.%Push("envidar")
                Do pendingLegalActions.%Push("ordago")
            }

            Set respondingTeam = pendingBet.%Get("respondingTeam", "")

            If respondingTeam = "" {
                Set respondingTeam = phaseState.%Get("respondingTeam", "")
            }

            If playerTeam '= respondingTeam {
                Set pResponse.Success = 0
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "PLAYER_CANNOT_RESPOND_TO_BET"
                Set pResponse.ErrorMessage = "Player team cannot respond to the current bet"
                Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                Return $$$OK
            }

            If '..IsPendingBetResponder(pendingBet, pRequest.PlayerId) {
                Set pResponse.Success = 0
                Set pResponse.IsLegal = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "PLAYER_NOT_PENDING_BET_RESPONDER"
                Set pResponse.ErrorMessage = "Player is not allowed to respond to the pending bet"
                Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                Return $$$OK
            }

            If pRequest.ActionType = "querer" {
                Set pResponse.IsLegal = 1
                Set pResponse.StatusCode = 200
                Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                Return $$$OK
            }

            If pRequest.ActionType = "no_querer" {
                Set pResponse.IsLegal = 1
                Set pResponse.StatusCode = 200
                Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                Return $$$OK
            }

            If pRequest.ActionType = "envidar" {
                If pendingBet.%Get("type", "") = "ordago" {
                    Set pResponse.Success = 0
                    Set pResponse.IsLegal = 0
                    Set pResponse.StatusCode = 409
                    Set pResponse.ErrorCode = "CANNOT_RAISE_ORDAGO"
                    Set pResponse.ErrorMessage = "Cannot raise a pending ordago"
                    Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                    Return $$$OK
                }

                Set currentAmount = +pendingBet.%Get("amount", 0)
                Set requestedAmount = +pRequest.Amount

                If requestedAmount <= currentAmount {
                    Set pResponse.Success = 0
                    Set pResponse.IsLegal = 0
                    Set pResponse.StatusCode = 400
                    Set pResponse.ErrorCode = "RAISE_AMOUNT_TOO_LOW"
                    Set pResponse.ErrorMessage = "Raise amount must be greater than current pending bet"
                    Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                    Return $$$OK
                }

                Set pResponse.IsLegal = 1
                Set pResponse.StatusCode = 200
                Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                Return $$$OK
            }

            If pRequest.ActionType = "ordago" {
                If pendingBet.%Get("type", "") = "ordago" {
                    Set pResponse.Success = 0
                    Set pResponse.IsLegal = 0
                    Set pResponse.StatusCode = 409
                    Set pResponse.ErrorCode = "ORDAGO_ALREADY_PENDING"
                    Set pResponse.ErrorMessage = "There is already a pending ordago"
                    Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                    Return $$$OK
                }

                Set pResponse.IsLegal = 1
                Set pResponse.StatusCode = 200
                Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
                Return $$$OK
            }

            Set pResponse.Success = 0
            Set pResponse.IsLegal = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "PENDING_BET_REQUIRES_RESPONSE"
            Set pResponse.ErrorMessage = "Pending bet must be answered with querer, no_querer, envidar or ordago"
            Set pResponse.LegalActionsJson = pendingLegalActions.%ToJSON()
            Return $$$OK
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

        If pRequest.ActionType = "confirmar_declaracion" {
            Set actionEvent = {
                "playerId": (pRequest.PlayerId),
                "team": "",
                "type": (pRequest.ActionType),
                "phase": (phase),
                "amount": (pRequest.Amount),
                "createdAt": ($ZDATETIME($HOROLOG, 3))
            }

            Return ..ResolveDeclarationConfirmation(.gameState, .hand, .phaseState, pRequest, .actionEvent, .pResponse)
        }

        If phaseState.%Get("status", "") = "declarationPending" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "DECLARATION_CONFIRMATION_REQUIRED"
            Set pResponse.ErrorMessage = "Phase "_phase_" is waiting for declaration confirmation"
            Return $$$OK
        }

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
    Set amount = +pRequest.Amount

    If amount <= 0 {
        Set amount = 2
    }

    Set existingBet = phaseState.%Get("pendingBet", "")

    If '$IsObject(existingBet) {
        Set respondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)
        Set respondingPlayers = ..BuildRespondingPlayers(gameState, phaseState, pRequest.PlayerId, respondingTeam)

        If respondingPlayers.%Size() = 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "NO_RESPONDER_FOR_BET"
            Set pResponse.ErrorMessage = "No player from team "_respondingTeam_" can respond to the bet in phase "_pRequest.Phase
            Return $$$OK
        }

        Set nextPlayerId = respondingPlayers.%Get(0)

        Set pendingBet = {
            "type": "envidar",
            "amount": (amount),
            "previousAmount": 0,
            "openedByPlayerId": (pRequest.PlayerId),
            "openedByTeam": (playerTeam),
            "lastRaisePlayerId": (pRequest.PlayerId),
            "lastRaiseTeam": (playerTeam),
            "respondingTeam": (respondingTeam),
            "respondingPlayerId": (nextPlayerId),
            "raiseCount": 0,
            "createdAt": ($ZDATETIME($HOROLOG, 3)),
            "updatedAt": ($ZDATETIME($HOROLOG, 3))
        }

        Do pendingBet.%Set("respondingPlayers", respondingPlayers)
        Do pendingBet.%Set("acceptedPlayers", [])
        Do pendingBet.%Set("rejectedPlayers", [])
    } Else {
        Set currentAmount = +existingBet.%Get("amount", 0)
        Set respondingTeam = existingBet.%Get("respondingTeam", "")

        If respondingTeam = "" {
            Set respondingTeam = phaseState.%Get("respondingTeam", "")
        }

        If playerTeam '= respondingTeam {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "PLAYER_CANNOT_RAISE_BET"
            Set pResponse.ErrorMessage = "Player team cannot raise the current bet"
            Return $$$OK
        }

        If amount <= currentAmount {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "RAISE_AMOUNT_TOO_LOW"
            Set pResponse.ErrorMessage = "Raise amount must be greater than current pending bet"
            Return $$$OK
        }

        Set newRespondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)
        Set respondingPlayers = ..BuildRespondingPlayers(gameState, phaseState, pRequest.PlayerId, newRespondingTeam)

        If respondingPlayers.%Size() = 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "NO_RESPONDER_FOR_RAISE"
            Set pResponse.ErrorMessage = "No player from team "_newRespondingTeam_" can respond to the raise in phase "_pRequest.Phase
            Return $$$OK
        }

        Set nextPlayerId = respondingPlayers.%Get(0)

        Set pendingBet = existingBet
        Do pendingBet.%Set("type", "envidar")
        Do pendingBet.%Set("previousAmount", currentAmount)
        Do pendingBet.%Set("amount", amount)
        Do pendingBet.%Set("lastRaisePlayerId", pRequest.PlayerId)
        Do pendingBet.%Set("lastRaiseTeam", playerTeam)
        Do pendingBet.%Set("respondingTeam", newRespondingTeam)
        Do pendingBet.%Set("respondingPlayers", respondingPlayers)
        Do pendingBet.%Set("acceptedPlayers", [])
        Do pendingBet.%Set("rejectedPlayers", [])
        Do pendingBet.%Set("respondingPlayerId", nextPlayerId)
        Do pendingBet.%Set("raiseCount", +pendingBet.%Get("raiseCount", 0) + 1)
        Do pendingBet.%Set("updatedAt", $ZDATETIME($HOROLOG, 3))
    }

    Do actionEvent.%Set("amount", amount)
    Do actionEvent.%Set("betAmount", amount)
    Do actionEvent.%Set("previousAmount", +pendingBet.%Get("previousAmount", 0))
    Do actionEvent.%Set("respondingTeam", pendingBet.%Get("respondingTeam", ""))
    Do actionEvent.%Set("respondingPlayerId", pendingBet.%Get("respondingPlayerId", ""))
    Do actionEvent.%Set("respondingPlayers", pendingBet.%Get("respondingPlayers", []))

    Do phaseState.%Set("pendingBet", pendingBet)
    Do phaseState.%Set("lastAggressorPlayerId", pRequest.PlayerId)
    Do phaseState.%Set("lastAggressorTeam", playerTeam)
    Do phaseState.%Set("respondingTeam", pendingBet.%Get("respondingTeam", ""))

    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("turnPlayerId", pendingBet.%Get("respondingPlayerId", ""))

    Do gameState.%Set("turnPlayerId", pendingBet.%Get("respondingPlayerId", ""))
    Do gameState.%Set("hand", hand)

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 0
    Set pResponse.NextPlayerId = pendingBet.%Get("respondingPlayerId", "")

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

    If '..IsPendingBetResponder(pendingBet, pRequest.PlayerId) {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 409
        Set pResponse.ErrorCode = "PLAYER_NOT_PENDING_BET_RESPONDER"
        Set pResponse.ErrorMessage = "Player is not allowed to accept this pending bet"
        Return $$$OK
    }

    Set betType = pendingBet.%Get("type", "")

    If betType = "ordago" {
        Return ..ResolveAcceptedOrdago(
            .gameState,
            .hand,
            .phaseState,
            pRequest,
            playerTeam,
            .actionEvent,
            .pResponse
        )
    }

    Set acceptedAmount = +pendingBet.%Get("amount", 0)

    Set acceptedBet = {
        "type": (pendingBet.%Get("type", "envidar")),
        "amount": (acceptedAmount),
        "previousAmount": (+pendingBet.%Get("previousAmount", 0)),
        "openedByPlayerId": (pendingBet.%Get("openedByPlayerId", "")),
        "openedByTeam": (pendingBet.%Get("openedByTeam", "")),
        "lastRaisePlayerId": (pendingBet.%Get("lastRaisePlayerId", "")),
        "lastRaiseTeam": (pendingBet.%Get("lastRaiseTeam", "")),
        "acceptedByPlayerId": (pRequest.PlayerId),
        "acceptedByTeam": (playerTeam),
        "acceptedAt": ($ZDATETIME($HOROLOG, 3))
    }

    Do actionEvent.%Set("acceptedByPlayerId", pRequest.PlayerId)
    Do actionEvent.%Set("acceptedByTeam", playerTeam)
    Do actionEvent.%Set("acceptedAmount", acceptedAmount)

    Do phaseState.%Set("acceptedBet", acceptedBet)
    Do phaseState.%Remove("pendingBet")
    Do phaseState.%Remove("respondingTeam")

    Return ..ClosePhase(
        .gameState,
        .hand,
        .phaseState,
        pRequest,
        .actionEvent,
        .pResponse,
        "accepted_bet",
        acceptedAmount
    )
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

    If '..IsPendingBetResponder(pendingBet, pRequest.PlayerId) {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 409
        Set pResponse.ErrorCode = "PLAYER_NOT_PENDING_BET_RESPONDER"
        Set pResponse.ErrorMessage = "Player is not allowed to reject this pending bet"
        Return $$$OK
    }

    Set rejectedPlayers = pendingBet.%Get("rejectedPlayers", "")

    If '$IsObject(rejectedPlayers) {
        Set rejectedPlayers = []
    }

    If '..ArrayContains(rejectedPlayers, pRequest.PlayerId) {
        Do rejectedPlayers.%Push(pRequest.PlayerId)
    }

    Do pendingBet.%Set("rejectedPlayers", rejectedPlayers)

    Set respondingPlayers = pendingBet.%Get("respondingPlayers", "")

    If '$IsObject(respondingPlayers) {
        Set respondingPlayers = []

        Set fallbackResponder = pendingBet.%Get("respondingPlayerId", "")

        If fallbackResponder '= "" {
            Do respondingPlayers.%Push(fallbackResponder)
        }
    }

    /*
      Si aun queda algun jugador rival sin rechazar, el envite sigue pendiente.
      El siguiente jugador puede aceptar y cerrar el envite, o rechazar tambien.
    */
    Set nextResponder = ..GetNextRejectedPendingResponder(
        pendingBet,
        pRequest.PlayerId
    )

    If nextResponder '= "" {
        Do pendingBet.%Set("respondingPlayerId", nextResponder)
        Do phaseState.%Set("pendingBet", pendingBet)
        Do phaseState.%Set("respondingTeam", pendingBet.%Get("respondingTeam", ""))

        Do hand.%Set("phaseState", phaseState)
        Do hand.%Set("turnPlayerId", nextResponder)

        Do gameState.%Set("turnPlayerId", nextResponder)
        Do gameState.%Set("hand", hand)

        Do actionEvent.%Set("rejectedByPlayerId", pRequest.PlayerId)
        Do actionEvent.%Set("rejectedByTeam", playerTeam)
        Do actionEvent.%Set("partialReject", 1)
        Do actionEvent.%Set("pendingBet", pendingBet)

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
        Set pResponse.ActionEventJson = actionEvent.%ToJSON()
        Set pResponse.PhaseClosed = 0
        Set pResponse.NextPlayerId = nextResponder

        Return $$$OK
    }

    /*
      Si todos los respondingPlayers han rechazado, entonces se rechaza el envite.
    */
    Set currentPhase = hand.%Get("phase", pRequest.Phase)

    Set winnerTeam = pendingBet.%Get("lastRaiseTeam", "")

    If winnerTeam = "" {
        Set winnerTeam = pendingBet.%Get("openedByTeam", "")
    }

    If winnerTeam = "" {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "NO_QUERER_WINNER_TEAM_NOT_FOUND"
        Set pResponse.ErrorMessage = "Could not resolve winner team for rejected bet"
        Return $$$OK
    }

    Set points = ..GetNoQuererAwardAmount(pendingBet)

    Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, winnerTeam, points)

    Do actionEvent.%Set("winnerTeam", winnerTeam)
    Do actionEvent.%Set("pointsAwarded", points)
    Do actionEvent.%Set("rejectedByPlayerId", pRequest.PlayerId)
    Do actionEvent.%Set("rejectedByTeam", playerTeam)
    Do actionEvent.%Set("rejectedPlayers", rejectedPlayers)
    Do actionEvent.%Set("rejectedBetAmount", +pendingBet.%Get("amount", 0))
    Do actionEvent.%Set("previousAmount", +pendingBet.%Get("previousAmount", 0))
    Do actionEvent.%Set("lastRaiseTeam", pendingBet.%Get("lastRaiseTeam", ""))
    Do actionEvent.%Set("lastRaisePlayerId", pendingBet.%Get("lastRaisePlayerId", ""))

    Do phaseState.%Set("status", "closed")
    Do phaseState.%Set("winnerTeam", winnerTeam)
    Do phaseState.%Set("pointsAwarded", points)
    Do phaseState.%Set("rejectedPlayers", rejectedPlayers)
    Do phaseState.%Set("rejectedBet", pendingBet)
    Do phaseState.%Remove("pendingBet")
    Do phaseState.%Remove("respondingTeam")

    Set pointsAwarded = {
        "phase": (currentPhase),
        "team": (winnerTeam),
        "points": (points),
        "reason": "bet_rejected",
        "rejectedByPlayerId": (pRequest.PlayerId),
        "rejectedByTeam": (playerTeam),
        "rejectedPlayers": (rejectedPlayers),
        "rejectedBetAmount": (+pendingBet.%Get("amount", 0)),
        "previousAmount": (+pendingBet.%Get("previousAmount", 0)),
        "lastRaiseTeam": (pendingBet.%Get("lastRaiseTeam", "")),
        "lastRaisePlayerId": (pendingBet.%Get("lastRaisePlayerId", ""))
    }

    /*
      En Pares y Juego, el deje se suma en el acto, pero el valor ordinario
      de la jugada de la pareja ganadora se cobra al final de la mano.
    */
    If currentPhase = "pares" {
        Set countPointsByTeam = ..BuildLanceCountPointsByTeam(gameState, currentPhase, phaseState)
        Do phaseState.%Set("teamCountPoints", countPointsByTeam)
        Do phaseState.%Set("countPointsPendingUntilHandEnd", 1)
        Do pointsAwarded.%Set("teamCountPoints", countPointsByTeam)
    }

    If currentPhase = "juego" {
        Set countPointsByTeam = ..BuildLanceCountPointsByTeam(gameState, currentPhase, phaseState)
        Do phaseState.%Set("teamCountPoints", countPointsByTeam)
        Do phaseState.%Set("countPointsPendingUntilHandEnd", 1)
        Do pointsAwarded.%Set("teamCountPoints", countPointsByTeam)
    }

    Return ..AdvanceToNextPhase(
        .gameState,
        .hand,
        .phaseState,
        pRequest,
        .actionEvent,
        .pResponse,
        pointsAwarded
    )
}

Method ResolveOrdago(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set amount = 999
    Set existingBet = phaseState.%Get("pendingBet", "")

    If '$IsObject(existingBet) {
        Set previousAmount = 0
        Set respondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)
        Set respondingPlayers = ..BuildRespondingPlayers(gameState, phaseState, pRequest.PlayerId, respondingTeam)

        If respondingPlayers.%Size() = 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "NO_RESPONDER_FOR_ORDAGO"
            Set pResponse.ErrorMessage = "No player from team "_respondingTeam_" can respond to the ordago in phase "_pRequest.Phase
            Return $$$OK
        }

        Set nextPlayerId = respondingPlayers.%Get(0)

        Set pendingBet = {
            "type": "ordago",
            "amount": (amount),
            "previousAmount": (previousAmount),
            "openedByPlayerId": (pRequest.PlayerId),
            "openedByTeam": (playerTeam),
            "lastRaisePlayerId": (pRequest.PlayerId),
            "lastRaiseTeam": (playerTeam),
            "respondingTeam": (respondingTeam),
            "respondingPlayerId": (nextPlayerId),
            "raiseCount": 0,
            "createdAt": ($ZDATETIME($HOROLOG, 3)),
            "updatedAt": ($ZDATETIME($HOROLOG, 3))
        }

        Do pendingBet.%Set("respondingPlayers", respondingPlayers)
        Do pendingBet.%Set("acceptedPlayers", [])
        Do pendingBet.%Set("rejectedPlayers", [])
    } Else {
        Set currentAmount = +existingBet.%Get("amount", 0)
        Set respondingTeam = existingBet.%Get("respondingTeam", "")

        If respondingTeam = "" {
            Set respondingTeam = phaseState.%Get("respondingTeam", "")
        }

        If playerTeam '= respondingTeam {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "PLAYER_CANNOT_RAISE_TO_ORDAGO"
            Set pResponse.ErrorMessage = "Player team cannot raise the current bet to ordago"
            Return $$$OK
        }

        Set newRespondingTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)
        Set respondingPlayers = ..BuildRespondingPlayers(gameState, phaseState, pRequest.PlayerId, newRespondingTeam)

        If respondingPlayers.%Size() = 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "NO_RESPONDER_FOR_ORDAGO_RAISE"
            Set pResponse.ErrorMessage = "No player from team "_newRespondingTeam_" can respond to the ordago in phase "_pRequest.Phase
            Return $$$OK
        }

        Set nextPlayerId = respondingPlayers.%Get(0)

        Set pendingBet = existingBet
        Do pendingBet.%Set("type", "ordago")
        Do pendingBet.%Set("previousAmount", currentAmount)
        Do pendingBet.%Set("amount", amount)
        Do pendingBet.%Set("lastRaisePlayerId", pRequest.PlayerId)
        Do pendingBet.%Set("lastRaiseTeam", playerTeam)
        Do pendingBet.%Set("respondingTeam", newRespondingTeam)
        Do pendingBet.%Set("respondingPlayers", respondingPlayers)
        Do pendingBet.%Set("acceptedPlayers", [])
        Do pendingBet.%Set("rejectedPlayers", [])
        Do pendingBet.%Set("respondingPlayerId", nextPlayerId)
        Do pendingBet.%Set("raiseCount", +pendingBet.%Get("raiseCount", 0) + 1)
        Do pendingBet.%Set("updatedAt", $ZDATETIME($HOROLOG, 3))
    }

    Do actionEvent.%Set("amount", amount)
    Do actionEvent.%Set("betAmount", amount)
    Do actionEvent.%Set("previousAmount", +pendingBet.%Get("previousAmount", 0))
    Do actionEvent.%Set("respondingTeam", pendingBet.%Get("respondingTeam", ""))
    Do actionEvent.%Set("respondingPlayerId", pendingBet.%Get("respondingPlayerId", ""))
    Do actionEvent.%Set("respondingPlayers", pendingBet.%Get("respondingPlayers", []))

    Do phaseState.%Set("pendingBet", pendingBet)
    Do phaseState.%Set("lastAggressorPlayerId", pRequest.PlayerId)
    Do phaseState.%Set("lastAggressorTeam", playerTeam)
    Do phaseState.%Set("respondingTeam", pendingBet.%Get("respondingTeam", ""))

    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("turnPlayerId", pendingBet.%Get("respondingPlayerId", ""))

    Do gameState.%Set("turnPlayerId", pendingBet.%Get("respondingPlayerId", ""))
    Do gameState.%Set("hand", hand)

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 0
    Set pResponse.NextPlayerId = pendingBet.%Get("respondingPlayerId", "")

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

    Set pendingBet = phaseState.%Get("pendingBet", "")

    If $IsObject(pendingBet) {
        Do acceptedBet.%Set("openedByPlayerId", pendingBet.%Get("openedByPlayerId", ""))
        Do acceptedBet.%Set("openedByTeam", pendingBet.%Get("openedByTeam", ""))
        Do acceptedBet.%Set("lastRaisePlayerId", pendingBet.%Get("lastRaisePlayerId", ""))
        Do acceptedBet.%Set("lastRaiseTeam", pendingBet.%Get("lastRaiseTeam", ""))
        Do acceptedBet.%Set("respondingPlayers", pendingBet.%Get("respondingPlayers", []))
        Do acceptedBet.%Set("acceptedPlayers", pendingBet.%Get("acceptedPlayers", []))
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

    Set handEndSettledPoints = []
    Do ..SettleHandCardValuesAtHandEnd(.gameState, .hand, .handEndSettledPoints)
    Do hand.%Set("settledPoints", handEndSettledPoints)

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

    Set countPointsByTeam = ""

    If currentPhase = "pares" {
        Set countPointsByTeam = ..BuildLanceCountPointsByTeam(gameState, currentPhase, phaseState)

        /*
          En Pares, los tantos ordinarios del lance se cobran al final de la mano.
          Si todos pasan, no hay envite adicional: solo se liquidan los pares de
          la pareja ganadora en countPointsByTeam.
        */
        If reason = "all_players_passed" {
            Set points = 0
        }
    }

    If currentPhase = "juego" {
        Set countPointsByTeam = ..BuildLanceCountPointsByTeam(gameState, currentPhase, phaseState)

        /*
          En Juego, los tantos ordinarios del lance se cobran al final de la mano.
          Si todos pasan, no hay envite adicional: solo se liquida el juego de
          la pareja ganadora en countPointsByTeam.
        */
        If reason = "all_players_passed" {
            Set points = 0
        }
    }

    If currentPhase = "punto", reason = "all_players_passed" {
        Set points = ##class(Mus.Util.MusRules).GetWinnerPuntoCountPoints(gameState)
    }

    /*
      No se suman puntos ordinarios de lance aqui.
      Grande, chica, pares, juego y punto se liquidan al final de la mano.
      Los rechazos de envites se siguen sumando inmediatamente en ResolveNoQuerer.
    */

    Do phaseState.%Set("status", "closed")
    Do phaseState.%Set("winner", winner)
    Do phaseState.%Set("winnerTeam", winnerTeam)
    Do phaseState.%Set("pointsAwarded", points)
    Do phaseState.%Set("pointsPendingUntilHandEnd", 1)

    If $IsObject(countPointsByTeam) {
        Do phaseState.%Set("teamCountPoints", countPointsByTeam)
        Do phaseState.%Set("countPointsPendingUntilHandEnd", 1)
    }

    Set pointsAwarded = {
        "phase": (currentPhase),
        "team": (winnerTeam),
        "points": (points),
        "reason": (reason),
        "winner": (winner),
        "pendingUntilHandEnd": true
    }

    If $IsObject(countPointsByTeam) {
        Do pointsAwarded.%Set("teamCountPoints", countPointsByTeam)
    }

    Return ..AdvanceToNextPhase(.gameState, .hand, .phaseState, pRequest, .actionEvent, .pResponse, pointsAwarded)
}

Method FinishGameIfTargetReached(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef closedPhaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse, pointsAwarded As %DynamicObject) As %Boolean
{
    Set score = gameState.%Get("score", "")

    If '$IsObject(score) {
        Return 0
    }

    Set targetScore = ##class(Mus.Util.MusRules).GetTargetScore(gameState)
    Set scoringTeam = ""

    If $IsObject(pointsAwarded) {
        Set scoringTeam = pointsAwarded.%Get("team", "")
    }

    If scoringTeam = "", $IsObject(actionEvent) {
        Set scoringTeam = actionEvent.%Get("winnerTeam", "")
    }

    If scoringTeam = "" {
        Set scoringTeam = ##class(Mus.Util.MusRules).GetWinningTeam(gameState)
    }

    If (scoringTeam '= "A") && (scoringTeam '= "B") {
        Return 0
    }

    Set reachedTarget = 0

    If scoringTeam = "A" {
        If +score.%Get("teamA", 0) >= targetScore {
            Set reachedTarget = 1
        }
    } ElseIf scoringTeam = "B" {
        If +score.%Get("teamB", 0) >= targetScore {
            Set reachedTarget = 1
        }
    }

    If 'reachedTarget {
        Return 0
    }

    Set currentPhase = hand.%Get("phase", pRequest.Phase)
    Set completedPhases = hand.%Get("completedPhases", "")

    If '$IsObject(completedPhases) {
        Set completedPhases = {}
    }

    If currentPhase '= "" {
        If $IsObject(closedPhaseState) {
            Do closedPhaseState.%Set("status", "closed")
            Do completedPhases.%Set(currentPhase, closedPhaseState)
        }
    }

    Do hand.%Set("completedPhases", completedPhases)
    Do hand.%Set("phase", "manoCerrada")
    Do hand.%Set("status", "closed")
    Do hand.%Set("phaseState", {})
    Do hand.%Set("turnPlayerId", "")

    Set handEndSettledPoints = []
    Do ..SettleHandCardValuesAtHandEnd(.gameState, .hand, .handEndSettledPoints)

    If handEndSettledPoints.%Size() > 0 {
        Do hand.%Set("settledPoints", handEndSettledPoints)
        If $IsObject(pointsAwarded) {
            Do pointsAwarded.%Set("handEndSettledPoints", handEndSettledPoints)
        }
        If $IsObject(actionEvent) {
            Do actionEvent.%Set("handEndSettledPoints", handEndSettledPoints)
        }
    }

    Do gameState.%Set("hand", hand)
    Do gameState.%Set("phase", "manoCerrada")
    Do gameState.%Set("turnPlayerId", "")
    Do gameState.%Set("nextAction", "")

    Set gameState = ##class(Mus.Util.MusRules).FinishGameForTeam(gameState, scoringTeam)

    If $IsObject(actionEvent) {
        Do actionEvent.%Set("gameFinished", 1)
        Do actionEvent.%Set("finishedByTeam", scoringTeam)
        Do actionEvent.%Set("targetScore", targetScore)
        Do actionEvent.%Set("finishReason", "target_score_reached")
    }

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 1
    Do ..AttachHandEndSettlementToMetadata(.gameState, .pointsAwarded, .actionEvent)
    Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()
    Set pResponse.NextPlayerId = ""

    Return 1
}

Method AppendDeclarationEvents(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, phase As %String, declarationType As %String, participants As %DynamicArray) As %Status
{
    Set playerIds = ["P1", "P2", "P3", "P4"]

    For i=0:1:playerIds.%Size()-1 {
        Set playerId = playerIds.%Get(i)
        Set team = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, playerId)
        Set hasValue = ..ArrayContains(participants, playerId)

        If declarationType = "declarar_pares" {
            Set label = $Select(hasValue:"Si a pares", 1:"No a pares")
        } Else {
            Set label = $Select(hasValue:"Si a juego", 1:"No a juego")
        }

        Set event = {
            "playerId": (playerId),
            "team": (team),
            "type": (declarationType),
            "phase": (phase),
            "hasValue": (hasValue),
            "label": (label),
            "createdAt": ($ZDATETIME($HOROLOG, 3))
        }

        Do ..AppendHandAction(.hand, event)
    }

    Do gameState.%Set("hand", hand)

    Return $$$OK
}

Method AppendPhaseSkippedEvent(ByRef hand As %DynamicObject, phase As %String, reason As %String, label As %String) As %Status
{
    Set event = {
        "playerId": "ALL",
        "type": "fase_saltada",
        "phase": (phase),
        "reason": (reason),
        "label": (label),
        "createdAt": ($ZDATETIME($HOROLOG, 3))
    }

    Do ..AppendHandAction(.hand, event)

    Return $$$OK
}

Method AppendPhaseAutoResolvedEvent(ByRef hand As %DynamicObject, phase As %String, winnerTeam As %String, points As %Integer, reason As %String, label As %String) As %Status
{
    Set event = {
        "playerId": "ALL",
        "type": "fase_auto_resuelta",
        "phase": (phase),
        "winnerTeam": (winnerTeam),
        "points": (points),
        "reason": (reason),
        "label": (label),
        "createdAt": ($ZDATETIME($HOROLOG, 3))
    }

    Do ..AppendHandAction(.hand, event)

    Return $$$OK
}

Method AppendHandAction(ByRef hand As %DynamicObject, event As %DynamicObject) As %Status
{
    Set actions = hand.%Get("actions", "")

    If '$IsObject(actions) {
        Set actions = []
    }

    Do actions.%Push(event)
    Do hand.%Set("actions", actions)

    Return $$$OK
}

Method CompletePhaseInHand(ByRef hand As %DynamicObject, phase As %String, phaseState As %DynamicObject) As %Status
{
    Set completedPhases = hand.%Get("completedPhases", "")

    If '$IsObject(completedPhases) {
        Set completedPhases = {}
    }

    Do completedPhases.%Set(phase, phaseState)
    Do hand.%Set("completedPhases", completedPhases)

    Return $$$OK
}

Method GetOnlyParticipantTeam(gameState As %DynamicObject, participants As %DynamicArray) As %String
{
    Set foundTeam = ""

    If '$IsObject(participants) {
        Return ""
    }

    For i=0:1:participants.%Size()-1 {
        Set playerId = participants.%Get(i)
        Set team = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, playerId)

        If (team '= "A") && (team '= "B") {
            Continue
        }

        If foundTeam = "" {
            Set foundTeam = team
        } ElseIf foundTeam '= team {
            Return "MIXED"
        }
    }

    Return foundTeam
}

Method FinishGameAfterAutoPoints(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, scoringTeam As %String, Output pResponse As Mus.Msg.ResolveActionResponse) As %Boolean
{
    Set score = gameState.%Get("score", "")

    If '$IsObject(score) {
        Return 0
    }

    Set targetScore = ##class(Mus.Util.MusRules).GetTargetScore(gameState)
    Set reachedTarget = 0

    If scoringTeam = "A" {
        If +score.%Get("teamA", 0) >= targetScore {
            Set reachedTarget = 1
        }
    } ElseIf scoringTeam = "B" {
        If +score.%Get("teamB", 0) >= targetScore {
            Set reachedTarget = 1
        }
    }

    If 'reachedTarget {
        Return 0
    }

    Do hand.%Set("phase", "manoCerrada")
    Do hand.%Set("status", "closed")
    Do hand.%Set("phaseState", {})
    Do hand.%Set("turnPlayerId", "")

    Do gameState.%Set("hand", hand)
    Do gameState.%Set("phase", "manoCerrada")
    Do gameState.%Set("turnPlayerId", "")
    Do gameState.%Set("nextAction", "")

    Set gameState = ##class(Mus.Util.MusRules).FinishGameForTeam(gameState, scoringTeam)

    Set pResponse.NextPlayerId = ""

    Return 1
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

    If ..FinishGameIfTargetReached(
        .gameState,
        .hand,
        .closedPhaseState,
        pRequest,
        .actionEvent,
        .pResponse,
        pointsAwarded
    ) {
        Return $$$OK
    }

    Set sc = ..OpenPhase(.gameState, .hand, nextPhase, .pResponse)
    If $$$ISERR(sc) {
        Return sc
    }

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 1
    Do ..AttachHandEndSettlementToMetadata(.gameState, .pointsAwarded, .actionEvent)
    Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()

    Return $$$OK
}

Method OpenPhase(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, phase As %String, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    If phase = "pares" {
        Return ..OpenDeclarationPhase(.gameState, .hand, "pares", .pResponse)
    }

    If phase = "juego" {
        Return ..OpenDeclarationPhase(.gameState, .hand, "juego", .pResponse)
    }

    If phase = "punto" {
        Return ..OpenPuntoPhase(.gameState, .hand, .pResponse)
    }

    If phase = "manoCerrada" {
        Return ..OpenClosedHandPhase(.gameState, .hand, .pResponse)
    }

    Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)

    Do hand.%Set("phase", phase)
    Do hand.%Set("phaseState", ##class(Mus.Util.MusRules).BuildInitialPhaseState(phase))
    Do hand.%Set("turnPlayerId", initialTurnPlayerId)

    Do gameState.%Set("phase", phase)
    Do gameState.%Set("turnPlayerId", initialTurnPlayerId)
    Do gameState.%Set("hand", hand)

    Set pResponse.NextPlayerId = initialTurnPlayerId

    Return $$$OK
}

Method OpenDeclarationPhase(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, phase As %String, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    /*
      Si el lance ya está en completedPhases, no volvemos a abrir la
      declaración. Esto evita duplicar declarar_juego al cierre de mano si
      algún flujo vuelve a invocar OpenPhase("juego") después de haberlo
      confirmado y jugado/autoresuelto.
    */
    Set completedPhases = hand.%Get("completedPhases", "")

    If $IsObject(completedPhases) {
        Set completedPhaseState = completedPhases.%Get(phase, "")

        If $IsObject(completedPhaseState) {
            If +completedPhaseState.%Get("declarationRequired", 0) '= 1 {
                Set nextPhase = completedPhaseState.%Get("nextPhaseAfterDeclaration", "")

                If nextPhase = "" {
                    If phase = "pares" {
                        Set nextPhase = "juego"
                    } Else {
                        Set nextPhase = "manoCerrada"
                    }
                }

                If nextPhase = "punto" {
                    Return ..OpenPuntoPhase(.gameState, .hand, .pResponse)
                }

                If nextPhase '= phase {
                    Return ..OpenPhase(.gameState, .hand, nextPhase, .pResponse)
                }
            }
        }
    }

    Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)

    If phase = "pares" {
        Set phaseState = ##class(Mus.Util.MusRules).BuildParesPhaseState(gameState)
        Set declarationType = "declarar_pares"
        Set skippedReason = "no_players_with_pares"
        Set skippedLabel = "Nadie tiene pares. Se pasa a juego."
        Set autoReason = "only_team_with_pares"
    } Else {
        Set phaseState = ##class(Mus.Util.MusRules).BuildJuegoPhaseState(gameState)
        Set declarationType = "declarar_juego"
        Set skippedReason = "no_players_with_juego"
        Set skippedLabel = "Nadie tiene juego. Se pasa a punto."
        Set autoReason = "only_team_with_juego"
    }

    Set participants = phaseState.%Get("participants", "")

    If '$IsObject(participants) {
        Set participants = []
    }

    Do ..AppendDeclarationEvents(.gameState, .hand, phase, declarationType, participants)

    Set declarationPlayers = ["P1", "P2", "P3", "P4"]
    Set declarations = {}

    For i=0:1:declarationPlayers.%Size()-1 {
        Set playerId = declarationPlayers.%Get(i)
        Do declarations.%Set(playerId, ..ArrayContains(participants, playerId))
    }

    Do phaseState.%Set("status", "declarationPending")
    Do phaseState.%Set("declarationRequired", 1)
    Do phaseState.%Set("declarationType", declarationType)
    Do phaseState.%Set("declarationPlayers", declarationPlayers)
    Do phaseState.%Set("declarations", declarations)
    Do phaseState.%Set("participants", participants)

    If participants.%Size() = 0 {
        Do phaseState.%Set("declarationOutcome", "skipped")
        Do phaseState.%Set("reason", skippedReason)
        Do phaseState.%Set("skipReason", skippedReason)
        Do phaseState.%Set("skipLabel", skippedLabel)

        If phase = "pares" {
            Do phaseState.%Set("nextPhaseAfterDeclaration", "juego")
        } Else {
            Do phaseState.%Set("nextPhaseAfterDeclaration", "punto")
        }
    } Else {
        Set onlyTeam = ..GetOnlyParticipantTeam(gameState, participants)

        If (onlyTeam = "A") || (onlyTeam = "B") {
            If phase = "pares" {
                Set countPointsByTeam = ..BuildLanceCountPointsByTeam(gameState, phase, phaseState)
                Set points = +countPointsByTeam.%Get(onlyTeam, 0)
                Set nextPhase = "juego"
                Set autoLabel = "Solo Equipo "_onlyTeam_" tiene pares. Equipo "_onlyTeam_" gana "_points_" punto(s)."
            } Else {
                Set countPointsByTeam = ..BuildLanceCountPointsByTeam(gameState, phase, phaseState)
                Set points = +countPointsByTeam.%Get(onlyTeam, 0)
                Set nextPhase = "manoCerrada"
                Set autoLabel = "Solo Equipo "_onlyTeam_" tiene juego. Equipo "_onlyTeam_" gana "_points_" punto(s)."
            }

            Do phaseState.%Set("declarationOutcome", "autoResolved")
            Do phaseState.%Set("autoResolveAfterDeclaration", 1)
            Do phaseState.%Set("winnerTeam", onlyTeam)
            Do phaseState.%Set("pointsAwarded", 0)
            Do phaseState.%Set("pointsPendingUntilHandEnd", 1)
            Do phaseState.%Set("teamCountPoints", countPointsByTeam)
            Do phaseState.%Set("countPointsPendingUntilHandEnd", 1)
            Do phaseState.%Set("reason", autoReason)
            Do phaseState.%Set("autoReason", autoReason)
            Do phaseState.%Set("autoLabel", autoLabel)
            Do phaseState.%Set("nextPhaseAfterDeclaration", nextPhase)
        } Else {
            Set orderedParticipants = ##class(Mus.Util.MusRules).OrderParticipantsFrom(participants, initialTurnPlayerId)
            Do phaseState.%Set("participants", orderedParticipants)
            Do phaseState.%Set("declarationOutcome", "actionRequired")
        }
    }

    Do hand.%Set("phase", phase)
    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("turnPlayerId", "")

    Do gameState.%Set("phase", phase)
    Do gameState.%Set("turnPlayerId", "")
    Do gameState.%Set("nextAction", "confirmar_declaracion")
    Do gameState.%Set("hand", hand)

    Set pResponse.NextPlayerId = ""

    Return $$$OK
}

Method ResolveDeclarationConfirmation(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set currentPhase = hand.%Get("phase", pRequest.Phase)

    If phaseState.%Get("status", "") '= "declarationPending" {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 409
        Set pResponse.ErrorCode = "NO_DECLARATION_PENDING"
        Set pResponse.ErrorMessage = "There is no pending declaration to confirm in phase "_currentPhase
        Return $$$OK
    }

    Set declarationOutcome = phaseState.%Get("declarationOutcome", "actionRequired")

    Do actionEvent.%Set("declarationConfirmed", 1)
    Do actionEvent.%Set("declarationOutcome", declarationOutcome)

    If declarationOutcome = "skipped" {
        Set skipReason = phaseState.%Get("skipReason", phaseState.%Get("reason", "declaration_skipped"))
        Set skipLabel = phaseState.%Get("skipLabel", "")
        Set nextPhase = phaseState.%Get("nextPhaseAfterDeclaration", "")

        Do phaseState.%Set("status", "skipped")
        Do phaseState.%Set("declarationRequired", 0)
        Do phaseState.%Set("reason", skipReason)

        Do ..AppendPhaseSkippedEvent(.hand, currentPhase, skipReason, skipLabel)
        Do ..CompletePhaseInHand(.hand, currentPhase, phaseState)
        Do gameState.%Set("hand", hand)

        If nextPhase = "" {
            If currentPhase = "pares" {
                Set nextPhase = "juego"
            } Else {
                Set nextPhase = "punto"
            }
        }

        If nextPhase = "punto" {
            Set sc = ..OpenPuntoPhase(.gameState, .hand, .pResponse)
        } Else {
            Set sc = ..OpenPhase(.gameState, .hand, nextPhase, .pResponse)
        }

        If $$$ISERR(sc) {
            Return sc
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
        Set pResponse.ActionEventJson = actionEvent.%ToJSON()
        Set pResponse.PhaseClosed = 1
        Set pointsAwarded = {
            "phase": (currentPhase),
            "team": "",
            "points": 0,
            "reason": (skipReason)
        }
        Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()

        Return $$$OK
    }

    If declarationOutcome = "autoResolved" {
        Set winnerTeam = phaseState.%Get("winnerTeam", "")
        Set countPointsByTeam = phaseState.%Get("teamCountPoints", "")

        If '$IsObject(countPointsByTeam) {
            If currentPhase = "pares" {
                Set countPointsByTeam = ..BuildLanceCountPointsByTeam(gameState, currentPhase, phaseState)
            } ElseIf currentPhase = "juego" {
                Set countPointsByTeam = ..BuildLanceCountPointsByTeam(gameState, currentPhase, phaseState)
            }
        }

        Set points = 0
        If $IsObject(countPointsByTeam) {
            Set points = +countPointsByTeam.%Get(winnerTeam, 0)
        }

        Set autoReason = phaseState.%Get("autoReason", phaseState.%Get("reason", "declaration_auto_resolved"))
        Set autoLabel = phaseState.%Get("autoLabel", "")
        Set nextPhase = phaseState.%Get("nextPhaseAfterDeclaration", "")

        Do phaseState.%Set("status", "autoResolved")
        Do phaseState.%Set("declarationRequired", 0)
        Do phaseState.%Set("winnerTeam", winnerTeam)
        Do phaseState.%Set("pointsAwarded", 0)
        Do phaseState.%Set("pointsPendingUntilHandEnd", 1)

        If $IsObject(countPointsByTeam) {
            Do phaseState.%Set("teamCountPoints", countPointsByTeam)
            Do phaseState.%Set("countPointsPendingUntilHandEnd", 1)
        }

        Do phaseState.%Set("reason", autoReason)

        Do ..AppendPhaseAutoResolvedEvent(.hand, currentPhase, winnerTeam, points, autoReason, autoLabel)
        Do ..CompletePhaseInHand(.hand, currentPhase, phaseState)
        Do gameState.%Set("hand", hand)

        If nextPhase = "" {
            If currentPhase = "pares" {
                Set nextPhase = "juego"
            } Else {
                Set nextPhase = "manoCerrada"
            }
        }

        Set sc = ..OpenPhase(.gameState, .hand, nextPhase, .pResponse)
        If $$$ISERR(sc) {
            Return sc
        }

        Set pointsAwarded = {
            "phase": (currentPhase),
            "team": (winnerTeam),
            "points": 0,
            "reason": (autoReason),
            "pendingUntilHandEnd": true,
            "teamCountPoints": (countPointsByTeam)
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
        Set pResponse.ActionEventJson = actionEvent.%ToJSON()
        Set pResponse.PhaseClosed = 1
        Do ..AttachHandEndSettlementToMetadata(.gameState, .pointsAwarded, .actionEvent)
        Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()

        Return $$$OK
    }

    Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)
    Set participants = phaseState.%Get("participants", "")

    If '$IsObject(participants) {
        Set participants = []
    }

    Set orderedParticipants = ##class(Mus.Util.MusRules).OrderParticipantsFrom(participants, initialTurnPlayerId)
    Do phaseState.%Set("participants", orderedParticipants)
    Do phaseState.%Set("status", "open")
    Do phaseState.%Set("declarationRequired", 0)
    Do phaseState.%Set("declarationOutcome", "actionRequired")

    Set firstParticipant = ""

    If orderedParticipants.%Size() > 0 {
        Set firstParticipant = orderedParticipants.%Get(0)
    }

    Do hand.%Set("phase", currentPhase)
    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("turnPlayerId", firstParticipant)

    Do gameState.%Set("phase", currentPhase)
    Do gameState.%Set("turnPlayerId", firstParticipant)
    Do gameState.%Set("nextAction", "")
    Do gameState.%Set("hand", hand)

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 0
    Set pResponse.NextPlayerId = firstParticipant

    Return $$$OK
}

Method OpenPuntoPhase(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set initialTurnPlayerId = ..GetInitialTurnPlayerId(gameState)
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
    Do gameState.%Set("nextAction", "")
    Do gameState.%Set("hand", hand)

    Set pResponse.NextPlayerId = initialTurnPlayerId

    Return $$$OK
}

Method BuildLanceCountPointsByTeam(gameState As %DynamicObject, phase As %String, phaseState As %DynamicObject) As %DynamicObject
{
    Set result = {"A": 0, "B": 0}

    If (phase '= "pares") && (phase '= "juego") {
        Return result
    }

    /*
      Fuente principal: phaseState.eligibility, que se construye al abrir la
      fase con BuildParesPhaseState/BuildJuegoPhaseState. Esto evita depender
      de helpers nuevos de MusRules y garantiza que se calculen los tantos
      ordinarios aunque el cierre de la mano llegue desde auto-resolucion,
      envite aceptado, pasar o rechazo.
    */
    Set eligibility = phaseState.%Get("eligibility", "")
    Set hand = gameState.%Get("hand", "")
    Set cards = ""

    If $IsObject(hand) {
        Set cards = hand.%Get("cards", "")
    }

    Set players = ["P1", "P2", "P3", "P4"]

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set team = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, playerId)

        If (team '= "A") && (team '= "B") {
            Continue
        }

        Set info = ""

        If $IsObject(eligibility) {
            Set info = eligibility.%Get(playerId, "")
        }

        /*
          Fallback defensivo: si algun estado antiguo no tiene eligibility,
          recalculamos desde hand.cards con los analizadores existentes.
        */
        If '$IsObject(info), $IsObject(cards) {
            Set playerCards = cards.%Get(playerId, "")

            If $IsObject(playerCards) {
                If phase = "pares" {
                    Set info = ##class(Mus.Util.MusRules).AnalyzePares(playerCards)
                } ElseIf phase = "juego" {
                    Set info = ##class(Mus.Util.MusRules).AnalyzeJuego(playerCards)
                }
            }
        }

        If '$IsObject(info) {
            Continue
        }

        Set countPoints = 0

        If phase = "pares" {
            If info.%Get("hasPares", 0) {
                Set countPoints = ##class(Mus.Util.MusRules).GetParesCountPoints(info)
            }
        } ElseIf phase = "juego" {
            If info.%Get("hasJuego", 0) {
                Set countPoints = ##class(Mus.Util.MusRules).GetJuegoCountPoints(info)
            }
        }

        If countPoints > 0 {
            Do result.%Set(team, +result.%Get(team, 0) + countPoints)
        }
    }

    Return result
}

Method SettleHandCardValuesAtHandEnd(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef settled As %DynamicArray) As %Status
{
    /*
      Liquidacion final de los valores ordinarios de cartas de pares y juego.

      v9: no se apoya en flags antiguos como cardValuesSettledAtHandEnd=1,
      porque esos flags pudieron quedar grabados por versiones anteriores sin
      haber sumado puntos. Solo se considera liquidado si la version actual ya
      se ejecuto correctamente.

      Tambien genera eventos de mano para dejar trazabilidad visible de que se
      repasaron las cartas y se sumaron los valores ordinarios.
    */
    If hand.%Get("cardValuesSettlementVersion", "") = "v9" {
        Return $$$OK
    }

    Set cards = hand.%Get("cards", "")

    If '$IsObject(cards) {
        Do hand.%Set("cardValuesSettlementSkippedReason", "cards_not_found")
        Do gameState.%Set("hand", hand)
        Return $$$OK
    }

    Set paresByTeam = {"A": 0, "B": 0}
    Set juegoByTeam = {"A": 0, "B": 0}
    Set paresBreakdown = []
    Set juegoBreakdown = []
    Set analyzedPlayers = 0
    Set players = ["P1", "P2", "P3", "P4"]

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set team = ##class(Mus.Util.MusRules).GetPlayerTeam(gameState, playerId)

        If (team '= "A") && (team '= "B") {
            Continue
        }

        Set playerCards = cards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Continue
        }

        Set analyzedPlayers = analyzedPlayers + 1

        Set paresInfo = ##class(Mus.Util.MusRules).AnalyzePares(playerCards)
        Set paresPoints = 0

        If $IsObject(paresInfo) {
            If +paresInfo.%Get("hasPares", 0) = 1 {
                Set paresPoints = ##class(Mus.Util.MusRules).GetParesCountPoints(paresInfo)
            }
        }

        If paresPoints > 0 {
            Do paresByTeam.%Set(team, +paresByTeam.%Get(team, 0) + paresPoints)
        }

        Do paresBreakdown.%Push({
            "playerId": (playerId),
            "team": (team),
            "points": (paresPoints),
            "type": ($Select($IsObject(paresInfo):paresInfo.%Get("type", "none"), 1:"none")),
            "cards": (playerCards)
        })

        Set juegoInfo = ##class(Mus.Util.MusRules).AnalyzeJuego(playerCards)
        Set juegoPoints = 0

        If $IsObject(juegoInfo) {
            If +juegoInfo.%Get("hasJuego", 0) = 1 {
                Set juegoPoints = ##class(Mus.Util.MusRules).GetJuegoCountPoints(juegoInfo)
            }
        }

        If juegoPoints > 0 {
            Do juegoByTeam.%Set(team, +juegoByTeam.%Get(team, 0) + juegoPoints)
        }

        Do juegoBreakdown.%Push({
            "playerId": (playerId),
            "team": (team),
            "points": (juegoPoints),
            "total": ($Select($IsObject(juegoInfo):+juegoInfo.%Get("total", 0), 1:0)),
            "hasJuego": ($Select($IsObject(juegoInfo):+juegoInfo.%Get("hasJuego", 0), 1:0)),
            "cards": (playerCards)
        })
    }

    If analyzedPlayers = 0 {
        Do hand.%Set("cardValuesSettlementSkippedReason", "no_player_cards_found")
        Do gameState.%Set("hand", hand)
        Return $$$OK
    }

    Set paresA = +paresByTeam.%Get("A", 0)
    Set paresB = +paresByTeam.%Get("B", 0)
    Set juegoA = +juegoByTeam.%Get("A", 0)
    Set juegoB = +juegoByTeam.%Get("B", 0)

    If paresA > 0 {
        Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, "A", paresA)
        Set event = {"playerId":"ALL","type":"valores_cartas_liquidados","phase":"pares","team":"A","points":(paresA),"reason":"hand_end_card_values","source":"hand.cards","breakdown":(paresBreakdown),"createdAt":($ZDATETIME($HOROLOG, 3))}
        Do ..AppendHandAction(.hand, event)
        Do settled.%Push(event)
    }

    If paresB > 0 {
        Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, "B", paresB)
        Set event = {"playerId":"ALL","type":"valores_cartas_liquidados","phase":"pares","team":"B","points":(paresB),"reason":"hand_end_card_values","source":"hand.cards","breakdown":(paresBreakdown),"createdAt":($ZDATETIME($HOROLOG, 3))}
        Do ..AppendHandAction(.hand, event)
        Do settled.%Push(event)
    }

    If juegoA > 0 {
        Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, "A", juegoA)
        Set event = {"playerId":"ALL","type":"valores_cartas_liquidados","phase":"juego","team":"A","points":(juegoA),"reason":"hand_end_card_values","source":"hand.cards","breakdown":(juegoBreakdown),"createdAt":($ZDATETIME($HOROLOG, 3))}
        Do ..AppendHandAction(.hand, event)
        Do settled.%Push(event)
    }

    If juegoB > 0 {
        Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, "B", juegoB)
        Set event = {"playerId":"ALL","type":"valores_cartas_liquidados","phase":"juego","team":"B","points":(juegoB),"reason":"hand_end_card_values","source":"hand.cards","breakdown":(juegoBreakdown),"createdAt":($ZDATETIME($HOROLOG, 3))}
        Do ..AppendHandAction(.hand, event)
        Do settled.%Push(event)
    }

    Do hand.%Set("cardValuesSettledAtHandEnd", 1)
    Do hand.%Set("cardValuesSettlementVersion", "v9")
    Do hand.%Set("cardValuesSettlementAnalyzedPlayers", analyzedPlayers)
    Do hand.%Set("paresCardValuesByTeam", paresByTeam)
    Do hand.%Set("juegoCardValuesByTeam", juegoByTeam)
    Do hand.%Set("paresCardValuesBreakdown", paresBreakdown)
    Do hand.%Set("juegoCardValuesBreakdown", juegoBreakdown)
    Do gameState.%Set("hand", hand)

    Return $$$OK
}

Method SettleCompletedPhasePointsAtHandEnd(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject) As %DynamicArray
{
    Set settled = []

    Do ..SettleHandCardValuesAtHandEnd(.gameState, .hand, .settled)

    Set completedPhases = hand.%Get("completedPhases", "")

    If '$IsObject(completedPhases) {
        Do gameState.%Set("hand", hand)
        Return settled
    }

    Set iter = completedPhases.%GetIterator()

    While iter.%GetNext(.phase, .phaseState) {
        If '$IsObject(phaseState) {
            Continue
        }

        /*
          ResolveNoQuerer ya suma el deje en tiempo real. No lo repetimos.
          Los valores ordinarios de pares/juego ya se liquidaron arriba desde
          hand.cards, por lo que aqui solo quedan puntos pendientes del envite
          aceptado u otros cierres ordinarios no resueltos en tiempo real.
        */
        If phaseState.%IsDefined("rejectedBet") {
            Continue
        }

        If +phaseState.%Get("pointsSettledAtHandEnd", 0) = 1 {
            Continue
        }

        If +phaseState.%Get("pointsPendingUntilHandEnd", 0) '= 1 {
            Continue
        }

        /*
          En pares y juego, los valores ordinarios de las cartas ya se suman
          para ambos equipos mediante SettleHandCardValuesAtHandEnd(). Si no
          hubo envite aceptado, no hay que volver a sumar pointsAwarded porque
          seria duplicar la jugada del ganador.
        */
        If ((phase = "pares") || (phase = "juego")) && ('phaseState.%IsDefined("acceptedBet")) {
            Continue
        }

        Set team = phaseState.%Get("winnerTeam", "")
        Set points = +phaseState.%Get("pointsAwarded", 0)

        If ((team '= "A") && (team '= "B")) || (points <= 0) {
            Continue
        }

        Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, team, points)

        Do phaseState.%Set("pointsPendingUntilHandEnd", 0)
        Do phaseState.%Set("pointsSettledAtHandEnd", 1)

        Set item = {
            "phase": (phase),
            "team": (team),
            "points": (points),
            "reason": "hand_end_settlement"
        }

        Do settled.%Push(item)
    }

    Do hand.%Set("completedPhases", completedPhases)
    Do gameState.%Set("hand", hand)

    Return settled
}

Method AttachHandEndSettlementToMetadata(ByRef gameState As %DynamicObject, ByRef pointsAwarded As %DynamicObject, ByRef actionEvent As %DynamicObject) As %Status
{
    Set responseHand = gameState.%Get("hand", "")

    If '$IsObject(responseHand) {
        Return $$$OK
    }

    Set settledPoints = responseHand.%Get("settledPoints", "")

    If '$IsObject(settledPoints) {
        Return $$$OK
    }

    Do pointsAwarded.%Set("settledPoints", settledPoints)
    Do pointsAwarded.%Set("handEndSettledPoints", settledPoints)

    If $IsObject(actionEvent) {
        Do actionEvent.%Set("settledPoints", settledPoints)
        Do actionEvent.%Set("handEndSettledPoints", settledPoints)
    }

    Return $$$OK
}

Method OpenClosedHandPhase(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set settledPoints = ..SettleCompletedPhasePointsAtHandEnd(.gameState, .hand)

    Do hand.%Set("settledPoints", settledPoints)
    Do hand.%Set("phase", "manoCerrada")
    Do hand.%Set("status", "closed")
    Do hand.%Set("phaseState", {})
    Do hand.%Set("turnPlayerId", "")

    Do gameState.%Set("phase", "manoCerrada")
    Do gameState.%Set("turnPlayerId", "")
    Do gameState.%Set("hand", hand)

    If ##class(Mus.Util.MusRules).IsGameFinished(gameState) {
        Set winningTeam = ##class(Mus.Util.MusRules).GetWinningTeam(gameState)
        Set gameState = ##class(Mus.Util.MusRules).FinishGameForTeam(gameState, winningTeam)

        /* FinishGameForTeam vuelve a escribir hand en gameState; reaseguramos
           que la trazabilidad de la liquidacion final siga disponible. */
        Set hand = gameState.%Get("hand", hand)
        If $IsObject(hand) {
            Do hand.%Set("settledPoints", settledPoints)
            Do gameState.%Set("hand", hand)
        }
    } Else {
        Do gameState.%Set("status", "handClosed")
        Do gameState.%Set("nextAction", "startNextHand")
    }

    Set pResponse.NextPlayerId = ""

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

    If phaseState.%Get("status", "") = "declarationPending" {
        Do actions.%Push("confirmar_declaracion")
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

Method BuildRespondingPlayers(gameState As %DynamicObject, phaseState As %DynamicObject, aggressorPlayerId As %String, respondingTeam As %String) As %DynamicArray
{
    Set result = []

    If respondingTeam = "" {
        Return result
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
            If '..ArrayContains(result, candidate) {
                Do result.%Push(candidate)
            }
        }
    }

    Return result
}

Method IsPendingBetResponder(pendingBet As %DynamicObject, playerId As %String) As %Boolean
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

Method GetNextPendingResponder(pendingBet As %DynamicObject) As %String
{
    If '$IsObject(pendingBet) {
        Return ""
    }

    Set respondingPlayers = pendingBet.%Get("respondingPlayers", "")

    If '$IsObject(respondingPlayers) {
        Return pendingBet.%Get("respondingPlayerId", "")
    }

    Set acceptedPlayers = pendingBet.%Get("acceptedPlayers", "")

    If '$IsObject(acceptedPlayers) {
        Set acceptedPlayers = []
    }

    For i=0:1:respondingPlayers.%Size()-1 {
        Set candidate = respondingPlayers.%Get(i)

        If '..ArrayContains(acceptedPlayers, candidate) {
            Return candidate
        }
    }

    Return ""
}

Method GetNextResponderPlayer(gameState As %DynamicObject, phaseState As %DynamicObject, aggressorPlayerId As %String, respondingTeam As %String) As %String
{
    Set respondingPlayers = ..BuildRespondingPlayers(gameState, phaseState, aggressorPlayerId, respondingTeam)

    If respondingPlayers.%Size() = 0 {
        Return ""
    }

    Return respondingPlayers.%Get(0)
}

Method GetNextRejectedPendingResponder(pendingBet As %DynamicObject, currentPlayerId As %String) As %String
{
    If '$IsObject(pendingBet) {
        Return ""
    }

    Set respondingPlayers = pendingBet.%Get("respondingPlayers", "")

    If '$IsObject(respondingPlayers) {
        Return ""
    }

    Set rejectedPlayers = pendingBet.%Get("rejectedPlayers", "")

    If '$IsObject(rejectedPlayers) {
        Set rejectedPlayers = []
    }

    For i=0:1:respondingPlayers.%Size()-1 {
        Set candidate = respondingPlayers.%Get(i)

        If candidate = currentPlayerId {
            Continue
        }

        If '..ArrayContains(rejectedPlayers, candidate) {
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

Method GetNoQuererAwardAmount(pendingBet As %DynamicObject) As %Integer
{
    If '$IsObject(pendingBet) {
        Return 1
    }

    Set previousAmount = +pendingBet.%Get("previousAmount", 0)

    If previousAmount > 0 {
        Return previousAmount
    }

    Return 1
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
