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

    If pRequest.%IsA("Mus.Msg.GenerateTournamentTeamsRequest") { Return ..HandleGenerateTournamentTeams(pRequest, .pResponse) }

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

Method HandleGenerateTournamentTeams(pRequest As Mus.Msg.GenerateTournamentTeamsRequest, Output pResponse As Mus.Msg.GenerateTournamentTeamsResponse) As %Status
{
  Set pResponse = ##class(Mus.Msg.GenerateTournamentTeamsResponse).%New()

  Try {
    Set teamCount = +pRequest.TeamCount
    If teamCount < 2 { Set teamCount = 2 }
    If teamCount > 16 { Set teamCount = 16 }
    If '..IsPowerOfTwo(teamCount) { Set teamCount = 4 }

    Set targetScore = +pRequest.TargetScore
    If targetScore <= 0 { Set targetScore = 40 }

    Set humanPlayerName = pRequest.HumanPlayerName
    If humanPlayerName = "" { Set humanPlayerName = "Jugador humano" }

    /*
      Las exclusiones se usan SOLO localmente para normalizar y garantizar
      unicidad. Ya no se envian al LLM: reduce tokens, latencia y ruido.
    */
    Set exclusions = ..BuildTournamentGenerationExclusions(pRequest.CorrelationId)

    /*
      El LLM solo aporta creatividad nominal.
      IRIS construye equipos, inserta al humano, aplica perfiles y resuelve
      duplicados/colisiones.
    */
    Set generatedBy = "llm"
    Set raw = ""

    Set systemPrompt = "Devuelve exclusivamente JSON valido, sin markdown, comentarios ni explicaciones."

    Set playerCount = (teamCount * 2) - 1

    /*
      No mostramos arrays vacios como ejemplo porque modelos pequenos tienden
      a copiarlos literalmente. Describimos el contrato y las cardinalidades.
    */
    Set userPrompt = "Genera nombres para un torneo de Mus. "_
      "La respuesta debe ser un objeto JSON con exactamente tres campos: "_
      "tournamentName, teamNames y playerNames. "_
      "tournamentName debe ser un string no vacio con un nombre para el torneo. "_
      "teamNames debe ser un array con exactamente "_teamCount_" strings no vacios y todos distintos. "_
      "playerNames debe ser un array con exactamente "_playerCount_" strings no vacios y todos distintos. "_
      "Usa nombres normales de persona para playerNames. "_
      "Los nombres de equipo son libres. "_
      "No devuelvas arrays vacios. No anadas otros campos."

    Set temperature = 0.45
    Set sc = ##class(Mus.LLM.Client).ChatJson(systemPrompt, userPrompt, temperature, .raw)

    Set generated = ""
    Set parseOk = 0
    Set fallbackReason = ""
    Set generationDiagnostic = {}

    If $$$ISOK(sc) {
      Try {
        Set generated = {}.%FromJSON(raw)
        If $IsObject(generated) {
          Set parseOk = 1
        }
      } Catch exJson {
        Set parseOk = 0
        Set fallbackReason = "invalid_json"
      }
    } Else {
      Set fallbackReason = "llm_error"
    }

    If parseOk {
      /*
        Aceptamos tambien pequenas variaciones de contrato que pueda producir
        el modelo y las reducimos al formato simple esperado.
      */
      Set generated = ..NormalizeCompactNamePayload(generated)

      Set generationDiagnostic = {}
      Do generationDiagnostic.%Set("tournamentName", generated.%Get("tournamentName", ""))
      Set diagnosticTeams = generated.%Get("teamNames", "")
      Set diagnosticPlayers = generated.%Get("playerNames", "")
      Do generationDiagnostic.%Set("teamNameCount", $Select($IsObject(diagnosticTeams):diagnosticTeams.%Size(), 1:0))
      Do generationDiagnostic.%Set("playerNameCount", $Select($IsObject(diagnosticPlayers):diagnosticPlayers.%Size(), 1:0))

      Set compactCheck = ..ValidateCompactNamePayload(
        generated,
        teamCount,
        playerCount
      )

      If compactCheck.%Get("ok", 0) {
        Set generated = ..ExpandCompactGeneratedTournamentTeams(
          generated,
          teamCount,
          humanPlayerName
        )
      } Else {
        Set generatedBy = "fallback"
        Set fallbackReason = compactCheck.%Get("reason", "incomplete_llm_payload")
        Set generated = ..BuildFallbackTournamentTeams(
          teamCount,
          humanPlayerName,
          exclusions
        )
      }
    } Else {
      Set generatedBy = "fallback"
      Set generated = ..BuildFallbackTournamentTeams(
        teamCount,
        humanPlayerName,
        exclusions
      )
    }

    Set result = ..NormalizeGeneratedTournamentTeams(
      generated,
      teamCount,
      humanPlayerName,
      exclusions,
      generatedBy
    )

    Do result.%Set("generatedBy", generatedBy)
    If generatedBy = "fallback" {
      Do result.%Set("generationFallbackReason", fallbackReason)
    }

    Set origin = {}
    If generatedBy = "llm" {
      Do origin.%Set("tournament", "llm")
      Do origin.%Set("teams", "llm")
      Do origin.%Set("players", "llm")
    } Else {
      Do origin.%Set("tournament", "local")
      Do origin.%Set("teams", "local")
      Do origin.%Set("players", "local")
    }
    Do result.%Set("nameGeneration", origin)
    Do result.%Set("generationDiagnostic", generationDiagnostic)

    Set pResponse.Success = 1
    Set pResponse.StatusCode = 200
    Set pResponse.ResultJson = result.%ToJSON()

    Return $$$OK
  } Catch ex {
    Set pResponse.Success = 0
    Set pResponse.StatusCode = 500
    Set pResponse.ErrorCode = "GENERATE_TOURNAMENT_TEAMS_EXCEPTION"
    Set pResponse.ErrorMessage = ex.DisplayString()
    Return $$$OK
  }
}

