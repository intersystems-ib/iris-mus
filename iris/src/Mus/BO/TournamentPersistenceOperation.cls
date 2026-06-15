Class Mus.BO.TournamentPersistenceOperation Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
    <MapItem MessageType="Mus.Msg.PersistTournamentRequest">
        <Method>PersistTournament</Method>
    </MapItem>

    <MapItem MessageType="Mus.Msg.GetTournamentRequest">
        <Method>GetTournament</Method>
    </MapItem>

    <MapItem MessageType="Mus.Msg.StartTournamentTableRequest">
        <Method>StartTournamentTable</Method>
    </MapItem>

    <MapItem MessageType="Mus.Msg.CompleteTournamentTableRequest">
        <Method>CompleteTournamentTable</Method>
    </MapItem>

</MapItems>
}

Method PersistTournament(pRequest As Mus.Msg.PersistTournamentRequest, Output pResponse As Mus.Msg.PersistTournamentResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.PersistTournamentResponse).%New()

    Try {
        If pRequest.Name = "" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "TOURNAMENT_NAME_REQUIRED"
            Set pResponse.ErrorMessage = "Tournament name is required"
            Return $$$OK
        }

        If pRequest.PayloadJson = "" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "TOURNAMENT_PAYLOAD_REQUIRED"
            Set pResponse.ErrorMessage = "Tournament payload is required"
            Return $$$OK
        }

        Set payload = {}.%FromJSON(pRequest.PayloadJson)

        Set teams = payload.%Get("teams", "")
        If '$IsObject(teams) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "TEAMS_REQUIRED"
            Set pResponse.ErrorMessage = "Tournament must contain teams"
            Return $$$OK
        }

        Set teamCount = teams.%Size()

        If teamCount < 2 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "NOT_ENOUGH_TEAMS"
            Set pResponse.ErrorMessage = "Tournament must contain at least two teams"
            Return $$$OK
        }

        If teamCount # 2 '= 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "TEAM_COUNT_MUST_BE_EVEN"
            Set pResponse.ErrorMessage = "Tournament team count must be even"
            Return $$$OK
        }

        If '..IsPowerOfTwo(teamCount) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "TEAM_COUNT_MUST_BE_POWER_OF_TWO"
            Set pResponse.ErrorMessage = "Single elimination tournaments require 2, 4, 8, 16... teams"
            Return $$$OK
        }

        TSTART

        Set tournament = ##class(Mus.Data.Tournament).%New()
        Set tournament.Name = pRequest.Name
        Set tournament.Format = $Select(pRequest.Format '= "": pRequest.Format, 1: "singleElimination")
        Set tournament.TargetScore = $Select(pRequest.TargetScore > 0: pRequest.TargetScore, 1: 40)
        Set tournament.Status = "created"
        Set tournament.CreatedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = tournament.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Return sc
        }

        Set tournamentId = tournament.%Id()

        Set teamIds = []
        Set teamSummaries = []

        For i=0:1:teamCount-1 {
            Set teamPayload = teams.%Get(i)

            If '$IsObject(teamPayload) {
                TROLLBACK
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 400
                Set pResponse.ErrorCode = "INVALID_TEAM"
                Set pResponse.ErrorMessage = "Invalid team at index "_i
                Return $$$OK
            }

            Set players = teamPayload.%Get("players", "")
            If '$IsObject(players) {
                TROLLBACK
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 400
                Set pResponse.ErrorCode = "TEAM_PLAYERS_REQUIRED"
                Set pResponse.ErrorMessage = "Team "_(i + 1)_" must contain players"
                Return $$$OK
            }

            If players.%Size() '= 2 {
                TROLLBACK
                Set pResponse.Success = 0
                Set pResponse.StatusCode = 400
                Set pResponse.ErrorCode = "TEAM_REQUIRES_TWO_PLAYERS"
                Set pResponse.ErrorMessage = "Team "_(i + 1)_" must contain exactly two players"
                Return $$$OK
            }

            Set tournamentTeam = ##class(Mus.Data.TournamentTeam).%New()
            Set tournamentTeam.TournamentId = tournamentId
            Set tournamentTeam.Name = teamPayload.%Get("name", "Pareja "_(i + 1))
            Set tournamentTeam.Status = "active"
            Set tournamentTeam.Seed = i + 1
            Set tournamentTeam.CreatedAt = $ZDATETIME($HOROLOG, 3)

            Set sc = tournamentTeam.%Save()
            If $$$ISERR(sc) {
                TROLLBACK
                Return sc
            }

            Set teamId = tournamentTeam.%Id()
            Do teamIds.%Push(teamId)

            Set playerSummaries = []

            For j=0:1:players.%Size()-1 {
                Set playerPayload = players.%Get(j)

                If '$IsObject(playerPayload) {
                    TROLLBACK
                    Set pResponse.Success = 0
                    Set pResponse.StatusCode = 400
                    Set pResponse.ErrorCode = "INVALID_TEAM_PLAYER"
                    Set pResponse.ErrorMessage = "Invalid player at team "_(i + 1)_", index "_j
                    Return $$$OK
                }

                Set playerType = playerPayload.%Get("type", "human")
                If (playerType '= "human") && (playerType '= "agent") {
                    TROLLBACK
                    Set pResponse.Success = 0
                    Set pResponse.StatusCode = 400
                    Set pResponse.ErrorCode = "INVALID_PLAYER_TYPE"
                    Set pResponse.ErrorMessage = "Invalid player type in team "_(i + 1)_": "_playerType
                    Return $$$OK
                }

                Set teamPlayer = ##class(Mus.Data.TournamentTeamPlayer).%New()
                Set teamPlayer.TournamentId = tournamentId
                Set teamPlayer.TeamId = teamId
                Set teamPlayer.PlayerNumber = j + 1
                Set teamPlayer.DisplayName = playerPayload.%Get("displayName", "Jugador "_(j + 1))
                Set teamPlayer.PlayerType = playerType
                Set teamPlayer.AgentProfile = playerPayload.%Get("agentProfile", "")

                Set sc = teamPlayer.%Save()
                If $$$ISERR(sc) {
                    TROLLBACK
                    Return sc
                }

                Do playerSummaries.%Push({
                    "id": (teamPlayer.%Id()),
                    "playerNumber": (teamPlayer.PlayerNumber),
                    "displayName": (teamPlayer.DisplayName),
                    "type": (teamPlayer.PlayerType),
                    "agentProfile": (teamPlayer.AgentProfile)
                })
            }

            Do teamSummaries.%Push({
                "id": (teamId),
                "seed": (tournamentTeam.Seed),
                "name": (tournamentTeam.Name),
                "status": (tournamentTeam.Status),
                "players": (playerSummaries)
            })
        }

        Set round = ##class(Mus.Data.TournamentRound).%New()
        Set round.TournamentId = tournamentId
        Set round.RoundNumber = 1
        Set round.Name = ..GetRoundName(1, teamCount)
        Set round.Status = "created"
        Set round.CreatedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = round.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Return sc
        }

        Set roundId = round.%Id()

        Set tableSummaries = []
        Set tableNumber = 0

        For i=0:2:teamIds.%Size()-1 {
            Set tableNumber = tableNumber + 1

            Set teamAId = teamIds.%Get(i)
            Set teamBId = teamIds.%Get(i + 1)

            Set table = ##class(Mus.Data.TournamentTable).%New()
            Set table.TournamentId = tournamentId
            Set table.RoundId = roundId
            Set table.RoundNumber = 1
            Set table.TableNumber = tableNumber
            Set table.Status = "created"
            Set table.TeamAId = teamAId
            Set table.TeamBId = teamBId
            Set table.WinnerTeamId = 0
            Set table.GameId = 0
            Set table.CreatedAt = $ZDATETIME($HOROLOG, 3)

            Set sc = table.%Save()
            If $$$ISERR(sc) {
                TROLLBACK
                Return sc
            }

            Do tableSummaries.%Push({
                "id": (table.%Id()),
                "tableNumber": (table.TableNumber),
                "status": (table.Status),
                "teamAId": (table.TeamAId),
                "teamBId": (table.TeamBId),
                "winnerTeamId": (table.WinnerTeamId),
                "gameId": (table.GameId)
            })
        }

        TCOMMIT

        Set rounds = []
        Do rounds.%Push({
            "id": (roundId),
            "roundNumber": (round.RoundNumber),
            "name": (round.Name),
            "status": (round.Status),
            "tables": (tableSummaries)
        })

        Set result = {
            "id": (tournamentId),
            "name": (tournament.Name),
            "format": (tournament.Format),
            "targetScore": (tournament.TargetScore),
            "status": (tournament.Status),
            "teams": (teamSummaries),
            "rounds": (rounds)
        }

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 201
        Set pResponse.TournamentId = tournamentId
        Set pResponse.TournamentJson = result.%ToJSON()

        Return $$$OK
    }
    Catch ex {
        If $TLEVEL {
            TROLLBACK
        }

        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "CREATE_TOURNAMENT_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()

        Return $$$OK
    }
}

