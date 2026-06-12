Class Mus.Test.GameSimulation
{

ClassMethod RunFullGame(maxHands As %Integer = 50) As %DynamicObject
{
    Set result = {
        "success": true,
        "gameId": null,
        "handsPlayed": 0,
        "events": [],
        "finalState": null,
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
        Set playersJson = {
            "players": [
                {
                    "id": "P1",
                    "name": "Player 1",
                    "team": "A"
                },
                {
                    "id": "P2",
                    "name": "Player 2",
                    "team": "B"
                },
                {
                    "id": "P3",
                    "name": "Player 3",
                    "team": "A"
                },
                {
                    "id": "P4",
                    "name": "Player 4",
                    "team": "B"
                }
            ]
        }

        Set createResp = ""
        Set sc = ..CreateGame(playersJson.%ToJSON(), .createResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "CREATE_GAME_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'createResp.Success {
            Return ..Fail(result, createResp.ErrorCode, createResp.ErrorMessage)
        }

        Set gameId = createResp.GameId
        Do result.%Set("gameId", gameId)

        Do ..AddEvent(result, "create_game", createResp.GameStateJson)

        Set startResp = ""
        Set sc = ..StartGame(gameId, .startResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "START_GAME_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'startResp.Success {
            Return ..Fail(result, startResp.ErrorCode, startResp.ErrorMessage)
        }

        Do ..AddEvent(result, "start_game", startResp.GameStateJson)

        Set handCounter = 0

        While handCounter < maxHands {
            Set stateResp = ""
            Set sc = ..GetGameState(gameId, .stateResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "GET_STATE_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If 'stateResp.Success {
                Return ..Fail(result, stateResp.ErrorCode, stateResp.ErrorMessage)
            }

            Set state = {}.%FromJSON(stateResp.GameStateJson)

            If state.%Get("status", "") = "finished" {
                Do result.%Set("finalState", state)
                Do result.%Set("handsPlayed", handCounter)
                Return result
            }

            Set phase = state.%Get("phase", "")

            If phase = "descartes" {
                Set discardsResp = ""
                Set sc = ..CloseDiscards(gameId, .discardsResp)
                If $$$ISERR(sc) {
                    Return ..Fail(result, "DISCARDS_STATUS_ERROR", $System.Status.GetErrorText(sc))
                }

                If 'discardsResp.Success {
                    Return ..Fail(result, discardsResp.ErrorCode, discardsResp.ErrorMessage)
                }

                Do ..AddEvent(result, "close_discards", discardsResp.GameStateJson)
            }

            Set playResult = ..PlayCurrentHand(gameId, result)

            If 'playResult.%Get("success", 0) {
                Return playResult
            }

            Set stateResp = ""
            Set sc = ..GetGameState(gameId, .stateResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "GET_STATE_AFTER_HAND_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If 'stateResp.Success {
                Return ..Fail(result, stateResp.ErrorCode, stateResp.ErrorMessage)
            }

            Set state = {}.%FromJSON(stateResp.GameStateJson)

            If state.%Get("status", "") = "finished" {
                Set handCounter = handCounter + 1
                Do result.%Set("handsPlayed", handCounter)
                Do result.%Set("finalState", state)
                Return result
            }

            If state.%Get("status", "") = "handClosed" {
                Set handCounter = handCounter + 1

                Set nextResp = ""
                Set sc = ..StartNextHand(gameId, .nextResp)
                If $$$ISERR(sc) {
                    Return ..Fail(result, "START_NEXT_HAND_STATUS_ERROR", $System.Status.GetErrorText(sc))
                }

                If 'nextResp.Success {
                    Return ..Fail(result, nextResp.ErrorCode, nextResp.ErrorMessage)
                }

                Do ..AddEvent(result, "start_next_hand", nextResp.GameStateJson)
            } Else {
                Return ..Fail(result, "HAND_NOT_CLOSED", "Expected handClosed or finished, got status "_state.%Get("status", ""))
            }
        }

        Set stateResp = ""
        Set sc = ..GetGameState(gameId, .stateResp)

        If $$$ISOK(sc), stateResp.Success {
            Set state = {}.%FromJSON(stateResp.GameStateJson)
            Do result.%Set("finalState", state)
        }

        Return ..Fail(result, "MAX_HANDS_REACHED", "Game did not finish after "_maxHands_" hands")
    }
    Catch ex {
        Return ..Fail(result, "RUN_FULL_GAME_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod PlayCurrentHand(gameId As %Integer, result As %DynamicObject) As %DynamicObject
{
    Try {
        Set safetyCounter = 0

        While safetyCounter < 100 {
            Set safetyCounter = safetyCounter + 1

            Set stateResp = ""
            Set sc = ..GetGameState(gameId, .stateResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "GET_STATE_IN_HAND_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If 'stateResp.Success {
                Return ..Fail(result, stateResp.ErrorCode, stateResp.ErrorMessage)
            }

            Set state = {}.%FromJSON(stateResp.GameStateJson)
            Set status = state.%Get("status", "")
            Set phase = state.%Get("phase", "")
            Set turnPlayerId = state.%Get("turnPlayerId", "")

            If status = "finished" {
                Do result.%Set("finalState", state)
                Return result
            }

            If phase = "manoCerrada" {
                Return result
            }

            If turnPlayerId = "" {
                Return ..Fail(result, "TURN_NOT_AVAILABLE", "No turnPlayerId found while phase is "_phase)
            }

            Set actionResp = ""
            Set sc = ..SendPlayerAction(gameId, turnPlayerId, "pasar", phase, 0, "{}", .actionResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "PLAYER_ACTION_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If 'actionResp.Success {
                Return ..Fail(result, actionResp.ErrorCode, actionResp.ErrorMessage)
            }

            Do ..AddEvent(result, "action_"_phase_"_"_turnPlayerId_"_pasar", actionResp.GameStateJson)
        }

        Return ..Fail(result, "HAND_SAFETY_LIMIT_REACHED", "Current hand did not close after 100 actions")
    }
    Catch ex {
        Return ..Fail(result, "PLAY_CURRENT_HAND_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod RunOrdagoAcceptedTest() As %DynamicObject
{
    Set result = {
        "success": true,
        "gameId": null,
        "events": [],
        "finalState": null,
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
        Set playersJson = {
            "players": [
                {
                    "id": "P1",
                    "name": "Player 1",
                    "team": "A"
                },
                {
                    "id": "P2",
                    "name": "Player 2",
                    "team": "B"
                },
                {
                    "id": "P3",
                    "name": "Player 3",
                    "team": "A"
                },
                {
                    "id": "P4",
                    "name": "Player 4",
                    "team": "B"
                }
            ]
        }

        Set createResp = ""
        Set sc = ..CreateGame(playersJson.%ToJSON(), .createResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "CREATE_GAME_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'createResp.Success {
            Return ..Fail(result, createResp.ErrorCode, createResp.ErrorMessage)
        }

        Set gameId = createResp.GameId
        Do result.%Set("gameId", gameId)
        Do ..AddEvent(result, "create_game", createResp.GameStateJson)

        Set startResp = ""
        Set sc = ..StartGame(gameId, .startResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "START_GAME_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'startResp.Success {
            Return ..Fail(result, startResp.ErrorCode, startResp.ErrorMessage)
        }

        Do ..AddEvent(result, "start_game", startResp.GameStateJson)

        Set discardsResp = ""
        Set sc = ..CloseDiscards(gameId, .discardsResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "DISCARDS_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'discardsResp.Success {
            Return ..Fail(result, discardsResp.ErrorCode, discardsResp.ErrorMessage)
        }

        Do ..AddEvent(result, "close_discards", discardsResp.GameStateJson)

        Set state = {}.%FromJSON(discardsResp.GameStateJson)
        Set phase = state.%Get("phase", "")
        Set turnPlayerId = state.%Get("turnPlayerId", "")

        If turnPlayerId = "" {
            Return ..Fail(result, "NO_TURN_FOR_ORDAGO", "No turnPlayerId available for ordago")
        }

        Set ordagoResp = ""
        Set sc = ..SendPlayerAction(gameId, turnPlayerId, "ordago", phase, 0, "{}", .ordagoResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "ORDAGO_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'ordagoResp.Success {
            Return ..Fail(result, ordagoResp.ErrorCode, ordagoResp.ErrorMessage)
        }

        Do ..AddEvent(result, "ordago", ordagoResp.GameStateJson)

        Set state = {}.%FromJSON(ordagoResp.GameStateJson)
        Set nextPlayerId = state.%Get("turnPlayerId", "")

        If nextPlayerId = "" {
            Return ..Fail(result, "NO_TURN_TO_ACCEPT_ORDAGO", "No turnPlayerId available to accept ordago")
        }

        Set quererResp = ""
        Set sc = ..SendPlayerAction(gameId, nextPlayerId, "querer", phase, 0, "{}", .quererResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "ACCEPT_ORDAGO_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'quererResp.Success {
            Return ..Fail(result, quererResp.ErrorCode, quererResp.ErrorMessage)
        }

        Do ..AddEvent(result, "querer_ordago", quererResp.GameStateJson)

        Set finalState = {}.%FromJSON(quererResp.GameStateJson)
        Do result.%Set("finalState", finalState)

        If finalState.%Get("status", "") '= "finished" {
            Return ..Fail(result, "ORDAGO_DID_NOT_FINISH_GAME", "Expected status finished after accepted ordago")
        }

        Return result
    }
    Catch ex {
        Return ..Fail(result, "RUN_ORDAGO_ACCEPTED_TEST_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod CreateGame(playersJson As %String, Output pResponse As Mus.Msg.CreateGameResponse) As %Status
{
    Set request = ##class(Mus.Msg.CreateGameRequest).%New()
    Set request.PlayersJson = playersJson
    Set request.CorrelationId = $System.Util.CreateGUID()

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod StartGame(gameId As %Integer, Output pResponse As Mus.Msg.StartGameResponse) As %Status
{
    Set request = ##class(Mus.Msg.StartGameRequest).%New()
    Set request.GameId = gameId
    Set request.CorrelationId = $System.Util.CreateGUID()

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod StartNextHand(gameId As %Integer, Output pResponse As Mus.Msg.StartNextHandResponse) As %Status
{
    Set request = ##class(Mus.Msg.StartNextHandRequest).%New()
    Set request.GameId = gameId
    Set request.CorrelationId = $System.Util.CreateGUID()

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod GetGameState(gameId As %Integer, Output pResponse As Mus.Msg.GetGameStateResponse) As %Status
{
    Set request = ##class(Mus.Msg.GetGameStateRequest).%New()
    Set request.GameId = gameId
    Set request.CorrelationId = $System.Util.CreateGUID()

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod CloseDiscards(gameId As %Integer, Output pResponse As Mus.Msg.ApplyDiscardsResponse) As %Status
{
    Set discards = {
        "P1": [],
        "P2": [],
        "P3": [],
        "P4": []
    }

    Set request = ##class(Mus.Msg.ApplyDiscardsRequest).%New()
    Set request.GameId = gameId
    Set request.DiscardsJson = discards.%ToJSON()
    Set request.CorrelationId = $System.Util.CreateGUID()

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod SendPlayerAction(gameId As %Integer, playerId As %String, actionType As %String, phase As %String, amount As %Integer = 0, payloadJson As %String = "{}", Output pResponse As Mus.Msg.PlayerActionResponse) As %Status
{
    Set request = ##class(Mus.Msg.PlayerActionRequest).%New()
    Set request.GameId = gameId
    Set request.PlayerId = playerId
    Set request.ActionType = actionType
    Set request.Phase = phase
    Set request.Amount = amount
    Set request.PayloadJson = payloadJson
    Set request.CorrelationId = $System.Util.CreateGUID()

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod AddEvent(result As %DynamicObject, eventType As %String, stateJson As %String) As %Status
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

            If $IsObject(state.%Get("score", "")) {
                Do event.%Set("score", state.%Get("score"))
            }

            If state.%Get("winnerTeam", "") '= "" {
                Do event.%Set("winnerTeam", state.%Get("winnerTeam", ""))
            }
        }
        Catch exState {
            Do event.%Set("stateParseError", exState.DisplayString())
        }
    }

    Do events.%Push(event)
    Do result.%Set("events", events)

    Return $$$OK
}

ClassMethod PlayEnviteAndAccept(gameId As %Integer, playerId As %String, phase As %String, amount As %Integer, result As %DynamicObject) As %DynamicObject
{
    Try {
        Set envidarResp = ""
        Set sc = ..SendPlayerAction(gameId, playerId, "envidar", phase, amount, "{}", .envidarResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "ENVIDAR_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'envidarResp.Success {
            Return ..Fail(result, envidarResp.ErrorCode, envidarResp.ErrorMessage)
        }

        Do ..AddEvent(result, "envidar_"_phase_"_"_playerId, envidarResp.GameStateJson)

        Set state = {}.%FromJSON(envidarResp.GameStateJson)
        Set responderPlayerId = state.%Get("turnPlayerId", "")

        If responderPlayerId = "" {
            Return ..Fail(result, "NO_RESPONDER_AFTER_ENVIDAR", "No turnPlayerId found after envidar in phase "_phase)
        }

        Set quererResp = ""
        Set sc = ..SendPlayerAction(gameId, responderPlayerId, "querer", phase, 0, "{}", .quererResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "QUERER_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'quererResp.Success {
            Return ..Fail(result, quererResp.ErrorCode, quererResp.ErrorMessage)
        }

        Do ..AddEvent(result, "querer_"_phase_"_"_responderPlayerId, quererResp.GameStateJson)

        Return result
    }
    Catch ex {
        Return ..Fail(result, "PLAY_ENVITE_AND_ACCEPT_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod PlayPhaseWithPasses(gameId As %Integer, result As %DynamicObject) As %DynamicObject
{
    Try {
        Set safetyCounter = 0

        While safetyCounter < 20 {
            Set safetyCounter = safetyCounter + 1

            Set stateResp = ""
            Set sc = ..GetGameState(gameId, .stateResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "GET_STATE_PASS_PHASE_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If 'stateResp.Success {
                Return ..Fail(result, stateResp.ErrorCode, stateResp.ErrorMessage)
            }

            Set state = {}.%FromJSON(stateResp.GameStateJson)
            Set status = state.%Get("status", "")
            Set phase = state.%Get("phase", "")
            Set turnPlayerId = state.%Get("turnPlayerId", "")

            If status = "finished" {
                Do result.%Set("finalState", state)
                Return result
            }

            If phase = "manoCerrada" {
                Do result.%Set("finalState", state)
                Return result
            }

            If turnPlayerId = "" {
                Return ..Fail(result, "TURN_NOT_AVAILABLE_FOR_PASS", "No turnPlayerId found while passing phase "_phase)
            }

            Set actionResp = ""
            Set sc = ..SendPlayerAction(gameId, turnPlayerId, "pasar", phase, 0, "{}", .actionResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "PASS_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If 'actionResp.Success {
                Return ..Fail(result, actionResp.ErrorCode, actionResp.ErrorMessage)
            }

            Do ..AddEvent(result, "pasar_"_phase_"_"_turnPlayerId, actionResp.GameStateJson)

            Set newState = {}.%FromJSON(actionResp.GameStateJson)
            Set newPhase = newState.%Get("phase", "")

            If newPhase '= phase {
                Return result
            }
        }

        Return ..Fail(result, "PASS_PHASE_SAFETY_LIMIT_REACHED", "Phase did not advance after 20 passes")
    }
    Catch ex {
        Return ..Fail(result, "PLAY_PHASE_WITH_PASSES_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod CanManoEnvidarRestrictedPhase(state As %DynamicObject, phase As %String, manoPlayerId As %String) As %Boolean
{
    Set hand = state.%Get("hand", "")
    If '$IsObject(hand) {
        Return 0
    }

    Set phaseState = hand.%Get("phaseState", "")
    If '$IsObject(phaseState) {
        Return 0
    }

    Set participants = phaseState.%Get("participants", "")
    If '$IsObject(participants) {
        Return 0
    }

    If '..ArrayContains(participants, manoPlayerId) {
        Return 0
    }

    Set manoTeam = ##class(Mus.Util.MusRules).GetPlayerTeam(state, manoPlayerId)
    If manoTeam = "" {
        Return 0
    }

    For i=0:1:participants.%Size()-1 {
        Set participantId = participants.%Get(i)
        Set participantTeam = ##class(Mus.Util.MusRules).GetPlayerTeam(state, participantId)

        If participantTeam '= "", participantTeam '= manoTeam {
            Return 1
        }
    }

    Return 0
}

ClassMethod RunManoEnvitesTest(amount As %Integer = 2) As %DynamicObject
{
    Set result = {
        "success": true,
        "gameId": null,
        "manoPlayerId": "",
        "events": [],
        "finalState": null,
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
        Set playersJson = {
            "players": [
                {
                    "id": "P1",
                    "name": "Player 1",
                    "team": "A"
                },
                {
                    "id": "P2",
                    "name": "Player 2",
                    "team": "B"
                },
                {
                    "id": "P3",
                    "name": "Player 3",
                    "team": "A"
                },
                {
                    "id": "P4",
                    "name": "Player 4",
                    "team": "B"
                }
            ]
        }

        Set createResp = ""
        Set sc = ..CreateGame(playersJson.%ToJSON(), .createResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "CREATE_GAME_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'createResp.Success {
            Return ..Fail(result, createResp.ErrorCode, createResp.ErrorMessage)
        }

        Set gameId = createResp.GameId
        Do result.%Set("gameId", gameId)
        Do ..AddEvent(result, "create_game", createResp.GameStateJson)

        Set startResp = ""
        Set sc = ..StartGame(gameId, .startResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "START_GAME_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'startResp.Success {
            Return ..Fail(result, startResp.ErrorCode, startResp.ErrorMessage)
        }

        Do ..AddEvent(result, "start_game", startResp.GameStateJson)

        Set discardsResp = ""
        Set sc = ..CloseDiscards(gameId, .discardsResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "CLOSE_DISCARDS_STATUS_ERROR", $System.Status.GetErrorText(sc))
        }

        If 'discardsResp.Success {
            Return ..Fail(result, discardsResp.ErrorCode, discardsResp.ErrorMessage)
        }

        Do ..AddEvent(result, "close_discards", discardsResp.GameStateJson)

        Set state = {}.%FromJSON(discardsResp.GameStateJson)
        Set manoPlayerId = ##class(Mus.Util.MusRules).GetInitialTurnPlayerIdForGameState(state)
        Do result.%Set("manoPlayerId", manoPlayerId)

        Set safetyCounter = 0

        While safetyCounter < 100 {
            Set safetyCounter = safetyCounter + 1

            Set stateResp = ""
            Set sc = ..GetGameState(gameId, .stateResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "GET_STATE_STATUS_ERROR", $System.Status.GetErrorText(sc))
            }

            If 'stateResp.Success {
                Return ..Fail(result, stateResp.ErrorCode, stateResp.ErrorMessage)
            }

            Set state = {}.%FromJSON(stateResp.GameStateJson)
            Set status = state.%Get("status", "")
            Set phase = state.%Get("phase", "")
            Set turnPlayerId = state.%Get("turnPlayerId", "")

            If status = "finished" {
                Do result.%Set("finalState", state)
                Return result
            }

            If phase = "manoCerrada" {
                Do result.%Set("finalState", state)
                Return result
            }

            If phase = "descartes" {
                Set discardsResp = ""
                Set sc = ..CloseDiscards(gameId, .discardsResp)
                If $$$ISERR(sc) {
                    Return ..Fail(result, "CLOSE_DISCARDS_IN_LOOP_STATUS_ERROR", $System.Status.GetErrorText(sc))
                }

                If 'discardsResp.Success {
                    Return ..Fail(result, discardsResp.ErrorCode, discardsResp.ErrorMessage)
                }

                Do ..AddEvent(result, "close_discards_in_loop", discardsResp.GameStateJson)
                Continue
            }

            If (phase = "grande") || (phase = "chica") {
                If turnPlayerId '= manoPlayerId {
                    Return ..Fail(result, "MANO_NOT_FIRST_IN_PHASE", "Expected mano player "_manoPlayerId_" to start phase "_phase_", but current turn is "_turnPlayerId)
                }

                Set playResult = ..PlayEnviteAndAccept(gameId, manoPlayerId, phase, amount, result)
                If 'playResult.%Get("success", 0) {
                    Return playResult
                }

                Continue
            }

            If (phase = "pares") || (phase = "juego") {
                If ..CanManoEnvidarRestrictedPhase(state, phase, manoPlayerId) {
                    If turnPlayerId '= manoPlayerId {
                        Return ..Fail(result, "MANO_NOT_FIRST_RESTRICTED_PHASE", "Expected mano player "_manoPlayerId_" to start phase "_phase_", but current turn is "_turnPlayerId)
                    }

                    Set playResult = ..PlayEnviteAndAccept(gameId, manoPlayerId, phase, amount, result)
                    If 'playResult.%Get("success", 0) {
                        Return playResult
                    }
                } Else {
                    Set playResult = ..PlayPhaseWithPasses(gameId, result)
                    If 'playResult.%Get("success", 0) {
                        Return playResult
                    }
                }

                Continue
            }

            If phase = "punto" {
                Set playResult = ..PlayPhaseWithPasses(gameId, result)
                If 'playResult.%Get("success", 0) {
                    Return playResult
                }

                Continue
            }

            Return ..Fail(result, "UNSUPPORTED_PHASE_IN_MANO_ENVITES_TEST", "Unsupported phase "_phase)
        }

        Return ..Fail(result, "MANO_ENVITES_SAFETY_LIMIT_REACHED", "Simulation did not finish after 100 iterations")
    }
    Catch ex {
        Return ..Fail(result, "RUN_MANO_ENVITES_TEST_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod ArrayContains(array As %DynamicArray, value As %String) As %Boolean
{
    For i=0:1:array.%Size()-1 {
        If array.%Get(i) = value {
            Return 1
        }
    }

    Return 0
}

ClassMethod Fail(result As %DynamicObject, errorCode As %String, errorMessage As %String) As %DynamicObject
{
    Do result.%Set("success", "false")
    Do result.%Set("errorCode", errorCode)
    Do result.%Set("errorMessage", errorMessage)

    Return result
}

}
