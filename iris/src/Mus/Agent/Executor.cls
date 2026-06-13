Class Mus.Agent.Executor Extends %RegisteredObject
{

ClassMethod RecommendOnly(gameId As %Integer, playerId As %String) As %DynamicObject
{
    Try {
        Set stateResp = ""
        Set sc = ##class(Mus.Test.GameSimulation).GetGameState(gameId, .stateResp)

        If $$$ISERR(sc) {
            Return {
                "success": false,
                "errorCode": "GET_STATE_STATUS_ERROR",
                "errorMessage": ($System.Status.GetErrorText(sc))
            }
        }

        If '$IsObject(stateResp) {
            Return {
                "success": false,
                "errorCode": "GET_STATE_NO_RESPONSE",
                "errorMessage": "GetGameState returned no response"
            }
        }

        If 'stateResp.Success {
            Return {
                "success": false,
                "errorCode": (stateResp.ErrorCode),
                "errorMessage": (stateResp.ErrorMessage)
            }
        }

        Set state = {}.%FromJSON(stateResp.GameStateJson)

        Set recommendation = ##class(Mus.Agent.PlayerAgent).RecommendAction(
            stateResp.GameStateJson,
            playerId
        )

        Return {
            "success": true,
            "gameId": (gameId),
            "playerId": (playerId),
            "phase": (state.%Get("phase", "")),
            "turnPlayerId": (state.%Get("turnPlayerId", "")),
            "recommendation": (recommendation)
        }
    }
    Catch ex {
        Return {
            "success": false,
            "errorCode": "RECOMMEND_ONLY_EXCEPTION",
            "errorMessage": (ex.DisplayString())
        }
    }
}

ClassMethod RecommendAndExecute(gameId As %Integer, playerId As %String, Output pActionResponse As Mus.Msg.PlayerActionResponse) As %Status
{
    Set trace = ""

    Return ..RecommendAndExecuteWithTrace(gameId, playerId, .pActionResponse, .trace)
}