Method GetTournament(pRequest As Mus.Msg.GetTournamentRequest, Output pResponse As Mus.Msg.GetTournamentResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.GetTournamentResponse).%New()

    Try {
        If pRequest.TournamentId <= 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "INVALID_TOURNAMENT_ID"
            Set pResponse.ErrorMessage = "Invalid tournament id"
            Return $$$OK
        }

        Set tournament = ##class(Mus.Data.Tournament).%OpenId(pRequest.TournamentId)

        If '$IsObject(tournament) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "TOURNAMENT_NOT_FOUND"
            Set pResponse.ErrorMessage = "Tournament not found"
            Return $$$OK
        }

        Set result = ..BuildTournamentJson(tournament)

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.TournamentId = tournament.%Id()
        Set pResponse.TournamentJson = result.%ToJSON()

        Return $$$OK
    }
    Catch ex {
        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "GET_TOURNAMENT_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()

        Return $$$OK
    }
}

ClassMethod IsPowerOfTwo(value As %Integer) As %Boolean
{
    If value < 2 {
        Return 0
    }

    Set n = value

    While n > 1 {
        If n # 2 '= 0 {
            Return 0
        }

        Set n = n \ 2
    }

    Return 1
}

ClassMethod GetRoundName(roundNumber As %Integer, teamsInRound As %Integer) As %String
{
    If teamsInRound = 2 {
        Return "Final"
    }

    If teamsInRound = 4 {
        Return "Semifinal"
    }

    If teamsInRound = 8 {
        Return "Cuartos"
    }

    If teamsInRound = 16 {
        Return "Octavos"
    }

    Return "Ronda "_roundNumber
}

