Class Mus.BP.GameCoordinator Extends Ens.BusinessProcess
{

Parameter SETTINGS = "PersistenceTarget,RuleEngineTarget";

Property PersistenceTarget As %String(MAXLEN = 200) [ InitialExpression = "Mus.BO.PersistenceOperation" ];

Property RuleEngineTarget As %String(MAXLEN = 200) [ InitialExpression = "Mus.BP.RuleEngine" ];

Method OnRequest(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status
{
    If pRequest.%IsA("Mus.Msg.CreateGameRequest") {
        Return ..HandleCreateGame(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.StartGameRequest") {
        Return ..HandleStartGame(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.GetGameStateRequest") {
        Return ..HandleGetGameState(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.PlayerActionRequest") {
        Return ..HandlePlayerAction(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.ApplyDiscardsRequest") {
        Return ..HandleApplyDiscards(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.StartNextHandRequest") {
        Return ..HandleStartNextHand(pRequest, .pResponse)
    }

    Return $$$ERROR($$$GeneralError, "Unsupported message type: "_pRequest.%ClassName(1))
}

Method HandleCreateGame(pRequest As Mus.Msg.CreateGameRequest, Output pResponse As Mus.Msg.CreateGameResponse) As %Status
{
    Return ..SendRequestSync(..PersistenceTarget, pRequest, .pResponse)
}

Method HandleStartGame(pRequest As Mus.Msg.StartGameRequest, Output pResponse As Mus.Msg.StartGameResponse) As %Status
{
    Return ..SendRequestSync(..PersistenceTarget, pRequest, .pResponse)
}

Method HandleGetGameState(pRequest As Mus.Msg.GetGameStateRequest, Output pResponse As Mus.Msg.GetGameStateResponse) As %Status
{
    Return ..SendRequestSync(..PersistenceTarget, pRequest, .pResponse)
}

Method HandleApplyDiscards(pRequest As Mus.Msg.ApplyDiscardsRequest, Output pResponse As Mus.Msg.ApplyDiscardsResponse) As %Status
{
    Return ..SendRequestSync(..PersistenceTarget, pRequest, .pResponse)
}

Method HandleStartNextHand(pRequest As Mus.Msg.StartNextHandRequest, Output pResponse As Mus.Msg.StartNextHandResponse) As %Status
{
    Return ..SendRequestSync(..PersistenceTarget, pRequest, .pResponse)
}

Method HandlePlayerAction(pRequest As Mus.Msg.PlayerActionRequest, Output pResponse As Mus.Msg.PlayerActionResponse) As %Status
{
    Set loadReq = ##class(Mus.Msg.LoadGameStateRequest).%New()
    Set loadReq.GameId = pRequest.GameId
    Set loadReq.CorrelationId = pRequest.CorrelationId

    Set sc = ..SendRequestSync(..PersistenceTarget, loadReq, .loadResp)
    If $$$ISERR(sc) {
        Return sc
    }

    If '$IsObject(loadResp) {
        Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New()
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "NULL_LOAD_RESPONSE"
        Set pResponse.ErrorMessage = "Persistence operation returned no response"
        Return $$$OK
    }

    Set loadedState = {}.%FromJSON(loadResp.GameStateJson)

    If loadedState.%Get("status", "") = "finished" {
        Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New()
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 409
        Set pResponse.ErrorCode = "GAME_ALREADY_FINISHED"
        Set pResponse.ErrorMessage = "The game is already finished"
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.GameStateJson = loadResp.GameStateJson
        Return $$$OK
    }

    If 'loadResp.Success {
        Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New()
        Set pResponse.Success = 0
        Set pResponse.StatusCode = loadResp.StatusCode
        Set pResponse.ErrorCode = loadResp.ErrorCode
        Set pResponse.ErrorMessage = loadResp.ErrorMessage
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.GameStateJson = loadResp.GameStateJson
        Return $$$OK
    }

    Set sc = ..NormalizeStateBeforeAction(loadResp.GameStateJson, pRequest, .normalizedGameStateJson)
    If $$$ISERR(sc) {
        Return sc
    }

    Set validateReq = ##class(Mus.Msg.ValidateActionRequest).%New()
    Set validateReq.GameId = pRequest.GameId
    Set validateReq.GameStateJson = normalizedGameStateJson
    Set validateReq.PlayerId = pRequest.PlayerId
    Set validateReq.ActionType = pRequest.ActionType
    Set validateReq.Phase = pRequest.Phase
    Set validateReq.Amount = pRequest.Amount
    Set validateReq.PayloadJson = pRequest.PayloadJson
    Set validateReq.CorrelationId = pRequest.CorrelationId

    Set sc = ..SendRequestSync(..RuleEngineTarget, validateReq, .validateResp)
    If $$$ISERR(sc) {
        Return sc
    }

    If '$IsObject(validateResp) {
        Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New()
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "NULL_VALIDATE_RESPONSE"
        Set pResponse.ErrorMessage = "Rule engine returned no response"
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.GameStateJson = normalizedGameStateJson
        Return $$$OK
    }

    If 'validateResp.IsLegal {
        Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New()
        Set pResponse.Success = 0
        Set pResponse.StatusCode = validateResp.StatusCode
        Set pResponse.ErrorCode = validateResp.ErrorCode
        Set pResponse.ErrorMessage = validateResp.ErrorMessage
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.GameStateJson = normalizedGameStateJson
        Return $$$OK
    }

    /*
      IMPORTANTE:
      A partir de aqui ya no llamamos a SavePlayerAction.
      Primero resolvemos la accion para calcular nuevo estado:
      - siguiente turno
      - apuesta pendiente
      - puntos
      - cambio de fase
    */

    Set resolveReq = ##class(Mus.Msg.ResolveActionRequest).%New()
    Set resolveReq.GameId = pRequest.GameId
    Set resolveReq.GameStateJson = normalizedGameStateJson
    Set resolveReq.PlayerId = pRequest.PlayerId
    Set resolveReq.ActionType = pRequest.ActionType
    Set resolveReq.Phase = pRequest.Phase
    Set resolveReq.Amount = pRequest.Amount
    Set resolveReq.PayloadJson = pRequest.PayloadJson
    Set resolveReq.CorrelationId = pRequest.CorrelationId

    Set sc = ..SendRequestSync(..RuleEngineTarget, resolveReq, .resolveResp)
    If $$$ISERR(sc) {
        Return sc
    }

    If '$IsObject(resolveResp) {
        Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New()
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "NULL_RESOLVE_RESPONSE"
        Set pResponse.ErrorMessage = "Rule engine returned no resolve response"
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.GameStateJson = loadResp.GameStateJson
        Return $$$OK
    }

    If 'resolveResp.Success {
        Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New()
        Set pResponse.Success = 0
        Set pResponse.StatusCode = resolveResp.StatusCode
        Set pResponse.ErrorCode = resolveResp.ErrorCode
        Set pResponse.ErrorMessage = resolveResp.ErrorMessage
        Set pResponse.GameId = pRequest.GameId
        Set pResponse.GameStateJson = loadResp.GameStateJson
        Return $$$OK
    }

    Set persistReq = ##class(Mus.Msg.PersistResolvedActionRequest).%New()
    Set persistReq.GameId = pRequest.GameId
    Set persistReq.PlayerId = pRequest.PlayerId
    Set persistReq.ActionType = pRequest.ActionType
    Set persistReq.Phase = pRequest.Phase
    Set persistReq.Amount = pRequest.Amount
    Set persistReq.PayloadJson = pRequest.PayloadJson
    Set persistReq.ActionEventJson = resolveResp.ActionEventJson
    Set persistReq.UpdatedGameStateJson = resolveResp.UpdatedGameStateJson
    Set persistReq.CorrelationId = pRequest.CorrelationId

    Return ..SendRequestSync(..PersistenceTarget, persistReq, .pResponse)
}

Method NormalizeStateBeforeAction(gameStateJson As %String, pRequest As Mus.Msg.PlayerActionRequest, Output normalizedGameStateJson As %String) As %Status
{
    Set normalizedGameStateJson = gameStateJson

    Try {
        Set gameState = {}.%FromJSON(gameStateJson)
        Set hand = gameState.%Get("hand", "")

        If '$IsObject(hand) {
            Return $$$OK
        }

        Set currentPhase = hand.%Get("phase", "")

        /*
          Permite saltar de descartes a grande sin llamar a /discards.
          Esto equivale a que los cuatro jugadores no se descartan.
        */
        If currentPhase = "descartes", pRequest.Phase = "grande" {
            Set initialTurnPlayerId = ##class(Mus.Util.MusRules).GetInitialTurnPlayerIdForGameState(gameState)

            Set phaseState = ##class(Mus.Util.MusRules).BuildInitialPhaseState("grande")

            Set now = $ZDATETIME($HOROLOG, 3)
            Set discardRound = +hand.%Get("discardRound", 0)

            Set autoDiscardAction = {
                "type": "descartes",
                "phase": "descartes",
                "playerId": "ALL",
                "round": (discardRound + 1),
                "totalDiscarded": 0,
                "autoClosed": true,
                "reason": "first_grande_action",
                "discards": {
                    "P1": [],
                    "P2": [],
                    "P3": [],
                    "P4": []
                },
                "createdAt": (now)
            }

            If '$IsObject(hand.%Get("actions", "")) {
                Do hand.%Set("actions", [])
            }

            Do hand.%Get("actions").%Push(autoDiscardAction)

            Do hand.%Set("phase", "grande")
            Do hand.%Set("turnPlayerId", initialTurnPlayerId)
            Do hand.%Set("discardsClosed", 1)
            Do hand.%Set("discardRound", discardRound + 1)
            Do hand.%Set("phaseState", phaseState)

            Do gameState.%Set("phase", "grande")
            Do gameState.%Set("turnPlayerId", initialTurnPlayerId)
            Do gameState.%Set("discardsClosed", 1)
            Do gameState.%Set("discardRound", discardRound + 1)
            Do gameState.%Set("hand", hand)

            Set normalizedGameStateJson = gameState.%ToJSON()
        }

        Return $$$OK
    }
    Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

Storage Default
{
<Data name="GameCoordinatorDefaultData">
<Subscript>"GameCoordinator"</Subscript>
<Value name="1">
<Value>PersistenceTarget</Value>
</Value>
<Value name="2">
<Value>RuleEngineTarget</Value>
</Value>
</Data>
<DefaultData>GameCoordinatorDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
