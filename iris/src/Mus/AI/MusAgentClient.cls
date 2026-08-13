Class Mus.AI.MusAgentClient Extends %RegisteredObject
{

Parameter ProviderName = "nim";

Parameter BaseURL = "http://llama:8000/v1";

Parameter ApiKey = "not-needed";

Parameter Model = "qwen3-4b-agent";

Parameter Temperature = 0.2;

Parameter MaxIterations = 4;

ClassMethod RecommendAction(gameStateJson As %String, playerId As %String, Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Try {
        If gameStateJson = "" {
            Return $$$ERROR($$$GeneralError, "gameStateJson is empty")
        }

        If playerId = "" {
            Return $$$ERROR($$$GeneralError, "playerId is empty")
        }

        Set provider = ..CreateProvider()
        If '$IsObject(provider) {
            Return $$$ERROR($$$GeneralError, "AI Hub provider could not be created")
        }

        Set agent = ##class(%AI.Agent).%New(provider)
        If '$IsObject(agent) {
            Return $$$ERROR($$$GeneralError, "AI Hub agent could not be created")
        }

        Set sc = agent.UseToolSet("Mus.AI.ToolSet.MusHandStrength")
        If $$$ISERR(sc) {
            Return sc
        }

        Set config = {
            "model": (..#Model),
            "temperature": (+..#Temperature),
            "systemPrompt": (..BuildSystemPrompt())
        }

        Set session = agent.CreateSession(config)
        If '$IsObject(session) {
            Return $$$ERROR($$$GeneralError, "AI Hub agent session could not be created")
        }

        Set goal = ..BuildGoal(gameStateJson, playerId)

        Set response = agent.Run(
            session,
            goal,
            ..#MaxIterations
        )

        If '$IsObject(response) {
            Return $$$ERROR($$$GeneralError, "AI Hub agent returned no response object")
        }

        Set responseText = ..ExtractResponseText(response)

        If responseText = "" {
            Return $$$ERROR($$$GeneralError, "AI Hub agent returned empty response")
        }

        Set rawResponse = ..ExtractJsonObject(responseText)

        If rawResponse = "" {
            Return $$$ERROR($$$GeneralError, "AI Hub agent returned no JSON object. Raw response: "_responseText)
        }

        Return $$$OK
    }
    Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod CreateProvider() As %RegisteredObject
{
    Set settings = {
        "base_url": (..#BaseURL),
        "api_key": (..#ApiKey)
    }

    Return ##class(%AI.Provider).Create(..#ProviderName, settings)
}

ClassMethod BuildSystemPrompt() As %String
{
    Set p = ""

    Set p = p_"Eres un jugador experto de Mus."_$Char(10)
    Set p = p_"Puedes usar como maximo una herramienta: evaluate_play_strength."_$Char(10)
    Set p = p_"La herramienta solo evalua cartas y lance: no recibe contexto de partida."_$Char(10)
    Set p = p_"No pidas mas herramientas."_$Char(10)
    Set p = p_"Despues de usar la herramienta, responde con una unica recomendacion JSON."_$Char(10)
    Set p = p_"Nunca elijas una accion fuera de legalActions."_$Char(10)
    Set p = p_"Devuelve exclusivamente JSON valido, sin markdown ni texto adicional."_$Char(10)
    Set p = p_"Formato obligatorio:"_$Char(10)
    Set p = p_"{""actionType"":""pasar|envidar|querer|no_querer|ordago|descartar|cortar_mus"",""amount"":0,""discards"":[],""reason"":""..."",""confidence"":0.0}"_$Char(10)

    Return p
}

ClassMethod BuildGoalFromContext(context As %DynamicObject, playerId As %String) As %String
{
    Set p = ""

    Set cards = context.%Get("cards", [])
    Set play = context.%Get("phase", "")
    Set legalActions = context.%Get("legalActions", [])

    Set p = p_"Jugador: "_playerId_$Char(10)
    Set p = p_"Cartas: "_cards.%ToJSON()_$Char(10)
    Set p = p_"Lance: "_play_$Char(10)
    Set p = p_"Acciones legales: "_legalActions.%ToJSON()_$Char(10)
    Set p = p_"Usa evaluate_play_strength con esas cartas y ese lance si necesitas calibrar la fuerza."_$Char(10)
    Set p = p_"Responde solo JSON."_$Char(10)

    Return p
}

ClassMethod BuildGoal(gameStateJson As %String, playerId As %String) As %String
{
    Set p = ""

    Set p = p_"Recomienda una accion para el jugador "_playerId_" en esta partida de Mus."_$Char(10)
    Set p = p_"Usa las herramientas disponibles para:"_$Char(10)
    Set p = p_"1. Obtener el contexto del jugador."_$Char(10)
    Set p = p_"2. Identificar acciones legales."_$Char(10)
    Set p = p_"3. Decidir una accion."_$Char(10)
    Set p = p_"4. Validarla."_$Char(10)
    Set p = p_"Presta especial atencion a scorePressure y bettingGuidance."_$Char(10)
    Set p = p_"Si scorePressure.ordagoPressure es high o desperation, evalua si ordago es apropiado."_$Char(10)
    Set p = p_"Devuelve solo el JSON final de recomendacion."_$Char(10)
    Set p = p_$Char(10)
    Set p = p_"playerId:"_$Char(10)
    Set p = p_playerId_$Char(10)
    Set p = p_$Char(10)
    Set p = p_"gameStateJson:"_$Char(10)
    Set p = p_gameStateJson

    Return p
}

ClassMethod ExtractResponseText(response As %RegisteredObject) As %String
{
    Try {
        Set text = response.Text
        If text '= "" {
            Return text
        }
    }
    Catch ex1 {
    }

    Try {
        Set text = response.Content
        If text '= "" {
            Return text
        }
    }
    Catch ex2 {
    }

    Try {
        Set text = response.Message
        If text '= "" {
            Return text
        }
    }
    Catch ex3 {
    }

    Try {
        Set text = response.Result
        If text '= "" {
            Return text
        }
    }
    Catch ex4 {
    }

    Try {
        Set text = response.Output
        If text '= "" {
            Return text
        }
    }
    Catch ex5 {
    }

    Try {
        Set text = response.%ToJSON()
        If text '= "" {
            Return text
        }
    }
    Catch ex6 {
    }

    Return ""
}

