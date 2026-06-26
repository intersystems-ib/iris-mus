Class Mus.BO.PersistenceOperation Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Mus.Msg.CreateGameRequest">
    <Method>CreateGame</Method>
  </MapItem>

  <MapItem MessageType="Mus.Msg.StartGameRequest">
    <Method>StartGame</Method>
  </MapItem>

  <MapItem MessageType="Mus.Msg.StartNextHandRequest">
    <Method>StartNextHand</Method>
  </MapItem>

  <MapItem MessageType="Mus.Msg.GetGameStateRequest">
    <Method>GetGameState</Method>
  </MapItem>

  <MapItem MessageType="Mus.Msg.LoadGameStateRequest">
    <Method>LoadGameState</Method>
  </MapItem>

  <MapItem MessageType="Mus.Msg.PlayerActionRequest">
    <Method>SavePlayerAction</Method>
  </MapItem>

  <MapItem MessageType="Mus.Msg.ApplyDiscardsRequest">
    <Method>ApplyDiscards</Method>
  </MapItem>
  
  <MapItem MessageType="Mus.Msg.PersistResolvedActionRequest">
    <Method>PersistResolvedAction</Method>
  </MapItem>
</MapItems>
}

Method CreateGame(pRequest As Mus.Msg.CreateGameRequest, Output pResponse As Mus.Msg.CreateGameResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.CreateGameResponse).%New()

    Try {
        Set game = ##class(Mus.Data.Game).%New()
        Set game.Status = "created"
        Set game.CreatedAt = $ZDATETIME($HOROLOG, 3)
        Set game.UpdatedAt = game.CreatedAt
        Set game.ScoreTeamA = 0
        Set game.ScoreTeamB = 0
        Set game.TurnPlayerId = ""

        Set state = {
            "status": "created",
            "targetScore": 40,
            "winnerTeam": "",
            "nextAction": "",
            "score": {
                "teamA": 0,
                "teamB": 0
            },
            "players": []
        }

        If pRequest.PlayersJson '= "" {
            Set body = {}.%FromJSON(pRequest.PlayersJson)
            Set players = body.%Get("players", "")
            If $IsObject(players) {
                Do state.%Set("players", ##class(Mus.Agent.PlayerProfile).ApplyDeclaredProfilesToPlayers(players))
                // Metadatos opcionales usados por la UI para mostrar nombres reales
                // de equipos en el resumen de mano, especialmente en torneos.
                Set teamNames = body.%Get("teamNames", "")
                If $IsObject(teamNames) {
                    Do state.%Set("teamNames", teamNames)
                }

                Set teams = body.%Get("teams", "")
                If $IsObject(teams) {
                    Do state.%Set("teams", teams)
                }

                Set tournamentInfo = body.%Get("tournament", "")
                If $IsObject(tournamentInfo) {
                    Do state.%Set("tournament", tournamentInfo)
                }
            } Else {
                Do state.%Set("players", ##class(Mus.Agent.PlayerProfile).ApplyDeclaredProfilesToPlayers(body))
            }
        }

        If $IsObject(state.%Get("players", "")) {
            Do state.%Set("players", ##class(Mus.Agent.PlayerProfile).ApplyDeclaredProfilesToPlayers(state.%Get("players")))
        }

        Set game.StateJson = state.%ToJSON()

        Set sc = game.%Save()
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_GAME_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set state.gameId = game.%Id()

        Set game.StateJson = state.%ToJSON()
        Set game.UpdatedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = game.%Save()
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_GAME_STATE_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 201
        Set pResponse.GameId = game.%Id()
        Set pResponse.GameStateJson = game.StateJson

        Return $$$OK
    }
    Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "CREATE_GAME_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method StartGame(pRequest As Mus.Msg.StartGameRequest, Output pResponse As Mus.Msg.StartGameResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.StartGameResponse).%New()

    Try {
        Set game = ##class(Mus.Data.Game).%OpenId(pRequest.GameId)

        If '$IsObject(game) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "GAME_NOT_FOUND"
            Set pResponse.ErrorMessage = "Game not found"
            Return $$$OK
        }

        Set gameState = {}.%FromJSON(game.StateJson)

        If gameState.%Get("status", "") = "finished" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "GAME_ALREADY_FINISHED"
            Set pResponse.ErrorMessage = "The game is already finished"
            Set pResponse.GameId = game.%Id()
            Set pResponse.GameStateJson = game.StateJson
            Return $$$OK
        }

        If game.CurrentHandId '= "" {
            Set existingHandState = gameState.%Get("hand", "")

            If $IsObject(existingHandState) {
                If existingHandState.%Get("phase", "") '= "manoCerrada", existingHandState.%Get("status", "") '= "closed" {
                    Set pResponse.Success = 0
                    Set pResponse.StatusCode = 409
                    Set pResponse.ErrorCode = "GAME_ALREADY_STARTED"
                    Set pResponse.ErrorMessage = "Game already has an active hand"
                    Set pResponse.GameId = game.%Id()
                    Set pResponse.GameStateJson = game.StateJson
                    Return $$$OK
                }
            }
        }

        Set handNumber = 1
        Set dealerPlayerId = "P4"

        Set hand = ##class(Mus.Data.Hand).%New()
        Set hand.GameId = game.%Id()
        Set hand.HandNumber = handNumber
        Set hand.Status = "started"
        Set hand.DealerPlayerId = dealerPlayerId
        Set hand.TurnPlayerId = ""
        Set hand.CreatedAt = $ZDATETIME($HOROLOG, 3)
        Set hand.UpdatedAt = hand.CreatedAt

        Set deckInfo = ##class(Mus.Util.Deck).DealFourPlayersWithRemainingDeck()
        Set cards = deckInfo.%Get("cards")
        Set remainingDeck = deckInfo.%Get("remainingDeck")

        Set hand.CardsJson = cards.%ToJSON()

        /*
          La mano empieza en descartes.
          Los descartes son opcionales y repetibles.
          La fase solo pasa a grande cuando todos descartan 0 cartas
          o cuando GameCoordinator normaliza una primera accion de grande.
        */

        Set handState = {
            "status": "started",
            "handNumber": (handNumber),
            "dealerPlayerId": (dealerPlayerId),
            "manoPlayerId": (dealerPlayerId),
            "handPlayerId": (dealerPlayerId),
            "startPlayerId": (dealerPlayerId),
            "initialTurnPlayerId": (dealerPlayerId),
            "phase": "descartes",
            "turnPlayerId": "",
            "pendingBet": null,
            "lastAggressorPlayerId": null,
            "cards": (cards),
            "remainingDeck": (remainingDeck),
            "discardRound": 0,
            "discardsClosed": false,
            "discardsApplied": false,
            "actions": []
        }

        Set hand.StateJson = handState.%ToJSON()

        Set sc = hand.%Save()
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_HAND_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set game.Status = "started"
        Set game.CurrentHandId = hand.%Id()
        Set game.TurnPlayerId = ""
        Set game.UpdatedAt = $ZDATETIME($HOROLOG, 3)

        Do gameState.%Set("status", "started")
        Do gameState.%Set("targetScore", +gameState.%Get("targetScore", 40))
        Do gameState.%Set("winnerTeam", "")
        Do gameState.%Set("nextAction", "")
        Do gameState.%Set("currentHandId", hand.%Id())
        Do gameState.%Set("handNumber", handNumber)
        Do gameState.%Set("dealerPlayerId", dealerPlayerId)
        Do gameState.%Set("manoPlayerId", dealerPlayerId)
        Do gameState.%Set("handPlayerId", dealerPlayerId)
        Do gameState.%Set("startPlayerId", dealerPlayerId)
        Do gameState.%Set("initialTurnPlayerId", dealerPlayerId)
        Do gameState.%Set("phase", "descartes")
        Do gameState.%Set("turnPlayerId", "")
        Do gameState.%Set("discardRound", 0)
        Do gameState.%Set("discardsClosed", 0)
        Do gameState.%Set("hand", handState)

        Set game.StateJson = gameState.%ToJSON()

        Set sc = game.%Save()
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_GAME_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = game.%Id()
        Set pResponse.HandId = hand.%Id()
        Set pResponse.GameStateJson = game.StateJson

        Return $$$OK
    }
    Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "START_GAME_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method StartNextHand(pRequest As Mus.Msg.StartNextHandRequest, Output pResponse As Mus.Msg.StartNextHandResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.StartNextHandResponse).%New()

    Try {
        Set game = ##class(Mus.Data.Game).%OpenId(pRequest.GameId)

        If '$IsObject(game) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "GAME_NOT_FOUND"
            Set pResponse.ErrorMessage = "Game not found"
            Return $$$OK
        }

        Set gameState = {}.%FromJSON(game.StateJson)

        If gameState.%Get("status", "") = "finished" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "GAME_ALREADY_FINISHED"
            Set pResponse.ErrorMessage = "The game is already finished"
            Set pResponse.GameId = game.%Id()
            Set pResponse.GameStateJson = game.StateJson
            Return $$$OK
        }

        Set currentHandState = gameState.%Get("hand", "")

        If $IsObject(currentHandState) {
            Set currentPhase = currentHandState.%Get("phase", "")
            Set currentStatus = currentHandState.%Get("status", "")

            If currentPhase '= "manoCerrada", currentStatus '= "closed" {
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "CURRENT_HAND_NOT_CLOSED"
                Set pResponse.ErrorMessage = "Current hand is not closed"
                Set pResponse.GameId = game.%Id()
                Set pResponse.GameStateJson = game.StateJson
                Return $$$OK
            }
        }

        If ##class(Mus.Util.MusRules).IsGameFinished(gameState) {
            Set winningTeam = ##class(Mus.Util.MusRules).GetWinningTeam(gameState)
            Set gameState = ##class(Mus.Util.MusRules).FinishGameForTeam(gameState, winningTeam)

            Set game.StateJson = gameState.%ToJSON()
            Set game.Status = "finished"
            Set game.TurnPlayerId = ""
            Set game.UpdatedAt = $ZDATETIME($HOROLOG, 3)

            Set sc = game.%Save()
            If $$$ISERR(sc) {
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 500
                Set pResponse.ErrorCode = "SAVE_GAME_ERROR"
                Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
                Return sc
            }

            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "GAME_ALREADY_FINISHED"
            Set pResponse.ErrorMessage = "The game has reached target score"
            Set pResponse.GameId = game.%Id()
            Set pResponse.GameStateJson = game.StateJson
            Return $$$OK
        }

        Set currentHandState = gameState.%Get("hand", "")
        If $IsObject(currentHandState) {
            Set sc = ..EnsureHandScoreHistory(.gameState, .currentHandState)
            If $$$ISERR(sc) {
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 500
                Set pResponse.ErrorCode = "HAND_SCORE_HISTORY_ERROR"
                Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
                Return sc
            }
        }

        Set sc = ..RebuildHandScoreHistoryFromPersistedHands(game.%Id(), .gameState)
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "HAND_SCORE_HISTORY_REBUILD_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set previousHandNumber = +gameState.%Get("handNumber", 0)
        Set nextHandNumber = previousHandNumber + 1

        If nextHandNumber <= 1 {
            Set nextHandNumber = 2
        }

        Set previousDealerPlayerId = gameState.%Get("dealerPlayerId", "")
        Set dealerPlayerId = ##class(Mus.Util.MusRules).GetNextDealerPlayerId(previousDealerPlayerId)

        Set deckInfo = ##class(Mus.Util.Deck).DealFourPlayersWithRemainingDeck()
        Set cards = deckInfo.%Get("cards")
        Set remainingDeck = deckInfo.%Get("remainingDeck")

        Set now = $ZDATETIME($HOROLOG, 3)

        Set hand = ##class(Mus.Data.Hand).%New()
        Set hand.GameId = game.%Id()
        Set hand.HandNumber = nextHandNumber
        Set hand.Status = "started"
        Set hand.DealerPlayerId = dealerPlayerId
        Set hand.TurnPlayerId = ""
        Set hand.CreatedAt = now
        Set hand.UpdatedAt = now
        Set hand.CardsJson = cards.%ToJSON()

        Set handState = {
            "status": "started",
            "handNumber": (nextHandNumber),
            "dealerPlayerId": (dealerPlayerId),
            "manoPlayerId": (dealerPlayerId),
            "handPlayerId": (dealerPlayerId),
            "startPlayerId": (dealerPlayerId),
            "initialTurnPlayerId": (dealerPlayerId),
            "phase": "descartes",
            "turnPlayerId": "",
            "pendingBet": null,
            "lastAggressorPlayerId": null,
            "cards": (cards),
            "remainingDeck": (remainingDeck),
            "discardRound": 0,
            "discardsClosed": false,
            "discardsApplied": false,
            "actions": []
        }

        Set hand.StateJson = handState.%ToJSON()

        TSTART

        Set sc = hand.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_HAND_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set game.Status = "started"
        Set game.CurrentHandId = hand.%Id()
        Set game.TurnPlayerId = ""
        Set game.UpdatedAt = now

        Do gameState.%Set("status", "started")
        Do gameState.%Set("phase", "descartes")
        Do gameState.%Set("turnPlayerId", "")
        Do gameState.%Set("currentHandId", hand.%Id())
        Do gameState.%Set("handNumber", nextHandNumber)
        Do gameState.%Set("dealerPlayerId", dealerPlayerId)
        Do gameState.%Set("manoPlayerId", dealerPlayerId)
        Do gameState.%Set("handPlayerId", dealerPlayerId)
        Do gameState.%Set("startPlayerId", dealerPlayerId)
        Do gameState.%Set("initialTurnPlayerId", dealerPlayerId)
        Do gameState.%Set("discardRound", 0)
        Do gameState.%Set("discardsClosed", 0)
        Do gameState.%Set("nextAction", "")
        Do gameState.%Set("hand", handState)

        Set game.StateJson = gameState.%ToJSON()

        Set sc = game.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_GAME_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        TCOMMIT

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = game.%Id()
        Set pResponse.HandId = hand.%Id()
        Set pResponse.GameStateJson = game.StateJson

        Return $$$OK
    }
    Catch ex {
        If $TLEVEL {
            TROLLBACK
        }

        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "START_NEXT_HAND_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method GetGameState(pRequest As Mus.Msg.GetGameStateRequest, Output pResponse As Mus.Msg.GetGameStateResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.GetGameStateResponse).%New()

    Try {
        Set game = ##class(Mus.Data.Game).%OpenId(pRequest.GameId)

        If '$IsObject(game) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "GAME_NOT_FOUND"
            Set pResponse.ErrorMessage = "Game not found"
            Return $$$OK
        }

        Set gameState = {}.%FromJSON(game.StateJson)

        Set sc = ..RebuildHandScoreHistoryFromPersistedHands(game.%Id(), .gameState)
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "HAND_SCORE_HISTORY_REBUILD_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set handState = gameState.%Get("hand", "")
        If $IsObject(handState) {
            Set sc = ..EnsureHandScoreHistory(.gameState, .handState)
            If $$$ISERR(sc) {
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 500
                Set pResponse.ErrorCode = "HAND_SCORE_HISTORY_ERROR"
                Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
                Return sc
            }
        }

        Set game.StateJson = gameState.%ToJSON()
        Set game.UpdatedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = game.%Save()
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_GAME_STATE_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = game.%Id()
        Set pResponse.GameStateJson = game.StateJson
        Return $$$OK
    } Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "GET_STATE_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method LoadGameState(pRequest As Mus.Msg.LoadGameStateRequest, Output pResponse As Mus.Msg.LoadGameStateResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.LoadGameStateResponse).%New()

    Try {
        Set game = ##class(Mus.Data.Game).%OpenId(pRequest.GameId)

        If '$IsObject(game) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "GAME_NOT_FOUND"
            Set pResponse.ErrorMessage = "Game not found"
            Return $$$OK
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = game.%Id()
        Set pResponse.GameStateJson = game.StateJson

        Return $$$OK
    }
    Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "LOAD_STATE_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method SavePlayerAction(pRequest As Mus.Msg.PlayerActionRequest, Output pResponse As Mus.Msg.PlayerActionResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New()

    Try {
        Set game = ##class(Mus.Data.Game).%OpenId(pRequest.GameId)

        If '$IsObject(game) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "GAME_NOT_FOUND"
            Set pResponse.ErrorMessage = "Game not found"
            Return $$$OK
        }

        Set action = ##class(Mus.Data.Action).%New()
        Set action.GameId = game.%Id()
        Set action.HandId = game.CurrentHandId
        Set action.PlayerId = pRequest.PlayerId
        Set action.ActionType = pRequest.ActionType
        Set action.Phase = pRequest.Phase
        Set action.Amount = pRequest.Amount
        Set action.PayloadJson = pRequest.PayloadJson
        Set action.CorrelationId = pRequest.CorrelationId
        Set action.CreatedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = action.%Save()
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_ACTION_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set state = {}.%FromJSON(game.StateJson)
        Set hand = state.%Get("hand", "")

        If $IsObject(hand) {
            If '$IsObject(hand.%Get("actions", "")) {
                Do hand.%Set("actions", [])
            }

            Set actions = hand.%Get("actions")
        } Else {
            If '$IsObject(state.%Get("actions", "")) {
                Do state.%Set("actions", [])
            }

            Set actions = state.%Get("actions")
        }

        Set actionJson = {
            "id": (action.%Id()),
            "playerId": (pRequest.PlayerId),
            "type": (pRequest.ActionType),
            "phase": (pRequest.Phase),
            "amount": (pRequest.Amount),
            "createdAt": (action.CreatedAt)
        }

        If pRequest.PayloadJson '= "" {
            Try {
                Set actionJson.payload = {}.%FromJSON(pRequest.PayloadJson)
            }
            Catch exPayload {
                Set actionJson.payloadRaw = pRequest.PayloadJson
            }
        } Else {
            Set actionJson.payload = {}
        }

        Do actions.%Push(actionJson)

        If $IsObject(hand) {
            Do hand.%Set("actions", actions)
            Do state.%Set("hand", hand)
        } Else {
            Do state.%Set("actions", actions)
        }

        Set game.StateJson = state.%ToJSON()
        Set game.UpdatedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = game.%Save()
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_GAME_STATE_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = game.%Id()
        Set pResponse.GameStateJson = game.StateJson

        Return $$$OK
    }
    Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "SAVE_ACTION_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method ApplyDiscards(pRequest As Mus.Msg.ApplyDiscardsRequest, Output pResponse As Mus.Msg.ApplyDiscardsResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.ApplyDiscardsResponse).%New()

    Try {
        Set game = ##class(Mus.Data.Game).%OpenId(pRequest.GameId)

        If '$IsObject(game) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "GAME_NOT_FOUND"
            Set pResponse.ErrorMessage = "Game not found"
            Return $$$OK
        }

        Set gameState = {}.%FromJSON(game.StateJson)

        If gameState.%Get("status", "") = "finished" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "GAME_ALREADY_FINISHED"
            Set pResponse.ErrorMessage = "The game is already finished"
            Set pResponse.GameId = game.%Id()
            Set pResponse.GameStateJson = game.StateJson
            Return $$$OK
        }

        If game.CurrentHandId = "" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "NO_ACTIVE_HAND"
            Set pResponse.ErrorMessage = "No active hand"
            Return $$$OK
        }

        Set hand = ##class(Mus.Data.Hand).%OpenId(game.CurrentHandId)

        If '$IsObject(hand) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "HAND_NOT_FOUND"
            Set pResponse.ErrorMessage = "Current hand not found"
            Return $$$OK
        }

        Set handState = gameState.%Get("hand", "")

        If '$IsObject(handState) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "HAND_STATE_NOT_FOUND"
            Set pResponse.ErrorMessage = "Hand state not found"
            Return $$$OK
        }

        Set phase = handState.%Get("phase", "")

        If phase '= "descartes" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "INVALID_PHASE"
            Set pResponse.ErrorMessage = "Discards can only be applied during descartes phase"
            Return $$$OK
        }

        Set discardsClosed = +handState.%Get("discardsClosed", 0)

        If discardsClosed {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "DISCARDS_CLOSED"
            Set pResponse.ErrorMessage = "Discards are already closed for this hand"
            Return $$$OK
        }

        Set discardRound = +handState.%Get("discardRound", 0)

        Try {
            Set discards = {}.%FromJSON(pRequest.DiscardsJson)
        }
        Catch exDiscards {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "INVALID_DISCARDS_JSON"
            Set pResponse.ErrorMessage = exDiscards.DisplayString()
            Return $$$OK
        }

        Set cards = handState.%Get("cards", "")
        Set remainingDeck = handState.%Get("remainingDeck", "")

        If '$IsObject(cards) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "CARDS_NOT_FOUND"
            Set pResponse.ErrorMessage = "Cards were not found in hand state"
            Return $$$OK
        }

        If '$IsObject(remainingDeck) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "REMAINING_DECK_NOT_FOUND"
            Set pResponse.ErrorMessage = "Remaining deck was not found in hand state"
            Return $$$OK
        }

        Set players = ["P1", "P2", "P3", "P4"]
        Set totalDiscarded = 0

        For i=0:1:players.%Size()-1 {
            Set playerId = players.%Get(i)
            Set playerDiscards = discards.%Get(playerId, "")

            If '$IsObject(playerDiscards) {
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 400
                Set pResponse.ErrorCode = "MISSING_PLAYER_DISCARDS"
                Set pResponse.ErrorMessage = "Missing discards for player "_playerId
                Return $$$OK
            }

            Set totalDiscarded = totalDiscarded + playerDiscards.%Size()

            Set playerCards = cards.%Get(playerId, "")

            If '$IsObject(playerCards) {
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 409
                Set pResponse.ErrorCode = "PLAYER_CARDS_NOT_FOUND"
                Set pResponse.ErrorMessage = "Cards not found for player "_playerId
                Return $$$OK
            }

            Set validationError = ..ValidatePlayerDiscards(playerId, playerCards, playerDiscards)

            If validationError '= "" {
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 400
                Set pResponse.ErrorCode = "INVALID_DISCARDS"
                Set pResponse.ErrorMessage = validationError
                Return $$$OK
            }
        }

        For i=0:1:players.%Size()-1 {
            Set playerId = players.%Get(i)
            Set playerCards = cards.%Get(playerId)
            Set playerDiscards = discards.%Get(playerId)

            Set sc = ..ApplyPlayerDiscards(.playerCards, playerDiscards, .remainingDeck)
            If $$$ISERR(sc) {
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 500
                Set pResponse.ErrorCode = "APPLY_PLAYER_DISCARDS_ERROR"
                Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
                Return sc
            }

            Do cards.%Set(playerId, playerCards)
        }

        Set now = $ZDATETIME($HOROLOG, 3)
        Set discardRound = discardRound + 1

        Set discardAction = {
            "type": "descartes",
            "phase": "descartes",
            "playerId": "ALL",
            "round": (discardRound),
            "totalDiscarded": (totalDiscarded),
            "discards": (discards),
            "createdAt": (now)
        }

        If '$IsObject(handState.%Get("actions", "")) {
            Set handState.actions = []
        }

        Do handState.actions.%Push(discardAction)

        Set handState.cards = cards
        Set handState.remainingDeck = remainingDeck
        Set handState.discardRound = discardRound

        If totalDiscarded > 0 {
            Set handState.discardsApplied = 1
        }

        If totalDiscarded = 0 {
            Set initialTurnPlayerId = ##class(Mus.Util.MusRules).GetInitialTurnPlayerIdForGameState(gameState)
            Set phaseState = ##class(Mus.Util.MusRules).BuildInitialPhaseState("grande")

            Set handState.phase = "grande"
            Set handState.turnPlayerId = initialTurnPlayerId
            Set handState.discardsClosed = 1
            Set handState.phaseState = phaseState

            Set gameState.phase = "grande"
            Set gameState.turnPlayerId = initialTurnPlayerId
            Set gameState.discardsClosed = 1

            Set hand.Status = "playing"
            Set hand.TurnPlayerId = initialTurnPlayerId
            Set game.TurnPlayerId = initialTurnPlayerId
        } Else {
            Set handState.phase = "descartes"
            Set handState.turnPlayerId = ""
            Set handState.discardsClosed = 0

            Set gameState.phase = "descartes"
            Set gameState.turnPlayerId = ""
            Set gameState.discardsClosed = 0

            Set hand.Status = "discarding"
            Set hand.TurnPlayerId = ""
            Set game.TurnPlayerId = ""
        }

        Set gameState.discardRound = discardRound
        Set gameState.hand = handState

        Set hand.CardsJson = cards.%ToJSON()
        Set hand.StateJson = handState.%ToJSON()
        Set hand.UpdatedAt = now

        Set game.StateJson = gameState.%ToJSON()
        Set game.UpdatedAt = now

        TSTART

        Set sc = hand.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_HAND_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set sc = game.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_GAME_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set action = ##class(Mus.Data.Action).%New()
        Set action.GameId = game.%Id()
        Set action.HandId = hand.%Id()
        Set action.PlayerId = "ALL"
        Set action.ActionType = "descartes"
        Set action.Phase = "descartes"
        Set action.Amount = totalDiscarded
        Set action.PayloadJson = discardAction.%ToJSON()
        Set action.CorrelationId = pRequest.CorrelationId
        Set action.CreatedAt = now

        Set sc = action.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_ACTION_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        TCOMMIT

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = game.%Id()
        Set pResponse.GameStateJson = game.StateJson

        Return $$$OK
    }
    Catch ex {
        If $TLEVEL {
            TROLLBACK
        }

        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "APPLY_DISCARDS_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Method ValidatePlayerDiscards(playerId As %String, playerCards As %DynamicArray, playerDiscards As %DynamicArray) As %String
{
    If playerDiscards.%Size() > 4 {
        Return "Player "_playerId_" cannot discard more than 4 cards"
    }

    For i=0:1:playerDiscards.%Size()-1 {
        Set card = playerDiscards.%Get(i)

        If '..ArrayContains(playerCards, card) {
            Return "Player "_playerId_" cannot discard card "_card_" because it is not in hand"
        }

        If ..ArrayCount(playerDiscards, card) > 1 {
            Return "Player "_playerId_" discarded duplicated card "_card
        }
    }

    Return ""
}

