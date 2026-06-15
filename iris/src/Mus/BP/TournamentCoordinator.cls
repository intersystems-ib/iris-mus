Class Mus.BP.TournamentCoordinator Extends Ens.BusinessProcess
{

Parameter SETTINGS;

Method OnRequest(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status
{
    If pRequest.%IsA("Mus.Msg.CreateTournamentRequest") {
        Return ..HandleCreateTournament(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.GetTournamentRequest") {
        Return ..HandleGetTournament(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.StartTournamentTableRequest") {
        Return ..HandleStartTournamentTable(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.CompleteTournamentTableRequest") {
        Return ..HandleCompleteTournamentTable(pRequest, .pResponse)
    }

    Set pResponse = ##class(Mus.Msg.CreateTournamentResponse).%New()
    Set pResponse.Success = 0
    Set pResponse.StatusCode = 400
    Set pResponse.ErrorCode = "UNSUPPORTED_TOURNAMENT_REQUEST"
    Set pResponse.ErrorMessage = "Unsupported tournament request: "_pRequest.%ClassName(1)

    Return $$$OK
}

Method HandleCreateTournament(pRequest As Mus.Msg.CreateTournamentRequest, Output pResponse As Mus.Msg.CreateTournamentResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.CreateTournamentResponse).%New()

    Set persistReq = ##class(Mus.Msg.PersistTournamentRequest).%New()
    Set persistReq.Name = pRequest.Name
    Set persistReq.Format = pRequest.Format
    Set persistReq.TargetScore = pRequest.TargetScore
    Set persistReq.PayloadJson = pRequest.PayloadJson
    Set persistReq.CorrelationId = pRequest.CorrelationId

    Set sc = ..SendRequestSync(
        "Mus.BO.TournamentPersistenceOperation",
        persistReq,
        .persistResp
    )

    If $$$ISERR(sc) {
        Return sc
    }

    If '$IsObject(persistResp) {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "NO_PERSIST_RESPONSE"
        Set pResponse.ErrorMessage = "Tournament persistence returned no response"
        Return $$$OK
    }

    Set pResponse.Success = persistResp.Success
    Set pResponse.StatusCode = persistResp.StatusCode
    Set pResponse.ErrorCode = persistResp.ErrorCode
    Set pResponse.ErrorMessage = persistResp.ErrorMessage
    Set pResponse.TournamentId = persistResp.TournamentId
    Set pResponse.TournamentJson = persistResp.TournamentJson

    Return $$$OK
}

Method HandleGetTournament(pRequest As Mus.Msg.GetTournamentRequest, Output pResponse As Mus.Msg.GetTournamentResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.GetTournamentResponse).%New()

    Set sc = ..SendRequestSync(
        "Mus.BO.TournamentPersistenceOperation",
        pRequest,
        .persistResp
    )

    If $$$ISERR(sc) {
        Return sc
    }

    If '$IsObject(persistResp) {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "NO_PERSIST_RESPONSE"
        Set pResponse.ErrorMessage = "Tournament persistence returned no response"
        Return $$$OK
    }

    Set pResponse.Success = persistResp.Success
    Set pResponse.StatusCode = persistResp.StatusCode
    Set pResponse.ErrorCode = persistResp.ErrorCode
    Set pResponse.ErrorMessage = persistResp.ErrorMessage
    Set pResponse.TournamentId = persistResp.TournamentId
    Set pResponse.TournamentJson = persistResp.TournamentJson

    Return $$$OK
}

Method HandleStartTournamentTable(pRequest As Mus.Msg.StartTournamentTableRequest, Output pResponse As Mus.Msg.StartTournamentTableResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.StartTournamentTableResponse).%New()

    Set sc = ..SendRequestSync(
        "Mus.BO.TournamentPersistenceOperation",
        pRequest,
        .persistResp
    )

    If $$$ISERR(sc) {
        Return sc
    }

    If '$IsObject(persistResp) {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "NO_PERSIST_RESPONSE"
        Set pResponse.ErrorMessage = "Tournament persistence returned no response"
        Return $$$OK
    }

    Set pResponse.Success = persistResp.Success
    Set pResponse.StatusCode = persistResp.StatusCode
    Set pResponse.ErrorCode = persistResp.ErrorCode
    Set pResponse.ErrorMessage = persistResp.ErrorMessage
    Set pResponse.TournamentId = persistResp.TournamentId
    Set pResponse.TableId = persistResp.TableId
    Set pResponse.GameId = persistResp.GameId
    Set pResponse.TableJson = persistResp.TableJson

    Return $$$OK
}

Method HandleCompleteTournamentTable(pRequest As Mus.Msg.CompleteTournamentTableRequest, Output pResponse As Mus.Msg.CompleteTournamentTableResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.CompleteTournamentTableResponse).%New()

    Set sc = ..SendRequestSync(
        "Mus.BO.TournamentPersistenceOperation",
        pRequest,
        .persistResp
    )

    If $$$ISERR(sc) {
        Return sc
    }

    If '$IsObject(persistResp) {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "NO_PERSIST_RESPONSE"
        Set pResponse.ErrorMessage = "Tournament persistence returned no response"
        Return $$$OK
    }

    Set pResponse.Success = persistResp.Success
    Set pResponse.StatusCode = persistResp.StatusCode
    Set pResponse.ErrorCode = persistResp.ErrorCode
    Set pResponse.ErrorMessage = persistResp.ErrorMessage
    Set pResponse.TournamentId = persistResp.TournamentId
    Set pResponse.TableId = persistResp.TableId
    Set pResponse.WinnerTeamId = persistResp.WinnerTeamId
    Set pResponse.TournamentJson = persistResp.TournamentJson

    Return $$$OK
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
