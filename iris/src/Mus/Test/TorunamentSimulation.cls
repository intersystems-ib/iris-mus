Class Mus.Test.TournamentSimulation Extends %RegisteredObject
{

ClassMethod RunFullAgentTournament(teamCount As %Integer = 4, maxHandsPerGame As %Integer = 50, maxActionsPerGame As %Integer = 1000) As %DynamicObject
{
    Set result = {
        "success": true,
        "tournamentId": 0,
        "teamCount": (teamCount),
        "tablesPlayed": 0,
        "gamesPlayed": 0,
        "events": [],
        "finalTournament": {}
    }

    Try {
        Set createPayload = ..BuildAgentTournamentPayload(teamCount)

        Set createResp = ""
        Set sc = ..CreateTournament(createPayload, .createResp)
        If $$$ISERR(sc) {
            Return ..Fail(result, "CREATE_TOURNAMENT_STATUS", $System.Status.GetErrorText(sc))
        }

        If '$IsObject(createResp) || 'createResp.Success {
            Return ..Fail(result, createResp.ErrorCode, createResp.ErrorMessage)
        }

        Set tournamentId = createResp.TournamentId
        Do result.%Set("tournamentId", tournamentId)

        Do ..AddEvent(result, "tournament_created", createResp.TournamentJson)

        For loop=1:1:1000 {
            Set tournamentResp = ""
            Set sc = ..GetTournament(tournamentId, .tournamentResp)
            If $$$ISERR(sc) {
                Return ..Fail(result, "GET_TOURNAMENT_STATUS", $System.Status.GetErrorText(sc))
            }

            If '$IsObject(tournamentResp) || 'tournamentResp.Success {
                Return ..Fail(result, tournamentResp.ErrorCode, tournamentResp.ErrorMessage)
            }

            Set tournament = {}.%FromJSON(tournamentResp.TournamentJson)

            If tournament.%Get("status", "") = "finished" {
                Do result.%Set("finalTournament", tournament)
                Do ..AddEvent(result, "tournament_finished", tournament.%ToJSON())
                Return result
            }

            Set nextTableId = ..FindNextPlayableTableId(tournament)

            If nextTableId <= 0 {
                Return ..Fail(result, "NO_PLAYABLE_TABLE", "Tournament is not finished but no created or playing table was found")
            }

            Set tableResult = ..PlayTable(nextTableId, maxHandsPerGame, maxActionsPerGame)

            Do result.%Get("events").%Push(tableResult)

            If 'tableResult.%Get("success", 0) {
                Do result.%Set("success", "false")
                Do result.%Set("errorCode", tableResult.%Get("errorCode", "TABLE_FAILED"))
                Do result.%Set("errorMessage", tableResult.%Get("errorMessage", "Table simulation failed"))
                Return result
            }

            Do result.%Set("tablesPlayed", +result.%Get("tablesPlayed", 0) + 1)
            Do result.%Set("gamesPlayed", +result.%Get("gamesPlayed", 0) + 1)
        }

        Return ..Fail(result, "TOURNAMENT_LOOP_LIMIT", "Tournament simulation loop limit reached")
    } Catch ex {
        Return ..Fail(result, "TOURNAMENT_SIMULATION_EXCEPTION", ex.DisplayString())
    }
}