Method ApplyPlayerDiscards(ByRef playerCards As %DynamicArray, playerDiscards As %DynamicArray, ByRef remainingDeck As %DynamicArray) As %Status
{
    For i=0:1:playerDiscards.%Size()-1 {
        Set card = playerDiscards.%Get(i)

        Set sc = ..RemoveCard(.playerCards, card)
        If $$$ISERR(sc) {
            Return sc
        }

        If remainingDeck.%Size() = 0 {
            Return $$$ERROR($$$GeneralError, "Remaining deck is empty")
        }

        Set newCard = remainingDeck.%Get(0)
        Do remainingDeck.%Remove(0)
        Do playerCards.%Push(newCard)
    }

    Return $$$OK
}

Method RemoveCard(ByRef cards As %DynamicArray, card As %String) As %Status
{
    For i=0:1:cards.%Size()-1 {
        If cards.%Get(i) = card {
            Do cards.%Remove(i)
            Return $$$OK
        }
    }

    Return $$$ERROR($$$GeneralError, "Card not found: "_card)
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

Method ArrayCount(array As %DynamicArray, value As %String) As %Integer
{
    Set count = 0

    For i=0:1:array.%Size()-1 {
        If array.%Get(i) = value {
            Set count = count + 1
        }
    }

    Return count
}

Method PersistResolvedAction(pRequest As Mus.Msg.PersistResolvedActionRequest, Output pResponse As Mus.Msg.PlayerActionResponse) As %Status
{
 
    Set pResponse = ##class(Mus.Msg.PlayerActionResponse).%New() 
    
    Try { 
        Set game = ##class(Mus.Data.Game).%OpenId(pRequest.GameId)

        If '$IsObject(game) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "GAME_NOT_FOUND"
            Set pResponse.ErrorMessage = "Game not found"
            Return $$$OK
        }

        Set gameState = {}.%FromJSON(pRequest.UpdatedGameStateJson)
        Set handState = gameState.%Get("hand", "")

        If '$IsObject(handState) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "HAND_STATE_NOT_FOUND"
            Set pResponse.ErrorMessage = "Updated hand state not found"
            Return $$$OK
        }

        Set actionEvent = {}.%FromJSON(pRequest.ActionEventJson)

        If '$IsObject(handState.%Get("actions", "")) {
            Do handState.%Set("actions", [])
        }

        Do handState.%Get("actions").%Push(actionEvent)
        Do gameState.%Set("hand", handState)

        Set sc = ..EnsureHandScoreHistory(.gameState, .handState)
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "HAND_SCORE_HISTORY_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        If ##class(Mus.Util.MusRules).IsGameFinished(gameState) {
            Set winningTeam = ##class(Mus.Util.MusRules).GetWinningTeam(gameState)

            If (winningTeam = "A") || (winningTeam = "B") {
                Set gameState = ##class(Mus.Util.MusRules).FinishGameForTeam(gameState, winningTeam)
                Set handState = gameState.%Get("hand", handState)
            }
        }

        Set sc = ..EnsureHandScoreHistory(.gameState, .handState)
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "HAND_SCORE_HISTORY_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        Set now = $ZDATETIME($HOROLOG, 3) 
        Set game.StateJson = gameState.%ToJSON()
        Set game.TurnPlayerId = gameState.%Get("turnPlayerId", "")
        Set game.Status = gameState.%Get("status", game.Status)
        Set game.ScoreTeamA = +gameState.%Get("score").%Get("teamA", 0)
        Set game.ScoreTeamB = +gameState.%Get("score").%Get("teamB", 0)
        Set game.UpdatedAt = now

        Set hand = ##class(Mus.Data.Hand).%OpenId(game.CurrentHandId)

        If $IsObject(hand) {
            Set hand.StateJson = handState.%ToJSON()

            If $IsObject(handState.%Get("cards", "")) {
                Set hand.CardsJson = handState.%Get("cards").%ToJSON()
            }

            Set hand.TurnPlayerId = handState.%Get("turnPlayerId", "")
            Set hand.Status = handState.%Get("status", "playing")
            Set hand.UpdatedAt = now
        }

        TSTART

        Set sc = game.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_GAME_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        If $IsObject(hand) {
            Set sc = hand.%Save()
            If $$$ISERR(sc) {
                TROLLBACK
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 500
                Set pResponse.ErrorCode = "SAVE_HAND_ERROR"
                Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
                Return sc
            }
        }

        Set action = ##class(Mus.Data.Action).%New()
        Set action.GameId = game.%Id()
        Set action.HandId = game.CurrentHandId
        Set action.PlayerId = pRequest.PlayerId
        Set action.ActionType = pRequest.ActionType
        Set action.Phase = pRequest.Phase
        Set action.Amount = pRequest.Amount
        Set action.PayloadJson = pRequest.ActionEventJson
        Set action.CorrelationId = pRequest.CorrelationId
        Set action.CreatedAt = now

        Set sc = action.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "SAVE_ACTION_ERROR"
            Set pResponse.ErrorMessage = $System.Status.GetErrorText(sc)
            Return sc
        }

        TCOMMIT

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = game.%Id()
        Set pResponse.GameStateJson = game.StateJson
        Set pResponse.NextPlayerId = game.TurnPlayerId

        Return $$$OK
    }
    Catch ex {
        If $TLEVEL {
            TROLLBACK
        }

        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "PERSIST_RESOLVED_ACTION_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

ClassMethod RebuildHandScoreHistoryFromPersistedHands(gameId As %String, ByRef gameState As %DynamicObject) As %Status
{
    If '$IsObject(gameState) {
        Quit $$$OK
    }

    Set history = []
    Set runningTeamA = 0
    Set runningTeamB = 0

    Set statement = ##class(%SQL.Statement).%New()
    Set sc = statement.%Prepare("SELECT ID, HandNumber, StateJson FROM Mus_Data.Hand WHERE GameId = ? ORDER BY HandNumber")

    If $$$ISERR(sc) {
        // Si la proyección SQL cambia de nombre, no debe romper /state.
        // En ese caso, se conserva el histórico ya presente en gameState.
        Quit $$$OK
    }

    Set result = statement.%Execute(gameId)

    While result.%Next() {
        Set handId = result.%Get("ID")
        Set handNumber = +result.%Get("HandNumber")
        Set stateJson = result.%Get("StateJson")

        If stateJson = "" {
            Continue
        }

        Try {
            Set persistedHandState = {}.%FromJSON(stateJson)
        } Catch exHandJson {
            Continue
        }

        If '..IsClosedHandForScoreHistory(gameState, persistedHandState) {
            Continue
        }

        Set delta = ..CalculateHandScoreDeltaFromHandState(persistedHandState)
        Set handTeamA = +delta.%Get("A", 0)
        Set handTeamB = +delta.%Get("B", 0)

        Set runningTeamA = runningTeamA + handTeamA
        Set runningTeamB = runningTeamB + handTeamB

        Set entry = ..BuildHandScoreHistoryEntry(persistedHandState, handId, handNumber, handTeamA, handTeamB, runningTeamA, runningTeamB)
        Do history.%Push(entry)
    }

    If history.%Size() > 0 {
        Do gameState.%Set("handHistory", history)
    }

    Do gameState.%Remove("completedHands")
    Do gameState.%Remove("handResults")

    Quit $$$OK
}

