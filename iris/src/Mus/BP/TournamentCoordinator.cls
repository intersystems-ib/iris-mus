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

    Set generatedBy = "llm"
    Set raw = ""
    Set systemPrompt = "Eres un narrador de Mus con tono castizo. Devuelve exclusivamente JSON valido, sin markdown. Crea nombres simpaticos, originales y castellanos para un torneo de Mus. No incluyas explicaciones." 
    Set userPrompt = "Genera un objeto JSON con tournamentName y teams. teams debe tener exactamente "_teamCount_" equipos. Cada equipo debe tener name y players. Cada players debe tener exactamente dos nombres. El equipo 1 debe representar al equipo del jugador humano y su primer jugador debe llamarse exactamente: "_humanPlayerName_
    "No generes perfiles de agente; solo nombres. Estilo de jugadores: nombres castellanos poco comunes, antiguos o en desuso, de tipo nombres de abuelos. No todos deben tener apodo: mezcla jugadores con nombre simple y jugadores con nombre mas apodo."_
    "Cuando un jugador tenga apodo, el apodo debe ir siempre entre comillas dobles dentro del nombre, por ejemplo: Ceferino ""el cura"", Atanasio ""el alguacil"", Eufrasio ""el avieso""."_
    "Equilibra apodos de oficio o cargo tradicional con apodos graciosos o de pueblo relacionado con los juegos de cartas."_
    "Evita que todos los nombres sigan el mismo patron. Evita nombres modernos, genericos o textos como Equipo agente, Pareja agente, Equipo 1, Jugador 1, Agente 2.1, Bot o IA."_
    "Estilo de equipos: cuadrillas, tabernas, cofradias, partidas antiguas, mus, baraja, piedras y amarracos."_
    "TargetScore: "_targetScore_"."
    Set sc = ##class(Mus.LLM.Client).ChatJson(systemPrompt, userPrompt, .raw)
    If $$$ISERR(sc) {
      Set generatedBy = "fallback"
      Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName)
    } Else {
      Try {
        Set generated = {}.%FromJSON(raw)
      } Catch exJson {
        Set generatedBy = "fallback"
        Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName)
      }
    }

    Set result = ..NormalizeGeneratedTournamentTeams(generated, teamCount, humanPlayerName)
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

Method NormalizeGeneratedTournamentTeams(generated As %DynamicObject, teamCount As %Integer, humanPlayerName As %String) As %DynamicObject
{
  If '$IsObject(generated) { Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName) }

  Set tournamentName = generated.%Get("tournamentName", "Torneo de los Amarracos Viejos") 
  If tournamentName = "" { Set tournamentName = "Torneo de los Amarracos Viejos" }

  Set teamsIn = generated.%Get("teams", "")
  If '$IsObject(teamsIn) { Set generated = ..BuildFallbackTournamentTeams(teamCount, humanPlayerName) Set teamsIn = generated.%Get("teams") }

  Set result = { "tournamentName": (tournamentName), "teams": [] }

  For i=0:1:teamCount-1 {
    Set seed = i + 1
    Set teamIn = ""
    If i < teamsIn.%Size() { Set teamIn = teamsIn.%Get(i) }
    If '$IsObject(teamIn) { Set teamIn = {} }

    Set teamName = teamIn.%Get("name", ..FallbackTeamName(seed)) 
    If teamName = "" { Set teamName = ..FallbackTeamName(seed) }

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

    If i = 0 { Set p1Name = humanPlayerName }
    If p1Name = "" { Set p1Name = ..FallbackPlayerName(seed, 1) } 
    If p2Name = "" { Set p2Name = ..FallbackPlayerName(seed, 2) }

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
    If i = 0 { Do team.%Get("players").%Get(0).%Remove("agentProfile") }

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

Method BuildFallbackTournamentTeams(teamCount As %Integer, humanPlayerName As %String) As %DynamicObject
{
 
    Set result = { "tournamentName": "Torneo de los Amarracos Viejos", "teams": [] } 
    For i=0:1:teamCount-1 { 
        Set seed = i + 1 
        Set teamName = ..FallbackTeamName(seed) 
        Set p1Name = $Select(i=0:humanPlayerName, 1:..FallbackPlayerName(seed, 1)) 
        Set p2Name = ..FallbackPlayerName(seed, 2) 
        Do result.%Get("teams").%Push({ "name": (teamName), "players": [ { "name": (p1Name) }, { "name": (p2Name) } ] }) 
    } 
    
    Return result
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
