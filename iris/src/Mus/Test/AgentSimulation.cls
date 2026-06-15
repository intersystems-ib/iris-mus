Class Mus.Test.AgentSimulation Extends %RegisteredObject
{

ClassMethod RunFullAgentGame(maxHands As %Integer = 50, maxActions As %Integer = 500) As %DynamicObject
{
    Set result = {
        "success": true,
        "gameId": null,
        "handsPlayed": 0,
        "actionsExecuted": 0,
        "events": [],
        "finalState": null,
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
        Set gameId = 0
        Set stateResp = ""

        Set sc = ##class(Mus.Test.GameSimulation).CreateStartedGameInDiscardPhase(.gameId, .stateResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "CREATE_STARTED_GAME_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        Do result.%Set("gameId", gameId)
        Do ..AddEvent(result, "game_started_for_agent_discards", stateResp.GameStateJson, "")

        Set handsPlayed = 0
        Set actionsExecuted = 0

        While actionsExecuted < maxActions {
            Set stateResp = ""
            Set actionResp = ""
            Set trace = ""

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

            If status = "finished" {
                Do result.%Set("handsPlayed", handsPlayed)
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do result.%Set("finalState", state)
                Do ..AddEvent(result, "game_finished", stateResp.GameStateJson, "")
                Return result
            }

            If (status = "handClosed") || ((phase = "manoCerrada") && (state.%Get("nextAction", "") = "startNextHand")) {
                If handsPlayed >= maxHands {
                    Do result.%Set("handsPlayed", handsPlayed)
                    Do result.%Set("actionsExecuted", actionsExecuted)
                    Do result.%Set("finalState", state)
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

                Do ..AddEvent(result, "start_next_hand", nextResp.GameStateJson, "")

                Continue
            }

            If phase = "descartes" {
                Set discardsResp = ""
                Set discardSummary = ""
                Set sc = ##class(Mus.Agent.Executor).RecommendAndApplyDiscardsWithSummary(
                    gameId,
                    .discardsResp,
                    .discardSummary
                )

                If $$$ISERR(sc) {
                    Return ..Fail(result, "APPLY_AGENT_DISCARDS_STATUS_ERROR", $System.Status.GetErrorText(sc))
                }

                If '$IsObject(discardsResp) {
                    Return ..Fail(result, "APPLY_AGENT_DISCARDS_NO_RESPONSE", "Agent discards returned no response")
                }

                If 'discardsResp.Success {
                    Return ..Fail(result, discardsResp.ErrorCode, discardsResp.ErrorMessage)
                }

                Do ..AddEvent(
                    result,
                    "agent_discards",
                    discardsResp.GameStateJson,
                    "",
                    {
                        "discardSummary": (discardSummary)
                    }
                )

                Continue
            }

            If phase = "manoCerrada" {
                Do result.%Set("finalState", state)
                Return ..Fail(result, "MANO_CERRADA_WITH_INVALID_STATUS", "Expected handClosed or finished, got "_status)
            }

            If turnPlayerId = "" {
                Do result.%Set("finalState", state)
                Return ..Fail(result, "TURN_PLAYER_NOT_FOUND", "No turnPlayerId found for phase "_phase_" and status "_status)
            }

            Set actionResp = ""
            Set trace = ""

            Set sc = ##class(Mus.Agent.Executor).RecommendAndExecuteWithTrace(
                gameId,
                turnPlayerId,
                .actionResp,
                .trace
            )

            If $$$ISERR(sc) {
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do result.%Set("finalState", state)

                If $IsObject(trace) {
                    Do ..AddEvent(result, "agent_action_failed_"_phase_"_"_turnPlayerId, stateResp.GameStateJson, "", trace)
                } Else {
                    Do ..AddEvent(result, "agent_action_failed_"_phase_"_"_turnPlayerId, stateResp.GameStateJson, "")
                }

                Return ..Fail(result, "AGENT_ACTION_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If '$IsObject(actionResp) {
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do result.%Set("finalState", state)

                If $IsObject(trace) {
                    Do ..AddEvent(result, "agent_action_failed_"_phase_"_"_turnPlayerId, stateResp.GameStateJson, "", trace)
                } Else {
                    Do ..AddEvent(result, "agent_action_failed_"_phase_"_"_turnPlayerId, stateResp.GameStateJson, "")
                }

                Return ..Fail(result, "AGENT_ACTION_NO_RESPONSE", "Agent action returned no response")
            }

            If 'actionResp.Success {
                Do result.%Set("actionsExecuted", actionsExecuted)

                If actionResp.GameStateJson '= "" {
                    Set failedState = {}.%FromJSON(actionResp.GameStateJson)
                    Do result.%Set("finalState", failedState)
                } Else {
                    Do result.%Set("finalState", state)
                }

                If $IsObject(trace) {
                    Do ..AddEvent(result, "agent_action_failed_"_phase_"_"_turnPlayerId, actionResp.GameStateJson, "", trace)
                } Else {
                    Do ..AddEvent(result, "agent_action_failed_"_phase_"_"_turnPlayerId, actionResp.GameStateJson, "")
                }

                Return ..Fail(result, actionResp.ErrorCode, actionResp.ErrorMessage)
            }

            Set actionsExecuted = actionsExecuted + 1
            Do result.%Set("actionsExecuted", actionsExecuted)

            If $IsObject(trace) {
                Do ..AddEvent(result, "agent_action_"_phase_"_"_turnPlayerId, actionResp.GameStateJson, "", trace)
            } Else {
                Do ..AddEvent(result, "agent_action_"_phase_"_"_turnPlayerId, actionResp.GameStateJson, "")
            }

            If actionResp.GameStateJson '= "" {
                Set stateAfterAction = {}.%FromJSON(actionResp.GameStateJson)
                Set statusAfterAction = stateAfterAction.%Get("status", "")
                Set phaseAfterAction = stateAfterAction.%Get("phase", "")

                Do result.%Set("finalState", stateAfterAction)

                If statusAfterAction = "finished" {
                    Do result.%Set("handsPlayed", handsPlayed)
                    Do result.%Set("actionsExecuted", actionsExecuted)
                    Do ..AddEvent(result, "game_finished", actionResp.GameStateJson, "")
                    Return result
                }

                If (statusAfterAction = "handClosed") || (phaseAfterAction = "manoCerrada") {
                    Do result.%Set("finalState", stateAfterAction)
                    Continue
                }
            }
        }

        Set stateResp = ""
        Set sc = ##class(Mus.Test.GameSimulation).GetGameState(gameId, .stateResp)

        If $$$ISOK(sc), $IsObject(stateResp), stateResp.Success {
            Set state = {}.%FromJSON(stateResp.GameStateJson)
            Do result.%Set("finalState", state)
        }

        Do result.%Set("handsPlayed", handsPlayed)
        Do result.%Set("actionsExecuted", actionsExecuted)

        Return ..Fail(result, "MAX_ACTIONS_REACHED", "Game did not finish after "_maxActions_" agent actions")
    }
    Catch ex {
        Return ..Fail(result, "RUN_FULL_AGENT_GAME_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod RunSingleAgentHand(maxActions As %Integer = 100) As %DynamicObject
{
    Set result = {
        "success": true,
        "gameId": null,
        "actionsExecuted": 0,
        "events": [],
        "finalState": null,
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
        Set gameId = 0
        Set stateResp = ""

        Set sc = ##class(Mus.Test.GameSimulation).CreateStartedGameReadyForAgent(.gameId, .stateResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "CREATE_STARTED_GAME_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        Do result.%Set("gameId", gameId)
        Do ..AddEvent(result, "game_ready_for_agents", stateResp.GameStateJson, "")

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

            If turnPlayerId = "" {
                Do result.%Set("finalState", state)
                Return ..Fail(result, "TURN_PLAYER_NOT_FOUND", "No turnPlayerId found for phase "_phase_" and status "_status)
            }

            If status = "finished" {
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do result.%Set("finalState", state)
                Do ..AddEvent(result, "game_finished", stateResp.GameStateJson, "")
                Return result
            }

            If status = "handClosed" || phase = "manoCerrada" {
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do result.%Set("finalState", state)
                Do ..AddEvent(result, "hand_closed", stateResp.GameStateJson, "")
                Return result
            }

            If phase = "descartes" {
                Set discardsResp = ""
                Set sc = ##class(Mus.Test.GameSimulation).CloseDiscards(gameId, .discardsResp)
                If $$$ISERR(sc) {
                    Return ..Fail(result, "CLOSE_DISCARDS_STATUS_ERROR", $System.Status.GetErrorText(sc))
                }

                If '$IsObject(discardsResp) {
                    Return ..Fail(result, "CLOSE_DISCARDS_NO_RESPONSE", "CloseDiscards returned no response")
                }

                If 'discardsResp.Success {
                    Return ..Fail(result, discardsResp.ErrorCode, discardsResp.ErrorMessage)
                }

                Do ..AddEvent(result, "close_discards", discardsResp.GameStateJson, "")

                Continue
            }

            If turnPlayerId = "" {
                Do result.%Set("finalState", state)
                Return ..Fail(result, "TURN_PLAYER_NOT_FOUND", "No turnPlayerId found for phase "_phase_" and status "_status)
            }

            Set actionResp = ""
            Set trace = ""

            Set sc = ##class(Mus.Agent.Executor).RecommendAndExecuteWithTrace(
                gameId,
                turnPlayerId,
                .actionResp,
                .trace
            )

            If $$$ISERR(sc) {
                Do ..AddEvent(result, "agent_action_status_error_"_phase_"_"_turnPlayerId, "", "", trace)
                Return ..Fail(result, "AGENT_ACTION_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If '$IsObject(actionResp) {
                Do ..AddEvent(result, "agent_action_no_response_"_phase_"_"_turnPlayerId, "", "", trace)
                Return ..Fail(result, "AGENT_ACTION_NO_RESPONSE", "Agent action returned no response")
            }

            If 'actionResp.Success {
                Do ..AddEvent(result, "agent_action_failed_"_phase_"_"_turnPlayerId, actionResp.GameStateJson, "", trace)
                Return ..Fail(result, actionResp.ErrorCode, actionResp.ErrorMessage)
            }

            Set actionsExecuted = actionsExecuted + 1
            Do result.%Set("actionsExecuted", actionsExecuted)

            Do ..AddEvent(result, "agent_action_"_phase_"_"_turnPlayerId, actionResp.GameStateJson, "", trace)

            If actionResp.GameStateJson '= "" {
                Set stateAfterAction = {}.%FromJSON(actionResp.GameStateJson)
                Set statusAfterAction = stateAfterAction.%Get("status", "")
                Set phaseAfterAction = stateAfterAction.%Get("phase", "")

                If (statusAfterAction = "finished") || (statusAfterAction = "handClosed") || (phaseAfterAction = "manoCerrada") {
                    Do result.%Set("actionsExecuted", actionsExecuted)
                    Do result.%Set("finalState", stateAfterAction)

                    If statusAfterAction = "finished" {
                        Do ..AddEvent(result, "game_finished", actionResp.GameStateJson, "")
                    } Else {
                        Do ..AddEvent(result, "hand_closed", actionResp.GameStateJson, "")
                    }

                    Return result
                }
            }
        }

        Set stateResp = ""
        Set sc = ##class(Mus.Test.GameSimulation).GetGameState(gameId, .stateResp)

        If $$$ISOK(sc), $IsObject(stateResp), stateResp.Success {
            Set state = {}.%FromJSON(stateResp.GameStateJson)
            Do result.%Set("finalState", state)
        }

        Do result.%Set("actionsExecuted", actionsExecuted)

        Return ..Fail(result, "MAX_ACTIONS_REACHED", "Hand did not finish after "_maxActions_" agent actions")
    }
    Catch ex {
        Return ..Fail(result, "RUN_SINGLE_AGENT_HAND_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod RunExistingGame(gameId As %Integer, maxActions As %Integer = 100) As %DynamicObject
{
    Set result = {
        "success": true,
        "gameId": (gameId),
        "actionsExecuted": 0,
        "events": [],
        "finalState": null,
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
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

            If status = "finished" {
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do result.%Set("finalState", state)
                Do ..AddEvent(result, "game_finished", stateResp.GameStateJson, "")
                Return result
            }

            If status = "handClosed" {
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do result.%Set("finalState", state)
                Do ..AddEvent(result, "hand_closed", stateResp.GameStateJson, "")
                Return result
            }

            If phase = "descartes" {
                Set discardsResp = ""
                Set sc = ##class(Mus.Test.GameSimulation).CloseDiscards(gameId, .discardsResp)
                If $$$ISERR(sc) {
                    Return ..Fail(result, "CLOSE_DISCARDS_STATUS_ERROR", $System.Status.GetErrorText(sc))
                }

                If '$IsObject(discardsResp) {
                    Return ..Fail(result, "CLOSE_DISCARDS_NO_RESPONSE", "CloseDiscards returned no response")
                }

                If 'discardsResp.Success {
                    Return ..Fail(result, discardsResp.ErrorCode, discardsResp.ErrorMessage)
                }

                Do ..AddEvent(result, "close_discards", discardsResp.GameStateJson, "")

                Continue
            }

            If phase = "manoCerrada" {
                Do result.%Set("actionsExecuted", actionsExecuted)
                Do result.%Set("finalState", state)
                Do ..AddEvent(result, "mano_cerrada", stateResp.GameStateJson, "")
                Return result
            }

            If turnPlayerId = "" {
                Do result.%Set("finalState", state)
                Return ..Fail(result, "TURN_PLAYER_NOT_FOUND", "No turnPlayerId found for phase "_phase_" and status "_status)
            }

            Set actionResp = ""
            Set sc = ##class(Mus.Agent.Executor).RecommendAndExecute(gameId, turnPlayerId, .actionResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "AGENT_ACTION_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If '$IsObject(actionResp) {
                Return ..Fail(result, "AGENT_ACTION_NO_RESPONSE", "Agent action returned no response")
            }

            If 'actionResp.Success {
                Do ..AddEvent(result, "agent_action_failed_"_phase_"_"_turnPlayerId, actionResp.GameStateJson, "")
                Return ..Fail(result, actionResp.ErrorCode, actionResp.ErrorMessage)
            }

            Set actionsExecuted = actionsExecuted + 1
            Do result.%Set("actionsExecuted", actionsExecuted)

            Do ..AddEvent(result, "agent_action_"_phase_"_"_turnPlayerId, actionResp.GameStateJson, "", "")
        }

        Set stateResp = ""
        Set sc = ##class(Mus.Test.GameSimulation).GetGameState(gameId, .stateResp)

        If $$$ISOK(sc), $IsObject(stateResp), stateResp.Success {
            Set state = {}.%FromJSON(stateResp.GameStateJson)
            Do result.%Set("finalState", state)
        }

        Do result.%Set("actionsExecuted", actionsExecuted)

        Return ..Fail(result, "MAX_ACTIONS_REACHED", "Existing game did not stop after "_maxActions_" agent actions")
    }
    Catch ex {
        Return ..Fail(result, "RUN_EXISTING_GAME_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod AddEvent(result As %DynamicObject, eventType As %String, stateJson As %String = "", actionEventJson As %String = "", agentTrace As %DynamicObject = "") As %Status
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

    If stateJson '= "" {
        Try {
            Set state = {}.%FromJSON(stateJson)

            Do event.%Set("status", state.%Get("status", ""))
            Do event.%Set("phase", state.%Get("phase", ""))
            Do event.%Set("turnPlayerId", state.%Get("turnPlayerId", ""))
            Do event.%Set("nextAction", state.%Get("nextAction", ""))

            If $IsObject(state.%Get("score", "")) {
                Do event.%Set("score", state.%Get("score"))
            }

            If state.%Get("winnerTeam", "") '= "" {
                Do event.%Set("winnerTeam", state.%Get("winnerTeam", ""))
            }

            If state.%Get("currentHandId", "") '= "" {
                Do event.%Set("currentHandId", state.%Get("currentHandId", ""))
            }

            If state.%Get("handNumber", "") '= "" {
                Do event.%Set("handNumber", state.%Get("handNumber", ""))
            }

            If eventType = "agent_discards" {
                Do ..AddCompactDiscardAudit(.event, state)
            }
        }
        Catch exState {
            Do event.%Set("stateParseError", exState.DisplayString())
        }
    }

    If actionEventJson '= "" {
        Try {
            Set actionEvent = {}.%FromJSON(actionEventJson)

            Do event.%Set("actionType", actionEvent.%Get("type", ""))
            Do event.%Set("playerId", actionEvent.%Get("playerId", ""))
            Do event.%Set("actionPhase", actionEvent.%Get("phase", ""))

            If actionEvent.%IsDefined("amount") {
                Do event.%Set("amount", actionEvent.%Get("amount"))
            }
        }
        Catch exAction {
            Do event.%Set("actionEventParseError", exAction.DisplayString())
        }
    }

    If $IsObject(agentTrace) {
        Do ..AddCompactAgentAudit(.event, agentTrace)
    }

    Do events.%Push(event)
    Do result.%Set("events", events)

    Return $$$OK
}

