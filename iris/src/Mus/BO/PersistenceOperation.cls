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

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.GameId = game.%Id()
        Set pResponse.GameStateJson = game.StateJson

        Return $$$OK
    }
    Catch ex {
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

}