ClassMethod BuildTournamentJson(tournament As Mus.Data.Tournament) As %DynamicObject
{
    Set tournamentId = tournament.%Id()

    Set result = {
        "id": (tournamentId),
        "name": (tournament.Name),
        "format": (tournament.Format),
        "targetScore": (tournament.TargetScore),
        "status": (tournament.Status),
        "createdAt": (tournament.CreatedAt),
        "startedAt": (tournament.StartedAt),
        "finishedAt": (tournament.FinishedAt),
        "teams": [],
        "rounds": []
    }

    Set teamsById = {}

    Set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT ID, Name, Status, Seed FROM Mus_Data.TournamentTeam WHERE TournamentId = ? ORDER BY Seed",
        tournamentId
    )

    While rs.%Next() {
        Set teamId = rs.%Get("ID")

        Set teamJson = {
            "id": (teamId),
            "name": (rs.%Get("Name")),
            "status": (rs.%Get("Status")),
            "seed": (+rs.%Get("Seed")),
            "players": []
        }

        Set playersRs = ##class(%SQL.Statement).%ExecDirect(
            ,
            "SELECT ID, PlayerNumber, DisplayName, PlayerType, AgentProfile FROM Mus_Data.TournamentTeamPlayer WHERE TeamId = ? ORDER BY PlayerNumber",
            teamId
        )

        While playersRs.%Next() {
            Do teamJson.%Get("players").%Push({
                "id": (playersRs.%Get("ID")),
                "playerNumber": (+playersRs.%Get("PlayerNumber")),
                "displayName": (playersRs.%Get("DisplayName")),
                "type": (playersRs.%Get("PlayerType")),
                "agentProfile": (playersRs.%Get("AgentProfile"))
            })
        }

        Do result.%Get("teams").%Push(teamJson)
        Do teamsById.%Set(teamId, teamJson)
    }

    Set roundsRs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT ID, RoundNumber, Name, Status, CreatedAt, StartedAt, FinishedAt FROM Mus_Data.TournamentRound WHERE TournamentId = ? ORDER BY RoundNumber",
        tournamentId
    )

    While roundsRs.%Next() {
        Set roundId = roundsRs.%Get("ID")

        Set roundJson = {
            "id": (roundId),
            "roundNumber": (+roundsRs.%Get("RoundNumber")),
            "name": (roundsRs.%Get("Name")),
            "status": (roundsRs.%Get("Status")),
            "createdAt": (roundsRs.%Get("CreatedAt")),
            "startedAt": (roundsRs.%Get("StartedAt")),
            "finishedAt": (roundsRs.%Get("FinishedAt")),
            "tables": []
        }

        Set tablesRs = ##class(%SQL.Statement).%ExecDirect(
            ,
            "SELECT ID, TableNumber, Status, TeamAId, TeamBId, WinnerTeamId, GameId, CreatedAt, StartedAt, FinishedAt FROM Mus_Data.TournamentTable WHERE RoundId = ? ORDER BY TableNumber",
            roundId
        )

        While tablesRs.%Next() {
            Set teamAId = +tablesRs.%Get("TeamAId")
            Set teamBId = +tablesRs.%Get("TeamBId")
            Set winnerTeamId = +tablesRs.%Get("WinnerTeamId")

            Set tableJson = {
                "id": (tablesRs.%Get("ID")),
                "tableNumber": (+tablesRs.%Get("TableNumber")),
                "status": (tablesRs.%Get("Status")),
                "teamAId": (teamAId),
                "teamBId": (teamBId),
                "winnerTeamId": (winnerTeamId),
                "gameId": (+tablesRs.%Get("GameId")),
                "createdAt": (tablesRs.%Get("CreatedAt")),
                "startedAt": (tablesRs.%Get("StartedAt")),
                "finishedAt": (tablesRs.%Get("FinishedAt"))
            }

            If teamsById.%IsDefined(teamAId) {
                Do tableJson.%Set("teamA", teamsById.%Get(teamAId))
            }

            If teamsById.%IsDefined(teamBId) {
                Do tableJson.%Set("teamB", teamsById.%Get(teamBId))
            }

            If winnerTeamId > 0, teamsById.%IsDefined(winnerTeamId) {
                Do tableJson.%Set("winnerTeam", teamsById.%Get(winnerTeamId))
            }

            Do roundJson.%Get("tables").%Push(tableJson)
        }

        Do result.%Get("rounds").%Push(roundJson)
    }

    Return result
}