ClassMethod AddCompactDiscardAudit(ByRef event As %DynamicObject, state As %DynamicObject) As %Status
{
    Set hand = state.%Get("hand", "")

    If '$IsObject(hand) {
        Return $$$OK
    }

    If hand.%Get("discardRound", "") '= "" {
        Do event.%Set("discardRound", +hand.%Get("discardRound", 0))
    }

    If hand.%Get("discardsClosed", "") '= "" {
        Do event.%Set("discardsClosed", +hand.%Get("discardsClosed", 0))
    }

    If hand.%Get("discardsApplied", "") '= "" {
        Do event.%Set("discardsApplied", +hand.%Get("discardsApplied", 0))
    }

    Set actions = hand.%Get("actions", "")
    If '$IsObject(actions) {
        Return $$$OK
    }

    Set lastDiscardAction = ""

    For i=0:1:actions.%Size()-1 {
        Set handAction = actions.%Get(i)

        If '$IsObject(handAction) {
            Continue
        }

        If handAction.%Get("type", "") = "descartes" {
            Set lastDiscardAction = handAction
        }
    }

    If '$IsObject(lastDiscardAction) {
        Return $$$OK
    }

    Do event.%Set("discardAction", {
        "round": (+lastDiscardAction.%Get("round", 0)),
        "totalDiscarded": (+lastDiscardAction.%Get("totalDiscarded", 0)),
        "createdAt": (lastDiscardAction.%Get("createdAt", ""))
    })

    /*
      Guardamos las cartas descartadas solo si realmente hubo descartes.
      Si todos son arrays vacíos, no añadimos el mapa completo.
    */
    Set totalDiscarded = +lastDiscardAction.%Get("totalDiscarded", 0)

    If totalDiscarded > 0 {
        If $IsObject(lastDiscardAction.%Get("discards", "")) {
            Do event.%Set("discards", lastDiscardAction.%Get("discards"))
        }
    }

    Return $$$OK
}