ClassMethod CalculateHandScoreDeltaFromHandState(handState As %DynamicObject) As %DynamicObject
{
    Set totals = {"A": 0, "B": 0}

    If '$IsObject(handState) {
        Quit totals
    }

    Set details = ..BuildHandScoreHistoryDetails(handState)
    Do totals.%Set("A", +details.%Get("teamA", 0))
    Do totals.%Set("B", +details.%Get("teamB", 0))

    Quit totals
}

ClassMethod AddAwardedPointsFromActions(ByRef totals As %DynamicObject, actions As %DynamicArray) As %Status
{
    If '$IsObject(actions) {
        Quit $$$OK
    }

    For i=0:1:actions.%Size()-1 {
        Set action = actions.%Get(i)

        If '$IsObject(action) {
            Continue
        }

        Set type = $ZCONVERT(action.%Get("type", action.%Get("actionType", "")), "L")

        If (type = "fase_auto_resuelta") || (type = "fase_saltada") || (type = "valores_cartas_liquidados") {
            Continue
        }

        If action.%Get("pointsAwarded", "") = "" {
            Continue
        }

        Set team = $ZCONVERT(action.%Get("winnerTeam", ""), "U")
        Set points = +action.%Get("pointsAwarded", 0)

        If (team = "A" || team = "B") && points > 0 {
            Do ..AddTeamPoints(.totals, team, points)
        }
    }

    Quit $$$OK
}