Method StartTournamentTable(pRequest As Mus.Msg.StartTournamentTableRequest, Output pResponse As Mus.Msg.StartTournamentTableResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.StartTournamentTableResponse).%New()

    Try {
        If pRequest.TableId <= 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "INVALID_TABLE_ID"
            Set pResponse.ErrorMessage = "Invalid tournament table id"
            Return $$$OK
        }

        Set table = ##class(Mus.Data.TournamentTable).%OpenId(pRequest.TableId)

        If '$IsObject(table) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "TABLE_NOT_FOUND"
            Set pResponse.ErrorMessage = "Tournament table not found"
            Return $$$OK
        }

        If table.Status '= "created" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "TABLE_ALREADY_STARTED"
            Set pResponse.ErrorMessage = "Tournament table is not in created status"
            Set pResponse.TournamentId = table.TournamentId
            Set pResponse.TableId = table.%Id()
            Set pResponse.GameId = table.GameId
            Return $$$OK
        }

        Set teamA = ##class(Mus.Data.TournamentTeam).%OpenId(table.TeamAId)
        Set teamB = ##class(Mus.Data.TournamentTeam).%OpenId(table.TeamBId)

        If '$IsObject(teamA) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "TEAM_A_NOT_FOUND"
            Set pResponse.ErrorMessage = "Team A not found"
            Return $$$OK
        }

        If '$IsObject(teamB) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "TEAM_B_NOT_FOUND"
            Set pResponse.ErrorMessage = "Team B not found"
            Return $$$OK
        }

        Set teamAPlayers = ..LoadTeamPlayers(table.TournamentId, table.TeamAId)
        Set teamBPlayers = ..LoadTeamPlayers(table.TournamentId, table.TeamBId)

        If teamAPlayers.%Size() '= 2 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "TEAM_A_INVALID_PLAYER_COUNT"
            Set pResponse.ErrorMessage = "Team A must contain exactly two players"
            Return $$$OK
        }

        If teamBPlayers.%Size() '= 2 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "TEAM_B_INVALID_PLAYER_COUNT"
            Set pResponse.ErrorMessage = "Team B must contain exactly two players"
            Return $$$OK
        }

        Set playersJson = ..BuildGamePlayersJson(teamAPlayers, teamBPlayers)

        /*
          Creamos la partida usando el flujo actual del motor.
          Ajusta CreateGameRequest.PlayersJson si en tu implementación
          la propiedad se llama distinto.
        */
        Set createGameReq = ##class(Mus.Msg.CreateGameRequest).%New()
        Set createGameReq.PlayersJson = playersJson.%ToJSON()
        Set createGameReq.CorrelationId = pRequest.CorrelationId

        Set sc = ##class(Mus.IOP.Dispatcher).Send(createGameReq, .createGameResp)
        If $$$ISERR(sc) {
            Return sc
        }

        If '$IsObject(createGameResp) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "NO_CREATE_GAME_RESPONSE"
            Set pResponse.ErrorMessage = "Create game returned no response"
            Return $$$OK
        }

        If 'createGameResp.Success {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = createGameResp.StatusCode
            Set pResponse.ErrorCode = createGameResp.ErrorCode
            Set pResponse.ErrorMessage = createGameResp.ErrorMessage
            Return $$$OK
        }

        Set gameId = createGameResp.GameId

        Set startGameReq = ##class(Mus.Msg.StartGameRequest).%New()
        Set startGameReq.GameId = gameId
        Set startGameReq.CorrelationId = pRequest.CorrelationId

        Set sc = ##class(Mus.IOP.Dispatcher).Send(startGameReq, .startGameResp)
        If $$$ISERR(sc) {
            Return sc
        }

        If '$IsObject(startGameResp) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 500
            Set pResponse.ErrorCode = "NO_START_GAME_RESPONSE"
            Set pResponse.ErrorMessage = "Start game returned no response"
            Return $$$OK
        }

        If 'startGameResp.Success {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = startGameResp.StatusCode
            Set pResponse.ErrorCode = startGameResp.ErrorCode
            Set pResponse.ErrorMessage = startGameResp.ErrorMessage
            Return $$$OK
        }

        TSTART

        Set table.Status = "playing"
        Set table.GameId = gameId
        Set table.StartedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = table.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Return sc
        }

        Set sc = ..CreateTableSeats(table, teamAPlayers, teamBPlayers)
        If $$$ISERR(sc) {
            TROLLBACK
            Return sc
        }

        TCOMMIT

        Set tableJson = ..BuildTournamentTableJson(table)

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.TournamentId = table.TournamentId
        Set pResponse.TableId = table.%Id()
        Set pResponse.GameId = gameId
        Set pResponse.TableJson = tableJson.%ToJSON()

        Return $$$OK
    }
    Catch ex {
        If $TLEVEL {
            TROLLBACK
        }

        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "START_TOURNAMENT_TABLE_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()

        Return $$$OK
    }
}

