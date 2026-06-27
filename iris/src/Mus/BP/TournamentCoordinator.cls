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

    Set exclusions = ..BuildTournamentGenerationExclusions(pRequest.CorrelationId)
    Set avoidTournamentNames = exclusions.%Get("tournamentNames")
    Set avoidTeamNames = exclusions.%Get("teamNames")
    Set avoidPlayerNames = exclusions.%Get("playerNames")

    /*
      No cambiamos la interfaz del front. Generamos una semilla en backend para
      que dos llamadas consecutivas no tengan exactamente el mismo prompt.
    */
    Set generationSeed = $System.Util.CreateGUID()_"-"_$Piece($Horolog,",",2)_"-"_$Random(999999)

    Set generatedBy = "llm"
    Set raw = ""

    Set systemPrompt = "Eres un narrador de Mus con tono castizo. Devuelve exclusivamente JSON valido, sin markdown. Crea nombres simpaticos, originales y castellanos para un torneo de Mus. No incluyas explicaciones. Tu prioridad es no reutilizar nombres ya existentes."

    Set userPrompt = "Genera un objeto JSON con tournamentName y teams. teams debe tener exactamente "_teamCount_" equipos. Cada equipo debe tener name y players. Cada players debe tener exactamente dos nombres. El equipo 1 debe representar al equipo del jugador humano y su primer jugador debe llamarse exactamente: "_humanPlayerName_"."_
    " No generes perfiles de agente; solo nombres."_
    " Semilla de variacion obligatoria: "_generationSeed_"."_
    " Debes generar un nombre de torneo diferente de estos nombres ya usados: "_..DynamicArrayToPromptText(avoidTournamentNames)_"."_
    " Debes generar nombres de equipos diferentes de estos nombres ya usados: "_..DynamicArrayToPromptText(avoidTeamNames)_"."_
    " Debes generar nombres de jugadores diferentes de estos nombres ya usados, salvo el jugador humano indicado: "_..DynamicArrayToPromptText(avoidPlayerNames)_"."_
    " No reutilices literalmente nombres de torneos, equipos o jugadores de la lista anterior."_
    " Todos los nombres de equipos de la respuesta deben ser unicos entre si."_
    " Todos los nombres de jugadores de la respuesta deben ser unicos entre si."_
    " Estilo de jugadores: nombres castellanos poco comunes, antiguos o en desuso, de tipo nombres de abuelos. No todos deben tener apodo: mezcla jugadores con nombre simple y jugadores con nombre mas apodo."_
    " Cuando un jugador tenga apodo, el apodo debe ir siempre entre comillas dobles dentro del nombre, por ejemplo: Ceferino ""el cura"", Atanasio ""el alguacil"", Eufrasio ""el avieso""."_
    " Equilibra apodos de oficio o cargo tradicional con apodos graciosos o de pueblo relacionado con los juegos de cartas."_
    " Evita que todos los nombres sigan el mismo patron. Evita nombres modernos, genericos o textos como Equipo agente, Pareja agente, Equipo 1, Jugador 1, Agente 2.1, Bot o IA."_
    " Estilo de equipos: cuadrillas, tabernas, cofradias, partidas antiguas, mus, baraja, piedras y amarracos."_
    " TargetScore: "_targetScore_"."

    Set temperature = 0.95
    Set sc = ##class(Mus.LLM.Client).ChatJson(systemPrompt, userPrompt, temperature, .raw)

    If $$$ISERR(sc) {
      Set generatedBy = "fallback"
      Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName, exclusions)
    } Else {
      Try {
        Set generated = {}.%FromJSON(raw)
      } Catch exJson {
        Set generatedBy = "fallback"
        Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName, exclusions)
      }
    }

    Set result = ..NormalizeGeneratedTournamentTeams(generated, teamCount, humanPlayerName, exclusions)
    Do result.%Set("generatedBy", generatedBy)

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

