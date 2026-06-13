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

        Set sc = agent.UseToolSet("Mus.AI.ToolSet.MusPlayer")
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

    Set p = p_"Eres un agente experto jugando al Mus."_$Char(10)
    Set p = p_"Debes usar las herramientas disponibles para analizar el contexto del jugador."_$Char(10)
    Set p = p_"Nunca puedes elegir una accion fuera de las acciones legales."_$Char(10)
    Set p = p_"No ejecutes acciones sobre la partida. Solo recomienda una accion."_$Char(10)
    Set p = p_"Debes devolver exclusivamente JSON valido, sin markdown y sin texto adicional."_$Char(10)
    Set p = p_"Formato obligatorio:"_$Char(10)
    Set p = p_"{""actionType"":""pasar|envidar|querer|no_querer|ordago"",""amount"":0,""reason"":""..."",""confidence"":0.0}"_$Char(10)
    Set p = p_"Si solo hay una accion legal, debes elegir exactamente esa accion."_$Char(10)
    Set p = p_"Si recomiendas envidar, amount debe ser mayor o igual a 2."_$Char(10)
    Set p = p_"Si recomiendas pasar o no_querer, amount debe ser 0."_$Char(10)
    Set p = p_"Si recomiendas ordago, amount debe ser 999."_$Char(10)
    Set p = p_"Antes de responder, usa get_player_context para obtener el contexto."_$Char(10)
    Set p = p_"Puedes usar recommend_fallback_action si necesitas una decision segura."_$Char(10)
    Set p = p_"Debes usar validate_recommendation antes de dar la respuesta final."_$Char(10)

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

}