ClassMethod AddSettledPoints(ByRef totals As %DynamicObject, settledPoints As %DynamicArray) As %Status
{
    If '$IsObject(settledPoints) {
        Quit $$$OK
    }

    For i=0:1:settledPoints.%Size()-1 {
        Set event = settledPoints.%Get(i)

        If '$IsObject(event) {
            Continue
        }

        Set type = $ZCONVERT(event.%Get("type", event.%Get("actionType", "")), "L")

        If type = "valores_cartas_liquidados" {
            Do ..AddCardValuePointsFromEvent(.totals, event)
            Continue
        }

        Set team = $ZCONVERT(event.%Get("team", event.%Get("winnerTeam", "")), "U")
        Set points = +event.%Get("points", event.%Get("pointsAwarded", event.%Get("amount", event.%Get("value", 0))))

        If (team = "A" || team = "B") && points > 0 {
            Do ..AddTeamPoints(.totals, team, points)
        }
    }

    Quit $$$OK
}

ClassMethod AddCardValuePointsFromActions(ByRef totals As %DynamicObject, actions As %DynamicArray) As %Status
{
    If '$IsObject(actions) {
        Quit $$$OK
    }

    For i=0:1:actions.%Size()-1 {
        Set action = actions.%Get(i)

        If '$IsObject(action) {
            Continue
        }

        Set type = $ZCONVERT(action.%Get("type", action.%Get("actionType", "")), "L")

        If type = "valores_cartas_liquidados" {
            Do ..AddCardValuePointsFromEvent(.totals, action)
        }
    }

    Quit $$$OK
}