ClassMethod LoadTeamPlayers(tournamentId As %Integer, teamId As %Integer) As %DynamicArray
{
    Set result = []

    Set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT ID, PlayerNumber, DisplayName, PlayerType, AgentProfile FROM Mus_Data.TournamentTeamPlayer WHERE TournamentId = ? AND TeamId = ? ORDER BY PlayerNumber",
        tournamentId,
        teamId
    )

    While rs.%Next() {
        Do result.%Push({
            "id": (rs.%Get("ID")),
            "playerNumber": (+rs.%Get("PlayerNumber")),
            "displayName": (rs.%Get("DisplayName")),
            "type": (rs.%Get("PlayerType")),
            "agentProfile": (rs.%Get("AgentProfile"))
        })
    }

    Return result
}

ClassMethod BuildGamePlayersJson(teamAPlayers As %DynamicArray, teamBPlayers As %DynamicArray) As %DynamicObject
{
    Set a1 = teamAPlayers.%Get(0)
    Set a2 = teamAPlayers.%Get(1)
    Set b1 = teamBPlayers.%Get(0)
    Set b2 = teamBPlayers.%Get(1)

    Set payload = {
        "players": [
            {
                "id": "P1",
                "name": (a1.%Get("displayName", "P1")),
                "team": "A"
            },
            {
                "id": "P2",
                "name": (b1.%Get("displayName", "P2")),
                "team": "B"
            },
            {
                "id": "P3",
                "name": (a2.%Get("displayName", "P3")),
                "team": "A"
            },
            {
                "id": "P4",
                "name": (b2.%Get("displayName", "P4")),
                "team": "B"
            }
        ]
    }

    Return payload
}

ClassMethod CreateTableSeats(table As Mus.Data.TournamentTable, teamAPlayers As %DynamicArray, teamBPlayers As %DynamicArray) As %Status
{
    Set a1 = teamAPlayers.%Get(0)
    Set a2 = teamAPlayers.%Get(1)
    Set b1 = teamBPlayers.%Get(0)
    Set b2 = teamBPlayers.%Get(1)

    Set sc = ..CreateOneTableSeat(table, table.TeamAId, "P1", a1)
    If $$$ISERR(sc) {
        Return sc
    }

    Set sc = ..CreateOneTableSeat(table, table.TeamBId, "P2", b1)
    If $$$ISERR(sc) {
        Return sc
    }

    Set sc = ..CreateOneTableSeat(table, table.TeamAId, "P3", a2)
    If $$$ISERR(sc) {
        Return sc
    }

    Set sc = ..CreateOneTableSeat(table, table.TeamBId, "P4", b2)
    If $$$ISERR(sc) {
        Return sc
    }

    Return $$$OK
}

