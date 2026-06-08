Class Mus.REST.GameApi Extends %CSP.REST
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
    Set body = ""

    If $IsObject(%request.Content) {
        While '%request.Content.AtEnd {
            Set body = body_%request.Content.Read(32000)
        }
    }

    Return body
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
        Do %response.SetHeader("Content-Type", "application/json")
        Write resp.GameStateJson

        Return $$$OK
    }

    If resp.%IsA("Mus.Msg.StartGameResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json")
        Write resp.GameStateJson

        Return $$$OK
    }

    If resp.%IsA("Mus.Msg.GetGameStateResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json")
        Write resp.GameStateJson

        Return $$$OK
    }

    If resp.%IsA("Mus.Msg.PlayerActionResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json")
        Write resp.GameStateJson

        Return $$$OK
    }

    If resp.%IsA("Mus.Msg.ApplyDiscardsResponse") {
        If 'resp.Success {
            Return ..WriteStatusError(resp.StatusCode, resp.ErrorCode, resp.ErrorMessage)
        }

        Set %response.Status = resp.StatusCode
        Do %response.SetHeader("Content-Type", "application/json")
        Write resp.GameStateJson

        Return $$$OK
    }

    Return ..WriteStatusError(500, "UNSUPPORTED_RESPONSE", resp.%ClassName(1))
}

ClassMethod WriteStatusError(statusCode As %Integer, errorCode As %String, errorMessage As %String) As %Status
{
    If statusCode = "" {
        Set statusCode = 500
    }

    Set %response.Status = statusCode
    Do %response.SetHeader("Content-Type", "application/json")

    Set err = {
        "success": false,
        "errorCode": (errorCode),
        "errorMessage": (errorMessage)
    }

    Write err.%ToJSON()

    Return $$$OK
}

}
