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

    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return $$$ERROR($$$GeneralError, "Game state has no hand")
    }

    Set discardRound = +hand.%Get("discardRound", gameState.%Get("discardRound", 1))

    /*
      Solo permitimos una ronda inteligente de descarte.
      A partir de la ronda 2, cerramos con cero descartes.
    */
    If discardRound > 1 {
        Set closeDiscards = ..BuildEmptyDiscards(gameState)

        Set sc = ##class(Mus.Test.GameSimulation).ApplyDiscards(
            gameId,
            closeDiscards.%ToJSON(),
            .pDiscardResponse
        )

        Return sc
    }

    Set players = gameState.%Get("players", "")
    If '$IsObject(players) {
        Return $$$ERROR($$$GeneralError, "Game state has no players")
    }

    Set proposedDiscards = {}
    Set allPlayersWantDiscard = 1

    /*
      Nueva regla:
      El descarte solo se aplica si TODOS los jugadores descartan al menos una carta.
      Si uno no quiere descartar, se cancela el descarte completo.
    */
    For i=0:1:players.%Size()-1 {
        Set player = players.%Get(i)
        Set playerId = player.%Get("id", "")

        If playerId = "" {
            Continue
        }

        Set playerDiscards = ##class(Mus.Agent.DiscardStrategy).RecommendDiscards(
            gameState,
            playerId
        )

        If '$IsObject(playerDiscards) {
            Set playerDiscards = []
        }

        Do proposedDiscards.%Set(playerId, playerDiscards)

        If playerDiscards.%Size() = 0 {
            Set allPlayersWantDiscard = 0
        }
    }

    If 'allPlayersWantDiscard {
        Set closeDiscards = ..BuildEmptyDiscards(gameState)

        Set sc = ##class(Mus.Test.GameSimulation).ApplyDiscards(
            gameId,
            closeDiscards.%ToJSON(),
            .pDiscardResponse
        )

        Return sc
    }

    /*
      Solo llegamos aquí si todos los jugadores han propuesto descartarse.
    */
    Set sc = ##class(Mus.Test.GameSimulation).ApplyDiscards(
        gameId,
        proposedDiscards.%ToJSON(),
        .pDiscardResponse
    )

    Return sc
}

ClassMethod BuildEmptyDiscards(gameState As %DynamicObject) As %DynamicObject
{
    Set discards = {}

    Set players = gameState.%Get("players", "")
    If $IsObject(players) {
        For i=0:1:players.%Size()-1 {
            Set player = players.%Get(i)
            Set playerId = player.%Get("id", "")

            If playerId '= "" {
                Do discards.%Set(playerId, [])
            }
        }

        Return discards
    }

    /*
      Fallback por si el estado no trae players.
    */
    Do discards.%Set("P1", [])
    Do discards.%Set("P2", [])
    Do discards.%Set("P3", [])
    Do discards.%Set("P4", [])

    Return discards
}

}
