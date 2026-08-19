Class Mus.AI.MusAgentClient Extends %RegisteredObject
{

Parameter ProviderName = "nim";

Parameter BaseURL = "http://llama:8000/v1";

Parameter ApiKey = "not-needed";

Parameter Model = "qwen3-4b-agent";

Parameter Temperature = 0;

Parameter MaxIterations = 3;

Parameter MaxReasonLength = 280;

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

        Set gameState = {}.%FromJSON(gameStateJson)
        Set context = ##class(Mus.Agent.ContextBuilder).BuildForPlayer(gameState, playerId)

        If '$IsObject(context) {
            Return $$$ERROR($$$GeneralError, "Could not build player context")
        }

        Set llmContext = ##class(Mus.Agent.PlayerAgent).BuildMinimalLLMContext(context)

        If '$IsObject(llmContext) {
            Return $$$ERROR($$$GeneralError, "Could not build compact LLM context")
        }

        Return ..RecommendActionWithLightTools(llmContext, playerId, .rawResponse)
    } Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod RecommendActionWithLightTools(llmContext As %DynamicObject, playerId As %String, Output rawResponse As %String) As %Status
{
    Set rawResponse = ""
    Set decisionId = ""

    Try {
        If '$IsObject(llmContext) {
            Return $$$ERROR($$$GeneralError, "llmContext is not an object")
        }

        If playerId = "" {
            Return $$$ERROR($$$GeneralError, "playerId is empty")
        }

        Set decisionId = ##class(Mus.Data.AgentToolLog).BeginDecision(llmContext, playerId)

        Set provider = ..CreateProvider()

        If '$IsObject(provider) {
            Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "error", "", "AI Hub provider could not be created")
            Return $$$ERROR($$$GeneralError, "AI Hub provider could not be created")
        }

        Set agent = ##class(%AI.Agent).%New(provider)

        If '$IsObject(agent) {
            Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "error", "", "AI Hub agent could not be created")
            Return $$$ERROR($$$GeneralError, "AI Hub agent could not be created")
        }

        Set phase = ..NormalizePhase(llmContext.%Get("phase", ""))

        If phase = "descartes" {
            Set sc = agent.UseToolSet("Mus.AI.ToolSet.MusDiscardDecision")
        } Else {
            Set sc = agent.UseToolSet("Mus.AI.ToolSet.MusBettingDecision")
        }

        If $$$ISERR(sc) {
            Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "error", "", $System.Status.GetErrorText(sc))
            Return sc
        }

        Set config = {
            "model": (..#Model),
            "temperature": (+..#Temperature),
            "systemPrompt": (..BuildPhaseSpecificSystemPrompt(phase))        
        }

        Set session = agent.CreateSession(config)

        If '$IsObject(session) {
            Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "error", "", "AI Hub agent session could not be created")
            Return $$$ERROR($$$GeneralError, "AI Hub agent session could not be created")
        }

        Set goal = ..BuildLightDecisionAgentGoal(llmContext, playerId)

        Set response = agent.Run(session, goal, ..#MaxIterations)

        /*
          El LLM debe invocar las tools. IRIS no calcula previamente la fuerza
          ni la presion ni el valor de descarte. Validamos el uso de tools tras
          agent.Run para evitar omisiones y repeticiones.
        */

        Set toolUsageError = ..ValidateRequiredToolUsage(phase, decisionId)
        If toolUsageError '= "" {
            Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "error", "", toolUsageError)
            Return $$$ERROR($$$GeneralError, toolUsageError)
        }

        If '$IsObject(response) {
            Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "error", "", "AI Hub agent returned no response object")
            Return $$$ERROR($$$GeneralError, "AI Hub agent returned no response object")
        }

        Set responseText = ..ExtractResponseText(response)

        If responseText = "" {
            Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "error", "", "AI Hub agent returned empty response")
            Return $$$ERROR($$$GeneralError, "AI Hub agent returned empty response")
        }

        Set json = ..ExtractJsonObject(responseText)

        If json = "" {
            Set json = ..BuildSafeJsonFromText(responseText, phase, llmContext, decisionId)

            If json = "" {
                Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "error", "", "AI Hub agent returned no JSON object")
                Return $$$ERROR($$$GeneralError, "AI Hub agent returned no JSON object. Raw response: "_responseText)
            }
        }

        Set json = ..EnsureLegalJson(json, phase, llmContext, decisionId)
        Set json = ..EnsureToolConsistentJson(json, phase, llmContext, decisionId)

        Set rawResponse = ..AttachToolTraceToJson(json, decisionId)
        Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "ok", rawResponse, "")
        Return $$$OK
    } Catch ex {
        Do ##class(Mus.Data.AgentToolLog).EndDecision(decisionId, "exception", "", ex.DisplayString())
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod NormalizePhase(phase As %String) As %String
{
    Set phase = $ZCONVERT($ZSTRIP(phase, "<>W"), "L")
    Set phase = $Replace(phase, "-", "_")
    Set phase = $Replace(phase, " ", "_")

    If (phase = "discard") || (phase = "discards") || (phase = "descartar") || (phase = "mus") {
        Return "descartes"
    }

    If (phase = "juego_punto") ||
       (phase = "juego_al_punto") ||
       (phase = "al_punto") ||
       (phase = "no_juego") ||
       (phase = "point") {
        Return "punto"
    }

    Return phase
}

ClassMethod ResolveToolPlay(llmContext As %DynamicObject, phase As %String, cardsJson As %String = "") As %String
{
    Set phase = ..NormalizePhase(phase)

    /*
      Alias explicitos para juego al punto.
    */
    If (phase = "punto") ||
       (phase = "juego_punto") ||
       (phase = "juego_al_punto") ||
       (phase = "al_punto") ||
       (phase = "no_juego") ||
       (phase = "point") {
        Return "punto"
    }

    /*
      Si el contexto compacto trae una señal explicita de punto,
      debe ganar frente a phase="juego".
    */
    If $IsObject(llmContext) {
        If +llmContext.%Get("isPointPhase", 0) {
            Return "punto"
        }

        If +llmContext.%Get("playingForPoint", 0) {
            Return "punto"
        }

        Set phaseMode = ..NormalizePhase(llmContext.%Get("phaseMode", ""))
        If (phaseMode = "punto") || (phaseMode = "no_juego") {
            Return "punto"
        }

        Set hand = llmContext.%Get("hand", "")
        If $IsObject(hand) {
            Set handPhaseMode = ..NormalizePhase(hand.%Get("phaseMode", ""))
            If (handPhaseMode = "punto") || (handPhaseMode = "no_juego") {
                Return "punto"
            }
        }

        Set phaseState = llmContext.%Get("phaseState", "")
        If $IsObject(phaseState) {
            Set phaseStateMode = ..NormalizePhase(phaseState.%Get("mode", phaseState.%Get("phaseMode", "")))
            If (phaseStateMode = "punto") || (phaseStateMode = "no_juego") {
                Return "punto"
            }

            If +phaseState.%Get("isPointPhase", 0) || +phaseState.%Get("playingForPoint", 0) {
                Return "punto"
            }
        }

        Set bettingGuidance = llmContext.%Get("bettingGuidance", "")
        If $IsObject(bettingGuidance) {
            Set guidancePhase = ..NormalizePhase(bettingGuidance.%Get("phase", ""))
            If (guidancePhase = "punto") || (guidancePhase = "no_juego") {
                Return "punto"
            }
        }
    }

    /*
      Ultimo recurso:
      si llega phase="juego" pero la mano no tiene juego, evaluar como punto.
      Esto corrige partidas donde el backend llama "juego" al lance de punto.
    */
    If phase = "juego" {
        Try {
            Set cards = [].%FromJSON(cardsJson)
            If $IsObject(cards) {
                Set points = ..HandPoints(cards)
                If points < 31 {
                    Return "punto"
                }
            }
        } Catch ex {
        }
    }

    Return phase
}

ClassMethod BuildPhaseSpecificSystemPrompt(phase As %String) As %String
{
    Set phase = ..NormalizePhase(phase)

    If phase = "descartes" {
        Return ..BuildDiscardDecisionSystemPrompt()
    }

    Return ..BuildBettingDecisionSystemPrompt()
}

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
    Set p = p_"Debes usar las herramientas ligeras aplicables antes de decidir."_$Char(10)
    Set p = p_"Herramientas disponibles: evaluate_play_strength, evaluate_score_pressure y evaluate_discard_hand_value."_$Char(10)
    Set p = p_"No pidas gameStateJson, historial, ni contexto adicional."_$Char(10)
    Set p = p_"Nunca elijas una accion fuera de legalActions."_$Char(10)
    Set p = p_"Devuelve exclusivamente JSON valido, sin markdown ni texto adicional."_$Char(10)
    Set p = p_"El campo reason es obligatorio y debe resumir tu razonamiento, citando brevemente los resultados de las herramientas que hayas usado."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Regla obligatoria de herramientas:"_$Char(10)
    Set p = p_"- Si phase es grande, chica, pares, juego o punto, debes llamar evaluate_play_strength antes de decidir."_$Char(10)
    Set p = p_"- Si phase es descartes, debes llamar evaluate_discard_hand_value antes de decidir entre descartar o cortar_mus."_$Char(10)
    Set p = p_"- Si legalActions contiene ordago y estas considerando elegir ordago, debes llamar evaluate_score_pressure."_$Char(10)
    Set p = p_"- No decidas por intuicion si hay una herramienta aplicable."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Regla fuerte para ordago:"_$Char(10)
    Set p = p_"- ordago solo puede elegirse si aparece en legalActions."_$Char(10)
    Set p = p_"- ordago requiere normalmente fuerza strong o very strong."_$Char(10)
    Set p = p_"- ordago requiere normalmente presion high o very high."_$Char(10)
    Set p = p_"- con presion low o medium, evita ordago."_$Char(10)
    Set p = p_"- con fuerza weak, neutral o medium, evita ordago salvo situacion desesperada muy clara."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Formato obligatorio:"_$Char(10)
    Set p = p_"{""actionType"":""pasar|envidar|querer|no_querer|ordago|descartar|cortar_mus"",""amount"":0,""discards"":[],""reason"":""razonamiento breve con señales de tools"",""confidence"":0.0}"_$Char(10)

    Set p = p_"Reglas de importes:"_$Char(10)
    Set p = p_"- pasar y no_querer usan amount 0."_$Char(10)
    Set p = p_"- querer usa pendingBet.amount si existe."_$Char(10)
    Set p = p_"- envidar sin pendingBet usa amount minimo 2."_$Char(10)
    Set p = p_"- envidar con pendingBet usa amount mayor que pendingBet.amount."_$Char(10)
    Set p = p_"- ordago usa amount 999."_$Char(10)
    Set p = p_"- cortar_mus usa discards []."_$Char(10)
    Set p = p_"- descartar usa cartas exactas de cards."_$Char(10)

    Return p
}