ClassMethod AddCardValuePointsFromEvent(ByRef totals As %DynamicObject, event As %DynamicObject) As %Status
{
    If '$IsObject(event) {
        Quit $$$OK
    }

    Set addedFromBreakdown = 0
    Set breakdown = event.%Get("breakdown", "")

    If $IsObject(breakdown) {
        For j=0:1:breakdown.%Size()-1 {
            Set item = breakdown.%Get(j)

            If '$IsObject(item) {
                Continue
            }

            Set itemTeam = $ZCONVERT(item.%Get("team", ""), "U")
            Set itemPoints = +item.%Get("points", 0)

            If (itemTeam = "A" || itemTeam = "B") && itemPoints > 0 {
                Do ..AddTeamPoints(.totals, itemTeam, itemPoints)
                Set addedFromBreakdown = 1
            }
        }
    }

    If addedFromBreakdown {
        Quit $$$OK
    }

    Set team = $ZCONVERT(event.%Get("team", event.%Get("winnerTeam", "")), "U")
    Set points = +event.%Get("points", event.%Get("amount", event.%Get("value", 0)))

    If (team = "A" || team = "B") && points > 0 {
        Do ..AddTeamPoints(.totals, team, points)
    }

    Quit $$$OK
}

ClassMethod AddPointsFromCompletedPhases(ByRef totals As %DynamicObject, completedPhases As %DynamicObject) As %Status
{
    If '$IsObject(completedPhases) {
        Quit $$$OK
    }

    Set phaseNames = ["grande", "chica", "pares", "juego", "punto"]

    For i=0:1:phaseNames.%Size()-1 {
        Set phaseName = phaseNames.%Get(i)
        Set phaseState = completedPhases.%Get(phaseName, "")

        If '$IsObject(phaseState) {
            Continue
        }

        Set winnerTeam = $ZCONVERT(phaseState.%Get("winnerTeam", ""), "U")
        Set pointsAwarded = +phaseState.%Get("pointsAwarded", 0)

        If (winnerTeam = "A" || winnerTeam = "B") && pointsAwarded > 0 {
            Do ..AddTeamPoints(.totals, winnerTeam, pointsAwarded)
        }

        Set teamCountPoints = phaseState.%Get("teamCountPoints", "")
        If $IsObject(teamCountPoints) {
            Do ..AddTeamPoints(.totals, "A", +teamCountPoints.%Get("A", 0))
            Do ..AddTeamPoints(.totals, "B", +teamCountPoints.%Get("B", 0))
        }
    }

    Quit $$$OK
}