ClassMethod AddCompactAgentAudit(ByRef event As %DynamicObject, agentTrace As %DynamicObject) As %Status
{
    Set discardSummary = agentTrace.%Get("discardSummary", "")
    If $IsObject(discardSummary) {
        Do event.%Set("discardSummary", discardSummary)

        /*
          Si este trace solo trae discardSummary, no añadimos bloque agent vacío.
        */
        If 'agentTrace.%IsDefined("success") {
            Return $$$OK
        }
    }

    Do event.%Set("agent", {
        "success": (agentTrace.%Get("success", "")),
        "phaseBefore": (agentTrace.%Get("phaseBefore", "")),
        "phaseAfter": (agentTrace.%Get("phaseAfter", "")),
        "turnPlayerIdBefore": (agentTrace.%Get("turnPlayerIdBefore", "")),
        "turnPlayerIdAfter": (agentTrace.%Get("turnPlayerIdAfter", ""))
    })

    If agentTrace.%Get("errorCode", "") '= "" {
        Do event.%Set("agentError", {
            "code": (agentTrace.%Get("errorCode", "")),
            "message": (agentTrace.%Get("errorMessage", ""))
        })
    }

    Set recommendation = agentTrace.%Get("recommendation", "")
    If $IsObject(recommendation) {
        Do event.%Set("recommendedActionType", recommendation.%Get("actionType", ""))
        Do event.%Set("recommendedAmount", +recommendation.%Get("amount", 0))
        Do event.%Set("recommendedConfidence", +recommendation.%Get("confidence", 0))

        Set reason = recommendation.%Get("reason", "")
        If reason '= "" {
            Do event.%Set("recommendedReason", ..TruncateText(reason, 180))
        }

        If recommendation.%IsDefined("rawModelOutput") {
            Do event.%Set("fallbackUsed", 1)
            Do event.%Set(
                "rawModelOutput",
                ..TruncateText(recommendation.%Get("rawModelOutput", ""), 300)
            )
        }
    }

    Set executedAction = agentTrace.%Get("executedAction", "")
    If $IsObject(executedAction) {
        Do event.%Set("actionType", executedAction.%Get("actionType", ""))
        Do event.%Set("playerId", executedAction.%Get("playerId", ""))
        Do event.%Set("actionPhase", executedAction.%Get("phase", ""))
        Do event.%Set("amount", +executedAction.%Get("amount", 0))
    }

    Set legalActions = agentTrace.%Get("legalActions", "")
    If $IsObject(legalActions) {
        Do event.%Set("legalActions", legalActions)
    }

    Set bettingGuidance = agentTrace.%Get("bettingGuidance", "")
    If $IsObject(bettingGuidance) {
        Do event.%Set("handStrength", bettingGuidance.%Get("handStrength", ""))

        If bettingGuidance.%IsDefined("ordagoPressure") {
            Do event.%Set("ordagoPressure", bettingGuidance.%Get("ordagoPressure", ""))
        }

        If bettingGuidance.%IsDefined("scoreAggressionMultiplier") {
            Do event.%Set(
                "scoreAggressionMultiplier",
                +bettingGuidance.%Get("scoreAggressionMultiplier", 1)
            )
        }

        Set scorePressure = bettingGuidance.%Get("scorePressure", "")
        If $IsObject(scorePressure) {
            Do event.%Set("scorePressure", {
                "myTeamScore": (+scorePressure.%Get("myTeamScore", 0)),
                "opponentTeamScore": (+scorePressure.%Get("opponentTeamScore", 0)),
                "opponentDistanceToTarget": (+scorePressure.%Get("opponentDistanceToTarget", 0)),
                "isEmergency": (+scorePressure.%Get("isEmergency", 0)),
                "isDesperationMode": (+scorePressure.%Get("isDesperationMode", 0)),
                "ordagoPressure": (scorePressure.%Get("ordagoPressure", "none"))
            })
        }
    }

    If $IsObject(agentTrace.%Get("scoreAfter", "")) {
        Do event.%Set("scoreAfter", agentTrace.%Get("scoreAfter"))
    }

    If agentTrace.%Get("winnerTeam", "") '= "" {
        Do event.%Set("winnerTeam", agentTrace.%Get("winnerTeam", ""))
    }

    Return $$$OK
}

ClassMethod TruncateText(text As %String, maxLen As %Integer = 200) As %String
{
    If maxLen <= 0 {
        Return ""
    }

    If $Length(text) <= maxLen {
        Return text
    }

    Return $Extract(text, 1, maxLen)_"..."
}

ClassMethod Fail(result As %DynamicObject, errorCode As %String, errorMessage As %String) As %DynamicObject
{
    Do result.%Set("success", "false")
    Do result.%Set("errorCode", errorCode)
    Do result.%Set("errorMessage", errorMessage)

    Return result
}

}
