Class Mus.REST.Api Extends %CSP.REST
{

Parameter CHARSET = "utf-8";

Parameter CONTENTTYPE = "application/json";

Parameter HandleCorsRequest = 1;

XData UrlMap
{
<Routes>
    <Route Url="/games" Method="POST" Call="CreateGame"/>
    <Route Url="/games/:gameId/start" Method="POST" Call="StartGame"/>
    <Route Url="/games/:gameId/state" Method="GET" Call="GetState"/>
    <Route Url="/games/:gameId/actions" Method="POST" Call="ApplyAction"/>
    <Route Url="/games/:gameId/discards" Method="POST" Call="ApplyDiscards"/>
    <Route Url="/games/:gameId/hands/next" Method="POST" Call="StartNextHand"/>
    <Route Url="/games/:gameId/agents/:playerId/discards" Method="GET" Call="GetAgentDiscards"/>
    <Route Url="/games/:gameId/agents/:playerId/action" Method="GET" Call="GetAgentAction"/>

    <Route Url="/tournaments" Method="POST" Call="CreateTournament"/>
    <Route Url="/tournaments" Method="GET" Call="ListTournaments"/>
    <Route Url="/tournaments/:tournamentId" Method="GET" Call="GetTournament"/>
    <Route Url="/tournaments/:tournamentId" Method="DELETE" Call="DeleteTournament"/>

    <Route Url="/tables/:tableId/start" Method="POST" Call="StartTournamentTable"/>
    <Route Url="/tables/:tableId/complete" Method="POST" Call="CompleteTournamentTable"/>
    <Route Url="/tables/:tableId/simulate" Method="POST" Call="SimulateTournamentTable"/>
</Routes>
}

ClassMethod CreateGame() As %Status
{
    Set body = ..ReadBody()

    Set req = ##class(Mus.Msg.CreateGameRequest).%New()
    Set req.CorrelationId = $System.Util.CreateGUID()

    If body '= "" {
        Set req.PlayersJson = body
    }

    Set sc = ##class(Mus.IOP.Dispatcher).Send(req, .resp)
    If $$$ISERR(sc) {
        Return ..WriteStatusError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteGenericGameResponse(resp)
}

ClassMethod StartGame(gameId As %String) As %Status
{
    Set req = ##class(Mus.Msg.StartGameRequest).%New()
    Set req.GameId = +gameId
    Set req.CorrelationId = $System.Util.CreateGUID()

    Set sc = ##class(Mus.IOP.Dispatcher).Send(req, .resp)
    If $$$ISERR(sc) {
        Return ..WriteStatusError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteGenericGameResponse(resp)
}

ClassMethod GetState(gameId As %String) As %Status
{
    Set req = ##class(Mus.Msg.GetGameStateRequest).%New()
    Set req.GameId = +gameId
    Set req.PlayerId = %request.Get("playerId")
    Set req.CorrelationId = $System.Util.CreateGUID()

    Set sc = ##class(Mus.IOP.Dispatcher).Send(req, .resp)
    If $$$ISERR(sc) {
        Return ..WriteStatusError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteGenericGameResponse(resp)
}

ClassMethod ApplyAction(gameId As %String) As %Status
{
    Set body = ..ReadBody()

    Try {
        Set json = {}.%FromJSON(body)
    }
    Catch ex {
        Return ..WriteStatusError(400, "INVALID_JSON", ex.DisplayString())
    }

    Set req = ##class(Mus.Msg.PlayerActionRequest).%New()
    Set req.GameId = +gameId
    Set req.CorrelationId = $System.Util.CreateGUID()

    Set req.PlayerId = json.%Get("playerId", "")
    Set req.ActionType = json.%Get("type", "")
    Set req.Phase = json.%Get("phase", "")
    Set req.Amount = +json.%Get("amount", 0)

    Set payload = json.%Get("payload", "")

    If $IsObject(payload) {
        Set req.PayloadJson = payload.%ToJSON()
    } ElseIf payload '= "" {
        Set req.PayloadJson = payload
    } Else {
        Set req.PayloadJson = "{}"
    }

    If req.PlayerId = "" {
        Return ..WriteStatusError(400, "MISSING_PLAYER_ID", "playerId is required")
    }

    If req.ActionType = "" {
        Return ..WriteStatusError(400, "MISSING_ACTION_TYPE", "type is required")
    }

    Set sc = ##class(Mus.IOP.Dispatcher).Send(req, .resp)
    If $$$ISERR(sc) {
        Return ..WriteStatusError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteGenericGameResponse(resp)
}

ClassMethod ApplyDiscards(gameId As %String) As %Status
{
    Set body = ..ReadBody()

    Try {
        Set json = {}.%FromJSON(body)
    }
    Catch ex {
        Return ..WriteStatusError(400, "INVALID_JSON", ex.DisplayString())
    }

    Set discards = json.%Get("discards", "")

    If '$IsObject(discards) {
        Return ..WriteStatusError(400, "MISSING_DISCARDS", "discards object is required")
    }

    Set req = ##class(Mus.Msg.ApplyDiscardsRequest).%New()
    Set req.GameId = +gameId
    Set req.CorrelationId = $System.Util.CreateGUID()
    Set req.DiscardsJson = discards.%ToJSON()

    Set sc = ##class(Mus.IOP.Dispatcher).Send(req, .resp)
    If $$$ISERR(sc) {
        Return ..WriteStatusError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteGenericGameResponse(resp)
}

ClassMethod ReadBody() As %String
{
    Return ..ReadBodyUtf8()
}

ClassMethod ReadBodyUtf8() As %String
{
    Set body = ""

    If '$IsObject(%request.Content) {
        Return body
    }

    While '%request.Content.AtEnd {
        Set body = body_%request.Content.Read(32000)
    }

    Try {
        Set body = $ZCONVERT(body, "I", "UTF8")
    } Catch ex {
        /* Si ya venía convertido por CSP, se deja como estaba. */
    }

    Return body
}

ClassMethod GetAgentAction(gameId As %String, playerId As %String) As %Status
{
    Try {
        If gameId = "" {
            Return ..WriteStatusError(400, "MISSING_GAME_ID", "gameId is required")
        }

        If playerId = "" {
            Return ..WriteStatusError(400, "MISSING_PLAYER_ID", "playerId is required")
        }

        Set stateReq = ##class(Mus.Msg.GetGameStateRequest).%New()
        Set stateReq.GameId = +gameId
        Set stateReq.PlayerId = playerId
        Set stateReq.CorrelationId = $System.Util.CreateGUID()

        Set sc = ##class(Mus.IOP.Dispatcher).Send(stateReq, .stateResp)

        If $$$ISERR(sc) {
            Return ..WriteStatusError(500, "GET_STATE_DISPATCH_ERROR", $System.Status.GetErrorText(sc))
        }

        If '$IsObject(stateResp) {
            Return ..WriteStatusError(500, "NULL_STATE_RESPONSE", "No state response returned")
        }

        If 'stateResp.Success {
            Return ..WriteStatusError(stateResp.StatusCode, stateResp.ErrorCode, stateResp.ErrorMessage)
        }

        Set gameStateJson = stateResp.GameStateJson

        If gameStateJson = "" {
            Return ..WriteStatusError(500, "EMPTY_GAME_STATE", "Game state JSON is empty")
        }

        Set recommendation = ##class(Mus.Agent.PlayerAgent).RecommendAction(gameStateJson, playerId)

        If '$IsObject(recommendation) {
            Return ..WriteStatusError(500, "INVALID_AGENT_RECOMMENDATION", "Agent returned no valid recommendation")
        }

        Set gameState = {}.%FromJSON(gameStateJson)

        Set actionType = recommendation.%Get("actionType", "")
        Set amount = +recommendation.%Get("amount", 0)

        Set result = {
            "success": true,
            "statusCode": 200,
            "gameId": (+gameId),
            "playerId": (playerId),
            "phase": (gameState.%Get("phase", "")),
            "turnPlayerId": (gameState.%Get("turnPlayerId", "")),
            "actionType": (actionType),
            "type": (actionType),
            "amount": (amount),
            "payload": {},
            "reason": (recommendation.%Get("reason", "")),
            "confidence": (+recommendation.%Get("confidence", 0.5))
        }

        If recommendation.%IsDefined("rawModelOutput") {
            Do result.%Set("rawModelOutput", recommendation.%Get("rawModelOutput"))
        }

        If recommendation.%IsDefined("llmError") {
            Do result.%Set("llmError", recommendation.%Get("llmError"))
        }

        Set %response.Status = 200
        Do %response.SetHeader("Content-Type", "application/json; charset=utf-8")
        Write result.%ToJSON()

        Return $$$OK
    } Catch ex {
        Return ..WriteStatusError(500, "AGENT_ACTION_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod WriteGenericGameResponse(resp As Ens.Response) As %Status
{
    If '$IsObject(resp) {
        Return ..WriteStatusError(500, "NULL_RESPONSE", "No response returned from production")
    }

    If resp.%IsA("Mus.Msg.CreateGameResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json; charset=utf-8")
        Write resp.GameStateJson

        Return $$$OK
    }

    If resp.%IsA("Mus.Msg.StartGameResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json; charset=utf-8")
        Write resp.GameStateJson

        Return $$$OK
    }

    If resp.%IsA("Mus.Msg.GetGameStateResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json; charset=utf-8")
        Write resp.GameStateJson

        Return $$$OK
    }

    If resp.%IsA("Mus.Msg.PlayerActionResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json; charset=utf-8")
        Write resp.GameStateJson

        Return $$$OK
    }

    If resp.%IsA("Mus.Msg.ApplyDiscardsResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json; charset=utf-8")
        Write resp.GameStateJson

        Return $$$OK
    }

    Return ..WriteStatusError(500, "UNSUPPORTED_RESPONSE", resp.%ClassName(1))
}