ClassMethod AddTeamPoints(ByRef totals As %DynamicObject, team As %String, points As %Integer) As %Status
{
    Set team = $ZCONVERT(team, "U")

    If team '= "A", team '= "B" {
        Quit $$$OK
    }

    If points <= 0 {
        Quit $$$OK
    }

    Do totals.%Set(team, +totals.%Get(team, 0) + points)
    Quit $$$OK
}

ClassMethod BuildHandScoreHistoryDetails(handState As %DynamicObject) As %DynamicObject
{
    Set details = {
        "teamA": 0,
        "teamB": 0,
        "phases": {},
        "cardValues": {}
    }

    If '$IsObject(handState) {
        Quit details
    }

    Set completedPhases = handState.%Get("completedPhases", "")

    If $IsObject(completedPhases) {
        Do ..AddPhaseHistoryDetails(.details, completedPhases, "grande")
        Do ..AddPhaseHistoryDetails(.details, completedPhases, "chica")
        Do ..AddPhaseHistoryDetails(.details, completedPhases, "pares")
        Do ..AddPhaseHistoryDetails(.details, completedPhases, "juego")
        Do ..AddPhaseHistoryDetails(.details, completedPhases, "punto")
    }

    Do ..AddCardValueHistoryDetails(.details, handState, "pares")
    Do ..AddCardValueHistoryDetails(.details, handState, "juego")

    If (+details.%Get("teamA", 0) + +details.%Get("teamB", 0)) > 0 {
        Quit details
    }

    /*
      Respaldo para manos antiguas que no tengan completedPhases completo.
      Mantiene la compatibilidad con acciones y settledPoints sin mezclar esas
      fuentes con completedPhases, para no duplicar puntos.
    */
    Set fallbackTotals = ..CalculateHandScoreDeltaFromFallbackSources(handState)
    Do details.%Set("teamA", +fallbackTotals.%Get("A", 0))
    Do details.%Set("teamB", +fallbackTotals.%Get("B", 0))

    Quit details
}