Method IsPowerOfTwo(value As %Integer) As %Boolean
{
  If value < 2 { Return 0 }
  Set n = value
  While n > 1 {
    If n # 2 '= 0 { Return 0 }
    Set n = n \ 2
  }
  Return 1
}

Method NormalizeCompactNamePayload(generated As %DynamicObject) As %DynamicObject
{
  Set result = {
    "tournamentName": "",
    "teamNames": [],
    "playerNames": []
  }

  If '$IsObject(generated) {
    Return result
  }

  Set tournamentName = $ZSTRIP(
    generated.%Get("tournamentName", generated.%Get("name", "")),
    "<>W"
  )
  Do result.%Set("tournamentName", tournamentName)

  /*
    Formato preferido: teamNames = ["...", "..."]
    Compatibilidad: teams = ["..."] o [{ "name":"..." }]
  */
  Set teamNames = generated.%Get("teamNames", "")
  If ('$IsObject(teamNames)) || (teamNames.%Size() = 0) {
    Set alternateTeams = generated.%Get("teams", "")
    If $IsObject(alternateTeams) {
      Set teamNames = alternateTeams
    }
  }

  If $IsObject(teamNames) {
    For i=0:1:teamNames.%Size()-1 {
      Set item = teamNames.%Get(i)
      Set value = ""

      If $IsObject(item) {
        Set value = item.%Get("name", item.%Get("displayName", ""))
      } Else {
        Set value = item
      }

      Set value = $ZSTRIP(value, "<>W")
      If value '= "" {
        Do result.%Get("teamNames").%Push(value)
      }
    }
  }

  /*
    Formato preferido: playerNames = ["Ana","Luis",...]
    Compatibilidad: players = strings u objetos name/displayName.
  */
  Set playerNames = generated.%Get("playerNames", "")
  If ('$IsObject(playerNames)) || (playerNames.%Size() = 0) {
    Set alternatePlayers = generated.%Get("players", "")
    If $IsObject(alternatePlayers) {
      Set playerNames = alternatePlayers
    }
  }

  If $IsObject(playerNames) {
    For i=0:1:playerNames.%Size()-1 {
      Set item = playerNames.%Get(i)
      Set value = ""

      If $IsObject(item) {
        Set value = item.%Get("displayName", item.%Get("name", ""))
      } Else {
        Set value = item
      }

      Set value = $ZSTRIP(value, "<>W")
      If value '= "" {
        Do result.%Get("playerNames").%Push(value)
      }
    }
  }

  Return result
}