ClassMethod CreateOneTableSeat(table As Mus.Data.TournamentTable, teamId As %Integer, seat As %String, playerJson As %DynamicObject) As %Status
{
    Set existingId = ..FindTableSeatId(table.%Id(), seat)

    If existingId > 0 {
        Set tableSeat = ##class(Mus.Data.TournamentTableSeat).%OpenId(existingId)
    } Else {
        Set tableSeat = ##class(Mus.Data.TournamentTableSeat).%New()
    }

    Set tableSeat.TournamentId = table.TournamentId
    Set tableSeat.TableId = table.%Id()
    Set tableSeat.TeamId = teamId
    Set tableSeat.Seat = seat
    Set tableSeat.GamePlayerId = seat
    Set tableSeat.DisplayName = playerJson.%Get("displayName", seat)
    Set tableSeat.PlayerType = playerJson.%Get("type", "human")
    Set tableSeat.AgentProfile = playerJson.%Get("agentProfile", "")
    Set tableSeat.CreatedAt = $ZDATETIME($HOROLOG, 3)

    Return tableSeat.%Save()
}

ClassMethod FindTableSeatId(tableId As %Integer, seat As %String) As %Integer
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT ID FROM Mus_Data.TournamentTableSeat WHERE TableId = ? AND Seat = ?",
        tableId,
        seat
    )

    If rs.%Next() {
        Return +rs.%Get("ID")
    }

    Return 0
}

ClassMethod BuildTournamentTableJson(table As Mus.Data.TournamentTable) As %DynamicObject
{
    Set result = {
        "id": (table.%Id()),
        "tournamentId": (table.TournamentId),
        "roundId": (table.RoundId),
        "roundNumber": (table.RoundNumber),
        "tableNumber": (table.TableNumber),
        "status": (table.Status),
        "teamAId": (table.TeamAId),
        "teamBId": (table.TeamBId),
        "winnerTeamId": (table.WinnerTeamId),
        "gameId": (table.GameId),
        "createdAt": (table.CreatedAt),
        "startedAt": (table.StartedAt),
        "finishedAt": (table.FinishedAt),
        "seats": []
    }

    Set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT ID, TeamId, Seat, GamePlayerId, DisplayName, PlayerType, AgentProfile FROM Mus_Data.TournamentTableSeat WHERE TableId = ? ORDER BY Seat",
        table.%Id()
    )

    While rs.%Next() {
        Do result.%Get("seats").%Push({
            "id": (rs.%Get("ID")),
            "teamId": (+rs.%Get("TeamId")),
            "seat": (rs.%Get("Seat")),
            "gamePlayerId": (rs.%Get("GamePlayerId")),
            "displayName": (rs.%Get("DisplayName")),
            "type": (rs.%Get("PlayerType")),
            "agentProfile": (rs.%Get("AgentProfile"))
        })
    }

    Return result
}