ClassMethod BuildLightDecisionAgentGoal(llmContext As %DynamicObject, playerId As %String) As %String
{
    Set p = ""

    If '$IsObject(llmContext) {
        Return "{}"
    }

    Set phase = ..NormalizePhase(llmContext.%Get("phase", ""))
    Set cards = llmContext.%Get("cards", [])
    Set cardsJson = "[]"
    If $IsObject(cards) {
        Set cardsJson = cards.%ToJSON()
    }
    Set toolPlay = ..ResolveToolPlay(llmContext, phase, cardsJson)
    Set legalActions = llmContext.%Get("legalActions", [])
    Set targetScore = +llmContext.%Get("targetScore", 40)

    If targetScore <= 0 {
        Set targetScore = 40
    }

    Set myScore = 0
    Set opponentScore = 0

    Set score = llmContext.%Get("score", "")
    Set team = llmContext.%Get("team", "")

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

    Set p = p_"Jugador: "_playerId_$Char(10)
    Set p = p_"Lance actual: "_phase_$Char(10)
    Set p = p_"Lance para evaluar cartas: "_toolPlay_$Char(10)

    If $IsObject(cards) {
        Set p = p_"Cartas: "_cards.%ToJSON()_$Char(10)
    } Else {
        Set p = p_"Cartas: []"_$Char(10)
    }

    If $IsObject(legalActions) {
        Set p = p_"Acciones legales: "_legalActions.%ToJSON()_$Char(10)
    } Else {
        Set p = p_"Acciones legales: []"_$Char(10)
    }

    Set p = p_"myScore: "_myScore_$Char(10)
    Set p = p_"opponentScore: "_opponentScore_$Char(10)
    Set p = p_"targetScore: "_targetScore_$Char(10)

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

    If phase = "descartes" {
        Set discardTurnInfo = llmContext.%Get("discardTurnInfo", "")

        Set isLastToSpeak = 0
        Set rivalMusCount = 0
        Set teammateMusCount = 0

        If $IsObject(discardTurnInfo) {
            Set isLastToSpeak = +discardTurnInfo.%Get("isLastToSpeak", 0)
            Set rivalMusCount = +discardTurnInfo.%Get("rivalMusCount", 0)
            Set teammateMusCount = +discardTurnInfo.%Get("teammateMusCount", 0)
        }

        Set p = p_"Llamada requerida exacta antes de responder:"_$Char(10)
        Set p = p_"evaluate_discard_hand_value con {""cards"": "_cards.%ToJSON()
        Set p = p_", ""isLastToSpeak"": "_isLastToSpeak
        Set p = p_", ""rivalMusCount"": "_rivalMusCount
        Set p = p_", ""teammateMusCount"": "_teammateMusCount_"}"_$Char(10)
        Set p = p_"Llama esa herramienta exactamente una vez. No la repitas."_$Char(10)
        Set p = p_"Usa globalStrength y recommendedBias junto con legalActions y discardTurnInfo."_$Char(10)
        Set p = p_"Si recommendedBias=ask_mus, actionType debe ser descartar, nunca cortar_mus."_$Char(10)
        Set p = p_"Si globalStrength es weak o very weak, no cortes mus."_$Char(10)
        Set p = p_"El campo reason debe mencionar globalStrength y recommendedBias."_$Char(10)
    } Else {
        Set p = p_"Llamada requerida exacta antes de responder:"_$Char(10)
        Set p = p_"evaluate_play_strength con {""cards"": "_cardsJson_", ""play"": """_toolPlay_"""}"_$Char(10)
        Set p = p_"Llama evaluate_play_strength exactamente una vez. No la repitas."_$Char(10)
        Set p = p_"Solo llama evaluate_score_pressure si estas considerando ordago o si necesitas valorar riesgo de marcador; si la llamas, hazlo exactamente una vez."_$Char(10)
        Set p = p_"Si playStrength.strength es weak o very weak, no subas el envite salvo presion very high y una razon extrema."_$Char(10)
        Set p = p_"El campo reason debe mencionar playStrength.strength."_$Char(10)
    }

    Return p
}

ClassMethod AttachToolTraceToJson(json As %String, decisionId As %String) As %String
{
    If json = "" {
        Return json
    }

    Try {
        Set obj = {}.%FromJSON(json)
        Do obj.%Set("toolLogId", decisionId)
        Do obj.%Set("toolSummary", ..BuildToolSummaryFromLog(decisionId))

        Set reason = obj.%Get("reason", "")
        If reason = "" {
            Set reason = ..BuildReasonFromToolCalls(decisionId)
        }

        Do obj.%Set("reason", ..CompactReason(reason))
        Return obj.%ToJSON()
    } Catch ex {
        Return json
    }
}

ClassMethod ValidateRequiredToolUsage(phase As %String, decisionId As %String) As %String
{
    Set phase = ..NormalizePhase(phase)

    If phase = "descartes" {
        Set discardCount = ..ToolCallCount(decisionId, "evaluate_discard_hand_value")
        If discardCount = 0 {
            Return "Agent did not call required discard hand value tool"
        }
        If discardCount > 1 {
            Return "Agent repeated discard hand value tool"
        }
        Return ""
    }

    Set strengthCount = ..ToolCallCount(decisionId, "evaluate_play_strength")
    If strengthCount = 0 {
        Return "Agent did not call required hand strength tool"
    }
    If strengthCount > 1 {
        Return "Agent repeated hand strength tool"
    }

    Set pressureCount = ..ToolCallCount(decisionId, "evaluate_score_pressure")
    If pressureCount > 1 {
        Return "Agent repeated score pressure tool"
    }

    Return ""
}

ClassMethod ToolCallCount(decisionId As %String, toolName As %String) As %Integer
{
    Set count = 0

    Try {
        Set calls = ##class(Mus.Data.AgentToolLog).GetToolCalls(decisionId)
        If '$IsObject(calls) {
            Return 0
        }

        For i=0:1:calls.%Size()-1 {
            Set call = calls.%Get(i)
            If $IsObject(call), call.%Get("name", "") = toolName {
                Set count = count + 1
            }
        }
    } Catch ex {
        Return 0
    }

    Return count
}

ClassMethod BuildToolSummaryFromLog(decisionId As %String) As %DynamicObject
{
    Set summary = {}

    Try {
        Set calls = ##class(Mus.Data.AgentToolLog).GetToolCalls(decisionId)
        If '$IsObject(calls) {
            Return summary
        }

        For i=0:1:calls.%Size()-1 {
            Set call = calls.%Get(i)
            If '$IsObject(call) {
                Continue
            }

            Set name = call.%Get("name", "")
            Set output = call.%Get("output", "")
            If '$IsObject(output) {
                Continue
            }

            If name = "evaluate_play_strength" {
                Do summary.%Set("playStrength", output.%Get("strength", ""))
                Do summary.%Set("play", output.%Get("play", ""))
                Do summary.%Set("playScore", +output.%Get("score", 0))
            } ElseIf name = "evaluate_score_pressure" {
                Do summary.%Set("scorePressure", output.%Get("pressure", ""))
            } ElseIf name = "evaluate_discard_hand_value" {
                Do summary.%Set("discardHandValue", output.%Get("globalStrength", ""))
                Do summary.%Set("discardBias", output.%Get("recommendedBias", ""))
            }
        }
    } Catch ex {
    }

    Return summary
}

ClassMethod GetLoggedPlayStrength(decisionId As %String) As %String
{
    Set summary = ..BuildToolSummaryFromLog(decisionId)
    Return $ZCONVERT(summary.%Get("playStrength", ""), "L")
}

ClassMethod GetLoggedScorePressure(decisionId As %String) As %String
{
    Set summary = ..BuildToolSummaryFromLog(decisionId)
    Return $ZCONVERT(summary.%Get("scorePressure", ""), "L")
}

ClassMethod BuildReasonFromLog(phase As %String, actionType As %String, decisionId As %String = "", responseText As %String = "") As %String
{
    Set summary = ..BuildToolSummaryFromLog(decisionId)
    Set parts = []

    Try {
        If summary.%IsDefined("playStrength") {
            Do parts.%Push("playStrength="_summary.%Get("playStrength", ""))
        }

        If summary.%IsDefined("scorePressure") {
            Do parts.%Push("scorePressure="_summary.%Get("scorePressure", ""))
        }

        If summary.%IsDefined("discardHandValue") {
            Do parts.%Push("discardHandValue="_summary.%Get("discardHandValue", "")_"/"_summary.%Get("discardBias", ""))
        }

        If actionType '= "" {
            Do parts.%Push("action="_actionType)
        }

        Set reason = ""
        For i=0:1:parts.%Size()-1 {
            If parts.%Get(i) = "" {
                Continue
            }
            If reason '= "" {
                Set reason = reason_"; "
            }
            Set reason = reason_parts.%Get(i)
        }

        If reason = "" {
            Set reason = $Extract($ZSTRIP(responseText, "<>W"), 1, ..#MaxReasonLength)
        }

        Return ..CompactReason(reason)
    } Catch ex {
        Return "Decision recuperada sin razonamiento estructurado"
    }
}

ClassMethod ChooseSafeAction(llmContext As %DynamicObject) As %DynamicObject
{
    Set result = {
        "actionType": "pasar",
        "amount": 0
    }

    If '$IsObject(llmContext) {
        Return result
    }

    Set legalActions = llmContext.%Get("legalActions", "")
    If '$IsObject(legalActions) || legalActions.%Size() = 0 {
        Return result
    }

    Set pendingBet = llmContext.%Get("pendingBet", "")

    /*
      legalActions es la fuente de verdad.
      Si "pasar" no esta en legalActions, nunca debe ser fallback.
      En respuesta a envite, no_querer es la accion segura preferida.
    */
    If ..ArrayContains(legalActions, "no_querer") {
        Do result.%Set("actionType", "no_querer")
        Do result.%Set("amount", 0)
        Return result
    }

    If ..ArrayContains(legalActions, "pasar") {
        Do result.%Set("actionType", "pasar")
        Do result.%Set("amount", 0)
        Return result
    }

    If ..ArrayContains(legalActions, "cortar_mus") {
        Do result.%Set("actionType", "cortar_mus")
        Do result.%Set("amount", 0)
        Return result
    }

    If ..ArrayContains(legalActions, "querer") {
        Do result.%Set("actionType", "querer")
        If $IsObject(pendingBet) {
            Do result.%Set("amount", +pendingBet.%Get("amount", 0))
        } Else {
            Do result.%Set("amount", 0)
        }
        Return result
    }

    If ..ArrayContains(legalActions, "descartar") {
        Do result.%Set("actionType", "descartar")
        Do result.%Set("amount", 0)
        Return result
    }

    If ..ArrayContains(legalActions, "envidar") {
        Do result.%Set("actionType", "envidar")
        Do result.%Set("amount", 2)
        Return result
    }

    If ..ArrayContains(legalActions, "ordago") {
        Do result.%Set("actionType", "ordago")
        Do result.%Set("amount", 999)
        Return result
    }

    Do result.%Set("actionType", legalActions.%Get(0))
    Do result.%Set("amount", 0)

    Return result
}

ClassMethod EnsureToolConsistentJson(json As %String, phase As %String, llmContext As %DynamicObject, decisionId As %String = "") As %String
{
    If json = "" {
        Return json
    }

    Try {
        Set phase = ..NormalizePhase(phase)
        Set obj = {}.%FromJSON(json)
        If '$IsObject(obj) {
            Return json
        }

        Set legalActions = llmContext.%Get("legalActions", "")
        If '$IsObject(legalActions) {
            Return json
        }

        Set actionType = obj.%Get("actionType", "")

        /*
          En descartes la herramienta no es decorativa:
          - ask_mus significa que NO se debe cortar mus.
          - cut_mus significa que NO se debe descartar salvo que no sea legal cortar.
          - borderline / borderline_cut permiten decision del LLM.
        */
        If phase = "descartes" {
            Set summary = ..BuildToolSummaryFromLog(decisionId)
            Set discardBias = $ZCONVERT(summary.%Get("discardBias", ""), "L")
            Set discardStrength = $ZCONVERT(summary.%Get("discardHandValue", ""), "L")

            If (discardBias = "ask_mus") && (actionType = "cortar_mus") && ..ArrayContains(legalActions, "descartar") {
                Do obj.%Set("actionType", "descartar")
                Do obj.%Set("amount", 0)
                Do obj.%Set("discards", ..BuildDefaultAskMusDiscards(llmContext))
                Do obj.%Set("reason", ..CompactReason("discardHandValue="_discardStrength_"/"_discardBias_"; action=descartar; repairedToolInconsistentAction=cortar_mus"))
                Do obj.%Set("formatRecovered", 1)
                Do obj.%Set("toolConsistencyRepaired", 1)
                Return obj.%ToJSON()
            }

            If ((discardBias = "cut_mus") || (discardBias = "borderline_cut")) && (actionType = "descartar") && ..ArrayContains(legalActions, "cortar_mus") {
                If discardBias = "cut_mus" {
                    Do obj.%Set("actionType", "cortar_mus")
                    Do obj.%Set("amount", 0)
                    Do obj.%Set("discards", [])
                    Do obj.%Set("reason", ..CompactReason("discardHandValue="_discardStrength_"/"_discardBias_"; action=cortar_mus; repairedToolInconsistentAction=descartar"))
                    Do obj.%Set("formatRecovered", 1)
                    Do obj.%Set("toolConsistencyRepaired", 1)
                    Return obj.%ToJSON()
                }
            }

            Return json
        }

        /*
          En apuestas, si la herramienta dice weak/very weak, no permitimos
          subidas agresivas salvo que haya presion high/very high.
        */
        If (actionType = "envidar") || (actionType = "ordago") {
            Set summary = ..BuildToolSummaryFromLog(decisionId)
            Set playStrength = $ZCONVERT(summary.%Get("playStrength", ""), "L")
            Set scorePressure = $ZCONVERT(summary.%Get("scorePressure", ""), "L")

            If (playStrength = "weak") || (playStrength = "very weak") || (playStrength = "veryweak") {
                If (scorePressure '= "high") && (scorePressure '= "very high") && (scorePressure '= "veryhigh") {
                    Set safeAction = ..ChooseSafeAction(llmContext)
                    Set safeType = safeAction.%Get("actionType", "pasar")
                    Set safeAmount = +safeAction.%Get("amount", 0)

                    If (safeType '= "envidar") && (safeType '= "ordago") {
                        Do obj.%Set("actionType", safeType)
                        Do obj.%Set("amount", safeAmount)
                        Do obj.%Set("discards", [])
                        Do obj.%Set("reason", ..CompactReason("playStrength="_playStrength_"; scorePressure="_scorePressure_"; action="_safeType_"; repairedToolInconsistentAction="_actionType))
                        Do obj.%Set("formatRecovered", 1)
                        Do obj.%Set("toolConsistencyRepaired", 1)
                        Return obj.%ToJSON()
                    }
                }
            }
        }

        Return json
    } Catch ex {
        Return json
    }
}

ClassMethod BuildDefaultAskMusDiscards(llmContext As %DynamicObject) As %DynamicArray
{
    /*
      Reparacion minima para no convertir ask_mus en cortar_mus.
      En una mano marcada como ask_mus, descartar todas las cartas es una
      salida segura y legal. La estrategia fina de descartes sigue perteneciendo
      al LLM; esto solo evita una accion contradictoria con la tool.
    */
    Set discards = []

    Try {
        If '$IsObject(llmContext) {
            Return discards
        }

        Set cards = llmContext.%Get("cards", "")
        If '$IsObject(cards) {
            Return discards
        }

        For i=0:1:cards.%Size()-1 {
            Do discards.%Push(cards.%Get(i))
        }

        Return discards
    } Catch ex {
        Return []
    }
}

ClassMethod EnsureLegalJson(json As %String, phase As %String, llmContext As %DynamicObject, decisionId As %String = "") As %String
{
    If json = "" {
        Return json
    }

    Try {
        Set obj = {}.%FromJSON(json)
        If '$IsObject(obj) {
            Return json
        }

        Set actionType = obj.%Get("actionType", "")
        Set legalActions = llmContext.%Get("legalActions", "")

        If '$IsObject(legalActions) {
            Return json
        }

        If ..ArrayContains(legalActions, actionType) {
            Return json
        }

        Set safeAction = ..ChooseSafeAction(llmContext)
        Set safeType = safeAction.%Get("actionType", "pasar")
        Set safeAmount = +safeAction.%Get("amount", 0)

        Do obj.%Set("actionType", safeType)
        Do obj.%Set("amount", safeAmount)

        If safeType '= "descartar" {
            Do obj.%Set("discards", [])
        }

        Set reason = ..BuildReasonFromLog(phase, safeType, decisionId, "")
        If reason = "" {
            Set reason = "Reparada accion ilegal: "_actionType_" no estaba en legalActions; action="_safeType
        } Else {
            Set reason = reason_"; repairedIllegalAction="_actionType
        }

        Do obj.%Set("reason", ..CompactReason(reason))
        Do obj.%Set("formatRecovered", 1)
        Do obj.%Set("legalRepaired", 1)

        Return obj.%ToJSON()
    } Catch ex {
        Return json
    }
}

ClassMethod BuildReasonFromToolCalls(decisionId As %String) As %String
{
    Set calls = ##class(Mus.Data.AgentToolLog).GetToolCalls(decisionId)
    If '$IsObject(calls) || calls.%Size() = 0 {
        Return "El agente no devolvio razonamiento explicito"
    }

    Set reason = "Razonamiento basado en tools: "
    For i=0:1:calls.%Size()-1 {
        Set call = calls.%Get(i)
        If '$IsObject(call) { Continue }
        Set name = call.%Get("name", "")
        Set output = call.%Get("output", "")
        Set summary = ""

        If $IsObject(output) {
            If output.%IsDefined("strength") { Set summary = output.%Get("strength", "") }
            ElseIf output.%IsDefined("pressure") { Set summary = output.%Get("pressure", "") }
            ElseIf output.%IsDefined("globalStrength") { Set summary = output.%Get("globalStrength", "")_"/"_output.%Get("recommendedBias", "") }
        }

        If summary '= "" {
            If reason '= "Razonamiento basado en tools: " { Set reason = reason_"; " }
            Set reason = reason_name_"="_summary
        }
    }

    Return $ZSTRIP(reason, ">W")
}

ClassMethod BuildBettingDecisionSystemPrompt() As %String
{
    Set p = ""

    Set p = p_"Eres un agente jugador de Mus en fase de apuesta."_$Char(10)
    Set p = p_"CRITICO: tu respuesta final debe ser SOLO un objeto JSON valido."_$Char(10)
    Set p = p_"No escribas razonamiento fuera del JSON."_$Char(10)
    Set p = p_"No escribas frases antes ni despues del JSON."_$Char(10)
    Set p = p_"El razonamiento debe ir exclusivamente dentro del campo reason."_$Char(10)
    Set p = p_"El campo reason debe ser corto: maximo 240 caracteres, sin markdown ni listas."_$Char(10)
    Set p = p_"Si no puedes decidir, devuelve JSON con actionType=pasar."_$Char(10)
    Set p = p_"Debes recomendar una unica accion para el jugador actual."_$Char(10)
    Set p = p_"Herramientas disponibles: evaluate_play_strength y evaluate_score_pressure."_$Char(10)
    Set p = p_"No tienes herramienta de descartes. No hables de pedir MUS ni de cortar MUS en fases de apuesta."_$Char(10)
    Set p = p_"IRIS ya te proporciona playStrength calculado con evaluate_play_strength antes de tu decision."_$Char(10)
    Set p = p_"Debes basar la decision en playStrength.strength y mencionarlo en reason."_$Char(10)
    Set p = p_"Si el lance real es juego al punto, playStrength se calcula como punto, no como juego."_$Char(10)
    Set p = p_"IRIS tambien te proporciona scorePressure calculado con evaluate_score_pressure para valorar ordago o riesgo de marcador."_$Char(10)
    Set p = p_"Nunca elijas una accion fuera de legalActions."_$Char(10)
    Set p = p_"No subas un envite si evaluate_play_strength devuelve weak o very weak, salvo que haya presion very high y razon extrema."_$Char(10)
    Set p = p_"Con fuerza weak o very weak en chica, grande, pares, juego o punto, debes tender a pasar o no_querer."_$Char(10)
    Set p = p_"Regla fuerte sobre pares:"_$Char(10)
    Set p = p_"- En pares, un par bajo aislado debe tratarse como weak, no como neutral."_$Char(10)
    Set p = p_"- Solo duples o medias justifican agresividad clara en pares."_$Char(10)
    Set p = p_"Regla fuerte sobre faroles:"_$Char(10)
    Set p = p_"- El perfil bluffer permite algun farol, pero NO permite subir con playStrength weak o very weak si scorePressure no es high o very high."_$Char(10)
    Set p = p_"- Si playStrength es weak o very weak y scorePressure es low o medium, actionType debe ser pasar o no_querer."_$Char(10)
    Set p = p_"- Nunca uses profile=bluffer como unica razon para envidar."_$Char(10)
    Set p = p_"Devuelve exclusivamente JSON valido, sin markdown ni texto adicional."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Formato obligatorio:"_$Char(10)
    Set p = p_"{""actionType"":""pasar|envidar|querer|no_querer|ordago"",""amount"":0,""discards"":[],""reason"":""razonamiento breve basado en tools"",""confidence"":0.0}"_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Reglas de importes:"_$Char(10)
    Set p = p_"- pasar y no_querer usan amount 0."_$Char(10)
    Set p = p_"- querer usa pendingBet.amount si existe."_$Char(10)
    Set p = p_"- envidar sin pendingBet usa amount minimo 2."_$Char(10)
    Set p = p_"- envidar con pendingBet usa amount mayor que pendingBet.amount."_$Char(10)
    Set p = p_"- ordago usa amount 999."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"El campo reason debe mencionar explicitamente el resultado de evaluate_play_strength."_$Char(10)
    Set p = p_"Ejemplo de reason valido: ""playStrength=weak; scorePressure=low; paso porque no hay fuerza ni presion""."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Respuesta final obligatoria. Copia esta forma exacta y rellena valores:"_$Char(10)
    Set p = p_"{""actionType"":""pasar"",""amount"":0,""discards"":[],""reason"":""playStrength=weak; scorePressure=low; no subo"",""confidence"":0.5}"_$Char(10)
    Set p = p_"No devuelvas texto natural fuera de ese JSON."_$Char(10)

    Return p
}

ClassMethod BuildDiscardDecisionSystemPrompt() As %String
{
    Set p = ""

    Set p = p_"Eres un agente jugador de Mus en fase de descartes."_$Char(10)
    Set p = p_"CRITICO: tu respuesta final debe ser SOLO un objeto JSON valido."_$Char(10)
    Set p = p_"No escribas razonamiento fuera del JSON."_$Char(10)
    Set p = p_"No escribas frases antes ni despues del JSON."_$Char(10)
    Set p = p_"El razonamiento debe ir exclusivamente dentro del campo reason."_$Char(10)
    Set p = p_"El campo reason debe ser corto: maximo 240 caracteres, sin markdown ni listas."_$Char(10)
    Set p = p_"Si no puedes decidir, devuelve JSON con actionType=cortar_mus."_$Char(10)
    Set p = p_"Debes decidir si pedir MUS descartando cartas o cortar MUS conservando la mano."_$Char(10)
    Set p = p_"Herramienta disponible: evaluate_discard_hand_value."_$Char(10)
    Set p = p_"IRIS ya te proporciona discardHandValue calculado con evaluate_discard_hand_value antes de tu decision."_$Char(10)
    Set p = p_"Debes basar la decision en discardHandValue.globalStrength y discardHandValue.recommendedBias y mencionarlos en reason."_$Char(10)
    Set p = p_"Regla obligatoria: si recommendedBias=ask_mus, actionType debe ser descartar, nunca cortar_mus."_$Char(10)
    Set p = p_"Regla obligatoria: si recommendedBias=cut_mus, actionType debe ser cortar_mus, salvo que no este en legalActions."_$Char(10)
    Set p = p_"Si globalStrength es weak o very weak, no cortes mus."_$Char(10)
    Set p = p_"No uses evaluate_play_strength en descartes; la herramienta global ya evalua todos los lances."_$Char(10)
    Set p = p_"Nunca elijas una accion fuera de legalActions."_$Char(10)
    Set p = p_"Si eliges descartar, discards debe contener cartas exactas de cards."_$Char(10)
    Set p = p_"Si eliges cortar_mus, discards debe ser []."_$Char(10)
    Set p = p_"Devuelve exclusivamente JSON valido, sin markdown ni texto adicional."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Formato obligatorio:"_$Char(10)
    Set p = p_"{""actionType"":""descartar|cortar_mus"",""amount"":0,""discards"":[],""reason"":""razonamiento breve basado en tools"",""confidence"":0.0}"_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"El campo reason debe mencionar globalStrength y recommendedBias devueltos por evaluate_discard_hand_value."_$Char(10)

    Set p = p_$Char(10)
    Set p = p_"Respuesta final obligatoria. Copia esta forma exacta y rellena valores:"_$Char(10)
    Set p = p_"{""actionType"":""cortar_mus"",""amount"":0,""discards"":[],""reason"":""discardHandValue=strong/cut_mus; conservo la mano"",""confidence"":0.5}"_$Char(10)
    Set p = p_"No devuelvas texto natural fuera de ese JSON."_$Char(10)

    Return p
}

ClassMethod BuildSafeJsonFromText(responseText As %String, phase As %String, llmContext As %DynamicObject, decisionId As %String = "") As %String
{
    Try {
        Set phase = $ZCONVERT(phase, "L")
        Set result = {}

        If phase = "descartes" {
            Set actionType = "cortar_mus"
            Set amount = 0
            Set reason = ..BuildReasonFromLog(phase, actionType, decisionId, responseText)

            Do result.%Set("actionType", actionType)
            Do result.%Set("amount", amount)
            Do result.%Set("discards", [])
            Do result.%Set("reason", reason)
            Do result.%Set("confidence", 0.35)
            Do result.%Set("formatRecovered", 1)

            Return result.%ToJSON()
        }

        Set actionType = "pasar"
        Set amount = 0

        Set legalActions = llmContext.%Get("legalActions", "")
        Set lowerText = $ZCONVERT(responseText, "L")

        If $IsObject(legalActions) {
            If (lowerText [ "no_querer") || (lowerText [ "no querer") || (lowerText [ "rechaz") {
                If ..ArrayContains(legalActions, "no_querer") {
                    Set actionType = "no_querer"
                    Set amount = 0
                }
            } ElseIf (lowerText [ "querer") || (lowerText [ "acept") {
                If ..ArrayContains(legalActions, "querer") {
                    Set pendingBet = llmContext.%Get("pendingBet", "")
                    Set actionType = "querer"
                    If $IsObject(pendingBet) {
                        Set amount = +pendingBet.%Get("amount", 0)
                    }
                }
            } ElseIf (lowerText [ "envid") || (lowerText [ "sub") {
                If ..ArrayContains(legalActions, "envidar") {
                    Set canEnvidar = 1

                    Set strength = ..GetLoggedPlayStrength(decisionId)
                    Set pressure = ..GetLoggedScorePressure(decisionId)

                    If (strength = "weak") || (strength = "very weak") || (strength = "veryweak") {
                        Set canEnvidar = 0

                        If (pressure = "high") || (pressure = "very high") || (pressure = "veryhigh") {
                            Set canEnvidar = 1
                        }
                    }

                    If canEnvidar {
                        Set actionType = "envidar"
                        Set amount = 2
                    }
                }
            } ElseIf (lowerText [ "ordago") || (lowerText [ "órdago") {
                If ..ArrayContains(legalActions, "ordago") {
                    Set canOrdago = 1

                    Set strength = ..GetLoggedPlayStrength(decisionId)
                    Set pressure = ..GetLoggedScorePressure(decisionId)

                    If (strength = "weak") || (strength = "very weak") || (strength = "veryweak") || (strength = "neutral") || (strength = "medium") {
                        Set canOrdago = 0
                    }

                    If (pressure '= "high") && (pressure '= "very high") && (pressure '= "veryhigh") {
                        Set canOrdago = 0
                    }

                    If canOrdago {
                        Set actionType = "ordago"
                        Set amount = 999
                    }
                }
            }
        }

        Set reason = ..BuildReasonFromLog(phase, actionType, decisionId, responseText)

        Do result.%Set("actionType", actionType)
        Do result.%Set("amount", amount)
        Do result.%Set("discards", [])
        Do result.%Set("reason", reason)
        Do result.%Set("confidence", 0.35)
        Do result.%Set("formatRecovered", 1)

        Return result.%ToJSON()
    } Catch ex {
        Return ""
    }
}

ClassMethod BuildReasonFromSignals(phase As %String, actionType As %String, toolSignals As %DynamicObject = "", responseText As %String = "") As %String
{
    Set parts = []

    Try {
        If $IsObject(toolSignals) {
            Set playStrength = toolSignals.%Get("playStrength", "")
            If $IsObject(playStrength) {
                Do parts.%Push("playStrength="_playStrength.%Get("strength", ""))
            }

            Set scorePressure = toolSignals.%Get("scorePressure", "")
            If $IsObject(scorePressure) {
                Do parts.%Push("scorePressure="_scorePressure.%Get("pressure", ""))
            }

            Set discardHandValue = toolSignals.%Get("discardHandValue", "")
            If $IsObject(discardHandValue) {
                Do parts.%Push("discardHandValue="_discardHandValue.%Get("globalStrength", "")_"/"_discardHandValue.%Get("recommendedBias", ""))
            }
        }

        If actionType '= "" {
            Do parts.%Push("action="_actionType)
        }

        Set reason = ""
        For i=0:1:parts.%Size()-1 {
            If parts.%Get(i) = "" { Continue }
            If reason '= "" { Set reason = reason_"; " }
            Set reason = reason_parts.%Get(i)
        }

        If reason = "" {
            Set reason = $Extract($ZSTRIP(responseText, "<>W"), 1, ..#MaxReasonLength)
        }

        Return ..CompactReason(reason)
    } Catch ex {
        Return "Decision recuperada sin razonamiento estructurado"
    }
}

ClassMethod CompactReason(reason As %String) As %String
{
    Set reason = $ZSTRIP(reason, "<>W")
    Set reason = $Replace(reason, """", "'")
    Set reason = $Replace(reason, $Char(13), " ")
    Set reason = $Replace(reason, $Char(10), " ")
    Set reason = $Replace(reason, "**", "")

    For {
        Quit:reason'["  "
        Set reason = $Replace(reason, "  ", " ")
    }

    If $Length(reason) > ..#MaxReasonLength {
        Set reason = $Extract(reason, 1, ..#MaxReasonLength-3)_"..."
    }

    Return reason
}

