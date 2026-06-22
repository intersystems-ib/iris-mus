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

    If pRequest.%IsA("Mus.Msg.ListTournamentsRequest") {
        Return ..HandleListTournaments(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.DeleteTournamentRequest") {
        Return ..HandleDeleteTournament(pRequest, .pResponse)
    }

    If pRequest.%IsA("Mus.Msg.SimulateTournamentTableRequest") {
        Return ..HandleSimulateTournamentTable(pRequest, .pResponse)
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

Method HandleListTournaments(pRequest As Mus.Msg.ListTournamentsRequest, Output pResponse As Mus.Msg.ListTournamentsResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.ListTournamentsResponse).%New()

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
    Set pResponse.TournamentsJson = persistResp.TournamentsJson
    Set pResponse.Total = persistResp.Total

    Return $$$OK
}

Method HandleDeleteTournament(pRequest As Mus.Msg.DeleteTournamentRequest, Output pResponse As Mus.Msg.DeleteTournamentResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.DeleteTournamentResponse).%New()

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

Method HandleSimulateTournamentTable(pRequest As Mus.Msg.SimulateTournamentTableRequest, Output pResponse As Mus.Msg.SimulateTournamentTableResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.SimulateTournamentTableResponse).%New()

    Try {
        If pRequest.TableId <= 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "INVALID_TABLE_ID"
            Set pResponse.ErrorMessage = "Invalid table id"
            Return $$$OK
        }

        /*
          Paso 1: iniciar la mesa de torneo con la misma operación existente.
          Si la mesa ya estuviera playing, esta operación deberá devolver el gameId existente
          o un error explícito. En la primera versión el frontend solo lanza simular en mesas created.
        */
        Set startReq = ##class(Mus.Msg.StartTournamentTableRequest).%New()
        Set startReq.TableId = pRequest.TableId
        Set startReq.CorrelationId = pRequest.CorrelationId

        Set sc = ..SendRequestSync(
            "Mus.BO.TournamentPersistenceOperation",
            startReq,
            .startResp
        )

        If $$$ISERR(sc) {
            Return sc
        }

        If '$IsObject(startResp) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "NO_START_TABLE_RESPONSE"
            Set pResponse.ErrorMessage = "Tournament persistence returned no start table response"
            Return $$$OK
        }

        If 'startResp.Success {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = startResp.StatusCode
            Set pResponse.ErrorCode = startResp.ErrorCode
            Set pResponse.ErrorMessage = startResp.ErrorMessage
            Set pResponse.TournamentId = startResp.TournamentId
            Set pResponse.TableId = pRequest.TableId
            Set pResponse.GameId = startResp.GameId
            Set pResponse.TableJson = startResp.TableJson
            Set pResponse.TournamentJson = startResp.TournamentJson
            Return $$$OK
        }

        Set pResponse.TournamentId = startResp.TournamentId
        Set pResponse.TableId = startResp.TableId
        Set pResponse.GameId = startResp.GameId
        Set pResponse.TableJson = startResp.TableJson
        Set pResponse.TournamentJson = startResp.TournamentJson

        If startResp.GameId <= 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "TABLE_START_WITHOUT_GAME_ID"
            Set pResponse.ErrorMessage = "Started tournament table did not return a game id"
            Return $$$OK
        }

        /*
          Paso 2: simular la partida completa en una operación dedicada.
          La operación usa la misma lógica base que Mus.Test.AgentSimulation,
          pero queda integrada en la producción como BO.
        */
        Set simReq = ##class(Mus.Msg.SimulateAgentGameRequest).%New()
        Set simReq.GameId = startResp.GameId
        Set simReq.MaxHands = pRequest.MaxHands
        Set simReq.MaxActions = pRequest.MaxActions
        Set simReq.CorrelationId = pRequest.CorrelationId

        Set sc = ..SendRequestSync(
            "Mus.BO.AgentGameSimulationOperation",
            simReq,
            .simResp
        )

        If $$$ISERR(sc) {
            Return sc
        }

        If '$IsObject(simResp) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "NO_SIMULATION_RESPONSE"
            Set pResponse.ErrorMessage = "Agent simulation operation returned no response"
            Return $$$OK
        }

        Set pResponse.SimulationJson = simResp.SimulationJson

        If 'simResp.Success {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = simResp.StatusCode
            Set pResponse.ErrorCode = simResp.ErrorCode
            Set pResponse.ErrorMessage = simResp.ErrorMessage
            Return $$$OK
        }

        Set pResponse.WinnerTeam = simResp.WinnerTeam

        /*
          Paso 3: completar la mesa con la operación de persistencia existente.
          CompleteTournamentTable toma el gameId de la mesa y calcula el winnerTeamId.
        */
        Set completeReq = ##class(Mus.Msg.CompleteTournamentTableRequest).%New()
        Set completeReq.TableId = pRequest.TableId
        Set completeReq.CorrelationId = pRequest.CorrelationId

        Set sc = ..SendRequestSync(
            "Mus.BO.TournamentPersistenceOperation",
            completeReq,
            .completeResp
        )

        If $$$ISERR(sc) {
            Return sc
        }

        If '$IsObject(completeResp) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "NO_COMPLETE_TABLE_RESPONSE"
            Set pResponse.ErrorMessage = "Tournament persistence returned no complete table response"
            Return $$$OK
        }

        Set pResponse.Success = completeResp.Success
        Set pResponse.StatusCode = completeResp.StatusCode
        Set pResponse.ErrorCode = completeResp.ErrorCode
        Set pResponse.ErrorMessage = completeResp.ErrorMessage
        Set pResponse.TournamentId = completeResp.TournamentId
        Set pResponse.TableId = completeResp.TableId
        Set pResponse.GameId = completeResp.GameId
        Set pResponse.WinnerTeamId = completeResp.WinnerTeamId
        Set pResponse.TableJson = completeResp.TableJson
        Set pResponse.TournamentJson = completeResp.TournamentJson

        Return $$$OK
    } Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "SIMULATE_TOURNAMENT_TABLE_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()
        Return $$$OK
    }
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