Method CompleteTournamentTable(pRequest As Mus.Msg.CompleteTournamentTableRequest, Output pResponse As Mus.Msg.CompleteTournamentTableResponse) As %Status
{
    Set pResponse = ##class(Mus.Msg.CompleteTournamentTableResponse).%New()

    Try {
        If pRequest.TableId <= 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 400
            Set pResponse.ErrorCode = "INVALID_TABLE_ID"
            Set pResponse.ErrorMessage = "Invalid tournament table id"
            Return $$$OK
        }

        Set table = ##class(Mus.Data.TournamentTable).%OpenId(pRequest.TableId)

        If '$IsObject(table) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "TABLE_NOT_FOUND"
            Set pResponse.ErrorMessage = "Tournament table not found"
            Return $$$OK
        }

        If table.Status = "finished" {
            Set tournament = ##class(Mus.Data.Tournament).%OpenId(table.TournamentId)
            If $IsObject(tournament) {
                Set tournamentJson = ..BuildTournamentJson(tournament)
            } Else {
                Set tournamentJson = {}
            }

            Set pResponse.Success = 1
            Set pResponse.StatusCode = 200
            Set pResponse.TournamentId = table.TournamentId
            Set pResponse.TableId = table.%Id()
            Set pResponse.WinnerTeamId = table.WinnerTeamId
            Set pResponse.TournamentJson = tournamentJson.%ToJSON()
            Return $$$OK
        }

        If table.GameId <= 0 {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "TABLE_HAS_NO_GAME"
            Set pResponse.ErrorMessage = "Tournament table has no associated game"
            Return $$$OK
        }

        Set game = ##class(Mus.Data.Game).%OpenId(table.GameId)

        If '$IsObject(game) {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 404
            Set pResponse.ErrorCode = "GAME_NOT_FOUND"
            Set pResponse.ErrorMessage = "Associated game not found"
            Return $$$OK
        }

        If game.Status '= "finished" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "GAME_NOT_FINISHED"
            Set pResponse.ErrorMessage = "Associated game is not finished"
            Return $$$OK
        }

        Set gameState = {}.%FromJSON(game.StateJson)
        Set winnerSide = gameState.%Get("winnerTeam", "")

        If winnerSide = "" {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "GAME_WINNER_NOT_FOUND"
            Set pResponse.ErrorMessage = "Finished game has no winnerTeam"
            Return $$$OK
        }

        If winnerSide = "A" {
            Set winnerTeamId = table.TeamAId
        } ElseIf winnerSide = "B" {
            Set winnerTeamId = table.TeamBId
        } Else {
            Set pResponse.Success = 0
            Set pResponse.StatusCode = 409
            Set pResponse.ErrorCode = "INVALID_GAME_WINNER"
            Set pResponse.ErrorMessage = "Invalid game winnerTeam: "_winnerSide
            Return $$$OK
        }

        TSTART

        Set table.Status = "finished"
        Set table.WinnerTeamId = winnerTeamId
        Set table.FinishedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = table.%Save()
        If $$$ISERR(sc) {
            TROLLBACK
            Return sc
        }

        Set sc = ..AdvanceTournamentIfRoundFinished(table.TournamentId, table.RoundNumber)
        If $$$ISERR(sc) {
            TROLLBACK
            Return sc
        }

        TCOMMIT

        Set tournament = ##class(Mus.Data.Tournament).%OpenId(table.TournamentId)
        Set tournamentJson = ..BuildTournamentJson(tournament)

        Set pResponse.Success = 1
        Set pResponse.StatusCode = 200
        Set pResponse.TournamentId = table.TournamentId
        Set pResponse.TableId = table.%Id()
        Set pResponse.WinnerTeamId = winnerTeamId
        Set pResponse.TournamentJson = tournamentJson.%ToJSON()

        Return $$$OK
    }
    Catch ex {
        If $TLEVEL {
            TROLLBACK
        }

        Set pResponse.Success = 0
        Set pResponse.StatusCode = 500
        Set pResponse.ErrorCode = "COMPLETE_TOURNAMENT_TABLE_EXCEPTION"
        Set pResponse.ErrorMessage = ex.DisplayString()

        Return $$$OK
    }
}

ClassMethod AdvanceTournamentIfRoundFinished(tournamentId As %Integer, roundNumber As %Integer) As %Status
{
    Set pendingCount = ..CountPendingTablesInRound(tournamentId, roundNumber)

    If pendingCount > 0 {
        Return $$$OK
    }

    Set winnerTeamIds = ..GetRoundWinnerTeamIds(tournamentId, roundNumber)

    If winnerTeamIds.%Size() = 0 {
        Return $$$ERROR($$$GeneralError, "Round has no winners")
    }

    /*
      Si solo queda un ganador, el torneo termina.
    */
    If winnerTeamIds.%Size() = 1 {
        Set winnerTeamId = winnerTeamIds.%Get(0)

        Set tournament = ##class(Mus.Data.Tournament).%OpenId(tournamentId)
        If '$IsObject(tournament) {
            Return $$$ERROR($$$GeneralError, "Tournament not found")
        }

        Set tournament.Status = "finished"
        Set tournament.FinishedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = tournament.%Save()
        If $$$ISERR(sc) {
            Return sc
        }

        Set team = ##class(Mus.Data.TournamentTeam).%OpenId(winnerTeamId)
        If $IsObject(team) {
            Set team.Status = "winner"
            Set sc = team.%Save()
            If $$$ISERR(sc) {
                Return sc
            }
        }

        Return ..MarkOtherTeamsEliminated(tournamentId, winnerTeamId)
    }

    /*
      Si hay varios ganadores, crear la siguiente ronda.
      No crearla si ya existe.
    */
    Set nextRoundNumber = roundNumber + 1

    If ..RoundExists(tournamentId, nextRoundNumber) {
        Return $$$OK
    }

    Return ..CreateRoundFromWinners(tournamentId, nextRoundNumber, winnerTeamIds)
}