Method ValidateCompactNamePayload(generated As %DynamicObject, teamCount As %Integer, playerCount As %Integer) As %DynamicObject
{
  Set result = {
    "ok": 0,
    "reason": ""
  }

  If '$IsObject(generated) {
    Do result.%Set("reason", "payload_not_object")
    Return result
  }

  If $ZSTRIP(generated.%Get("tournamentName", ""), "<>W") = "" {
    Do result.%Set("reason", "missing_tournament_name")
    Return result
  }

  Set teamNames = generated.%Get("teamNames", "")
  If '$IsObject(teamNames) {
    Do result.%Set("reason", "missing_team_names")
    Return result
  }

  If teamNames.%Size() '= teamCount {
    Do result.%Set("reason", "wrong_team_name_count:"_teamNames.%Size()_"/"_teamCount)
    Return result
  }

  Set seenTeams = []
  For i=0:1:teamNames.%Size()-1 {
    Set value = $ZSTRIP(teamNames.%Get(i), "<>W")
    If value = "" {
      Do result.%Set("reason", "empty_team_name")
      Return result
    }
    If ..NameAlreadyUsed(value, seenTeams) {
      Do result.%Set("reason", "duplicate_team_name")
      Return result
    }
    Do seenTeams.%Push(value)
  }

  Set playerNames = generated.%Get("playerNames", "")
  If '$IsObject(playerNames) {
    Do result.%Set("reason", "missing_player_names")
    Return result
  }

  If playerNames.%Size() '= playerCount {
    Do result.%Set("reason", "wrong_player_name_count:"_playerNames.%Size()_"/"_playerCount)
    Return result
  }

  Set seenPlayers = []
  For i=0:1:playerNames.%Size()-1 {
    Set value = $ZSTRIP(playerNames.%Get(i), "<>W")
    If value = "" {
      Do result.%Set("reason", "empty_player_name")
      Return result
    }
    If ..NameAlreadyUsed(value, seenPlayers) {
      Do result.%Set("reason", "duplicate_player_name")
      Return result
    }
    Do seenPlayers.%Push(value)
  }

  Do result.%Set("ok", 1)
  Return result
}

Method ExpandCompactGeneratedTournamentTeams(generated As %DynamicObject, teamCount As %Integer, humanPlayerName As %String) As %DynamicObject
{
  Set result = { "tournamentName": "", "teams": [] }

  If '$IsObject(generated) {
    Return result
  }

  Do result.%Set("tournamentName", $ZSTRIP(generated.%Get("tournamentName", ""), "<>W"))

  Set teamNames = generated.%Get("teamNames", "")
  Set playerNames = generated.%Get("playerNames", "")
  Set playerIndex = 0

  For i=0:1:teamCount-1 {
    Set teamName = ""
    If $IsObject(teamNames), i < teamNames.%Size() {
      Set teamName = $ZSTRIP(teamNames.%Get(i), "<>W")
    }

    Set team = { "name": (teamName), "players": [] }

    If i = 0 {
      Do team.%Get("players").%Push({
        "name": (humanPlayerName),
        "nickname": ""
      })
    } Else {
      Set playerName = ""
      If $IsObject(playerNames), playerIndex < playerNames.%Size() {
        Set playerName = $ZSTRIP(playerNames.%Get(playerIndex), "<>W")
      }

      Do team.%Get("players").%Push({
        "name": (playerName),
        "nickname": ""
      })
      Set playerIndex = playerIndex + 1
    }

    Set playerName = ""
    If $IsObject(playerNames), playerIndex < playerNames.%Size() {
      Set playerName = $ZSTRIP(playerNames.%Get(playerIndex), "<>W")
    }

    Do team.%Get("players").%Push({
      "name": (playerName),
      "nickname": ""
    })
    Set playerIndex = playerIndex + 1

    Do result.%Get("teams").%Push(team)
  }

  Return result
}