ClassMethod AddPhaseHistoryDetails(ByRef details As %DynamicObject, completedPhases As %DynamicObject, phaseName As %String) As %Status
{
    If '$IsObject(details) {
        Quit $$$OK
    }

    If '$IsObject(completedPhases) {
        Quit $$$OK
    }

    Set phaseState = completedPhases.%Get(phaseName, "")

    If '$IsObject(phaseState) {
        Quit $$$OK
    }

    Set teamA = 0
    Set teamB = 0
    Set winnerTeam = $ZCONVERT(phaseState.%Get("winnerTeam", ""), "U")
    Set pointsAwarded = +phaseState.%Get("pointsAwarded", 0)

    If winnerTeam = "A", pointsAwarded > 0 {
        Set teamA = teamA + pointsAwarded
    }

    If winnerTeam = "B", pointsAwarded > 0 {
        Set teamB = teamB + pointsAwarded
    }

    Set teamCountPoints = phaseState.%Get("teamCountPoints", "")

    If $IsObject(teamCountPoints) {
        Set teamA = teamA + +teamCountPoints.%Get("A", 0)
        Set teamB = teamB + +teamCountPoints.%Get("B", 0)
    }

    Set phaseEntry = {
        "phase": (phaseName),
        "status": (phaseState.%Get("status", "")),
        "teamA": (teamA),
        "teamB": (teamB)
    }

    If winnerTeam '= "" {
        Do phaseEntry.%Set("winnerTeam", winnerTeam)
    }

    If pointsAwarded > 0 {
        Do phaseEntry.%Set("pointsAwarded", pointsAwarded)
    }

    If $IsObject(teamCountPoints) {
        Do phaseEntry.%Set("teamCountPoints", teamCountPoints)
    }

    If phaseState.%Get("reason", "") '= "" {
        Do phaseEntry.%Set("reason", phaseState.%Get("reason"))
    }

    If phaseState.%Get("autoReason", "") '= "" {
        Do phaseEntry.%Set("reason", phaseState.%Get("autoReason"))
    }

    If phaseState.%Get("skipReason", "") '= "" {
        Do phaseEntry.%Set("reason", phaseState.%Get("skipReason"))
    }

    If phaseState.%Get("autoLabel", "") '= "" {
        Do phaseEntry.%Set("label", phaseState.%Get("autoLabel"))
    }

    If phaseState.%Get("skipLabel", "") '= "" {
        Do phaseEntry.%Set("label", phaseState.%Get("skipLabel"))
    }

    Set acceptedBet = phaseState.%Get("acceptedBet", "")
    If $IsObject(acceptedBet) {
        Do phaseEntry.%Set("acceptedBet", acceptedBet)
    }

    Set rejectedBet = phaseState.%Get("rejectedBet", "")
    If $IsObject(rejectedBet) {
        Do phaseEntry.%Set("rejectedBet", rejectedBet)
    }

    Set winner = phaseState.%Get("winner", "")
    If $IsObject(winner) {
        Do phaseEntry.%Set("winner", winner)
    }

    Do details.%Get("phases").%Set(phaseName, phaseEntry)
    Do details.%Set("teamA", +details.%Get("teamA", 0) + teamA)
    Do details.%Set("teamB", +details.%Get("teamB", 0) + teamB)

    Quit $$$OK
}

ClassMethod AddCardValueHistoryDetails(ByRef details As %DynamicObject, handState As %DynamicObject, phaseName As %String) As %Status
{
    If '$IsObject(details) {
        Quit $$$OK
    }

    If '$IsObject(handState) {
        Quit $$$OK
    }

    Set byTeamField = phaseName_"CardValuesByTeam"
    Set breakdownField = phaseName_"CardValuesBreakdown"
    Set byTeam = handState.%Get(byTeamField, "")
    Set breakdown = handState.%Get(breakdownField, "")
    Set teamA = 0
    Set teamB = 0

    If $IsObject(byTeam) {
        Set teamA = +byTeam.%Get("A", 0)
        Set teamB = +byTeam.%Get("B", 0)
    } ElseIf $IsObject(breakdown) {
        For i=0:1:breakdown.%Size()-1 {
            Set item = breakdown.%Get(i)

            If '$IsObject(item) {
                Continue
            }

            Set itemTeam = $ZCONVERT(item.%Get("team", ""), "U")
            Set itemPoints = +item.%Get("points", 0)

            If itemTeam = "A" {
                Set teamA = teamA + itemPoints
            }

            If itemTeam = "B" {
                Set teamB = teamB + itemPoints
            }
        }
    }

    If (teamA + teamB) <= 0, '$IsObject(breakdown) {
        Quit $$$OK
    }

    Set cardEntry = {
        "phase": (phaseName),
        "teamA": (teamA),
        "teamB": (teamB)
    }

    If $IsObject(breakdown) {
        Do cardEntry.%Set("breakdown", breakdown)
    }

    Do details.%Get("cardValues").%Set(phaseName, cardEntry)

    Quit $$$OK
}

