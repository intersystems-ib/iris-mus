Class Mus.Test.ApiClient Extends %RegisteredObject
{

ClassMethod GetGameState(gameId As %Integer, Output pResponse As Mus.Msg.GetGameStateResponse) As %Status
{
    Set request = ##class(Mus.Msg.GetGameStateRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.GameId = gameId

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod StartNextHand(gameId As %Integer, Output pResponse As Mus.Msg.StartNextHandResponse) As %Status
{
    Set request = ##class(Mus.Msg.StartNextHandRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.GameId = gameId

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod ApplyDiscards(gameId As %Integer, discardsJson As %String, Output pResponse As Mus.Msg.ApplyDiscardsResponse) As %Status
{
    Set request = ##class(Mus.Msg.ApplyDiscardsRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.GameId = gameId
    Set request.DiscardsJson = discardsJson

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod PlayerAction(gameId As %Integer, playerId As %String, actionType As %String, phase As %String, amount As %Integer = 0, payloadJson As %String = "", Output pResponse As Mus.Msg.PlayerActionResponse) As %Status
{
    Set request = ##class(Mus.Msg.PlayerActionRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.GameId = gameId
    Set request.PlayerId = playerId
    Set request.ActionType = actionType
    Set request.Phase = phase
    Set request.Amount = amount
    Set request.PayloadJson = payloadJson

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod CreateTournament(payload As %DynamicObject, Output pResponse As Mus.Msg.CreateTournamentResponse) As %Status
{
    Set request = ##class(Mus.Msg.CreateTournamentRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.Name = payload.%Get("name", "Torneo automatico")
    Set request.Format = payload.%Get("format", "singleElimination")
    Set request.TargetScore = +payload.%Get("targetScore", 40)
    Set request.PayloadJson = payload.%ToJSON()

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod GetTournament(tournamentId As %Integer, Output pResponse As Mus.Msg.GetTournamentResponse) As %Status
{
    Set request = ##class(Mus.Msg.GetTournamentRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.TournamentId = tournamentId

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod ListTournaments(status As %String = "", limit As %Integer = 50, offset As %Integer = 0, Output pResponse As Mus.Msg.ListTournamentsResponse) As %Status
{
    Set request = ##class(Mus.Msg.ListTournamentsRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.Status = status
    Set request.Limit = limit
    Set request.Offset = offset

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod StartTournamentTable(tableId As %Integer, Output pResponse As Mus.Msg.StartTournamentTableResponse) As %Status
{
    Set request = ##class(Mus.Msg.StartTournamentTableRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.TableId = tableId

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

ClassMethod CompleteTournamentTable(tableId As %Integer, Output pResponse As Mus.Msg.CompleteTournamentTableResponse) As %Status
{
    Set request = ##class(Mus.Msg.CompleteTournamentTableRequest).%New()
    Set request.CorrelationId = $System.Util.CreateGUID()
    Set request.TableId = tableId

    Return ##class(Mus.IOP.Dispatcher).Send(request, .pResponse)
}

}