Method NormalizeGeneratedPlayerObject(player As %DynamicAbstractObject) As %DynamicObject
{
  Set result = { "name": "", "nickname": "" }

  If '$IsObject(player) {
    Set name = $ZSTRIP(player, "<>W")
    Do result.%Set("name", name)
    Return result
  }

  Set name = $ZSTRIP(player.%Get("name", ""), "<>W")
  Set nickname = $ZSTRIP(player.%Get("nickname", ""), "<>W")

  /*
    Garantizamos que el nombre base no contenga comillas/apodo embebido.
    Si el LLM ignora el contrato, la normalizacion final podra aplicar fallback.
  */
  If name [ """" {
    Set name = $Piece(name, """", 1)
    Set name = $ZSTRIP(name, "<>W")
  }

  Do result.%Set("name", name)
  Do result.%Set("nickname", nickname)

  Return result
}

Method GeneratedTournamentNamesComplete(generated As %DynamicObject, teamCount As %Integer, largeGeneration As %Boolean = 0) As %Boolean
{
  If '$IsObject(generated) {
    Return 0
  }

  Set tournamentName = $ZSTRIP(generated.%Get("tournamentName", ""), "<>W")
  If tournamentName = "" {
    Return 0
  }

  Set teams = generated.%Get("teams", "")
  If '$IsObject(teams) || teams.%Size() < teamCount {
    Return 0
  }

  For i=0:1:teamCount-1 {
    Set team = teams.%Get(i)
    If '$IsObject(team) {
      Return 0
    }

    If $ZSTRIP(team.%Get("name", ""), "<>W") = "" {
      Return 0
    }

    Set players = team.%Get("players", "")
    If '$IsObject(players) || players.%Size() < 2 {
      Return 0
    }

    For j=0:1:1 {
      If (i = 0) && (j = 0) {
        Continue
      }

      Set displayName = ..GeneratedPlayerDisplayName(players.%Get(j))
      If $ZSTRIP(displayName, "<>W") = "" {
        Return 0
      }
    }
  }

  Return 1
}

Method NormalizeGeneratedTournamentTeams(generated As %DynamicObject, teamCount As %Integer, humanPlayerName As %String, exclusions As %DynamicObject = "", generationMode As %String = "fallback") As %DynamicObject
{
  If '$IsObject(exclusions) {
    Set exclusions = { "tournamentNames": [], "teamNames": [], "playerNames": [] }
  }

  If '$IsObject(generated) {
    Set generationMode = "fallback"
    Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName, exclusions)
  }

  Set usedTournamentNames = ..CloneDynamicArray(exclusions.%Get("tournamentNames"))
  Set usedTeamNames = ..CloneDynamicArray(exclusions.%Get("teamNames"))
  Set usedPlayerNames = ..CloneDynamicArray(exclusions.%Get("playerNames"))

  Set llmNames = (generationMode = "llm")
  Set localPlayers = (generationMode = "fallback")

  Set tournamentName = generated.%Get("tournamentName", "")

  If llmNames {
    Set tournamentName = ..EnsureUniqueLLMName(tournamentName, usedTournamentNames, "Torneo", 1)
  } Else {
    Set tournamentName = ..EnsureUniqueGeneratedName(tournamentName, usedTournamentNames, "Torneo", ..FallbackTournamentName($Random(999)), 1)
  }

  Set teamsIn = generated.%Get("teams", "")
  If '$IsObject(teamsIn) {
    Set generationMode = "fallback"
    Set llmNames = 0
    Set localPlayers = 1
    Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName, exclusions)
    Set teamsIn = generated.%Get("teams")
  }

  Set result = { "tournamentName": (tournamentName), "teams": [] }

  For i=0:1:teamCount-1 {
    Set seed = i + 1
    Set teamIn = ""
    If i < teamsIn.%Size() {
      Set teamIn = teamsIn.%Get(i)
    }
    If '$IsObject(teamIn) {
      Set teamIn = {}
    }

    Set teamName = teamIn.%Get("name", "")

    If llmNames {
      Set teamName = ..EnsureUniqueLLMName(teamName, usedTeamNames, "Equipo", seed)
    } Else {
      Set teamName = ..EnsureUniqueGeneratedName(teamName, usedTeamNames, "Equipo", ..FallbackTeamName(seed + $Random(99)), seed)
    }

    Set playersIn = teamIn.%Get("players", "")
    Set p1Name = ""
    Set p2Name = ""

    If $IsObject(playersIn) {
      If playersIn.%Size() > 0 {
        Set p1 = playersIn.%Get(0)
        Set p1Name = ..GeneratedPlayerDisplayName(p1)
      }

      If playersIn.%Size() > 1 {
        Set p2 = playersIn.%Get(1)
        Set p2Name = ..GeneratedPlayerDisplayName(p2)
      }
    }

    If i = 0 {
      Set p1Name = humanPlayerName
      Do ..PushUniqueName(usedPlayerNames, p1Name)
    } ElseIf localPlayers {
      Set p1Name = ..EnsureUniqueGeneratedName(
        "",
        usedPlayerNames,
        "Jugador",
        ..FallbackPlayerName(seed + $Random(999), 1),
        (seed * 2) - 1
      )
    } Else {
      Set p1Name = ..EnsureUniqueLLMName(
        p1Name,
        usedPlayerNames,
        "Jugador",
        (seed * 2) - 1
      )
    }

    If localPlayers {
      Set p2Name = ..EnsureUniqueGeneratedName(
        "",
        usedPlayerNames,
        "Jugador",
        ..FallbackPlayerName(seed + $Random(999), 2),
        seed * 2
      )
    } Else {
      Set p2Name = ..EnsureUniqueLLMName(
        p2Name,
        usedPlayerNames,
        "Jugador",
        seed * 2
      )
    }

    Set team = {
      "name": (teamName),
      "seed": (seed),
      "players": [
        {
          "playerNumber": 1,
          "displayName": (p1Name),
          "type": ($Select(i=0:"human", 1:"agent")),
          "agentProfile": ($Select(i=0:"", 1:..RandomAgentProfile()))
        },
        {
          "playerNumber": 2,
          "displayName": (p2Name),
          "type": "agent",
          "agentProfile": (..RandomAgentProfile())
        }
      ]
    }

    If i = 0 {
      Do team.%Get("players").%Get(0).%Remove("agentProfile")
    }

    Do result.%Get("teams").%Push(team)
  }

  Return result
}