ClassMethod PlayTable(tableId As %Integer, maxHandsPerGame As %Integer = 50, maxActionsPerGame As %Integer = 1000) As %DynamicObject
{
    Set result = {
        "success": true,
        "type": "table_played",
        "tableId": (tableId),
        "gameId": 0,
        "startTable": {},
        "game": {},
        "completeTable": {}
    }

    Set startResp = ""
    Set sc = ..StartTournamentTable(tableId, .startResp)

    If $$$ISERR(sc) {
        Return ..Fail(result, "START_TABLE_STATUS", $System.Status.GetErrorText(sc))
    }

    If '$IsObject(startResp) || 'startResp.Success {
        Return ..Fail(result, startResp.ErrorCode, startResp.ErrorMessage)
    }

    Set table = {}.%FromJSON(startResp.TableJson)
    Set gameId = +table.%Get("gameId", 0)

    Do result.%Set("gameId", gameId)
    Do result.%Set("startTable", table)

    Set gameResult = ##class(Mus.Test.AgentSimulation).RunExistingAgentGame(
        gameId,
        maxHandsPerGame,
        maxActionsPerGame
    )

    Do result.%Set("game", gameResult)

    If 'gameResult.%Get("success", 0) {
        Return ..Fail(result, "GAME_FAILED", gameResult.%Get("errorMessage", "Agent game failed"))
    }

    Set completeResp = ""
    Set sc = ..CompleteTournamentTable(tableId, .completeResp)

    If $$$ISERR(sc) {
        Return ..Fail(result, "COMPLETE_TABLE_STATUS", $System.Status.GetErrorText(sc))
    }

    If '$IsObject(completeResp) || 'completeResp.Success {
        Return ..Fail(result, completeResp.ErrorCode, completeResp.ErrorMessage)
    }

    Set completedTable = {}.%FromJSON(completeResp.TableJson)
    Do result.%Set("completeTable", completedTable)

    Return result
}

ClassMethod BuildAgentTournamentPayload(teamCount As %Integer = 4) As %DynamicObject
{
    If teamCount < 2 {
        Set teamCount = 2
    }

    Set payload = {
        "name": ("Torneo automatico agentes "_$ZDATETIME($HOROLOG, 3)),
        "format": "singleElimination",
        "targetScore": 40,
        "teams": []
    }

    Set profiles = ["conservative", "aggressive", "bluffer", "balanced"]

    For i=1:1:teamCount {
        Set p1Profile = profiles.%Get((i - 1) # profiles.%Size())
        Set p2Profile = profiles.%Get(i # profiles.%Size())

        Set team = {
            "name": ("Pareja "_i),
            "players": [
                {
                    "displayName": ("Agente "_i_"A "_p1Profile),
                    "type": "agent",
                    "agentProfile": (p1Profile)
                },
                {
                    "displayName": ("Agente "_i_"B "_p2Profile),
                    "type": "agent",
                    "agentProfile": (p2Profile)
                }
            ]
        }

        Do payload.%Get("teams").%Push(team)
    }

    Return payload
}

ClassMethod FindNextPlayableTableId(tournament As %DynamicObject) As %Integer
{
    Set rounds = tournament.%Get("rounds", "")

    If '$IsObject(rounds) {
        Return 0
    }

    For r=0:1:rounds.%Size()-1 {
        Set round = rounds.%Get(r)
        Set tables = round.%Get("tables", "")

        If '$IsObject(tables) {
            Continue
        }

        For t=0:1:tables.%Size()-1 {
            Set table = tables.%Get(t)
            Set status = table.%Get("status", "")

            If status = "created" {
                Return +table.%Get("id", 0)
            }

            If status = "playing" {
                Return +table.%Get("id", 0)
            }
        }
    }

    Return 0
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

ClassMethod AddEvent(result As %DynamicObject, eventType As %String, payloadJson As %String = "") As %Status
{
    Set event = {
        "type": (eventType),
        "createdAt": ($ZDATETIME($HOROLOG, 3))
    }

    If payloadJson '= "" {
        Try {
            Set payload = {}.%FromJSON(payloadJson)
            Do event.%Set("payload", payload)
        } Catch ex {
            Do event.%Set("payloadJson", payloadJson)
        }
    }

    Do result.%Get("events").%Push(event)

    Return $$$OK
}

ClassMethod Fail(result As %DynamicObject, errorCode As %String, errorMessage As %String) As %DynamicObject
{
    Do result.%Set("success", "false")
    Do result.%Set("errorCode", errorCode)
    Do result.%Set("errorMessage", errorMessage)
    Return result
}

}