ClassMethod StartNextHand(gameId As %String) As %Status
{
    Try {
        Set request = ##class(Mus.Msg.StartNextHandRequest).%New()
        Set request.GameId = +gameId
        Set request.CorrelationId = $System.Util.CreateGUID()

        Set sc = ##class(Mus.IOP.Dispatcher).Send(request, .response)

        If $$$ISERR(sc) {
            Set %response.Status = 500
            Set %response.ContentType = "application/json; charset=utf-8"

            Set error = {
                "success": false,
                "errorCode": "START_NEXT_HAND_DISPATCH_ERROR",
                "errorMessage": ($System.Status.GetErrorText(sc))
            }

            Write error.%ToJSON()
            Return $$$OK
        }

        If '$IsObject(response) {
            Set %response.Status = 500
            Set %response.ContentType = "application/json; charset=utf-8"

            Set error = {
                "success": false,
                "errorCode": "NULL_START_NEXT_HAND_RESPONSE",
                "errorMessage": "Production returned no response"
            }

            Write error.%ToJSON()
            Return $$$OK
        }

        Set statusCode = +response.StatusCode

        If statusCode <= 0 {
            Set statusCode = $Select(response.Success:200, 1:500)
        }

        Set %response.Status = statusCode
        Set %response.ContentType = "application/json; charset=utf-8"

        Set result = {
            "success": (response.Success),
            "statusCode": (statusCode),
            "gameId": (response.GameId),
            "handId": (response.HandId)
        }

        If response.Success {
            If response.GameStateJson '= "" {
                Try {
                    Set state = {}.%FromJSON(response.GameStateJson)
                    Do result.%Set("state", state)
                }
                Catch exState {
                    Do result.%Set("stateRaw", response.GameStateJson)
                }
            }
        } Else {
            Do result.%Set("errorCode", response.ErrorCode)
            Do result.%Set("errorMessage", response.ErrorMessage)

            If response.GameStateJson '= "" {
                Try {
                    Set state = {}.%FromJSON(response.GameStateJson)
                    Do result.%Set("state", state)
                }
                Catch exState2 {
                    Do result.%Set("stateRaw", response.GameStateJson)
                }
            }
        }

        Write result.%ToJSON()

        Return $$$OK
    }
    Catch ex {
        Set %response.Status = 500
        Set %response.ContentType = "application/json; charset=utf-8"

        Set error = {
            "success": false,
            "errorCode": "START_NEXT_HAND_REST_EXCEPTION",
            "errorMessage": (ex.DisplayString())
        }

        Write error.%ToJSON()

        Return $$$OK
    }
}