Method GeneratedPlayerDisplayName(player As %DynamicAbstractObject) As %String
{
  If '$IsObject(player) {
    Return $ZSTRIP(player, "<>W")
  }

  Set displayName = $ZSTRIP(player.%Get("displayName", ""), "<>W")
  If displayName '= "" {
    Return displayName
  }

  Set name = $ZSTRIP(player.%Get("name", ""), "<>W")
  Set nickname = $ZSTRIP(player.%Get("nickname", ""), "<>W")

  If name = "" {
    Return ""
  }

  If nickname = "" {
    Return name
  }

  /*
    Las comillas se generan aqui, fuera del JSON producido por el LLM.
  */
  Return name_" """_nickname_""""
}

Method RandomAgentProfile() As %String
{
  Set n = $Random(4)
  Return $Select(n=0:"balanced", n=1:"aggressive", n=2:"conservative", 1:"bluffer")
}

Method FallbackTeamName(seed As %Integer) As %String
{
  /*
    Generador combinatorio: 8 prefijos x 24 referencias.
  */
  Set prefixes = [
    "Peña", "Cuadrilla", "Partida", "Ronda",
    "Mesa", "Amigos", "Cofradia", "Tertulia"
  ]

  Set references = [
    "del Olmo Viejo", "de la Fuente Seca", "del Campanario", "de la Venta Vieja",
    "del Casino", "de la Plaza Mayor", "de la Era", "del Portalon",
    "de San Roque", "del Molino", "del Fronton", "del Brasero",
    "de la Bodega", "del Camino Real", "de la Ermita", "del Pilon",
    "del Meson", "de la Alameda", "del Corral", "de la Estacion",
    "del Puente", "del Lavadero", "del Nogal", "de la Cuesta"
  ]

  Set prefixIndex = seed # prefixes.%Size()
  Set referenceIndex = ((seed * 7) + 3) # references.%Size()

  Return prefixes.%Get(prefixIndex)_" "_references.%Get(referenceIndex)
}

Method FallbackPlayerName(seed As %Integer, playerNumber As %Integer) As %String
{
  Set firstName = ..FallbackPlayerFirstName(seed, playerNumber)
  Set nickname = ..FallbackPlayerNickname(seed, playerNumber)

  If nickname = "" {
    Return firstName
  }

  Return firstName_" """_nickname_""""
}

Method FallbackPlayerFirstName(seed As %Integer, playerNumber As %Integer) As %String
{
  Set players = [
    "Ceferino", "Atanasio", "Gumersindo", "Eufrasio",
    "Primitivo", "Hermenegildo", "Aniceto", "Nicasio",
    "Telesforo", "Ciriaco", "Basilio", "Bonifacio",
    "Eleuterio", "Meliton", "Torcuato", "Apolinar",
    "Saturnino", "Genaro", "Venancio", "Laureano",
    "Fulgencio", "Abundio", "Sisenando", "Anselmo",
    "Eulogio", "Macario", "Faustino", "Isidoro",
    "Servando", "Crispin", "Fructuoso", "Ponciano"
  ]

  Set index = (((seed-1)*2)+(playerNumber-1)) # players.%Size()
  Return players.%Get(index)
}

Method FallbackPlayerNickname(seed As %Integer, playerNumber As %Integer) As %String
{
  Set nicknames = [
    "el cura", "el alguacil", "el boticario", "el sereno",
    "el sacristan", "el molinero", "el pregonero", "el barbero",
    "el campanero", "el tabernero", "el herrador", "el tratante",
    "el cartero", "el afilador", "el guarda", "el cestero",
    "el organista", "el carbonero", "el guarnicionero", "el esquilador",
    "el botijero", "el caminero", "el mayoral", "el recovero",
    "el tahonero", "el alpargatero", "el aperador", "el relojero",
    "el escribano", "el hortelano", "el sacamuelas", ""
  ]

  Set index = (((seed-1)*2)+(playerNumber-1)) # nicknames.%Size()
  Return nicknames.%Get(index)
}

Method BuildFallbackTournamentTeams(teamCount As %Integer, humanPlayerName As %String, exclusions As %DynamicObject = "") As %DynamicObject
{
  If '$IsObject(exclusions) {
    Set exclusions = { "tournamentNames": [], "teamNames": [], "playerNames": [] }
  }

  Set usedTournamentNames = ..CloneDynamicArray(exclusions.%Get("tournamentNames"))
  Set usedTeamNames = ..CloneDynamicArray(exclusions.%Get("teamNames"))
  Set usedPlayerNames = ..CloneDynamicArray(exclusions.%Get("playerNames"))

  Set tournamentName = ..EnsureUniqueGeneratedName("", usedTournamentNames, "Torneo", ..FallbackTournamentName($Random(999)), 1)
  Set result = { "tournamentName": (tournamentName), "teams": [] }

  Set offset = $Random(999)

  For i=0:1:teamCount-1 {
    Set seed = i + 1 + offset

    Set teamName = ..EnsureUniqueGeneratedName("", usedTeamNames, "Equipo", ..FallbackTeamName(seed), i + 1)

    If i = 0 {
      Set p1Name = humanPlayerName
      Set p1Nickname = ""
      Do ..PushUniqueName(usedPlayerNames, p1Name)
    } Else {
      Set p1FirstName = ..FallbackPlayerFirstName(seed, 1)
      Set p1Nickname = ..FallbackPlayerNickname(seed, 1)
      Set p1Display = ..GeneratedPlayerDisplayName({
        "name": (p1FirstName),
        "nickname": (p1Nickname)
      })
      Set p1Name = ..EnsureUniqueGeneratedName("", usedPlayerNames, "Jugador", p1Display, (i * 2) + 1)
    }

    Set p2FirstName = ..FallbackPlayerFirstName(seed, 2)
    Set p2Nickname = ..FallbackPlayerNickname(seed, 2)
    Set p2Display = ..GeneratedPlayerDisplayName({
      "name": (p2FirstName),
      "nickname": (p2Nickname)
    })
    Set p2Name = ..EnsureUniqueGeneratedName("", usedPlayerNames, "Jugador", p2Display, (i * 2) + 2)

    Do result.%Get("teams").%Push({
      "name": (teamName),
      "players": [
        { "displayName": (p1Name) },
        { "displayName": (p2Name) }
      ]
    })
  }

  Return result
}

Method BuildTournamentGenerationExclusions(correlationId As %String = "") As %DynamicObject
{
  Set exclusions = { "tournamentNames": [], "teamNames": [], "playerNames": [] }

  Try {
    Set listReq = ##class(Mus.Msg.ListTournamentsRequest).%New()
    Set listReq.CorrelationId = correlationId

    Set sc = ..SendRequestSync(
      "Mus.BO.TournamentPersistenceOperation",
      listReq,
      .listResp
    )

    If $$$ISERR(sc) {
      Return exclusions
    }

    If '$IsObject(listResp) {
      Return exclusions
    }

    If 'listResp.Success {
      Return exclusions
    }

    Set tournamentsJson = listResp.TournamentsJson
    If tournamentsJson = "" {
      Return exclusions
    }

    Set parsed = [].%FromJSON(tournamentsJson)
    Do ..CollectTournamentGenerationExclusions(parsed, exclusions)

    Return exclusions
  } Catch ex {
    Return exclusions
  }
}

Method CollectTournamentGenerationExclusions(value As %DynamicAbstractObject, exclusions As %DynamicObject)
{
  If '$IsObject(value) {
    Return
  }

  If value.%IsA("%DynamicArray") {
    For i=0:1:value.%Size()-1 {
      Set item = value.%Get(i)
      If $IsObject(item) {
        Do ..CollectTournamentGenerationExclusions(item, exclusions)
      }
    }

    Return
  }

  Do ..PushUniqueName(exclusions.%Get("tournamentNames"), value.%Get("name", value.%Get("tournamentName", "")))

  Set teams = value.%Get("teams", "")
  If '$IsObject(teams) {
    Return
  }

  For i=0:1:teams.%Size()-1 {
    Set team = teams.%Get(i)
    If '$IsObject(team) {
      Continue
    }

    Do ..PushUniqueName(exclusions.%Get("teamNames"), team.%Get("name", ""))

    Set players = team.%Get("players", "")
    If '$IsObject(players) {
      Continue
    }

    For j=0:1:players.%Size()-1 {
      Set player = players.%Get(j)

      If $IsObject(player) {
        Do ..PushUniqueName(exclusions.%Get("playerNames"), player.%Get("displayName", player.%Get("name", "")))
      } Else {
        Do ..PushUniqueName(exclusions.%Get("playerNames"), player)
      }
    }
  }
}

Method EnsureUniqueLLMName(name As %String, usedNames As %DynamicArray, kind As %String, index As %Integer) As %String
{
  Set clean = $ZSTRIP(name, "<>W")

  /*
    Los vacios no deben llegar aqui: GeneratedTournamentNamesComplete()
    fuerza fallback completo antes de normalizar.
  */
  If clean = "" {
    Set clean = kind_" "_index
  }

  If '..NameAlreadyUsed(clean, usedNames) {
    Do ..PushUniqueName(usedNames, clean)
    Return clean
  }

  /*
    Colision de un nombre generado por el LLM:
    conservamos el nombre y hacemos una modificacion minima, en vez de
    sustituirlo por un nombre del catalogo local.
  */
  For attempt=2:1:20 {
    Set candidate = clean_" "_attempt

    If '..NameAlreadyUsed(candidate, usedNames) {
      Do ..PushUniqueName(usedNames, candidate)
      Return candidate
    }
  }

  Set candidate = clean_" "_$Extract($System.Util.CreateGUID(), 2, 7)
  Do ..PushUniqueName(usedNames, candidate)
  Return candidate
}

Method EnsureUniqueGeneratedName(name As %String, usedNames As %DynamicArray, kind As %String, fallback As %String, index As %Integer) As %String
{
  Set clean = $ZSTRIP(name, "<>W")
  If clean = "" {
    Set clean = fallback
  }

  If clean = "" {
    Set clean = kind_" "_index
  }

  If '..NameAlreadyUsed(clean, usedNames) {
    Do ..PushUniqueName(usedNames, clean)
    Return clean
  }

  For attempt=1:1:20 {
    If kind = "Torneo" {
      Set candidate = ..FallbackTournamentName(index + attempt + $Random(999))
    } ElseIf kind = "Equipo" {
      Set candidate = ..FallbackTeamName(index + attempt + $Random(999))
    } Else {
      Set candidate = ..FallbackPlayerName(index + attempt + $Random(999), 1 + (attempt # 2))
    }

    If '..NameAlreadyUsed(candidate, usedNames) {
      Do ..PushUniqueName(usedNames, candidate)
      Return candidate
    }
  }

  Set candidate = kind_" "_index_" "_$Extract($System.Util.CreateGUID(), 2, 7)
  Do ..PushUniqueName(usedNames, candidate)

  Return candidate
}

Method NameAlreadyUsed(name As %String, usedNames As %DynamicArray) As %Boolean
{
  Set normalized = ..NormalizeNameForComparison(name)
  If normalized = "" {
    Return 0
  }

  For i=0:1:usedNames.%Size()-1 {
    If ..NormalizeNameForComparison(usedNames.%Get(i)) = normalized {
      Return 1
    }
  }

  Return 0
}

Method PushUniqueName(usedNames As %DynamicArray, name As %String)
{
  Set clean = $ZSTRIP(name, "<>W")
  If clean = "" {
    Return
  }

  If '..NameAlreadyUsed(clean, usedNames) {
    Do usedNames.%Push(clean)
  }
}

Method NormalizeNameForComparison(name As %String) As %String
{
  Set text = $ZCONVERT($ZSTRIP(name, "<>W"), "L")
  Set text = $Replace(text, """", "")
  Set text = $Replace(text, "'", "")
  Set text = $Replace(text, ".", "")
  Set text = $Replace(text, ",", "")
  Set text = $Replace(text, "  ", " ")

  Return text
}

