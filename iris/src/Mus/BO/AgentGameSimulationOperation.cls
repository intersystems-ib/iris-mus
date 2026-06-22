Class Mus.BO.AgentGameSimulationOperation Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
    <MapItem MessageType="Mus.Msg.SimulateAgentGameRequest">
        <Method>SimulateAgentGame</Method>
    </MapItem>
</MapItems>
}

Method SimulateAgentGame(pRequest As Mus.Msg.SimulateAgentGameRequest, Output pResponse As Mus.Msg.SimulateAgentGameResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.SimulateAgentGameResponse).%New()

    Try {
        If pRequest.GameId <= 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "INVALID_GAME_ID"
            Set pResponse.ErrorMessage = "Invalid game id"
            Return $$$OK
        }

        Set maxHands = +pRequest.MaxHands
        If maxHands <= 0 {
            Set maxHands = 50
        }

        Set maxActions = +pRequest.MaxActions
        If maxActions <= 0 {
            Set maxActions = 500
        }

        Set simulation = ..RunAgentGame(pRequest.GameId, maxHands, maxActions)

        Set pResponse.GameId = pRequest.GameId
        Set pResponse.SimulationJson = simulation.%ToJSON()

        If 'simulation.%Get("success", 0) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = simulation.%Get("errorCode", "SIMULATION_FAILED")
            Set pResponse.ErrorMessage = simulation.%Get("errorMessage", "Agent simulation failed")
            Return $$$OK
        }

        Set finalState = simulation.%Get("finalState", "")

        If '$IsObject(finalState) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SIMULATION_WITHOUT_FINAL_STATE"
            Set pResponse.ErrorMessage = "Agent simulation did not return a final game state"
            Return $$$OK
        }

        If finalState.%Get("status", "") '= "finished" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "SIMULATION_DID_NOT_FINISH_GAME"
            Set pResponse.ErrorMessage = "Agent simulation ended before game finished"
            Set pResponse.FinalGameStateJson = finalState.%ToJSON()
            Return $$$OK
        }

        Set winnerTeam = finalState.%Get("winnerTeam", "")

        If (winnerTeam '= "A") && (winnerTeam '= "B") {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SIMULATION_WINNER_TEAM_NOT_FOUND"
            Set pResponse.ErrorMessage = "Final game state does not contain winnerTeam"
            Set pResponse.FinalGameStateJson = finalState.%ToJSON()
            Return $$$OK
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.WinnerTeam = winnerTeam
        Set pResponse.FinalGameStateJson = finalState.%ToJSON()

        Return $$$OK
    } Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "SIMULATE_AGENT_GAME_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