ClassMethod RecommendAndExecuteWithTrace(gameId As %Integer, playerId As %String, Output pActionResponse As Mus.Msg.PlayerActionResponse, Output trace As %DynamicObject) As %Status
{
    Set pActionResponse = ""
    Set trace = {
        "success": false,
        "gameId": (gameId),
        "playerId": (playerId),
        "phaseBefore": "",
        "turnPlayerIdBefore": "",
        "recommendation": null,
        "executedAction": null,
        "statusAfter": "",
        "phaseAfter": "",
        "turnPlayerIdAfter": "",
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
        Set stateResp = ""
        Set sc = ##class(Mus.Test.GameSimulation).GetGameState(gameId, .stateResp)
        If $$$ISERR(sc) {
            Do trace.%Set("errorCode", "GET_STATE_STATUS_ERROR")
            Do trace.%Set("errorMessage", $System.Status.GetErrorText(sc))
            Return sc
        }

        If '$IsObject(stateResp) {
            Do trace.%Set("errorCode", "GET_STATE_NO_RESPONSE")
            Do trace.%Set("errorMessage", "GetGameState returned no response")
            Return $$$ERROR($$$GeneralError, "GetGameState returned no response")
        }

        If 'stateResp.Success {
            Do trace.%Set("errorCode", stateResp.ErrorCode)
            Do trace.%Set("errorMessage", stateResp.ErrorMessage)
            Return $$$ERROR($$$GeneralError, stateResp.ErrorCode_": "_stateResp.ErrorMessage)
        }

        Set state = {}.%FromJSON(stateResp.GameStateJson)

        Set phase = state.%Get("phase", "")
        Set turnPlayerId = state.%Get("turnPlayerId", "")
        Set status = state.%Get("status", "")

        Do trace.%Set("statusBefore", status)
        Do trace.%Set("phaseBefore", phase)
        Do trace.%Set("turnPlayerIdBefore", turnPlayerId)

        If status = "finished" {
            Do trace.%Set("errorCode", "GAME_ALREADY_FINISHED")
            Do trace.%Set("errorMessage", "Game is already finished")
            Return $$$ERROR($$$GeneralError, "Game is already finished")
        }

        If turnPlayerId '= playerId {
            Do trace.%Set("errorCode", "NOT_PLAYER_TURN")
            Do trace.%Set("errorMessage", "It is not player "_playerId_" turn")
            Return $$$ERROR($$$GeneralError, "It is not player "_playerId_" turn")
        }

        Set context = ##class(Mus.Agent.ContextBuilder).BuildForPlayer(state, playerId)
        Set legalActions = context.%Get("legalActions", "")

        If '$IsObject(legalActions) || legalActions.%Size() = 0 {
            Do trace.%Set("errorCode", "NO_LEGAL_ACTIONS_FOR_AGENT")
            Do trace.%Set("errorMessage", "No legal actions available for player "_playerId_" in phase "_phase)
            Return $$$ERROR($$$GeneralError, "No legal actions available for player "_playerId_" in phase "_phase)
        }

        Set recommendation = ##class(Mus.Agent.PlayerAgent).RecommendAction(
            stateResp.GameStateJson,
            playerId
        )

        Do trace.%Set("recommendation", recommendation)

        Set context = ##class(Mus.Agent.ContextBuilder).BuildForPlayer(state, playerId)
        Do trace.%Set("profile", context.%Get("profile", ""))
        Do trace.%Set("legalActions", context.%Get("legalActions", ""))
        Do trace.%Set("bettingGuidance", context.%Get("bettingGuidance", ""))

        Set actionType = recommendation.%Get("actionType", "pasar")
        Set amount = +recommendation.%Get("amount", 0)
        Set payloadJson = recommendation.%ToJSON()

        Set executedAction = {
            "gameId": (gameId),
            "playerId": (playerId),
            "phase": (phase),
            "actionType": (actionType),
            "amount": (amount),
            "payload": (recommendation)
        }

        Do trace.%Set("executedAction", executedAction)

        Set sc = ##class(Mus.Test.GameSimulation).SendPlayerAction(
            gameId,
            playerId,
            actionType,
            phase,
            amount,
            payloadJson,
            .pActionResponse
        )

        If $$$ISERR(sc) {
            Do trace.%Set("errorCode", "SEND_PLAYER_ACTION_STATUS_ERROR")
            Do trace.%Set("errorMessage", $System.Status.GetErrorText(sc))
            Return sc
        }

        If '$IsObject(pActionResponse) {
            Do trace.%Set("errorCode", "PLAYER_ACTION_NO_RESPONSE")
            Do trace.%Set("errorMessage", "SendPlayerAction returned no response")
            Return $$$ERROR($$$GeneralError, "SendPlayerAction returned no response")
        }

        If 'pActionResponse.Success {
            Do trace.%Set("errorCode", pActionResponse.ErrorCode)
            Do trace.%Set("errorMessage", pActionResponse.ErrorMessage)
            Return $$$OK
        }

        If pActionResponse.GameStateJson '= "" {
            Set stateAfter = {}.%FromJSON(pActionResponse.GameStateJson)

            Do trace.%Set("statusAfter", stateAfter.%Get("status", ""))
            Do trace.%Set("phaseAfter", stateAfter.%Get("phase", ""))
            Do trace.%Set("turnPlayerIdAfter", stateAfter.%Get("turnPlayerId", ""))

            If $IsObject(stateAfter.%Get("score", "")) {
                Do trace.%Set("scoreAfter", stateAfter.%Get("score"))
            }

            If stateAfter.%Get("winnerTeam", "") '= "" {
                Do trace.%Set("winnerTeam", stateAfter.%Get("winnerTeam", ""))
            }
        }

        Do trace.%Set("success", "true")

        Return $$$OK
    }
    Catch ex {
        Do trace.%Set("errorCode", "RECOMMEND_AND_EXECUTE_WITH_TRACE_EXCEPTION")
        Do trace.%Set("errorMessage", ex.DisplayString())

        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod RecommendAndApplyDiscards(gameId As %Integer, Output pDiscardResponse As Mus.Msg.ApplyDiscardsResponse) As %Status
{
    Set pDiscardResponse = ""

    Set stateResp = ""
    Set sc = ##class(Mus.Test.GameSimulation).GetGameState(gameId, .stateResp)
    If $$$ISERR(sc) {
        Return sc
    }

    If '$IsObject(stateResp) {
        Return $$$ERROR($$$GeneralError, "GetGameState returned no response")
    }

    If 'stateResp.Success {
        Return $$$ERROR($$$GeneralError, stateResp.ErrorCode_": "_stateResp.ErrorMessage)
    }

    Set gameState = {}.%FromJSON(stateResp.GameStateJson)

    If gameState.%Get("phase", "") '= "descartes" {
        Return $$$ERROR($$$GeneralError, "Game is not in discard phase")
    }

    Set discards = {}

    Set players = gameState.%Get("players", "")
    If '$IsObject(players) {
        Return $$$ERROR($$$GeneralError, "Game state has no players")
    }

    For i=0:1:players.%Size()-1 {
        Set player = players.%Get(i)
        Set playerId = player.%Get("id", "")

        If playerId '= "" {
            Set playerDiscards = ##class(Mus.Agent.DiscardStrategy).RecommendDiscards(gameState, playerId)
            Do discards.%Set(playerId, playerDiscards)
        }
    }

    Set sc = ##class(Mus.Test.GameSimulation).ApplyDiscards(
        gameId,
        discards.%ToJSON(),
        .pDiscardResponse
    )

    Return sc
}

}