Method CloneDynamicArray(source As %DynamicArray) As %DynamicArray
{
  Set clone = []

  If '$IsObject(source) {
    Return clone
  }

  For i=0:1:source.%Size()-1 {
    Do clone.%Push(source.%Get(i))
  }

  Return clone
}

Method DynamicArrayToPromptText(source As %DynamicArray) As %String
{
  If '$IsObject(source) {
    Return "ninguno"
  }

  If source.%Size() = 0 {
    Return "ninguno"
  }

  Set text = ""
  Set max = source.%Size()
  If max > 60 {
    Set max = 60
  }

  For i=0:1:max-1 {
    Set item = $ZSTRIP(source.%Get(i), "<>W")
    If item = "" {
      Continue
    }

    If text '= "" {
      Set text = text_", "
    }

    Set text = text_item
  }

  If text = "" {
    Return "ninguno"
  }

  Return text
}

Method DynamicArrayToPromptTextLimited(source As %DynamicArray, maxItems As %Integer = 10) As %String
{
  If '$IsObject(source) {
    Return "ninguno"
  }

  If source.%Size() = 0 {
    Return "ninguno"
  }

  If maxItems <= 0 {
    Set maxItems = 10
  }

  Set start = source.%Size() - maxItems
  If start < 0 {
    Set start = 0
  }

  Set text = ""

  For i=start:1:source.%Size()-1 {
    Set item = $ZSTRIP(source.%Get(i), "<>W")
    If item = "" {
      Continue
    }

    If text '= "" {
      Set text = text_", "
    }

    Set text = text_item
  }

  If text = "" {
    Return "ninguno"
  }

  Return text
}

Method FallbackTournamentName(seed As %Integer) As %String
{
  /*
    Generador combinatorio: 6 tipos x 24 referencias.
  */
  Set types = [
    "Campeonato de Mus",
    "Copa de Mus",
    "Memorial de Mus",
    "Torneo de Mus",
    "Trofeo de Mus",
    "Gran Partida de Mus"
  ]

  Set references = [
    "del Olmo Viejo", "de la Plaza Mayor", "de la Venta Vieja", "del Casino",
    "de San Roque", "del Campanario", "de la Fuente Seca", "del Molino",
    "del Portalon", "del Fronton", "del Brasero", "de la Bodega",
    "del Camino Real", "de la Ermita", "del Pilon", "del Meson",
    "de la Alameda", "del Corral", "de la Estacion", "del Puente",
    "del Lavadero", "del Nogal", "de la Cuesta", "de la Era"
  ]

  Set typeIndex = seed # types.%Size()
  Set referenceIndex = ((seed * 11) + 5) # references.%Size()

  Return types.%Get(typeIndex)_" "_references.%Get(referenceIndex)
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