Method NormalizeGeneratedTournamentTeams(generated As %DynamicObject, teamCount As %Integer, humanPlayerName As %String, exclusions As %DynamicObject = "") As %DynamicObject
{
  If '$IsObject(exclusions) {
    Set exclusions = { "tournamentNames": [], "teamNames": [], "playerNames": [] }
  }

  If '$IsObject(generated) {
    Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName, exclusions)
  }

  Set usedTournamentNames = ..CloneDynamicArray(exclusions.%Get("tournamentNames"))
  Set usedTeamNames = ..CloneDynamicArray(exclusions.%Get("teamNames"))
  Set usedPlayerNames = ..CloneDynamicArray(exclusions.%Get("playerNames"))

  Set tournamentName = generated.%Get("tournamentName", "")
  Set tournamentName = ..EnsureUniqueGeneratedName(tournamentName, usedTournamentNames, "Torneo", "Torneo de Mus", 1)

  Set teamsIn = generated.%Get("teams", "")
  If '$IsObject(teamsIn) {
    Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName, exclusions)
    Set teamsIn = generated.%Get("teams")
  }

  Set result = { "tournamentName": (tournamentName), "teams": [] }

  For i=0:1:teamCount-1 {
    Set seed = i + 1
    Set teamIn = ""
    If i < teamsIn.%Size() { Set teamIn = teamsIn.%Get(i) }
    If '$IsObject(teamIn) { Set teamIn = {} }

    Set teamName = teamIn.%Get("name", "")
    Set teamName = ..EnsureUniqueGeneratedName(teamName, usedTeamNames, "Equipo", ..FallbackTeamName(seed + $Random(99)), seed)

    Set playersIn = teamIn.%Get("players", "")
    Set p1Name = ""
    Set p2Name = ""

    If $IsObject(playersIn) {
      If playersIn.%Size() > 0 {
        Set p1 = playersIn.%Get(0)
        If $IsObject(p1) { Set p1Name = p1.%Get("displayName", p1.%Get("name", "")) } Else { Set p1Name = p1 }
      }

      If playersIn.%Size() > 1 {
        Set p2 = playersIn.%Get(1)
        If $IsObject(p2) { Set p2Name = p2.%Get("displayName", p2.%Get("name", "")) } Else { Set p2Name = p2 }
      }
    }

    If i = 0 {
      Set p1Name = humanPlayerName
      Do ..PushUniqueName(usedPlayerNames, p1Name)
    } Else {
      Set p1Name = ..EnsureUniqueGeneratedName(p1Name, usedPlayerNames, "Jugador", ..FallbackPlayerName(seed + $Random(99), 1), (seed * 2) - 1)
    }

    Set p2Name = ..EnsureUniqueGeneratedName(p2Name, usedPlayerNames, "Jugador", ..FallbackPlayerName(seed + $Random(99), 2), seed * 2)

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

Method RandomAgentProfile() As %String
{
  Set n = $Random(4)
  Return $Select(n=0:"balanced", n=1:"aggressive", n=2:"conservative", 1:"bluffer")
}

Method FallbackTeamName(seed As %Integer) As %String
{
 
    Set names = ["La Cuadrilla del Boticario", "Los del Portalon Viejo", "Cofradia del Amarraco", "La Taberna del Sereno", "Los Duples del Campanario", "Partida de la Fuente Seca", "Los del Esquinazo", "La Mesa del Sacristan", "Los Faroles del Casino", "Cuadrilla de la Era", "Los Pares del Molino", "La Ronda del Alguacil", "Los Treinta y Una", "La Peña del Chato", "Amarracos de Ultramarinos", "Los del Brasero"] 
    Return names.%Get((seed-1) # names.%Size())
}

Method FallbackPlayerName(seed As %Integer, playerNumber As %Integer) As %String
{
 
    Set players = ["Ceferino el cura", "Atanasio el alguacil", "Gumersindo el boticario", "Eufrasio el sereno", "Don Primitivo el sacristan", "Hermenegildo el molinero", "Aniceto el pregonero", "Nicasio el barbero", "Telesforo el campanero", "Ciriaco el tabernero", "Basilio el herrador", "Bonifacio el tratante", "Eleuterio el cartero", "Meliton el afilador", "Torcuato el guarda", "Apolinar el cestero", "Saturnino el organista", "Genaro el carbonero", "Venancio el guarnicionero", "Laureano el esquilador", "Fulgencio el botijero", "Abundio el peon caminero", "Sisenando el alguacilillo", "Anselmo el mayoral", "Eulogio el recovero", "Macario el tahonero", "Faustino el alpargatero", "Isidoro el aperador", "Servando el relojero", "Crispin el escribano", "Fructuoso el hortelano", "Ponciano el sacamuelas"] 
    Set index = (((seed-1)*2)+(playerNumber-1)) # players.%Size() Return players.%Get(index)
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
      Do ..PushUniqueName(usedPlayerNames, p1Name)
    } Else {
      Set p1Name = ..EnsureUniqueGeneratedName("", usedPlayerNames, "Jugador", ..FallbackPlayerName(seed, 1), (i * 2) + 1)
    }

    Set p2Name = ..EnsureUniqueGeneratedName("", usedPlayerNames, "Jugador", ..FallbackPlayerName(seed, 2), (i * 2) + 2)

    Do result.%Get("teams").%Push({
      "name": (teamName),
      "players": [
        { "name": (p1Name) },
        { "name": (p2Name) }
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

Method FallbackTournamentName(seed As %Integer) As %String
{
  Set names = [
    "Torneo del Envite Largo",
    "Memorial de la Piedra Torcida",
    "Copa del Amarraco Perdido",
    "Gran Mus del Portalon",
    "Desafio de la Taberna Vieja",
    "Liga de los Ordagueadores",
    "Torneo de la Baraja Gastada",
    "Copa de la Fuente Seca",
    "Partida Mayor del Casino",
    "Trofeo del Farol Bueno",
    "Campeonato del Mantel Verde",
    "Torneo de la Seña Fina",
    "Copa del Duple Travieso",
    "Gran Premio de los Pares",
    "Justa del Punto Treinta",
    "Torneo del Mus Cerrado"
  ]

  Return names.%Get(seed # names.%Size())
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