ClassMethod CalculateHandScoreDeltaFromFallbackSources(handState As %DynamicObject) As %DynamicObject
{
    Set totals = {"A": 0, "B": 0}

    If '$IsObject(handState) {
        Quit totals
    }

    Set actions = handState.%Get("actions", "")
    Set settledPoints = handState.%Get("settledPoints", "")
    Set hasSettledPoints = 0

    If $IsObject(settledPoints) {
        If settledPoints.%Size() > 0 {
            Set hasSettledPoints = 1
        }
    }

    If $IsObject(actions) {
        Do ..AddAwardedPointsFromActions(.totals, actions)
    }

    If hasSettledPoints {
        Do ..AddSettledPoints(.totals, settledPoints)
    } ElseIf $IsObject(actions) {
        Do ..AddCardValuePointsFromActions(.totals, actions)
    }

    Quit totals
}

ClassMethod BuildHandScoreHistoryEntry(handState As %DynamicObject, handId As %String, handNumber As %Integer, handTeamA As %Integer, handTeamB As %Integer, totalTeamA As %Integer, totalTeamB As %Integer) As %DynamicObject
{
    If handNumber <= 0 {
        Set handNumber = +handState.%Get("handNumber", 0)
    }

    Set details = ..BuildHandScoreHistoryDetails(handState)
    Set detailTeamA = +details.%Get("teamA", handTeamA)
    Set detailTeamB = +details.%Get("teamB", handTeamB)

    Set entry = {
        "handNumber": (handNumber),
        "teamA": (detailTeamA),
        "teamB": (detailTeamB),
        "phases": (details.%Get("phases")),
        "cardValues": (details.%Get("cardValues")),
        "total": {
            "teamA": (totalTeamA),
            "teamB": (totalTeamB)
        }
    }

    If handId '= "" {
        Do entry.%Set("handId", handId)
    }

    Quit entry
}

ClassMethod EnsureHandScoreHistory(ByRef gameState As %DynamicObject, ByRef handState As %DynamicObject) As %Status
{
    If '$IsObject(gameState) {
        Quit $$$OK
    }

    If '$IsObject(handState) {
        Quit $$$OK
    }

    If '..IsClosedHandForScoreHistory(gameState, handState) {
        Quit $$$OK
    }

    Set handNumber = +handState.%Get("handNumber", gameState.%Get("handNumber", 0))

    If handNumber <= 0 {
        Quit $$$OK
    }

    Set handId = ""

    If handState.%Get("id", "") '= "" {
        Set handId = handState.%Get("id")
    }

    If handId = "", gameState.%Get("currentHandId", "") '= "" {
        Set handId = gameState.%Get("currentHandId")
    }

    Set delta = ..CalculateHandScoreDeltaFromHandState(handState)
    Set handTeamA = +delta.%Get("A", 0)
    Set handTeamB = +delta.%Get("B", 0)

    Set history = gameState.%Get("handHistory", "")
    If '$IsObject(history) {
        Set history = []
    }

    Set entry = ..BuildHandScoreHistoryEntry(handState, handId, handNumber, handTeamA, handTeamB, 0, 0)
    Set replaced = 0

    For i=0:1:history.%Size()-1 {
        Set item = history.%Get(i)

        If ..IsSameHandScoreHistoryEntry(item, handId, handNumber) {
            Do history.%Set(i, entry)
            Set replaced = 1
            Quit
        }
    }

    If 'replaced {
        Do history.%Push(entry)
    }

    Do gameState.%Set("handHistory", history)
    Do gameState.%Remove("completedHands")
    Do gameState.%Remove("handResults")
    Do handState.%Set("scoreSummary", entry)
    Do handState.%Set("pointsByTeam", { "A": (handTeamA), "B": (handTeamB) })
    Do gameState.%Set("hand", handState)

    Quit $$$OK
}

ClassMethod IsClosedHandForScoreHistory(gameState As %DynamicObject, handState As %DynamicObject) As %Boolean
{
 
    Set phase = $ZCONVERT(handState.%Get("phase", gameState.%Get("phase", "")), "L") 
    Set status = $ZCONVERT(handState.%Get("status", ""), "L") 
    Set statePhase = $ZCONVERT(gameState.%Get("phase", ""), "L") 
    If phase = "manocerrada" { 
        Quit 1 
    } 
    If statePhase = "manocerrada" { 
        Quit 1 
    } 
    If status = "closed" { 
        Quit 1 
    } 
    If status = "finished" { 
        Quit 1 
    } 
    Quit 0
}

ClassMethod IsSameHandScoreHistoryEntry(entry As %DynamicObject, handId As %String, handNumber As %Integer) As %Boolean
{
    If '$IsObject(entry) { 
        Quit 0 
    } 
    If handId '= "", entry.%Get("handId", "") '= "" { 
        If entry.%Get("handId") = handId { 
            Quit 1 
        } 
    } 
    If +entry.%Get("handNumber", 0) = +handNumber { 
        Quit 1 
    } 
    Quit 0
}

ClassMethod BuildHandScoreBreakdown(actions As %DynamicArray) As %DynamicObject
{
 
    Set result = { "A": [], "B": [] } 
    If '$IsObject(actions) { 
        Quit result 
    } 
    For i=0:1:actions.%Size()-1 { 
        Set action = actions.%Get(i) 
        If '$IsObject(action) { 
            Continue 
        } 
        Set team = $ZCONVERT(action.%Get("team", action.%Get("winnerTeam", "")), "U") 
        If team '= "A", team '= "B" { 
            Continue 
        } 
        Set amount = +action.%Get("points", action.%Get("amount", action.%Get("value", 0))) 
        If amount <= 0 { 
            Continue 
        } 
        Set item = { "type": (action.%Get("type", action.%Get("actionType", ""))), "phase": (action.%Get("phase", "")), "points": (amount), "reason": (action.%Get("reason", action.%Get("description", ""))) } 
        Do result.%Get(team).%Push(item) 
    } 
    Quit result
}

}
