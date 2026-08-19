Class Mus.BO.AgentDecisionOperation Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Method OnMessage(pRequest As Mus.Msg.AgentDecisionRequest, Output pResponse As Mus.Msg.AgentDecisionResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.AgentDecisionResponse).%New()
    Set pResponse.Success = 0
    Set pResponse.StatusCode = 500
    Set pResponse.ErrorCode = "AGENT_DECISION_ERROR"
    Set pResponse.ErrorMessage = ""
    Set pResponse.RequestType = pRequest.RequestType
    Set pResponse.GameId = pRequest.GameId
    Set pResponse.PlayerId = pRequest.PlayerId
    Set pResponse.CorrelationId = pRequest.CorrelationId

    Try {
        If '$IsObject(pRequest) {
            Set pResponse.ErrorCode = "INVALID_REQUEST"
            Set pResponse.ErrorMessage = "Invalid AgentDecisionRequest"
            Return $$$OK
        }

        If pRequest.GameId <= 0 {
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "MISSING_GAME_ID"
            Set pResponse.ErrorMessage = "gameId is required"
            Return $$$OK
        }

        If pRequest.PlayerId = "" {
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "MISSING_PLAYER_ID"
            Set pResponse.ErrorMessage = "playerId is required"
            Return $$$OK
        }

        Set gameStateJson = pRequest.GameStateJson

        If gameStateJson = "" {
            Set stateReq = ##class(Mus.Msg.GetGameStateRequest).%New()
            Set stateReq.GameId = pRequest.GameId
            Set stateReq.PlayerId = pRequest.PlayerId
            Set stateReq.CorrelationId = pRequest.CorrelationId

            Set sc = ##class(Mus.IOP.Dispatcher).Send(stateReq, .stateResp)
            If $$$ISERR(sc) {
                Set pResponse.ErrorCode = "GET_STATE_DISPATCH_ERROR"
                Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
                Return $$$OK
            }

            If '$IsObject(stateResp) {
                Set pResponse.ErrorCode = "NULL_STATE_RESPONSE"
                Set pResponse.ErrorMessage = "No state response returned"
                Return $$$OK
            }

            If 'stateResp.Success {
                Set pResponse.StatusCode = stateResp.StatusCode
                Set pResponse.ErrorCode = stateResp.ErrorCode
                Set pResponse.ErrorMessage = stateResp.ErrorMessage
                Return $$$OK
            }

            Set gameStateJson = stateResp.GameStateJson
        }

        If gameStateJson = "" {
            Set pResponse.ErrorCode = "EMPTY_GAME_STATE"
            Set pResponse.ErrorMessage = "Game state JSON is empty"
            Return $$$OK
        }

        Set gameState = {}.%FromJSON(gameStateJson)
        Set phase = gameState.%Get("phase", "")
        Set pResponse.Phase = phase
        Set pResponse.TurnPlayerId = gameState.%Get("turnPlayerId", "")
        Set pResponse.GameStateJson = gameStateJson

        If pRequest.RequestType = "discard" {
            If phase '= "descartes" {
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "INVALID_PHASE"
                Set pResponse.ErrorMessage = "Game is not in discard phase"
                Return $$$OK
            }
        }

        Set recommendation = ##class(Mus.Agent.PlayerAgent).RecommendAction(
            gameStateJson,
            pRequest.PlayerId
        )

        If '$IsObject(recommendation) {
            Set pResponse.ErrorCode = "EMPTY_AGENT_RECOMMENDATION"
            Set pResponse.ErrorMessage = "Agent returned no recommendation"
            Return $$$OK
        }

        Set pResponse.RecommendationJson = recommendation.%ToJSON()
        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.ErrorCode = ""
        Set pResponse.ErrorMessage = ""

        Return $$$OK
    } Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "AGENT_DECISION_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

}