ClassMethod ExtractJsonObject(text As %String) As %String
{
    Set text = $ZSTRIP(text, "<W")

    If text = "" {
        Return ""
    }

    If $Extract(text, 1) = "{" {
        Return text
    }

    Set first = $Find(text, "{")
    If first = 0 {
        Return ""
    }

    Set start = first - 1
    Set last = 0

    For i=$Length(text):-1:1 {
        If $Extract(text, i) = "}" {
            Set last = i
            Return $Extract(text, start, last)
        }
    }

    Return ""
}

ClassMethod Ping(Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Set dummyState = {
        "status": "started",
        "phase": "grande",
        "turnPlayerId": "P1",
        "score": {
            "teamA": 0,
            "teamB": 0
        },
        "players": [
            {
                "id": "P1",
                "name": "Player 1",
                "team": "A"
            },
            {
                "id": "P2",
                "name": "Player 2",
                "team": "B"
            },
            {
                "id": "P3",
                "name": "Player 3",
                "team": "A"
            },
            {
                "id": "P4",
                "name": "Player 4",
                "team": "B"
            }
        ],
        "hand": {
            "phase": "grande",
            "turnPlayerId": "P1",
            "cards": {
                "P1": [
                    "12O",
                    "3B",
                    "7C",
                    "5E"
                ],
                "P2": [
                    "1O",
                    "2B",
                    "4C",
                    "6E"
                ],
                "P3": [
                    "10O",
                    "11B",
                    "7E",
                    "5C"
                ],
                "P4": [
                    "1B",
                    "4O",
                    "6C",
                    "12E"
                ]
            },
            "phaseState": {
                "name": "grande",
                "status": "open",
                "passedPlayers": [],
                "pendingBet": null
            }
        }
    }

    Return ..RecommendAction(dummyState.%ToJSON(), "P1", .rawResponse)
}