ClassMethod WriteStatusError(statusCode As %Integer, errorCode As %String, errorMessage As %String) As %Status
{
    If statusCode = "" {
        Set statusCode = 500
    }

    Set %response.Status = statusCode
    Do %response.SetHeader("Content-Type", "application/json; charset=utf-8")

    Set err = {
        "success": false,
        "errorCode": (errorCode),
        "errorMessage": (errorMessage)
    }

    Write err.%ToJSON()

    Return $$$OK
}

ClassMethod CreateTournament() As %Status
{
    Set sc = ..ReadJsonBody(.body)

    If $$$ISERR(sc) {
        Return ..WriteError(400, "INVALID_JSON", $System.Status.GetErrorText(sc))
    }

    Set request = ##class(Mus.Msg.CreateTournamentRequest).%New()
    Set request.Name = body.%Get("name", "")
    Set request.Format = body.%Get("format", "singleElimination")
    Set request.TargetScore = +body.%Get("targetScore", 40)
    Set request.PayloadJson = body.%ToJSON()
    Set request.CorrelationId = $System.Util.CreateGUID()

    Set sc = ##class(Mus.IOP.Dispatcher).Send(request, .response)

    If $$$ISERR(sc) {
        Return ..WriteError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteTournamentEnvelope(response)
}

ClassMethod GetTournament(tournamentId As %Integer) As %Status
{
    Set request = ##class(Mus.Msg.GetTournamentRequest).%New()
    Set request.TournamentId = +tournamentId
    Set request.CorrelationId = $System.Util.CreateGUID()

    Set sc = ##class(Mus.IOP.Dispatcher).Send(request, .response)

    If $$$ISERR(sc) {
        Return ..WriteError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteTournamentEnvelope(response)
}

ClassMethod StartTournamentTable(tableId As %Integer) As %Status
{
    Set request = ##class(Mus.Msg.StartTournamentTableRequest).%New()
    Set request.TableId = +tableId
    Set request.CorrelationId = $System.Util.CreateGUID()

    Set sc = ##class(Mus.IOP.Dispatcher).Send(request, .response)

    If $$$ISERR(sc) {
        Return ..WriteError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteTournamentEnvelope(response)
}

ClassMethod CompleteTournamentTable(tableId As %Integer) As %Status
{
    Set request = ##class(Mus.Msg.CompleteTournamentTableRequest).%New()
    Set request.TableId = +tableId
    Set request.CorrelationId = $System.Util.CreateGUID()

    Set sc = ##class(Mus.IOP.Dispatcher).Send(request, .response)

    If $$$ISERR(sc) {
        Return ..WriteError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteTournamentEnvelope(response)
}

ClassMethod ListTournaments() As %Status
{
    Set request = ##class(Mus.Msg.ListTournamentsRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.Status = %request.Get("status")
    Set request.Limit = +%request.Get("limit")
    Set request.Offset = +%request.Get("offset")

    If request.Limit <= 0 {
        Set request.Limit = 50
    }

    If request.Offset < 0 {
        Set request.Offset = 0
    }

    Set sc = ##class(Mus.IOP.Dispatcher).Send(request, .response)

    If $$$ISERR(sc) {
        Return ..WriteError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteTournamentEnvelope(response)
}

ClassMethod WriteTournamentEnvelope(response As Ens.Response) As %Status
{
    If '$IsObject(response) {
        Return ..WriteError(500, "NO_RESPONSE", "No response returned")
    }

    Set statusCode = +response.StatusCode

    If statusCode <= 0 {
        Set statusCode = $Select(response.Success:200, 1:500)
    }

    Set %response.Status = statusCode
    Set %response.ContentType = "application/json; charset=utf-8"

    Set payload = {
        "success": (response.Success),
        "statusCode": (statusCode)
    }

    If 'response.Success {
        Do payload.%Set("errorCode", response.ErrorCode)
        Do payload.%Set("errorMessage", response.ErrorMessage)
        Write payload.%ToJSON()
        Return $$$OK
    }

    If response.%IsA("Mus.Msg.CreateTournamentResponse") {
        Do payload.%Set("tournamentId", response.TournamentId)

        If response.TournamentJson '= "" {
            Set tournament = {}.%FromJSON(response.TournamentJson)
            Do payload.%Set("tournament", tournament)
        }

        Write payload.%ToJSON()
        Return $$$OK
    }

    If response.%IsA("Mus.Msg.GetTournamentResponse") {
        Do payload.%Set("tournamentId", response.TournamentId)

        If response.TournamentJson '= "" {
            Set tournament = {}.%FromJSON(response.TournamentJson)
            Do payload.%Set("tournament", tournament)
        }

        Write payload.%ToJSON()
        Return $$$OK
    }

    If response.%IsA("Mus.Msg.ListTournamentsResponse") {
        Do payload.%Set("total", +response.Total)

        If response.TournamentsJson '= "" {
            Set listPayload = {}.%FromJSON(response.TournamentsJson)

            If listPayload.%IsDefined("tournaments") {
                Do payload.%Set("tournaments", listPayload.%Get("tournaments"))
            } Else {
                Do payload.%Set("tournaments", [])
            }

            If listPayload.%IsDefined("limit") {
                Do payload.%Set("limit", +listPayload.%Get("limit"))
            }

            If listPayload.%IsDefined("offset") {
                Do payload.%Set("offset", +listPayload.%Get("offset"))
            }

            If listPayload.%IsDefined("status") {
                Do payload.%Set("filterStatus", listPayload.%Get("status"))
            }
        } Else {
            Do payload.%Set("tournaments", [])
        }

        Write payload.%ToJSON()
        Return $$$OK
    }

    If response.%IsA("Mus.Msg.StartTournamentTableResponse") {
        Do payload.%Set("tournamentId", response.TournamentId)
        Do payload.%Set("tableId", response.TableId)
        Do payload.%Set("gameId", response.GameId)
        Do payload.%Set("winnerTeamId", +response.WinnerTeamId)

        If response.TableJson '= "" {
            Set table = {}.%FromJSON(response.TableJson)
            Do payload.%Set("table", table)
        }

        If response.TournamentJson '= "" {
            Set tournament = {}.%FromJSON(response.TournamentJson)
            Do payload.%Set("tournament", tournament)
        }

        Write payload.%ToJSON()
        Return $$$OK
    }

    If response.%IsA("Mus.Msg.CompleteTournamentTableResponse") {
        Do payload.%Set("tournamentId", response.TournamentId)
        Do payload.%Set("tableId", response.TableId)
        Do payload.%Set("gameId", response.GameId)
        Do payload.%Set("winnerTeamId", response.WinnerTeamId)

        If response.TableJson '= "" {
            Set table = {}.%FromJSON(response.TableJson)
            Do payload.%Set("table", table)
        }

        If response.TournamentJson '= "" {
            Set tournament = {}.%FromJSON(response.TournamentJson)
            Do payload.%Set("tournament", tournament)
        }

        Write payload.%ToJSON()
        Return $$$OK
    }

    If response.%IsA("Mus.Msg.DeleteTournamentResponse") {
        Do payload.%Set("tournamentId", response.TournamentId)

        If response.TournamentJson '= "" {
            Set tournament = {}.%FromJSON(response.TournamentJson)
            Do payload.%Set("tournament", tournament)
        }

        Write payload.%ToJSON()
        Return $$$OK
    }

    If response.%IsA("Mus.Msg.SimulateTournamentTableResponse") {
        Do payload.%Set("tournamentId", response.TournamentId)
        Do payload.%Set("tableId", response.TableId)
        Do payload.%Set("gameId", response.GameId)
        Do payload.%Set("winnerTeamId", response.WinnerTeamId)
        Do payload.%Set("winnerTeam", response.WinnerTeam)

        If response.TableJson '= "" {
            Set table = {}.%FromJSON(response.TableJson)
            Do payload.%Set("table", table)
        }

        If response.TournamentJson '= "" {
            Set tournament = {}.%FromJSON(response.TournamentJson)
            Do payload.%Set("tournament", tournament)
        }

        If response.SimulationJson '= "" {
            Set simulation = {}.%FromJSON(response.SimulationJson)
            Do payload.%Set("simulation", simulation)
        }

        Write payload.%ToJSON()
        Return $$$OK
    }

    Return ..WriteError(500, "UNSUPPORTED_TOURNAMENT_RESPONSE", response.%ClassName(1))
}