ClassMethod HandPoints(cards As %DynamicArray) As %Integer
{
    Set total = 0

    If '$IsObject(cards) {
        Return total
    }

    For i=0:1:cards.%Size()-1 {
        Set rank = ..ExtractRank(cards.%Get(i))

        If rank >= 10 {
            Set total = total + 10
        } Else {
            Set total = total + rank
        }
    }

    Return total
}

ClassMethod ExtractRank(card As %String) As %Integer
{
    Set card = $ZCONVERT(card, "U")
    Set digits = ""

    For i=1:1:$Length(card) {
        Set ch = $Extract(card, i)

        If ch?1N {
            Set digits = digits_ch
        } Else {
            Quit
        }
    }

    If digits '= "" {
        Return +digits
    }

    If $Extract(card, 1) = "A" {
        Return 1
    }

    If $Extract(card, 1) = "S" {
        Return 10
    }

    If $Extract(card, 1) = "C" {
        Return 11
    }

    If $Extract(card, 1) = "R" {
        Return 12
    }

    Return 0
}

ClassMethod ArrayContains(array As %DynamicArray, value As %String) As %Boolean
{
    If '$IsObject(array) {
        Return 0
    }

    For i=0:1:array.%Size()-1 {
        If array.%Get(i) = value {
            Return 1
        }
    }

    Return 0
}