ClassMethod RecommendActionWithHandStrengthTool(llmContext As %DynamicObject, playerId As %String, Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Try {
        If '$IsObject(llmContext) {
            Return $$$ERROR($$$GeneralError, "llmContext is not an object")
        }

        Set provider = ..CreateProvider()

        If '$IsObject(provider) {
            Return $$$ERROR($$$GeneralError, "AI Hub provider could not be created")
        }

        Set agent = ##class(%AI.Agent).%New(provider)

        If '$IsObject(agent) {
            Return $$$ERROR($$$GeneralError, "AI Hub agent could not be created")
        }

        /*
          ToolSet ultraligero: sólo evaluate_play_strength.
          No usar Mus.AI.ToolSet.MusPlayer aquí.
        */
        Set sc = agent.UseToolSet("Mus.AI.ToolSet.MusHandStrength")

        If $$$ISERR(sc) {
            Return sc
        }

        Set config = {
            "model": (..#Model),
            "temperature": (+..#Temperature),
            "systemPrompt": (..BuildHandStrengthAgentSystemPrompt())
        }

        Set session = agent.CreateSession(config)

        If '$IsObject(session) {
            Return $$$ERROR($$$GeneralError, "AI Hub agent session could not be created")
        }

        Set goal = ..BuildHandStrengthAgentGoal(llmContext, playerId)

        /*
          2 iteraciones:
          1) el modelo puede llamar evaluate_play_strength
          2) el modelo devuelve JSON final
        */
        Set response = agent.Run(session, goal, 2)

        If '$IsObject(response) {
            Return $$$ERROR($$$GeneralError, "AI Hub agent returned no response object")
        }

        Set responseText = ..ExtractResponseText(response)

        If responseText = "" {
            Return $$$ERROR($$$GeneralError, "AI Hub agent returned empty response")
        }

        Set json = ..ExtractJsonObject(responseText)

        If json = "" {
            Return $$$ERROR($$$GeneralError, "AI Hub agent returned no JSON object. Raw response: "_responseText)
        }

        Set rawResponse = json
        Return $$$OK
    } Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod BuildHandStrengthAgentSystemPrompt() As %String
{
    Set p = ""

    Set p = p_"Eres un agente jugador de Mus."_$Char(10)
    Set p = p_"Debes recomendar una unica accion para el jugador actual."_$Char(10)
    Set p = p_"Puedes usar como maximo una herramienta."_$Char(10)
    Set p = p_"La unica herramienta disponible debe ser evaluate_play_strength."_$Char(10)
    Set p = p_"La herramienta evalua la fuerza de las cartas para el lance actual y devuelve very strong, strong, neutral, weak o very weak."_$Char(10)
    Set p = p_"No pidas contexto adicional."_$Char(10)
    Set p = p_"No inventes acciones fuera de legalActions."_$Char(10)
    Set p = p_"Despues de usar la herramienta, devuelve exclusivamente JSON valido, sin markdown ni texto adicional."_$Char(10)

    Set p = p_"Formato obligatorio:"_$Char(10)
    Set p = p_"{""actionType"":""pasar|envidar|querer|no_querer|ordago|descartar|cortar_mus"",""amount"":0,""discards"":[],""reason"":""..."",""confidence"":0.0}"_$Char(10)

    Set p = p_"Reglas:"_$Char(10)
    Set p = p_"- actionType debe estar en legalActions."_$Char(10)
    Set p = p_"- pasar y no_querer usan amount 0."_$Char(10)
    Set p = p_"- querer usa pendingBet.amount si existe."_$Char(10)
    Set p = p_"- envidar usa amount minimo 2 si no hay pendingBet."_$Char(10)
    Set p = p_"- envidar con pendingBet debe usar amount mayor que pendingBet.amount."_$Char(10)
    Set p = p_"- ordago usa amount 999."_$Char(10)
    Set p = p_"- cortar_mus usa discards []."_$Char(10)
    Set p = p_"- descartar usa cartas exactas de cards."_$Char(10)

    Return p
}

ClassMethod BuildHandStrengthAgentGoal(llmContext As %DynamicObject, playerId As %String) As %String
{
    Set p = ""

    Set phase = llmContext.%Get("phase", "")
    Set cards = llmContext.%Get("cards", [])
    Set legalActions = llmContext.%Get("legalActions", [])

    Set p = p_"Jugador: "_playerId_$Char(10)
    Set p = p_"Lance actual: "_phase_$Char(10)
    Set p = p_"Cartas: "_cards.%ToJSON()_$Char(10)
    Set p = p_"Acciones legales: "_legalActions.%ToJSON()_$Char(10)

    Set pendingBet = llmContext.%Get("pendingBet", "")
    If $IsObject(pendingBet) {
        Set p = p_"pendingBet: "_pendingBet.%ToJSON()_$Char(10)
    } Else {
        Set p = p_"pendingBet: {}"_$Char(10)
    }

    Set profile = llmContext.%Get("profile", "")
    If $IsObject(profile) {
        Set p = p_"profile: "_profile.%ToJSON()_$Char(10)
    }

    Set scorePressure = llmContext.%Get("scorePressure", "")
    If $IsObject(scorePressure) {
        Set p = p_"scorePressure: "_scorePressure.%ToJSON()_$Char(10)
    }

    /*
      Dejamos claro cómo usar la única tool.
      El agente no necesita contexto completo.
    */
    Set p = p_$Char(10)
    Set p = p_"Puedes llamar evaluate_play_strength con:"_$Char(10)
    Set p = p_"{""cards"": "_cards.%ToJSON()_", ""play"": """_phase_"""}"_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Decide una accion legal y responde solo JSON."_$Char(10)

    Return p
}

}
