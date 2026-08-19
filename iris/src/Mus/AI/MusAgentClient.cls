Class Mus.AI.MusAgentClient Extends %RegisteredObject
{

Parameter ProviderName = "nim";

Parameter BaseURL = "http://llama:8000/v1";

Parameter ApiKey = "not-needed";

Parameter Model = "qwen3-4b-agent";

Parameter Temperature = 0.2;

Parameter MaxIterations = 3;

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

        /*
          Compatibilidad con llamadas antiguas: ya no enviamos gameStateJson completo
          al agente. IRIS construye contexto, lo compacta y el agente usa solo tools
          ligeras.
        */
        Set gameState = {}.%FromJSON(gameStateJson)
        Set context = ##class(Mus.Agent.ContextBuilder).BuildForPlayer(gameState, playerId)
        Set llmContext = ##class(Mus.Agent.PlayerAgent).BuildMinimalLLMContext(context)

        Return ..RecommendActionWithLightTools(llmContext, playerId, .rawResponse)
    } Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod RecommendActionWithLightTools(llmContext As %DynamicObject, playerId As %String, Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Try {
        If '$IsObject(llmContext) {
            Return $$$ERROR($$$GeneralError, "llmContext is not an object")
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

        Set sc = agent.UseToolSet("Mus.AI.ToolSet.MusLightDecision")
        If $$$ISERR(sc) {
            Return sc
        }

        Set config = {
            "model": (..#Model),
            "temperature": (+..#Temperature),
            "systemPrompt": (..BuildLightDecisionAgentSystemPrompt())
        }

        Set session = agent.CreateSession(config)
        If '$IsObject(session) {
            Return $$$ERROR($$$GeneralError, "AI Hub agent session could not be created")
        }

        Set goal = ..BuildLightDecisionAgentGoal(llmContext, playerId)
        Set response = agent.Run(session, goal, ..#MaxIterations)

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

/* Wrapper temporal para no romper referencias antiguas mientras se migra PlayerAgent. */
ClassMethod RecommendActionWithHandStrengthTool(llmContext As %DynamicObject, playerId As %String, Output rawResponse As %String) As %Status
{
    Return ..RecommendActionWithLightTools(llmContext, playerId, .rawResponse)
}

ClassMethod CreateProvider() As %RegisteredObject
{
    Set settings = {
        "base_url": (..#BaseURL),
        "api_key": (..#ApiKey)
    }

    Return ##class(%AI.Provider).Create(..#ProviderName, settings)
}

ClassMethod BuildLightDecisionAgentSystemPrompt() As %String
{
    Set p = ""

    Set p = p_"Eres un agente jugador de Mus."_$Char(10)
    Set p = p_"Debes recomendar una unica accion para el jugador actual."_$Char(10)
    Set p = p_"No recibiras gameStateJson ni contexto completo; solo un contexto compacto."_$Char(10)
    Set p = p_"Herramientas disponibles: evaluate_play_strength, evaluate_score_pressure y evaluate_discard_hand_value."_$Char(10)
    Set p = p_"No pidas historial, jugadores completos ni contexto adicional."_$Char(10)
    Set p = p_"Nunca elijas una accion fuera de legalActions."_$Char(10)
    Set p = p_"Devuelve exclusivamente JSON valido, sin markdown ni texto adicional."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Regla obligatoria de herramientas:"_$Char(10)
    Set p = p_"- Si phase es grande, chica, pares, juego o punto, antes de decidir debes llamar evaluate_play_strength(cards, phase)."_$Char(10)
    Set p = p_"- Si phase es descartes, antes de decidir debes llamar evaluate_discard_hand_value(cards, isLastToSpeak, rivalMusCount, teammateMusCount)."_$Char(10)
    Set p = p_"- Si legalActions contiene ordago, antes de elegir ordago debes llamar evaluate_score_pressure(myScore, opponentScore, targetScore)."_$Char(10)
    Set p = p_"- No decidas por intuicion si una herramienta aplicable esta disponible."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Regla fuerte para ordago:"_$Char(10)
    Set p = p_"- ordago solo puede elegirse si aparece en legalActions."_$Char(10)
    Set p = p_"- ordago requiere normalmente fuerza strong o very strong."_$Char(10)
    Set p = p_"- ordago requiere normalmente presion high o very high."_$Char(10)
    Set p = p_"- con presion low o medium, evita ordago."_$Char(10)
    Set p = p_"- con fuerza weak, very weak o neutral, evita ordago incluso con presion alta salvo caso desesperado muy claro."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Regla para descartes:"_$Char(10)
    Set p = p_"- En phase descartes, actionType debe ser descartar o cortar_mus."_$Char(10)
    Set p = p_"- Si evaluate_discard_hand_value devuelve recommendedBias=cut_mus, normalmente debes elegir cortar_mus."_$Char(10)
    Set p = p_"- Si devuelve recommendedBias=ask_mus, normalmente debes elegir descartar."_$Char(10)
    Set p = p_"- Si devuelve recommendedBias=borderline_cut, cortar_mus es razonable, especialmente si eres ultimo en hablar."_$Char(10)
    Set p = p_"- Si eliges descartar, usa solo cartas exactas de cards."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Formato obligatorio:"_$Char(10)
    Set p = p_"{""actionType"":""pasar|envidar|querer|no_querer|ordago|descartar|cortar_mus"",""amount"":0,""discards"":[],""reason"":""..."",""confidence"":0.0}"_$Char(10)

    Set p = p_"Reglas de importes:"_$Char(10)
    Set p = p_"- pasar y no_querer usan amount 0."_$Char(10)
    Set p = p_"- querer usa pendingBet.amount si existe."_$Char(10)
    Set p = p_"- envidar sin pendingBet usa amount minimo 2."_$Char(10)
    Set p = p_"- envidar con pendingBet usa amount mayor que pendingBet.amount."_$Char(10)
    Set p = p_"- ordago usa amount 999."_$Char(10)
    Set p = p_"- cortar_mus usa amount 0 y discards []."_$Char(10)
    Set p = p_"- descartar usa amount 0 y discards con cartas exactas de cards."_$Char(10)

    Return p
}

ClassMethod BuildLightDecisionAgentGoal(llmContext As %DynamicObject, playerId As %String) As %String
{
    Set p = ""

    Set phase = llmContext.%Get("phase", "")
    Set cards = llmContext.%Get("cards", [])
    Set legalActions = llmContext.%Get("legalActions", [])
    Set targetScore = +llmContext.%Get("targetScore", 40)
    If targetScore <= 0 { Set targetScore = 40 }

    Set myScore = 0
    Set opponentScore = 0
    Set score = llmContext.%Get("score", "")
    Set team = llmContext.%Get("team", llmContext.%Get("playerTeam", ""))

    If $IsObject(score) {
        If team = "A" {
            Set myScore = +score.%Get("teamA", 0)
            Set opponentScore = +score.%Get("teamB", 0)
        } ElseIf team = "B" {
            Set myScore = +score.%Get("teamB", 0)
            Set opponentScore = +score.%Get("teamA", 0)
        } Else {
            Set myScore = +score.%Get("teamA", 0)
            Set opponentScore = +score.%Get("teamB", 0)
        }
    }

    Set discardInfo = llmContext.%Get("discardTurnInfo", "")
    Set isLastToSpeak = 0
    Set rivalMusCount = 0
    Set teammateMusCount = 0

    If $IsObject(discardInfo) {
        Set isLastToSpeak = +discardInfo.%Get("isLastToSpeak", 0)
        Set rivalMusCount = +discardInfo.%Get("rivalMusCount", 0)
        Set teammateMusCount = +discardInfo.%Get("teammateMusCount", 0)
    }

    Set p = p_"Jugador: "_playerId_$Char(10)
    Set p = p_"phase: "_phase_$Char(10)
    Set p = p_"cards: "_cards.%ToJSON()_$Char(10)
    Set p = p_"legalActions: "_legalActions.%ToJSON()_$Char(10)
    Set p = p_"myScore: "_myScore_$Char(10)
    Set p = p_"opponentScore: "_opponentScore_$Char(10)
    Set p = p_"targetScore: "_targetScore_$Char(10)
    Set p = p_"isLastToSpeak: "_isLastToSpeak_$Char(10)
    Set p = p_"rivalMusCount: "_rivalMusCount_$Char(10)
    Set p = p_"teammateMusCount: "_teammateMusCount_$Char(10)

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

    Set bettingGuidance = llmContext.%Get("bettingGuidance", "")
    If $IsObject(bettingGuidance) {
        Set p = p_"bettingGuidance: "_bettingGuidance.%ToJSON()_$Char(10)
    }

    Set discardGuidance = llmContext.%Get("discardGuidance", "")
    If $IsObject(discardGuidance) {
        Set p = p_"discardGuidance: "_discardGuidance.%ToJSON()_$Char(10)
    }

    Set p = p_$Char(10)
    Set p = p_"Herramientas a usar segun la fase:"_$Char(10)
    Set p = p_"- Para grande/chica/pares/juego/punto: evaluate_play_strength con {""cards"": "_cards.%ToJSON()_", ""play"": """_phase_"""}."_$Char(10)
    Set p = p_"- Para descartes: evaluate_discard_hand_value con {""cards"": "_cards.%ToJSON()_", ""isLastToSpeak"": "_isLastToSpeak_", ""rivalMusCount"": "_rivalMusCount_", ""teammateMusCount"": "_teammateMusCount_"}."_$Char(10)
    Set p = p_"- Para considerar ordago: evaluate_score_pressure con {""myScore"": "_myScore_", ""opponentScore"": "_opponentScore_", ""targetScore"": "_targetScore_"}."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Decide una unica accion legal y responde solo JSON."_$Char(10)

    Return p
}

ClassMethod ExtractResponseText(response As %RegisteredObject) As %String
{
    Try {
        Set text = response.Text
        If text '= "" { Return text }
    } Catch ex1 {}

    Try {
        Set text = response.Content
        If text '= "" { Return text }
    } Catch ex2 {}

    Try {
        Set text = response.Message
        If text '= "" { Return text }
    } Catch ex3 {}

    Try {
        Set text = response.Result
        If text '= "" { Return text }
    } Catch ex4 {}

    Try {
        Set text = response.Output
        If text '= "" { Return text }
    } Catch ex5 {}

    Try {
        Set text = response.%ToJSON()
        If text '= "" { Return text }
    } Catch ex6 {}

    Return ""
}

ClassMethod ExtractJsonObject(text As %String) As %String
{
    Set text = $ZSTRIP(text, "<W")

    If text = "" { Return "" }

    If $Extract(text, 1) = "{" {
        Return text
    }

    Set first = $Find(text, "{")
    If first = 0 { Return "" }

    Set start = first - 1

    For i=$Length(text):-1:1 {
        If $Extract(text, i) = "}" {
            Return $Extract(text, start, i)
        }
    }

    Return ""
}

ClassMethod Ping(Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Set context = {
        "phase": "grande",
        "playerId": "P1",
        "team": "A",
        "cards": ["12O", "3B", "7C", "5E"],
        "legalActions": ["pasar", "envidar", "ordago"],
        "score": {
            "teamA": 18,
            "teamB": 36
        },
        "targetScore": 40,
        "pendingBet": null,
        "profile": {
            "id": "balanced"
        }
    }

    Return ..RecommendActionWithLightTools(context, "P1", .rawResponse)
}

}
