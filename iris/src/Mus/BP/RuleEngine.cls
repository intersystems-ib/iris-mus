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

        Set phaseState = hand.%Get("phaseState", "")

        If '$IsObject(phaseState) {
            Set phaseState = {
                "name": (phase),
                "status": "open",
                "passedPlayers": [],
                "pendingBet": null,
                "acceptedBet": null,
                "lastAggressorPlayerId": "",
                "lastAggressorTeam": "",
                "respondingTeam": "",
                "pointsAtStake": 1
            }
        }

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

Method ContainsAction(actions As %DynamicArray, actionType As %String) As %Boolean
{
    For i=0:1:actions.%Size()-1 {
        If actions.%Get(i) = actionType {
            Return 1
        }
    }

    Return 0
}

Method ResolveAction(pRequest As Mus.Msg.ResolveActionRequest, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.ResolveActionResponse).%New()

    Try {
        Set gameState = {}.%FromJSON(pRequest.GameStateJson)
        Set hand = gameState.%Get("hand")
        Set phaseState = hand.%Get("phaseState", "")

        If '$IsObject(phaseState) {
            Set phaseState = {
                "name": (pRequest.Phase),
                "status": "open",
                "passedPlayers": [],
                "pendingBet": null,
                "acceptedBet": null,
                "lastAggressorPlayerId": "",
                "lastAggressorTeam": "",
                "respondingTeam": "",
                "pointsAtStake": 1
            }
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
            "phase": (pRequest.Phase),
            "amount": (pRequest.Amount),
            "createdAt": ($ZDATETIME($HOROLOG, 3))
        }

        If pRequest.ActionType = "pasar" {
            Set sc = ..ResolvePass(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
            Return sc
        }

        If pRequest.ActionType = "envidar" {
            Set sc = ..ResolveEnvidar(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
            Return sc
        }

        If pRequest.ActionType = "querer" {
            Set sc = ..ResolveQuerer(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
            Return sc
        }

        If pRequest.ActionType = "no_querer" {
            Set sc = ..ResolveNoQuerer(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
            Return sc
        }

        If pRequest.ActionType = "ordago" {
            Set sc = ..ResolveOrdago(.gameState, .hand, .phaseState, pRequest, playerTeam, .actionEvent, .pResponse)
            Return sc
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

    If passedPlayers.%Size() >= 4 {
        Set points = 1
        Set winner = ##class(Mus.Util.MusRules).ResolveGrandeWinner(gameState)
        Set winnerTeam = winner.%Get("team")

        Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, winnerTeam, points)

        Do phaseState.%Set("status", "closed")
        Do phaseState.%Set("winner", winner)
        Do phaseState.%Set("pointsAwarded", points)

        Do hand.%Set("phaseState", phaseState)
        Do hand.%Set("phase", "chica")
        Do hand.%Set("turnPlayerId", "P1")

        Do gameState.%Set("phase", "chica")
        Do gameState.%Set("turnPlayerId", "P1")
        Do gameState.%Set("hand", hand)

        Set pointsAwarded = {
            "phase": "grande",
            "team": (winnerTeam),
            "points": (points),
            "reason": "all_players_passed",
            "winner": (winner)
        }

        Set pResponse.PhaseClosed = 1
        Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()
        Set pResponse.NextPlayerId = "P1"
    } Else {
        Set nextPlayerId = ##class(Mus.Util.MusRules).GetNextPlayerId(pRequest.PlayerId)

        Do hand.%Set("phaseState", phaseState)
        Do hand.%Set("turnPlayerId", nextPlayerId)

        Do gameState.%Set("turnPlayerId", nextPlayerId)
        Do gameState.%Set("hand", hand)

        Set pResponse.PhaseClosed = 0
        Set pResponse.NextPlayerId = nextPlayerId
    }

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()

    Return $$$OK
}

Method ResolveEnvidar(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    Set amount = pRequest.Amount

    If amount <= 0 {
        Set amount = 2
    }

    Set opponentTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)

    Set pendingBet = {
        "type": "envidar",
        "amount": (amount),
        "playerId": (pRequest.PlayerId),
        "team": (playerTeam)
    }

    Do phaseState.%Set("pendingBet", pendingBet)
    Do phaseState.%Set("lastAggressorPlayerId", pRequest.PlayerId)
    Do phaseState.%Set("lastAggressorTeam", playerTeam)
    Do phaseState.%Set("respondingTeam", opponentTeam)

    Set nextPlayerId = ##class(Mus.Util.MusRules).GetNextPlayerId(pRequest.PlayerId)

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

    Set acceptedAmount = +pendingBet.%Get("amount", 2)

    Set acceptedBet = {
        "amount": (acceptedAmount),
        "acceptedByPlayerId": (pRequest.PlayerId),
        "acceptedByTeam": (playerTeam),
        "originalBet": (pendingBet)
    }

    Do phaseState.%Set("acceptedBet", acceptedBet)
    Do phaseState.%Set("pendingBet", "")
    Do phaseState.%Set("status", "closed")

    Set winner = ##class(Mus.Util.MusRules).ResolveGrandeWinner(gameState)
    Set winnerTeam = winner.%Get("team")

    Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, winnerTeam, acceptedAmount)

    Do phaseState.%Set("winner", winner)
    Do phaseState.%Set("pointsAwarded", acceptedAmount)

    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("phase", "chica")
    Do hand.%Set("turnPlayerId", "P1")

    Do gameState.%Set("phase", "chica")
    Do gameState.%Set("turnPlayerId", "P1")
    Do gameState.%Set("hand", hand)

    Set pointsAwarded = {
        "phase": "grande",
        "team": (winnerTeam),
        "points": (acceptedAmount),
        "reason": "accepted_bet",
        "winner": (winner)
    }

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 1
    Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()
    Set pResponse.NextPlayerId = "P1"

    Return $$$OK
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

    /*
      Simplificación inicial:
      Si no se quiere un envido, el equipo que lanzó gana 1 punto.
    */

    Set bettorTeam = pendingBet.%Get("team")
    Set points = 1

    Set gameState = ##class(Mus.Util.MusRules).AddPoints(gameState, bettorTeam, points)

    Do phaseState.%Set("status", "closed")
    Do phaseState.%Set("pendingBet", "")
    Do phaseState.%Set("winnerTeam", bettorTeam)
    Do phaseState.%Set("pointsAwarded", points)

    Do hand.%Set("phaseState", phaseState)
    Do hand.%Set("phase", "chica")
    Do hand.%Set("turnPlayerId", "P1")

    Do gameState.%Set("phase", "chica")
    Do gameState.%Set("turnPlayerId", "P1")
    Do gameState.%Set("hand", hand)

    Set pointsAwarded = {
        "phase": "grande",
        "team": (bettorTeam),
        "points": (points),
        "reason": "bet_rejected"
    }

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.UpdatedGameStateJson = gameState.%ToJSON()
    Set pResponse.ActionEventJson = actionEvent.%ToJSON()
    Set pResponse.PhaseClosed = 1
    Set pResponse.PointsAwardedJson = pointsAwarded.%ToJSON()
    Set pResponse.NextPlayerId = "P1"

    Return $$$OK
}

Method ResolveOrdago(ByRef gameState As %DynamicObject, ByRef hand As %DynamicObject, ByRef phaseState As %DynamicObject, pRequest As Mus.Msg.ResolveActionRequest, playerTeam As %String, ByRef actionEvent As %DynamicObject, Output pResponse As Mus.Msg.ResolveActionResponse) As %Status
{
    /*
      MVP:
      El órdago se marca como pendiente.
      En la siguiente iteración podemos tratar querer/no querer de órdago
      como cierre de partida.
    */

    Set opponentTeam = ##class(Mus.Util.MusRules).GetTeamOpponent(playerTeam)

    Set pendingBet = {
        "type": "ordago",
        "amount": 999,
        "playerId": (pRequest.PlayerId),
        "team": (playerTeam)
    }

    Do phaseState.%Set("pendingBet", pendingBet)
    Do phaseState.%Set("lastAggressorPlayerId", pRequest.PlayerId)
    Do phaseState.%Set("lastAggressorTeam", playerTeam)
    Do phaseState.%Set("respondingTeam", opponentTeam)

    Set nextPlayerId = ##class(Mus.Util.MusRules).GetNextPlayerId(pRequest.PlayerId)

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

Method ArrayContains(array As %DynamicArray, value As %String) As %Boolean
{
    For i=0:1:array.%Size()-1 {
        If array.%Get(i) = value {
            Return 1
        }
    }

    Return 0
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