ClassMethod ToolWasCalled(toolLogId As %String, toolName As %String) As %Boolean
{
    Try {
        Set detail = ##class(Mus.Data.AgentToolLog).GetDecision(toolLogId)

        If '$IsObject(detail) {
            Return 0
        }

        Set calls = detail.%Get("toolCalls", "")
        If '$IsObject(calls) {
            Return 0
        }

        For i=0:1:calls.%Size()-1 {
            Set call = calls.%Get(i)
            If $IsObject(call), call.%Get("name", "") = toolName {
                Return 1
            }
        }
    } Catch ex {
        Return 0
    }

    Return 0
}

ClassMethod ExtractResponseText(response As %RegisteredObject) As %String
{
    Try {
        Set text = response.Text
        If text '= "" {
            Return text
        }
    } Catch ex1 {
    }

    Try {
        Set text = response.Content
        If text '= "" {
            Return text
        }
    } Catch ex2 {
    }

    Try {
        Set text = response.Message
        If text '= "" {
            Return text
        }
    } Catch ex3 {
    }

    Try {
        Set text = response.Result
        If text '= "" {
            Return text
        }
    } Catch ex4 {
    }

    Try {
        Set text = response.Output
        If text '= "" {
            Return text
        }
    } Catch ex5 {
    }

    Try {
        Set text = response.%ToJSON()
        If text '= "" {
            Return text
        }
    } Catch ex6 {
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
        "targetScore": 40,
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