ClassMethod GetAgentDiscards(gameId As %String, playerId As %String) As %Status
{
    Try {
        If gameId = "" {
            Return ..WriteError(400, "MISSING_GAME_ID", "gameId is required")
        }

        If playerId = "" {
            Return ..WriteError(400, "MISSING_PLAYER_ID", "playerId is required")
        }

        Set req = ##class(Mus.Msg.GetGameStateRequest).%New()
        Set req.GameId = +gameId
        Set req.PlayerId = playerId
        Set req.CorrelationId = $System.Util.CreateGUID()

        Set sc = ##class(Mus.IOP.Dispatcher).Send(req, .resp)
        If $$$ISERR(sc) {
            Return ..WriteError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
        }

        If '$IsObject(resp) {
            Return ..WriteError(500, "NULL_RESPONSE", "No response returned from production")
        }

        If 'resp.Success {
            Return ..WriteError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        If resp.GameStateJson = "" {
            Return ..WriteError(500, "EMPTY_GAME_STATE", "Game state response is empty")
        }

        Set gameState = {}.%FromJSON(resp.GameStateJson)
        Set phase = gameState.%Get("phase", "")

        If phase '= "descartes" {
            Return ..WriteError(409, "INVALID_PHASE", "Game is not in discard phase")
        }

        Set recommendation = ##class(Mus.Agent.PlayerAgent).RecommendAction(
            resp.GameStateJson,
            playerId
        )

        If '$IsObject(recommendation) {
            Return ..WriteError(500, "EMPTY_AGENT_RECOMMENDATION", "Agent returned no recommendation")
        }

        Set actionType = recommendation.%Get("actionType", "")
        Set rawDiscards = recommendation.%Get("discards", "")

        Set discards = []
        If $IsObject(rawDiscards) {
            For i=0:1:rawDiscards.%Size()-1 {
                Do discards.%Push(rawDiscards.%Get(i))
            }
        }

        Set cutsMus = 0
        If actionType = "cortar_mus" {
            Set cutsMus = 1
            Set discards = []
        }

        If actionType = "descartar", discards.%Size() = 0 {
            Set cutsMus = 1
        }

        Set payload = {
            "success": true,
            "statusCode": 200,
            "gameId": (+gameId),
            "playerId": (playerId),
            "phase": (phase),
            "actionType": (actionType),
            "discards": (discards),
            "cutsMus": (cutsMus),
            "discardCount": (discards.%Size()),
            "reason": (recommendation.%Get("reason", "")),
            "confidence": (+recommendation.%Get("confidence", 0.5))
        }

        Set %response.Status = 200
        Return ..WriteJson(payload)
    }
    Catch ex {
        Return ..WriteError(500, "GET_AGENT_DISCARDS_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod DeleteTournament(tournamentId As %Integer) As %Status
{
    Set request = ##class(Mus.Msg.DeleteTournamentRequest).%New()
    Set request.TournamentId = +tournamentId
    Set request.CorrelationId = $System.Util.CreateGUID()

    Set sc = ##class(Mus.IOP.Dispatcher).Send(request, .response)

    If $$$ISERR(sc) {
        Return ..WriteError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteTournamentEnvelope(response)
}

ClassMethod SimulateTournamentTable(tableId As %Integer) As %Status
{
    Set request = ##class(Mus.Msg.SimulateTournamentTableRequest).%New()
    Set request.TableId = +tableId
    Set request.MaxHands = +%request.Get("maxHands")
    Set request.MaxActions = +%request.Get("maxActions")
    Set request.CorrelationId = $System.Util.CreateGUID()

    If request.MaxHands <= 0 {
        Set request.MaxHands = 50
    }

    If request.MaxActions <= 0 {
        Set request.MaxActions = 500
    }

    Set sc = ##class(Mus.IOP.Dispatcher).Send(request, .response)

    If $$$ISERR(sc) {
        Return ..WriteError(500, "DISPATCH_ERROR", $System.Status.GetErrorText(sc))
    }

    Return ..WriteTournamentEnvelope(response)
}

ClassMethod ReadJsonBody(Output json As %DynamicObject) As %Status
{
    Set json = {}

    Try {
        Set body = ..ReadBody()

        If body = "" {
            Set json = {}
            Return $$$OK
        }

        Set json = {}.%FromJSON(body)
        Return $$$OK
    }
    Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod WriteJson(json As %DynamicObject) As %Status
{
    Set %response.ContentType = "application/json; charset=utf-8"

    If $IsObject(json) {
        Write json.%ToJSON()
    } Else {
        Write "{}"
    }

    Return $$$OK
}

ClassMethod WriteError(statusCode As %Integer, errorCode As %String, errorMessage As %String) As %Status
{
    Set %response.Status = statusCode
    Set %response.ContentType = "application/json; charset=utf-8"

    Set payload = {
        "success": false,
        "statusCode": (statusCode),
        "errorCode": (errorCode),
        "errorMessage": (errorMessage)
    }

    Write payload.%ToJSON()

    Return $$$OK
}

}