ClassMethod CountPendingTablesInRound(tournamentId As %Integer, roundNumber As %Integer) As %Integer
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT COUNT(*) AS Cnt FROM Mus_Data.TournamentTable WHERE TournamentId = ? AND RoundNumber = ? AND Status <> ?",
        tournamentId,
        roundNumber,
        "finished"
    )

    If rs.%Next() {
        Return +rs.%Get("Cnt")
    }

    Return 0
}

ClassMethod GetRoundWinnerTeamIds(tournamentId As %Integer, roundNumber As %Integer) As %DynamicArray
{
    Set result = []

    Set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT WinnerTeamId FROM Mus_Data.TournamentTable WHERE TournamentId = ? AND RoundNumber = ? ORDER BY TableNumber",
        tournamentId,
        roundNumber
    )

    While rs.%Next() {
        Set winnerTeamId = +rs.%Get("WinnerTeamId")

        If winnerTeamId > 0 {
            Do result.%Push(winnerTeamId)
        }
    }

    Return result
}

ClassMethod RoundExists(tournamentId As %Integer, roundNumber As %Integer) As %Boolean
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT ID FROM Mus_Data.TournamentRound WHERE TournamentId = ? AND RoundNumber = ?",
        tournamentId,
        roundNumber
    )

    If rs.%Next() {
        Return 1
    }

    Return 0
}

ClassMethod CreateRoundFromWinners(tournamentId As %Integer, roundNumber As %Integer, winnerTeamIds As %DynamicArray) As %Status
{
    If '$IsObject(winnerTeamIds) {
        Return $$$ERROR($$$GeneralError, "winnerTeamIds is not an array")
    }

    If winnerTeamIds.%Size() < 2 {
        Return $$$ERROR($$$GeneralError, "Not enough winners to create next round")
    }

    If winnerTeamIds.%Size() # 2 '= 0 {
        Return $$$ERROR($$$GeneralError, "Winner count must be even")
    }

    Set tournament = ##class(Mus.Data.Tournament).%OpenId(tournamentId)
    If '$IsObject(tournament) {
        Return $$$ERROR($$$GeneralError, "Tournament not found")
    }

    Set round = ##class(Mus.Data.TournamentRound).%New()
    Set round.TournamentId = tournamentId
    Set round.RoundNumber = roundNumber
    Set round.Name = ..GetRoundName(roundNumber, winnerTeamIds.%Size())
    Set round.Status = "created"
    Set round.CreatedAt = $ZDATETIME($HOROLOG, 3)

    Set sc = round.%Save()
    If $$$ISERR(sc) {
        Return sc
    }

    Set roundId = round.%Id()
    Set tableNumber = 0

    For i=0:2:winnerTeamIds.%Size()-1 {
        Set tableNumber = tableNumber + 1

        Set table = ##class(Mus.Data.TournamentTable).%New()
        Set table.TournamentId = tournamentId
        Set table.RoundId = roundId
        Set table.RoundNumber = roundNumber
        Set table.TableNumber = tableNumber
        Set table.Status = "created"
        Set table.TeamAId = winnerTeamIds.%Get(i)
        Set table.TeamBId = winnerTeamIds.%Get(i + 1)
        Set table.WinnerTeamId = 0
        Set table.GameId = 0
        Set table.CreatedAt = $ZDATETIME($HOROLOG, 3)

        Set sc = table.%Save()
        If $$$ISERR(sc) {
            Return sc
        }
    }

    Set tournament.Status = "playing"
    Set sc = tournament.%Save()
    If $$$ISERR(sc) {
        Return sc
    }

    Return $$$OK
}

ClassMethod MarkOtherTeamsEliminated(tournamentId As %Integer, winnerTeamId As %Integer) As %Status
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT ID FROM Mus_Data.TournamentTeam WHERE TournamentId = ?",
        tournamentId
    )

    While rs.%Next() {
        Set teamId = +rs.%Get("ID")
        Set team = ##class(Mus.Data.TournamentTeam).%OpenId(teamId)

        If '$IsObject(team) {
            Continue
        }

        If teamId = winnerTeamId {
            Set team.Status = "winner"
        } Else {
            Set team.Status = "eliminated"
        }

        Set sc = team.%Save()
        If $$$ISERR(sc) {
            Return sc
        }
    }

    Return $$$OK
}

}