ClassMethod RunAgentGame(gameId As %Integer, maxHands As %Integer = 50, maxActions As %Integer = 500) As %DynamicObject
{
    Set result = {
        "success": true,
        "gameId": (gameId),
        "handsPlayed": 0,
        "actionsExecuted": 0,
        "events": [],
        "finalState": null,
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
        Set handsPlayed = 0
        Set actionsExecuted = 0

        While actionsExecuted < maxActions {
            Set stateResp = ""
            Set sc = ##class(Mus.Test.GameSimulation).GetGameState(gameId, .stateResp)

            If $$$ISERR(sc) {
                Return ..Fail(result, "GET_STATE_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If '$IsObject(stateResp) {
                Return ..Fail(result, "GET_STATE_NO_RESPONSE", "GetGameState returned no response")
            }

            If 'stateResp.Success {
                Return ..Fail(result, stateResp.ErrorCode, stateResp.ErrorMessage)
            }

            Set state = {}.%FromJSON(stateResp.GameStateJson)
            Set status = state.%Get("status", "")
            Set phase = state.%Get("phase", "")
            Set turnPlayerId = state.%Get("turnPlayerId", "")

            Do result.%Set("finalState", state)

            If status = "finished" {
                Do result.%Set("handsPlayed", handsPlayed)
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do ..AddEvent(result, "game_finished", state)
                Return result
            }

            If (status = "handClosed") || ((phase = "manoCerrada") && (state.%Get("nextAction", "") = "startNextHand")) {
                If handsPlayed >= maxHands {
                    Return ..Fail(result, "MAX_HANDS_REACHED", "Game did not finish after "_maxHands_" hands")
                }

                Set nextResp = ""
                Set sc = ##class(Mus.Test.GameSimulation).StartNextHand(gameId, .nextResp)

                If $$$ISERR(sc) {
                    Return ..Fail(result, "START_NEXT_HAND_STATUS_ERROR", $System.Status.GetErrorText(sc))
                }

                If '$IsObject(nextResp) {
                    Return ..Fail(result, "START_NEXT_HAND_NO_RESPONSE", "StartNextHand returned no response")
                }

                If 'nextResp.Success {
                    Return ..Fail(result, nextResp.ErrorCode, nextResp.ErrorMessage)
                }

                Set handsPlayed = handsPlayed + 1
                Do result.%Set("handsPlayed", handsPlayed)

                Set nextState = {}.%FromJSON(nextResp.GameStateJson)
                Do result.%Set("finalState", nextState)
                Do ..AddEvent(result, "start_next_hand", nextState)
                Continue
            }

            If phase = "descartes" {
                Set discardsResp = ""
                Set discardSummary = ""
                Set sc = ##class(Mus.Agent.Executor).RecommendAndApplyDiscardsWithSummary(gameId, .discardsResp, .discardSummary)

                If $$$ISERR(sc) {
                    Return ..Fail(result, "APPLY_AGENT_DISCARDS_STATUS_ERROR", $System.Status.GetErrorText(sc))
                }

                If '$IsObject(discardsResp) {
                    Return ..Fail(result, "APPLY_AGENT_DISCARDS_NO_RESPONSE", "Agent discards returned no response")
                }

                If 'discardsResp.Success {
                    Return ..Fail(result, discardsResp.ErrorCode, discardsResp.ErrorMessage)
                }

                Set stateAfterDiscards = {}.%FromJSON(discardsResp.GameStateJson)
                Do result.%Set("finalState", stateAfterDiscards)
                Do ..AddEvent(result, "agent_discards", stateAfterDiscards, discardSummary)
                Continue
            }

            If phase = "manoCerrada" {
                Return ..Fail(result, "MANO_CERRADA_WITH_INVALID_STATUS", "Expected handClosed or finished, got "_status)
            }

            If turnPlayerId = "" {
                Return ..Fail(result, "TURN_PLAYER_NOT_FOUND", "No turnPlayerId found for phase "_phase_" and status "_status)
            }

            Set actionResp = ""
            Set trace = ""
            Set sc = ##class(Mus.Agent.Executor).RecommendAndExecuteWithTrace(gameId, turnPlayerId, .actionResp, .trace)

            If $$$ISERR(sc) {
                If $IsObject(trace) {
                    Do ..AddEvent(result, "agent_action_status_error", state, trace)
                }
                Return ..Fail(result, "AGENT_ACTION_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If '$IsObject(actionResp) {
                Return ..Fail(result, "AGENT_ACTION_NO_RESPONSE", "Agent action returned no response")
            }

            If 'actionResp.Success {
                If actionResp.GameStateJson '= "" {
                    Set failedState = {}.%FromJSON(actionResp.GameStateJson)
                    Do result.%Set("finalState", failedState)
                }

                If $IsObject(trace) {
                    Do ..AddEvent(result, "agent_action_failed", result.%Get("finalState"), trace)
                }

                Return ..Fail(result, actionResp.ErrorCode, actionResp.ErrorMessage)
            }

            Set actionsExecuted = actionsExecuted + 1
            Do result.%Set("actionsExecuted", actionsExecuted)

            If actionResp.GameStateJson '= "" {
                Set stateAfterAction = {}.%FromJSON(actionResp.GameStateJson)
                Do result.%Set("finalState", stateAfterAction)
                Do ..AddEvent(result, "agent_action", stateAfterAction, trace)
            }
        }

        Return ..Fail(result, "MAX_ACTIONS_REACHED", "Game did not finish after "_maxActions_" agent actions")
    } Catch ex {
        Return ..Fail(result, "RUN_AGENT_GAME_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod AddEvent(result As %DynamicObject, eventType As %String, state As %DynamicObject = "", agentTrace As %DynamicObject = "") As %Status
{
    Set events = result.%Get("events", "")

    If '$IsObject(events) {
        Set events = []
        Do result.%Set("events", events)
    }

    Set event = {
        "type": (eventType),
        "createdAt": ($ZDATETIME($HOROLOG, 3))
    }

    If $IsObject(state) {
        Do event.%Set("status", state.%Get("status", ""))
        Do event.%Set("phase", state.%Get("phase", ""))
        Do event.%Set("turnPlayerId", state.%Get("turnPlayerId", ""))
        If $IsObject(state.%Get("score", "")) {
            Do event.%Set("score", state.%Get("score"))
        }
        If state.%Get("winnerTeam", "") '= "" {
            Do event.%Set("winnerTeam", state.%Get("winnerTeam", ""))
        }
    }

    If $IsObject(agentTrace) {
        Set recommendation = agentTrace.%Get("recommendation", "")
        If $IsObject(recommendation) {
            Do event.%Set("recommendedActionType", recommendation.%Get("actionType", ""))
            Do event.%Set("recommendedAmount", +recommendation.%Get("amount", 0))
        }

        Set executedAction = agentTrace.%Get("executedAction", "")
        If $IsObject(executedAction) {
            Do event.%Set("playerId", executedAction.%Get("playerId", ""))
            Do event.%Set("actionType", executedAction.%Get("actionType", ""))
            Do event.%Set("amount", +executedAction.%Get("amount", 0))
        }
    }

    Do events.%Push(event)
    Do result.%Set("events", events)

    Return $$$OK
}

ClassMethod Fail(result As %DynamicObject, errorCode As %String, errorMessage As %String) As %DynamicObject
{
    Do result.%Set("success", 0)
    Do result.%Set("errorCode", errorCode)
    Do result.%Set("errorMessage", errorMessage)
    Return result
}

}
