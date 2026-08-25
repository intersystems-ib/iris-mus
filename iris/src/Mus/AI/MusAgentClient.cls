Class Mus.AI.MusAgentClient Extends %RegisteredObject
{

Parameter ProviderName = "nim";

Parameter BaseURL = "http://llama:8000/v1";

Parameter ApiKey = "not-needed";

Parameter Model = "llama-3.1-8b-instruct";

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

        Set phase = ..NormalizePhase(llmContext.%Get("phase", ""))

        /*
          ARQUITECTURA EN DOS ETAPAS

          Etapa 1:
            - agente con UNA tool aplicable;
            - session.max_iterations=1 limita las tool calls del turno;
            - Run(...,1) evita una segunda generacion del modelo con las tools
              todavia anunciadas;
            - IRIS extrae mecanicamente del contexto el resultado de la tool.

          Etapa 2:
            - agente NUEVO, sin UseToolSet();
            - sesion NUEVA, sin catalogo de tools;
            - recibe contexto + resultado bruto de la tool;
            - el LLM toma la decision estrategica final.

          IRIS no transforma la senal de la tool en una decision.
        */
        Set evaluationStartedMs = ..NowMs()
        Set sc = ..RunEvaluationStage(
            provider,
            llmContext,
            playerId,
            phase,
            .toolResult,
            .evaluationContextDiagnostic,
            .evaluationResponseText
        )
        Set evaluationMs = ..ElapsedMs(evaluationStartedMs)

        If $$$ISERR(sc) {
            Return sc
        }

        If '$IsObject(toolResult) {
            Set rawResponse = ..BuildTwoStageDiagnostic(
                "EVALUATION_RESULT_MISSING",
                phase,
                "",
                evaluationContextDiagnostic,
                "",
                evaluationResponseText,
                "",
                evaluationMs,
                0
            )
            Return $$$OK
        }

        Set decisionStartedMs = ..NowMs()
        Set sc = ..RunDecisionStage(
            provider,
            llmContext,
            playerId,
            phase,
            toolResult,
            .decisionText,
            .decisionContextDiagnostic
        )
        Set decisionMs = ..ElapsedMs(decisionStartedMs)

        If $$$ISERR(sc) {
            Return sc
        }

        If decisionText = "" {
            Set rawResponse = ..BuildTwoStageDiagnostic(
                "EMPTY_DECISION_RESPONSE",
                phase,
                toolResult,
                evaluationContextDiagnostic,
                decisionContextDiagnostic,
                evaluationResponseText,
                decisionText,
                evaluationMs,
                decisionMs
            )
            Return $$$OK
        }

        /*
          La segunda sesion no tiene tools, por lo que ya no necesitamos
          proteger peg-native frente a JSON de tool calling. Conservamos FINAL|
          como transporte simple y estable.
        */
        Set json = ..ParseFinalTransport(decisionText, phase)

        If json = "" {
            Set json = ..ExtractJsonObject(decisionText)
        }

        If json = "" {
            Set rawResponse = ..BuildTwoStageDiagnostic(
                "INVALID_DECISION_OUTPUT",
                phase,
                toolResult,
                evaluationContextDiagnostic,
                decisionContextDiagnostic,
                evaluationResponseText,
                decisionText,
                evaluationMs,
                decisionMs
            )
            Return $$$OK
        }

        Set json = ..EnsureLegalJson(json, phase, llmContext)
        Set json = ..AttachTwoStageDiagnostics(
            json,
            toolResult,
            evaluationContextDiagnostic,
            decisionContextDiagnostic,
            evaluationResponseText,
            decisionText,
            evaluationMs,
            decisionMs
        )

        Set rawResponse = json
        Return $$$OK
    } Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod RunEvaluationStage(provider As %RegisteredObject, llmContext As %DynamicObject, playerId As %String, phase As %String, Output toolResult As %DynamicObject, Output sessionContextDiagnostic As %DynamicArray, Output responseText As %String) As %Status
{
    Set toolResult = ""
    Set sessionContextDiagnostic = []
    Set responseText = ""

    Try {
        Set agent = ##class(%AI.Agent).%New(provider)
        If '$IsObject(agent) {
            Return $$$ERROR($$$GeneralError, "Evaluation agent could not be created")
        }

        If phase = "descartes" {
            Set expectedToolName = "EvaluateDiscardHandValue"
            Set sc = agent.UseToolSet("Mus.AI.ToolSet.MusDiscardDecision")
        } Else {
            Set expectedToolName = "EvaluatePlayStrength"
            Set sc = agent.UseToolSet("Mus.AI.ToolSet.MusHandStrength")
        }

        If $$$ISERR(sc) {
            Return sc
        }

        /*
          max_iterations es una propiedad de SESION y limita el numero de
          tool calls por iteracion de Run. La documentacion de AI Hub distingue
          este valor del maximo de turnos pasado a Run().
        */
        Set config = {
            "model": (..#Model),
            "temperature": (+..#Temperature),
            "max_iterations": 1,
            "systemPrompt": (..BuildEvaluationSystemPrompt(phase))
        }

        Set session = agent.CreateSession(config)
        If '$IsObject(session) {
            Return $$$ERROR($$$GeneralError, "Evaluation session could not be created")
        }

        Set goal = ..BuildEvaluationGoal(llmContext, playerId, phase)

        /*
          Un solo turno del agente:
            modelo -> tool call -> ejecucion de tool
          No permitimos un segundo turno con el catalogo de tools todavia activo.
        */
        Set response = agent.Run(session, goal, 1)

        Set sessionContextDiagnostic = ..BuildSessionContextDiagnostic(session)

        If $IsObject(response) {
            Set responseText = ..ExtractResponseText(response)
        }

        Set sc = ..ExtractSingleToolResult(
            session,
            expectedToolName,
            .toolResult
        )

        Return sc
    } Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod RunDecisionStage(provider As %RegisteredObject, llmContext As %DynamicObject, playerId As %String, phase As %String, toolResult As %DynamicObject, Output responseText As %String, Output sessionContextDiagnostic As %DynamicArray) As %Status
{
    Set responseText = ""
    Set sessionContextDiagnostic = []

    Try {
        /*
          Agente deliberadamente SIN UseToolSet().
          La segunda sesion no recibe ningun catalogo de tools.
        */
        Set agent = ##class(%AI.Agent).%New(provider)
        If '$IsObject(agent) {
            Return $$$ERROR($$$GeneralError, "Decision agent could not be created")
        }

        Set config = {
            "model": (..#Model),
            "temperature": (+..#Temperature),
            "max_tokens": 48,
            "systemPrompt": (..BuildDecisionOnlySystemPrompt(phase, llmContext))
        }

        Set session = agent.CreateSession(config)
        If '$IsObject(session) {
            Return $$$ERROR($$$GeneralError, "Decision session could not be created")
        }

        Set goal = ..BuildDecisionOnlyGoal(
            llmContext,
            playerId,
            phase,
            toolResult
        )

        Set response = agent.Run(session, goal, 1)
        Set sessionContextDiagnostic = ..BuildSessionContextDiagnostic(session)

        If '$IsObject(response) {
            Return $$$ERROR($$$GeneralError, "Decision agent returned no response object")
        }

        Set responseText = ..ExtractResponseText(response)
        Return $$$OK
    } Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod ExtractSingleToolResult(session As %RegisteredObject, expectedToolName As %String, Output toolResult As %DynamicObject) As %Status
{
    Set toolResult = ""

    Try {
        If '$IsObject(session) {
            Return $$$ERROR($$$GeneralError, "Tool session is not an object")
        }

        Set messages = session.GetContext()
        If '$IsObject(messages) {
            Return $$$ERROR($$$GeneralError, "Tool session has no context")
        }

        Set callCount = 0
        Set resultCount = 0
        Set toolCallId = ""
        Set toolContent = ""

        Set iter = messages.%GetIterator()

        While iter.%GetNext(.i, .msg) {
            Set role = ""
            Set rawMessage = ""
            Set rawObj = ""

            Try { Set role = msg.role } Catch exRole {}

            /*
              Algunos objetos de contexto de AI Hub no exponen tool_calls
              correctamente mediante acceso directo a propiedades, aunque
              msg.%ToJSON() si contiene el array "tool_calls".

              Por eso usamos la serializacion JSON como fuente mecanica de
              verdad para inspeccionar llamadas y tool_call_id.
            */
            Try {
                Set rawMessage = msg.%ToJSON()
                If rawMessage '= "" {
                    Set rawObj = {}.%FromJSON(rawMessage)
                }
            } Catch exRaw {
                Set rawObj = ""
            }

            If role = "" {
                If $IsObject(rawObj) {
                    Set role = rawObj.%Get("role", "")
                }
            }

            If role = "assistant" {
                Set calls = ""

                /*
                  Primero intentamos el objeto serializado, que es la ruta mas
                  fiable observada con NIM/llama.cpp.
                */
                If $IsObject(rawObj) {
                    Set calls = rawObj.%Get("tool_calls", "")
                }

                /*
                  Fallback por si otro provider si expone tool_calls como
                  propiedad directa.
                */
                If '$IsObject(calls) {
                    Try {
                        Set calls = msg.tool_calls
                    } Catch exCallsDirect {
                        Set calls = ""
                    }
                }

                If $IsObject(calls) {
                    Set callIter = calls.%GetIterator()

                    While callIter.%GetNext(.j, .call) {
                        Set callName = ""
                        Set callId = ""

                        If $IsObject(call) {
                            Set callName = call.%Get("name", "")
                            Set callId = call.%Get("id", "")
                        }

                        /*
                          Algunos formatos OpenAI-style encapsulan la funcion:
                          {"id":"...","type":"function",
                           "function":{"name":"...","arguments":"..."}}
                        */
                        If (callName = "") && $IsObject(call) {
                            Set functionObj = call.%Get("function", "")
                            If $IsObject(functionObj) {
                                Set callName = functionObj.%Get("name", "")
                            }
                        }

                        Set callCount = callCount + 1

                        If callName '= expectedToolName {
                            Set errorMsg = "Unexpected tool call: "_callName_"; expected "_expectedToolName
                            Return $$$ERROR($$$GeneralError,errorMsg)
                        }

                        Set toolCallId = callId
                    }
                }
            }

            If role = "tool" {
                Set currentContent = ""
                Set currentCallId = ""

                If $IsObject(rawObj) {
                    Set currentContent = rawObj.%Get("content", "")
                    Set currentCallId = rawObj.%Get("tool_call_id", "")
                }

                If currentContent = "" {
                    Try { Set currentContent = msg.content } Catch exContent {}
                }

                If currentCallId = "" {
                    Try { Set currentCallId = msg.tool_call_id } Catch exToolCallId {}
                }

                /*
                  Si el wrapper no expone ids, aceptamos el unico role=tool.
                  Si existen ids, deben corresponder a la llamada detectada.
                */
                If (toolCallId = "") || (currentCallId = "") || (currentCallId = toolCallId) {
                    Set resultCount = resultCount + 1
                    Set toolContent = currentContent
                }
            }
        }

        /*
          Para aceptar el resultado exigimos exactamente una llamada y un
          resultado. Si AI Hub cambia el wrapper, rawMessage permite seguir
          contando la llamada aun cuando msg.tool_calls no sea accesible.
        */
        If callCount '= 1 {
            Set errorMsg = "Expected exactly one tool call; got "_callCount
            Return $$$ERROR($$$GeneralError, errorMsg)
        }

        If resultCount '= 1 {
            Set errorMsg = "Expected exactly one tool result; got "_resultCount
            Return $$$ERROR($$$GeneralError, errorMsg)
        }

        If toolContent = "" {
            Set errorMsg = "Tool result content is empty"
            Return $$$ERROR($$$GeneralError, errorMsg)
        }

        Set parsed = {}.%FromJSON(toolContent)
        If '$IsObject(parsed) {
            Set errorMsg = "Tool result is not valid JSON"
            Return $$$ERROR($$$GeneralError, errorMsg)
        }

        If '+parsed.%Get("success", 0) {
            Set errorMsg = "Tool returned success=0: "_toolContent
            Return $$$ERROR($$$GeneralError,errorMsg)
        }

        Set toolResult = parsed
        Return $$$OK
    } Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod BuildEvaluationSystemPrompt(phase As %String) As %String
{
    Set phase = ..NormalizePhase(phase)
    Set p = ""

    If phase = "descartes" {
        Set p = p_"Tu unica tarea es evaluar una mano de Mus mediante EvaluateDiscardHandValue."_$Char(10)
        Set p = p_"Debes llamar exactamente una vez a EvaluateDiscardHandValue con los argumentos proporcionados."_$Char(10)
        Set p = p_"No tomes la decision final entre descartar y cortar_mus."_$Char(10)
        Set p = p_"No llames ninguna otra herramienta."_$Char(10)
        Return p
    }

    Set p = p_"Tu unica tarea es evaluar la fuerza de una mano de Mus mediante EvaluatePlayStrength."_$Char(10)
    Set p = p_"Debes llamar exactamente una vez a EvaluatePlayStrength con los argumentos proporcionados."_$Char(10)
    Set p = p_"No tomes ninguna decision de apuesta."_$Char(10)
    Set p = p_"No llames ninguna otra herramienta."_$Char(10)
    Return p
}

ClassMethod BuildEvaluationGoal(llmContext As %DynamicObject, playerId As %String, phase As %String) As %String
{
    Set cards = llmContext.%Get("cards", [])
    Set cardsJson = "[]"
    If $IsObject(cards) {
        Set cardsJson = cards.%ToJSON()
    }

    Set phase = ..NormalizePhase(phase)

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

        Set p = "Jugador: "_playerId_$Char(10)
        Set p = p_"Evalua esta mano para descartes."_$Char(10)
        Set p = p_"Llama exactamente una vez a EvaluateDiscardHandValue con:"_$Char(10)
        Set p = p_"{""cards"": "_cardsJson_", ""isLastToSpeak"": "_isLastToSpeak_", ""rivalMusCount"": "_rivalMusCount_", ""teammateMusCount"": "_teammateMusCount_"}"_$Char(10)
        Set p = p_"Usa isLastToSpeak como entero 0 o 1."_$Char(10)
        Set p = p_"No decidas la accion final."_$Char(10)
        Return p
    }

    Set toolPlay = ..ResolveToolPlay(llmContext, phase, cardsJson)

    Set p = "Jugador: "_playerId_$Char(10)
    Set p = p_"Evalua esta mano para el lance "_toolPlay_"."_$Char(10)
    Set p = p_"Llama exactamente una vez a EvaluatePlayStrength con:"_$Char(10)
    Set p = p_"{""cards"": "_cardsJson_", ""play"": """_toolPlay_"""}"_$Char(10)
    Set p = p_"No decidas ninguna accion de apuesta."_$Char(10)
    Return p
}

ClassMethod BuildDecisionOnlySystemPrompt(phase As %String, llmContext As %DynamicObject) As %String
{
    Set p = ""
    Set p = p_"Elige UNA sola linea FINAL de las candidatas recibidas."_$Char(10)
    Set p = p_"Copia la linea elegida exactamente."_$Char(10)
    Set p = p_"No razones, no expliques, no listes alternativas y no inventes otra salida."_$Char(10)
    Return p
}

ClassMethod BuildBettingOpeningDecisionRules(phase As %String) As %String
{
    Set p = ""
    Set p = p_"Situacion: no hay envite pendiente."_$Char(10)
    Set p = p_"Aplica la PRIMERA regla que coincida con strength:"_$Char(10)
    Set p = p_"1. weak o very weak: si pasar es legal, DEBES elegir pasar con amount=0. No envides y no elijas ordago."_$Char(10)
    Set p = p_"2. neutral: normalmente pasa; aggressive o bluffer pueden envidar ocasionalmente. ORDAGO PROHIBIDO."_$Char(10)
    Set p = p_"3. strong: puedes envidar si es legal. ORDAGO PROHIBIDO. strong NO es suficiente para ordago."_$Char(10)
    Set p = p_"4. very strong: normalmente envida. Solo aqui puede considerarse ordago, y aun asi debe ser excepcional."_$Char(10)
    Set p = p_"REGLA DE ORDAGO: solo puede elegirse con strength=very strong. Con cualquier otro strength esta prohibido."_$Char(10)
    Set p = p_"REGLA DE MARCADOR: si ambos equipos estan lejos de targetScore, no elijas ordago aunque strength=very strong; prefiere un envite normal."_$Char(10)
    Set p = p_"ordagoFrequency es una frecuencia de rareza, no una invitacion a elegir ordago. Valores bajos como 0.02 o 0.04 significan que debe ser muy infrecuente."_$Char(10)
    Set p = p_"La legalidad de ordago solo significa que puede jugarse; NO significa que sea estrategicamente apropiado."_$Char(10)
    Set p = p_"Las reglas anteriores prevalecen sobre profile, riskTolerance y bluffFrequency."_$Char(10)
    Set p = p_"Nunca enumeres alternativas ni generes varias lineas FINAL|. Debes tomar UNA sola decision."_$Char(10)
    Set p = p_"Si envidas, usa los importes del profile como referencia segun strength."_$Char(10)
    Set p = p_"No expliques nada. Escribe solo una linea que empiece literalmente por FINAL| y termina."_$Char(10)
    Set p = p_"Devuelve una unica linea:"_$Char(10)
    Set p = p_"FINAL|actionType=<accion>|amount=<numero>|strength=<valor>|confidence=<numero>"_$Char(10)
    Return p
}

ClassMethod BuildBettingResponseDecisionRules(phase As %String) As %String
{
    Set p = ""
    Set p = p_"Situacion: respondes a un envite ya abierto."_$Char(10)
    Set p = p_"Aplica la PRIMERA regla que coincida con strength:"_$Char(10)
    Set p = p_"1. weak o very weak: si no_querer es legal, debes elegir no_querer. ORDAGO PROHIBIDO."_$Char(10)
    Set p = p_"2. neutral: considera querer o no_querer; no reenvides normalmente. ORDAGO PROHIBIDO."_$Char(10)
    Set p = p_"3. strong: querer es razonable y puedes considerar reenvidar. ORDAGO PROHIBIDO."_$Char(10)
    Set p = p_"4. very strong: considera seriamente reenvidar. Solo aqui puede considerarse ordago, y debe seguir siendo excepcional."_$Char(10)
    Set p = p_"REGLA DE ORDAGO: solo puede elegirse con strength=very strong. Con cualquier otro strength esta prohibido."_$Char(10)
    Set p = p_"REGLA DE MARCADOR: si ambos equipos estan lejos de targetScore, evita ordago incluso con very strong y prefiere querer o reenvidar."_$Char(10)
    Set p = p_"ordagoFrequency es una frecuencia de rareza, no una invitacion. Valores bajos como 0.02 o 0.04 implican uso muy infrecuente."_$Char(10)
    Set p = p_"La regla 1 y las reglas de ordago prevalecen sobre profile, riskTolerance y bluffFrequency."_$Char(10)
    Set p = p_"No enumeres ni expliques. Devuelve exactamente una sola linea que empiece literalmente por FINAL| y termina."_$Char(10)
    Set p = p_"Devuelve una unica linea:"_$Char(10)
    Set p = p_"FINAL|actionType=<accion>|amount=<numero>|strength=<valor>|confidence=<numero>"_$Char(10)
    Return p
}

ClassMethod BuildDecisionOnlyGoal(llmContext As %DynamicObject, playerId As %String, phase As %String, toolResult As %DynamicObject) As %String
{
    Set phase = ..NormalizePhase(phase)

    Set cards = llmContext.%Get("cards", [])
    Set cardsJson = "[]"
    If $IsObject(cards) {
        Set cardsJson = cards.%ToJSON()
    }

    Set legalActions = llmContext.%Get("legalActions", [])
    Set profile = llmContext.%Get("profile", "")

    Set targetScore = +llmContext.%Get("targetScore", 40)
    If targetScore <= 0 { Set targetScore = 40 }

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

    Set style = ""
    Set riskTolerance = 0
    Set bluffFrequency = 0

    If $IsObject(profile) {
        Set style = profile.%Get("style", profile.%Get("profileId", ""))
        Set riskTolerance = +profile.%Get("riskTolerance", 0)
        Set bluffFrequency = +profile.%Get("bluffFrequency", 0)
    }

    /*
      DESCARTES:
      si la evaluacion ya trae un bias categorico, no reabrimos la decision
      entre descartar y cortar_mus.
    */
    If phase = "descartes" {
        Set globalStrength = ""
        Set recommendedBias = ""
        Set cardAnalysis = []

        If $IsObject(toolResult) {
            Set globalStrength = toolResult.%Get("globalStrength", "")
            Set recommendedBias = toolResult.%Get("recommendedBias", "")
            Set cardAnalysis = toolResult.%Get("cardAnalysis", [])
        }

        If recommendedBias = "cut_mus" {
            Return "COPIA EXACTAMENTE ESTA LINEA:"_$Char(10)_
                   "FINAL|actionType=cortar_mus|amount=0|discards=|globalStrength="_globalStrength_"|recommendedBias=cut_mus|confidence=0.8"
        }

        If (recommendedBias = "ask_mus") || (recommendedBias = "borderline") {
            /*
              Para un modelo pequeno, no le pedimos que "analice" cardAnalysis.
              Construimos mecanicamente el conjunto de cartas candidatas a descarte:
              solo cartas que NO estan marcadas como valiosas para grande/chica
              y que NO forman parte de pares.

              El LLM conserva libertad estrategica eligiendo entre combinaciones
              concretas de esas cartas, pero ya no tiene que razonar sobre JSON.
            */
            Set discardable = []

            If $IsObject(cardAnalysis) {
                Set iter = cardAnalysis.%GetIterator()

                While iter.%GetNext(.i, .item) {
                    If '$IsObject(item) {
                        Continue
                    }

                    Set valuableForGrande = +item.%Get("valuableForGrande", 0)
                    Set valuableForChica = +item.%Get("valuableForChica", 0)
                    Set partOfPair = +item.%Get("partOfPair", 0)
                    Set card = item.%Get("card", "")

                    If (card '= "") &&
                       ('valuableForGrande) &&
                       ('valuableForChica) &&
                       ('partOfPair) {
                        Do discardable.%Push(card)
                    }
                }
            }

            /*
              Si no hay ninguna carta claramente descartable segun cardAnalysis,
              dejamos al LLM elegir una carta original, pero con un prompt minimo.
            */
            If discardable.%Size() = 0 {
                If recommendedBias = "borderline" {
                    Return "COPIA EXACTAMENTE ESTA LINEA:"_$Char(10)_
                           "FINAL|actionType=cortar_mus|amount=0|discards=|globalStrength="_globalStrength_"|recommendedBias=borderline|confidence=0.7"
                }

                Set p = "ELIGE UNA SOLA LINEA Y COPIALA EXACTAMENTE:"_$Char(10)

                For i=0:1:cards.%Size()-1 {
                    Set card = cards.%Get(i)
                    Set p = p_"FINAL|actionType=descartar|amount=0|discards="_card_"|globalStrength="_globalStrength_"|recommendedBias="_recommendedBias_"|confidence=0.8"_$Char(10)
                }

                Return p
            }

            /*
              Generamos candidatas exactas. Como una mano de Mus tiene 4 cartas,
              como maximo hay 15 subconjuntos no vacios.
            */
            Set p = "ELIGE UNA SOLA LINEA Y COPIALA EXACTAMENTE:"_$Char(10)

            If recommendedBias = "borderline" {
                Set p = p_"FINAL|actionType=cortar_mus|amount=0|discards=|globalStrength="_globalStrength_"|recommendedBias=borderline|confidence=0.7"_$Char(10)
            }

            Set n = discardable.%Size()

            For a=0:1:n-1 {
                Set c1 = discardable.%Get(a)
                Set p = p_"FINAL|actionType=descartar|amount=0|discards="_c1_"|globalStrength="_globalStrength_"|recommendedBias="_recommendedBias_"|confidence=0.8"_$Char(10)

                For b=a+1:1:n-1 {
                    Set c2 = discardable.%Get(b)
                    Set p = p_"FINAL|actionType=descartar|amount=0|discards="_c1_","_c2_"|globalStrength="_globalStrength_"|recommendedBias="_recommendedBias_"|confidence=0.8"_$Char(10)

                    For c=b+1:1:n-1 {
                        Set c3 = discardable.%Get(c)
                        Set p = p_"FINAL|actionType=descartar|amount=0|discards="_c1_","_c2_","_c3_"|globalStrength="_globalStrength_"|recommendedBias="_recommendedBias_"|confidence=0.8"_$Char(10)

                        For d=c+1:1:n-1 {
                            Set c4 = discardable.%Get(d)
                            Set p = p_"FINAL|actionType=descartar|amount=0|discards="_c1_","_c2_","_c3_","_c4_"|globalStrength="_globalStrength_"|recommendedBias="_recommendedBias_"|confidence=0.8"_$Char(10)
                        }
                    }
                }
            }

            Return p
        }

        Set p = "legalActions="_legalActions.%ToJSON()_$Char(10)
        Set p = p_"globalStrength="_globalStrength_"; recommendedBias="_recommendedBias_$Char(10)
        Set p = p_"Devuelve solo una linea FINAL valida."
        Return p
    }

    /*
      APUESTAS:
      strength viene fijado por la primera sesion.
      El LLM solo selecciona entre candidatos compatibles con esa strength.
      Los importes normales se mantienen entre 2 y 5.
    */
    Set strength = ""
    If $IsObject(toolResult) {
        Set strength = toolResult.%Get("strength", "")
    }

    Set pendingBet = llmContext.%Get("pendingBet", "")
    Set hasPendingBet = 0
    Set pendingBetAmount = 0

    If $IsObject(pendingBet) {
        Set pendingBetAmount = +pendingBet.%Get("amount", 0)
        If pendingBetAmount > 0 {
            Set hasPendingBet = 1
        }
    }

    Set p = "strength="_strength_$Char(10)
    Set p = p_"marcador="_myScore_"-"_opponentScore_" a "_targetScore_$Char(10)
    Set p = p_"perfil="_style_"; risk="_riskTolerance_"; bluff="_bluffFrequency_$Char(10)
    Set p = p_"ELIGE UNA SOLA DE ESTAS LINEAS Y COPIALA EXACTAMENTE:"_$Char(10)

    If hasPendingBet {
        /*
          Respuesta a envite:
          - weak/very weak: solo no_querer;
          - neutral: querer/no_querer;
          - strong: querer + reenvidos legales 2..4;
          - very strong: querer + reenvidos legales 2..5.
        */
        If (strength = "weak") || (strength = "very weak") {
            If ..ArrayContains(legalActions, "no_querer") {
                Set p = p_"FINAL|actionType=no_querer|amount=0|strength="_strength_"|confidence=0.8"_$Char(10)
            }
            Return p
        }

        If strength = "neutral" {
            If ..ArrayContains(legalActions, "querer") {
                Set p = p_"FINAL|actionType=querer|amount="_pendingBetAmount_"|strength=neutral|confidence=0.6"_$Char(10)
            }

            If ..ArrayContains(legalActions, "no_querer") {
                Set p = p_"FINAL|actionType=no_querer|amount=0|strength=neutral|confidence=0.6"_$Char(10)
            }

            Return p
        }

        If strength = "strong" {
            If ..ArrayContains(legalActions, "querer") {
                Set p = p_"FINAL|actionType=querer|amount="_pendingBetAmount_"|strength=strong|confidence=0.8"_$Char(10)
            }

            If ..ArrayContains(legalActions, "envidar") {
                For amount=2:1:4 {
                    If amount > pendingBetAmount {
                        Set p = p_"FINAL|actionType=envidar|amount="_amount_"|strength=strong|confidence=0.8"_$Char(10)
                    }
                }
            }

            Return p
        }

        If strength = "very strong" {
            If ..ArrayContains(legalActions, "querer") {
                Set p = p_"FINAL|actionType=querer|amount="_pendingBetAmount_"|strength=very strong|confidence=0.9"_$Char(10)
            }

            If ..ArrayContains(legalActions, "envidar") {
                For amount=2:1:5 {
                    If amount > pendingBetAmount {
                        Set p = p_"FINAL|actionType=envidar|amount="_amount_"|strength=very strong|confidence=0.9"_$Char(10)
                    }
                }
            }

            Return p
        }
    } Else {
        /*
          Apertura:
          - weak/very weak: pasar;
          - neutral: pasar y, solo para aggressive/bluffer, envidar 2;
          - strong: envidar 2,3,4;
          - very strong: envidar 2,3,4,5.
        */
        If (strength = "weak") || (strength = "very weak") {
            If ..ArrayContains(legalActions, "pasar") {
                Set p = p_"FINAL|actionType=pasar|amount=0|strength="_strength_"|confidence=0.8"_$Char(10)
            }
            Return p
        }

        If strength = "neutral" {
            If ..ArrayContains(legalActions, "pasar") {
                Set p = p_"FINAL|actionType=pasar|amount=0|strength=neutral|confidence=0.6"_$Char(10)
            }

            If ..ArrayContains(legalActions, "envidar") && ((style = "aggressive") || (style = "bluffer")) {
                Set p = p_"FINAL|actionType=envidar|amount=2|strength=neutral|confidence=0.6"_$Char(10)
            }

            Return p
        }

        If strength = "strong" {
            If ..ArrayContains(legalActions, "envidar") {
                For amount=2:1:4 {
                    Set p = p_"FINAL|actionType=envidar|amount="_amount_"|strength=strong|confidence=0.8"_$Char(10)
                }
            }
            Return p
        }

        If strength = "very strong" {
            If ..ArrayContains(legalActions, "envidar") {
                For amount=2:1:5 {
                    Set p = p_"FINAL|actionType=envidar|amount="_amount_"|strength=very strong|confidence=0.9"_$Char(10)
                }
            }
            Return p
        }
    }

    Set p = p_"legalActions="_legalActions.%ToJSON()_$Char(10)
    Set p = p_"Devuelve solo una linea FINAL valida."
    Return p
}

ClassMethod AttachTwoStageDiagnostics(json As %String, toolResult As %DynamicObject, evaluationContext As %DynamicArray, decisionContext As %DynamicArray, evaluationResponseText As %String, decisionResponseText As %String, evaluationMs As %Integer, decisionMs As %Integer) As %String
{
    If json = "" {
        Return json
    }

    Try {
        Set obj = {}.%FromJSON(json)
        If '$IsObject(obj) {
            Return json
        }

        If $IsObject(toolResult) {
            Do obj.%Set("toolResultDiagnostic", toolResult)
        }

        If $IsObject(evaluationContext) {
            Do obj.%Set("evaluationSessionContextDiagnostic", evaluationContext)
        }

        If $IsObject(decisionContext) {
            Do obj.%Set("decisionSessionContextDiagnostic", decisionContext)
        }

        Do obj.%Set("evaluationResponseTextDiagnostic", evaluationResponseText)
        Do obj.%Set("decisionResponseTextDiagnostic", decisionResponseText)

        Do obj.%Set("timing", {
            "evaluationMs": (+evaluationMs),
            "decisionMs": (+decisionMs),
            "totalMs": (+(evaluationMs + decisionMs))
        })

        Return obj.%ToJSON()
    } Catch ex {
        Return json
    }
}

ClassMethod BuildTwoStageDiagnostic(error As %String, phase As %String, toolResult As %DynamicObject = "", evaluationContext As %DynamicArray = "", decisionContext As %DynamicArray = "", evaluationResponseText As %String = "", decisionResponseText As %String = "", evaluationMs As %Integer = 0, decisionMs As %Integer = 0) As %String
{
    Try {
        Set result = {
            "success": 0,
            "diagnostic": 1,
            "error": (error),
            "phase": (phase),
            "evaluationResponseText": (evaluationResponseText),
            "decisionResponseText": (decisionResponseText),
            "timing": {
                "evaluationMs": (+evaluationMs),
                "decisionMs": (+decisionMs),
                "totalMs": (+(evaluationMs + decisionMs))
            }
        }

        If $IsObject(toolResult) {
            Do result.%Set("toolResult", toolResult)
        }

        If $IsObject(evaluationContext) {
            Do result.%Set("evaluationSessionContext", evaluationContext)
        }

        If $IsObject(decisionContext) {
            Do result.%Set("decisionSessionContext", decisionContext)
        }

        Return result.%ToJSON()
    } Catch ex {
        Return "{""success"":0,""diagnostic"":1,""error"":""TWO_STAGE_DIAGNOSTIC_FAILED""}"
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

ClassMethod BuildPhaseSpecificSystemPrompt(phase As %String, llmContext As %DynamicObject = "") As %String
{
    Set phase = ..NormalizePhase(phase)

    If phase = "descartes" {
        Return ..BuildDiscardDecisionSystemPrompt()
    }

    Set pendingBet = ""
    Set hasPendingBet = 0

    If $IsObject(llmContext) {
        Set pendingBet = llmContext.%Get("pendingBet", "")
        If $IsObject(pendingBet) {
            If +pendingBet.%Get("amount", 0) > 0 {
                Set hasPendingBet = 1
            }
        }
    }

    If hasPendingBet {
        Return ..BuildBettingResponseSystemPrompt(phase)
    }

    Return ..BuildBettingOpeningSystemPrompt(phase)
}

ClassMethod BuildBettingBaseSystemPrompt(phase As %String) As %String
{
    Set p = ""
    Set p = p_"Eres un agente de Mus. Decide una sola accion para el lance "_phase_"."_$Char(10)
    Set p = p_"EvaluatePlayStrength es la UNICA herramienta permitida y debes llamarla exactamente una vez antes de decidir."_$Char(10)
    Set p = p_"Despues de recibir el resultado de EvaluatePlayStrength, esta TERMINANTEMENTE PROHIBIDO llamar o escribir ScoreToStrength, BuildReason, Score, HandStrengthHelper o cualquier otra funcion."_$Char(10)
    Set p = p_"Despues del resultado de EvaluatePlayStrength NO escribas objetos con campos name, parameters, arguments o tool_calls."_$Char(10)
    Set p = p_"Despues de la tool, tu siguiente y unica salida debe comenzar literalmente por FINAL|."_$Char(10)
    Set p = p_"Usa strength devuelto por la tool como senal principal."_$Char(10)
    Set p = p_"Elige exclusivamente una accion presente en legalActions y copia actionType literalmente."_$Char(10)
    Set p = p_"No sustituyas envidar por enviar."_$Char(10)
    Set p = p_"Formato final unico:"_$Char(10)
    Set p = p_"FINAL|actionType=<accion>|amount=<numero>|strength=<valor>|confidence=<numero>"_$Char(10)
    Set p = p_"No escribas JSON, markdown, explicaciones ni texto antes o despues de FINAL|... ."_$Char(10)
    Return p
}

ClassMethod BuildBettingOpeningSystemPrompt(phase As %String) As %String
{
    Set p = ..BuildBettingBaseSystemPrompt(phase)
    Set p = p_"SITUACION: no hay envite pendiente; debes decidir entre pasar, abrir envite u ordago segun legalActions."_$Char(10)
    Set p = p_"very strong: normalmente envida si es legal."_$Char(10)
    Set p = p_"strong: considera seriamente envidar."_$Char(10)
    Set p = p_"neutral: normalmente pasa; perfiles aggressive o bluffer pueden envidar ocasionalmente."_$Char(10)
    Set p = p_"weak o very weak: normalmente pasa."_$Char(10)
    Set p = p_"Si envidas, usa los importes del profile como referencia: baseEnvidoAmount, strongHandEnvidoAmount o veryStrongHandEnvidoAmount segun strength."_$Char(10)
    Set p = p_"ordago es excepcional y solo puede elegirse si esta en legalActions."_$Char(10)
    Return p
}

ClassMethod BuildBettingResponseSystemPrompt(phase As %String) As %String
{
    Set p = ..BuildBettingBaseSystemPrompt(phase)
    Set p = p_"SITUACION: estas respondiendo a un envite ya abierto."_$Char(10)
    Set p = p_"Aplica la PRIMERA regla que coincida con el strength recibido:"_$Char(10)
    Set p = p_"1. weak o very weak: si no_querer es legal, DEBES elegir no_querer."_$Char(10)
    Set p = p_"2. neutral: considera querer o no_querer; reenvidar debe ser excepcional."_$Char(10)
    Set p = p_"3. strong: querer es razonable y puedes considerar reenvidar."_$Char(10)
    Set p = p_"4. very strong: considera seriamente reenvidar si es legal."_$Char(10)
    Set p = p_"La regla 1 tiene prioridad sobre profile, riskTolerance y bluffFrequency."_$Char(10)
    Set p = p_"Con weak o very weak no elijas querer, envidar ni ordago cuando no_querer sea legal."_$Char(10)
    Set p = p_"ordago sigue siendo excepcional."_$Char(10)
    Return p
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
    If '$IsObject(llmContext) {
        Return "{}"
    }

    Set phase = ..NormalizePhase(llmContext.%Get("phase", ""))

    If phase = "descartes" {
        Return ..BuildDiscardDecisionGoal(llmContext, playerId)
    }

    Set pendingBet = llmContext.%Get("pendingBet", "")
    If $IsObject(pendingBet) {
        If +pendingBet.%Get("amount", 0) > 0 {
            Return ..BuildBettingResponseGoal(llmContext, playerId, phase)
        }
    }

    Return ..BuildBettingOpeningGoal(llmContext, playerId, phase)
}

ClassMethod BuildGoalCommonContext(llmContext As %DynamicObject, playerId As %String, phase As %String, Output cardsJson As %String, Output toolPlay As %String, Output legalActions As %DynamicArray, Output profile As %DynamicObject) As %String
{
    Set p = ""
    Set cards = llmContext.%Get("cards", [])
    Set cardsJson = "[]"

    If $IsObject(cards) {
        Set cardsJson = cards.%ToJSON()
    }

    Set toolPlay = ..ResolveToolPlay(llmContext, phase, cardsJson)
    Set legalActions = llmContext.%Get("legalActions", [])
    Set profile = llmContext.%Get("profile", "")

    Set targetScore = +llmContext.%Get("targetScore", 40)
    If targetScore <= 0 { Set targetScore = 40 }

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
    Set p = p_"Lance: "_phase_$Char(10)
    Set p = p_"Cartas: "_cardsJson_$Char(10)

    If $IsObject(legalActions) {
        Set p = p_"legalActions: "_legalActions.%ToJSON()_$Char(10)
    } Else {
        Set p = p_"legalActions: []"_$Char(10)
    }

    Set p = p_"Marcador: "_myScore_"-"_opponentScore_" a "_targetScore_$Char(10)

    If $IsObject(profile) {
        Set p = p_"profile: "_profile.%ToJSON()_$Char(10)
    }

    Return p
}

ClassMethod BuildBettingToolInstruction(cardsJson As %String, toolPlay As %String) As %String
{
    Set p = ""
    Set p = p_"PASO 1: llama exactamente una vez a EvaluatePlayStrength con:"_$Char(10)
    Set p = p_"{""cards"": "_cardsJson_", ""play"": """_toolPlay_"""}"_$Char(10)
    Set p = p_"PASO 2: al recibir el resultado, no llames ninguna funcion mas."_$Char(10)
    Set p = p_"No llames ni escribas ScoreToStrength, BuildReason, Score, HandStrengthHelper ni ninguna funcion auxiliar."_$Char(10)
    Set p = p_"No generes objetos de tool call ni estructuras con name, parameters, arguments o tool_calls."_$Char(10)
    Set p = p_"Tu siguiente mensaje debe empezar directamente por FINAL| y contener solo la linea final."_$Char(10)
    Return p
}

ClassMethod BuildBettingOpeningGoal(llmContext As %DynamicObject, playerId As %String, phase As %String) As %String
{
    Set p = ..BuildGoalCommonContext(llmContext, playerId, phase, .cardsJson, .toolPlay, .legalActions, .profile)
    Set p = p_"Situacion: NO hay pendingBet."_$Char(10)
    Set p = p_..BuildBettingToolInstruction(cardsJson, toolPlay)
    Set p = p_"Decision tras la tool:"_$Char(10)
    Set p = p_"very strong -> normalmente envidar si es legal."_$Char(10)
    Set p = p_"strong -> considerar seriamente envidar."_$Char(10)
    Set p = p_"neutral -> normalmente pasar; aggressive/bluffer puede envidar ocasionalmente."_$Char(10)
    Set p = p_"weak o very weak -> normalmente pasar."_$Char(10)
    Set p = p_"Si eliges envidar usa un importe del profile coherente con strength y legal."_$Char(10)
    Set p = p_"pasar usa amount=0. ordago usa amount=999."_$Char(10)
    Return p
}

ClassMethod BuildBettingResponseGoal(llmContext As %DynamicObject, playerId As %String, phase As %String) As %String
{
    Set p = ..BuildGoalCommonContext(llmContext, playerId, phase, .cardsJson, .toolPlay, .legalActions, .profile)

    Set pendingBet = llmContext.%Get("pendingBet", "")
    Set pendingBetAmount = 0
    If $IsObject(pendingBet) {
        Set pendingBetAmount = +pendingBet.%Get("amount", 0)
        Set p = p_"pendingBet: "_pendingBet.%ToJSON()_$Char(10)
    }

    Set minRaiseAmount = pendingBetAmount + 1

    Set p = p_"Situacion: RESPONDES a un envite. No estas abriendo uno nuevo desde cero."_$Char(10)
    Set p = p_..BuildBettingToolInstruction(cardsJson, toolPlay)
    Set p = p_"Aplica la PRIMERA regla que coincida:"_$Char(10)
    Set p = p_"1. weak o very weak -> no_querer, amount=0, si no_querer es legal."_$Char(10)
    Set p = p_"2. neutral -> querer o no_querer; no reenvides normalmente."_$Char(10)
    Set p = p_"3. strong -> querer o considerar reenvidar."_$Char(10)
    Set p = p_"4. very strong -> considerar seriamente reenvidar."_$Char(10)
    Set p = p_"La regla 1 prevalece sobre profile, riskTolerance y bluffFrequency."_$Char(10)
    Set p = p_"Importes: querer="_pendingBetAmount_", no_querer=0, reenvido minimo="_minRaiseAmount_", ordago=999."_$Char(10)
    Set p = p_"Si strength=weak o very weak y no_querer es legal, ejemplo de salida: FINAL|actionType=no_querer|amount=0|strength=weak|confidence=0.8"_$Char(10)
    Return p
}

ClassMethod BuildDiscardDecisionGoal(llmContext As %DynamicObject, playerId As %String) As %String
{
    Set phase = "descartes"
    Set p = ..BuildGoalCommonContext(llmContext, playerId, phase, .cardsJson, .toolPlay, .legalActions, .profile)

    Set discardTurnInfo = llmContext.%Get("discardTurnInfo", "")
    Set isLastToSpeak = 0
    Set rivalMusCount = 0
    Set teammateMusCount = 0

    If $IsObject(discardTurnInfo) {
        Set isLastToSpeak = +discardTurnInfo.%Get("isLastToSpeak", 0)
        Set rivalMusCount = +discardTurnInfo.%Get("rivalMusCount", 0)
        Set teammateMusCount = +discardTurnInfo.%Get("teammateMusCount", 0)
    }

    Set p = p_"Situacion: fase de descartes."_$Char(10)
    Set p = p_"PASO 1: llama UNA SOLA VEZ a EvaluateDiscardHandValue con EXACTAMENTE estos argumentos:"_$Char(10)
    Set p = p_"{""cards"": "_cardsJson_", ""isLastToSpeak"": "_isLastToSpeak_", ""rivalMusCount"": "_rivalMusCount_", ""teammateMusCount"": "_teammateMusCount_"}"_$Char(10)
    Set p = p_"Estos argumentos son fijos. No cambies isLastToSpeak, rivalMusCount, teammateMusCount ni cards."_$Char(10)
    Set p = p_"Para isLastToSpeak usa exclusivamente el numero 0 o 1. Nunca uses true, false, True ni False."_$Char(10)
    Set p = p_"Si ya has recibido el resultado de EvaluateDiscardHandValue, NO vuelvas a llamar EvaluateDiscardHandValue."_$Char(10)
    Set p = p_"PASO 2: usa directamente el resultado recibido. No recalcules ningun campo."_$Char(10)
    Set p = p_"No llames ni escribas BuildReason, BuildRecommendedBias, EvaluatePares, HandPoints, PairType, ParseCards, ScoreToGlobalStrength, StrengthScore ni ninguna funcion adicional."_$Char(10)
    Set p = p_"No generes objetos de tool call ni estructuras con name, parameters, arguments o tool_calls."_$Char(10)
    Set p = p_"recommendedBias=ask_mus -> actionType=descartar."_$Char(10)
    Set p = p_"globalStrength=weak o very weak -> actionType no puede ser cortar_mus."_$Char(10)
    Set p = p_"recommendedBias=cut_mus y fuerza suficiente -> puedes cortar_mus si es legal."_$Char(10)
    Set p = p_"Si eliges descartar, decide tu las cartas concretas usando solamente Cartas originales; NO vuelvas a llamar la tool para elegir descartes."_$Char(10)
    Set p = p_"Si actionType=descartar, discards es OBLIGATORIO y debe contener una o mas cartas exactas de Cartas separadas por comas."_$Char(10)
    Set p = p_"Nunca devuelvas actionType=descartar con discards vacio."_$Char(10)
    Set p = p_"No inventes cartas ni modifiques sus codigos."_$Char(10)
    Set p = p_"Solo actionType=cortar_mus usa discards= vacio."_$Char(10)
    Set p = p_"PASO 3: tu siguiente mensaje debe empezar directamente por FINAL| y contener solo la linea final."_$Char(10)
    Set p = p_"Salida unica: FINAL|actionType=<accion>|amount=0|discards=<cartas_separadas_por_comas>|globalStrength=<valor>|recommendedBias=<valor>|confidence=<numero>"_$Char(10)
    Set p = p_"Ejemplo si decides descartar dos cartas: FINAL|actionType=descartar|amount=0|discards=4O,2C|globalStrength=very weak|recommendedBias=ask_mus|confidence=0.8"_$Char(10)
    Return p
}

ClassMethod ResolveMaxIterations(llmContext As %DynamicObject, phase As %String) As %Integer
{
    Return ..#MaxIterations
}

ClassMethod BuildInvalidAgentDiagnostic(responseText As %String, phase As %String, createSessionMs As %Integer, agentRunMs As %Integer, sessionToRunMs As %Integer, maxIterations As %Integer, sessionContextDiagnostic As %DynamicArray = "") As %String
{
    Try {
        /*
          Limitamos el texto bruto para no convertir una respuesta diagnostica
          en un payload enorme, pero conservamos suficiente contenido para ver
          exactamente como termino agent.Run().
        */
        Set rawText = responseText
        If $Length(rawText) > 4000 {
            Set rawText = $Extract(rawText, 1, 4000)
        }

        Set timing = {
            "createSessionMs": (+createSessionMs),
            "agentRunMs": (+agentRunMs),
            "sessionToRunMs": (+sessionToRunMs),
            "maxIterations": (+maxIterations)
        }

        Set result = {
            "success": 0,
            "diagnostic": 1,
            "error": "INVALID_AGENT_JSON",
            "phase": (phase),
            "rawAgentText": (rawText),
            "sessionContext": (sessionContextDiagnostic),
            "timing": (timing)
        }

        Return result.%ToJSON()
    } Catch ex {
        Return "{""success"":0,""diagnostic"":1,""error"":""INVALID_AGENT_JSON_DIAGNOSTIC_FAILED""}"
    }
}

ClassMethod BuildSessionContextDiagnostic(session As %RegisteredObject) As %DynamicArray
{
    Set out = []

    Try {
        If '$IsObject(session) {
            Return out
        }

        Set messages = session.GetContext()
        If '$IsObject(messages) {
            Return out
        }

        Set iter = messages.%GetIterator()

        While iter.%GetNext(.i, .msg) {
            Set item = {
                "index": (+i),
                "role": "",
                "content": "",
                "name": "",
                "toolCallId": "",
                "toolCalls": []
            }

            Try { Do item.%Set("role", msg.role) } Catch exRole {}
            Try { Do item.%Set("content", msg.content) } Catch exContent {}
            Try { Do item.%Set("name", msg.name) } Catch exName {}
            Try { Do item.%Set("toolCallId", msg.tool_call_id) } Catch exToolCallId {}

            Try {
                Set calls = msg.tool_calls
                If $IsObject(calls) {
                    Do item.%Set("toolCalls", calls)
                }
            } Catch exToolCalls {}

            /*
              Algunos providers/objetos exponen propiedades adicionales.
              Conservamos una serializacion JSON cuando sea posible para no perder
              argumentos o metadatos de tool calls durante el diagnostico.
            */
            Try {
                Set rawMessage = msg.%ToJSON()
                If rawMessage '= "" {
                    Do item.%Set("rawMessage", rawMessage)
                }
            } Catch exRaw {}

            Do out.%Push(item)
        }
    } Catch ex {
        Do out.%Push({
            "diagnosticError": (ex.DisplayString())
        })
    }

    Return out
}

ClassMethod AttachSessionContextDiagnostic(json As %String, sessionContextDiagnostic As %DynamicArray) As %String
{
    If json = "" {
        Return json
    }

    Try {
        Set obj = {}.%FromJSON(json)
        If '$IsObject(obj) {
            Return json
        }

        If $IsObject(sessionContextDiagnostic) {
            Do obj.%Set("sessionContextDiagnostic", sessionContextDiagnostic)
        }

        Return obj.%ToJSON()
    } Catch ex {
        Return json
    }
}

ClassMethod AttachTimingToJson(json As %String, createSessionMs As %Integer, agentRunMs As %Integer, sessionToRunMs As %Integer, maxIterations As %Integer) As %String
{
    If json = "" {
        Return json
    }

    Try {
        Set obj = {}.%FromJSON(json)
        If '$IsObject(obj) {
            Return json
        }

        Set timing = {
            "createSessionMs": (+createSessionMs),
            "agentRunMs": (+agentRunMs),
            "sessionToRunMs": (+sessionToRunMs),
            "maxIterations": (+maxIterations)
        }

        Do obj.%Set("timing", timing)

        Set reason = obj.%Get("reason", "")
        If $IsObject(reason) {
            /* reason estructurado: conservarlo sin convertirlo a texto */
        } ElseIf reason '= "" {
            Do obj.%Set("reason", ..CompactReason(reason))
        }

        Return obj.%ToJSON()
    } Catch ex {
        Return json
    }
}

ClassMethod NowMs() As %Numeric
{
    /*
      $ZHOROLOG devuelve segundos monotónicos con fracción.
      Convertimos directamente a milisegundos.
    */
    Return $ZHOROLOG * 1000
}

ClassMethod ElapsedMs(startMs As %Numeric) As %Integer
{
    Try {
        Set elapsed = ..NowMs() - startMs
        If elapsed < 0 {
            Return 0
        }

        Return $Justify(elapsed, 0, 0)
    } Catch ex {
        Return 0
    }
}

ClassMethod BuildReasonFromResponseText(actionType As %String, responseText As %String = "") As %String
{
    Try {
        Set reason = $Extract($ZSTRIP(responseText, "<>W"), 1, ..#MaxReasonLength)

        If reason = "" {
            Set reason = "action="_actionType
        }

        Return ..CompactReason(reason)
    } Catch ex {
        Return "action="_actionType
    }
}

ClassMethod ChooseDeclineAction(llmContext As %DynamicObject) As %DynamicObject
{
    Set result = {
        "actionType": "",
        "amount": 0
    }

    If '$IsObject(llmContext) {
        Return result
    }

    Set legalActions = llmContext.%Get("legalActions", "")
    If '$IsObject(legalActions) {
        Return result
    }

    /*
      Acciones defensivas/evasivas. En respuesta a envite, aceptar ("querer")
      NO es un fallback seguro para una recomendacion original de pasar.
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

    Return result
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

ClassMethod NormalizeActionType(actionType As %String) As %String
{
    Set actionType = $ZCONVERT($ZSTRIP(actionType, "<>W"), "L")

    /*
      Normalizacion puramente lexical del transporte final.
      No cambia la estrategia decidida por el LLM.
    */
    If actionType = "enviar" {
        Return "envidar"
    }

    Return actionType
}

ClassMethod EnsureLegalJson(json As %String, phase As %String, llmContext As %DynamicObject) As %String
{
    If json = "" {
        Return json
    }

    Try {
        Set obj = {}.%FromJSON(json)
        If '$IsObject(obj) {
            Return json
        }

        Set originalActionType = obj.%Get("actionType", "")
        Set actionType = ..NormalizeActionType(originalActionType)
        If actionType '= originalActionType {
            Do obj.%Set("actionType", actionType)
        }
        Set legalActions = llmContext.%Get("legalActions", "")

        If '$IsObject(legalActions) {
            Return json
        }

        If ..ArrayContains(legalActions, actionType) {
            Return json
        }

        /*
          Si el LLM queria pasar/no querer y esa accion concreta no es legal,
          no debemos convertirla en querer. Aceptar un envite no es una
          reparacion segura de una intencion defensiva.
        */
        If (actionType = "pasar") || (actionType = "no_querer") {
            Set declineAction = ..ChooseDeclineAction(llmContext)
            Set declineType = declineAction.%Get("actionType", "")
            If declineType '= "" {
                Set safeAction = declineAction
            } Else {
                Set safeAction = ..ChooseSafeAction(llmContext)
            }
        } Else {
            Set safeAction = ..ChooseSafeAction(llmContext)
        }

        Set safeType = safeAction.%Get("actionType", "pasar")
        Set safeAmount = +safeAction.%Get("amount", 0)

        Do obj.%Set("actionType", safeType)
        Do obj.%Set("amount", safeAmount)

        If safeType '= "descartar" {
            Do obj.%Set("discards", [])
        }

        Set reason = obj.%Get("reason", "")
        If $IsObject(reason) {
            Do reason.%Set("repairedIllegalAction", actionType)
            Do reason.%Set("repairedAction", safeType)
            Do obj.%Set("reason", reason)
        } Else {
            If reason = "" {
                Set reason = "Reparada accion ilegal: "_actionType_" no estaba en legalActions; action="_safeType
            } Else {
                Set reason = reason_"; repairedIllegalAction="_actionType
            }
            Do obj.%Set("reason", ..CompactReason(reason))
        }

        Do obj.%Set("formatRecovered", 1)
        Do obj.%Set("legalRepaired", 1)

        Return obj.%ToJSON()
    } Catch ex {
        Return json
    }
}

ClassMethod BuildBettingDecisionSystemPrompt() As %String
{
    Set p = ""
    Set p = p_"Prompt legacy de compatibilidad. La ruta activa usa BuildPhaseSpecificSystemPrompt(phase,llmContext)."_$Char(10)
    Set p = p_"Usa EvaluatePlayStrength exactamente una vez, elige solo legalActions y devuelve FINAL|actionType=<accion>|amount=<numero>|strength=<valor>|confidence=<numero>."_$Char(10)
    Return p
}

ClassMethod BuildDiscardDecisionSystemPrompt() As %String
{
    Set p = ""
    Set p = p_"Eres un agente de Mus en fase de descartes."_$Char(10)
    Set p = p_"EvaluateDiscardHandValue es la UNICA herramienta permitida y debes llamarla exactamente una vez."_$Char(10)
    Set p = p_"Los argumentos de EvaluateDiscardHandValue son datos FIJOS del contexto. No los cambies, no los reinterpretres y no vuelvas a evaluar la mano con otros valores."_$Char(10)
    Set p = p_"En EvaluateDiscardHandValue, isLastToSpeak debe serializarse exclusivamente como entero 0 o 1; nunca como true, false, True o False."_$Char(10)
    Set p = p_"Si ya has recibido un resultado de EvaluateDiscardHandValue, esta PROHIBIDO volver a llamar EvaluateDiscardHandValue."_$Char(10)
    Set p = p_"Despues de recibir el resultado de EvaluateDiscardHandValue, esta TERMINANTEMENTE PROHIBIDO llamar o escribir BuildReason, BuildRecommendedBias, EvaluatePares, HandPoints, PairType, ParseCards, ScoreToGlobalStrength, StrengthScore o cualquier otra funcion."_$Char(10)
    Set p = p_"Despues del resultado NO escribas objetos con campos name, parameters, arguments o tool_calls."_$Char(10)
    Set p = p_"Usa directamente globalStrength y recommendedBias devueltos por EvaluateDiscardHandValue. No recalcules ni completes esos valores."_$Char(10)
    Set p = p_"recommendedBias=ask_mus -> actionType=descartar."_$Char(10)
    Set p = p_"globalStrength=weak o very weak -> actionType no puede ser cortar_mus."_$Char(10)
    Set p = p_"Usa solamente acciones incluidas en legalActions."_$Char(10)
    Set p = p_"Si actionType=descartar, discards NO puede estar vacio."_$Char(10)
    Set p = p_"Si actionType=descartar, elige una o mas cartas concretas tomadas literalmente de cards y escribelas separadas por comas en discards."_$Char(10)
    Set p = p_"No inventes cartas y no escribas ninguna carta que no aparezca exactamente en cards."_$Char(10)
    Set p = p_"Si actionType=cortar_mus, usa discards= vacio."_$Char(10)
    Set p = p_"Despues de la tool, tu siguiente y unico mensaje debe comenzar literalmente por FINAL|."_$Char(10)
    Set p = p_"Formato final unico:"_$Char(10)
    Set p = p_"FINAL|actionType=<accion>|amount=0|discards=<cartas_separadas_por_comas>|globalStrength=<valor>|recommendedBias=<valor>|confidence=<numero>"_$Char(10)
    Set p = p_"No escribas JSON, markdown, explicaciones ni texto antes o despues de FINAL|... ."_$Char(10)
    Return p
}

ClassMethod BuildSafeJsonFromText(responseText As %String, phase As %String, llmContext As %DynamicObject) As %String
{
    Try {
        Set phase = $ZCONVERT(phase, "L")
        Set result = {}

        If phase = "descartes" {
            Set actionType = "cortar_mus"
            Set amount = 0
            Set reason = ..BuildReasonFromResponseText(actionType, responseText)

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

                    Set strength = ""
                    Set pressure = ""

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

                    Set strength = ""
                    Set pressure = ""

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

        Set reason = ..BuildReasonFromResponseText(actionType, responseText)

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

    /*
      Puntuacion mecanica de Mus para juego/punto:
      - as y 2 valen 1
      - 3, sota, caballo y rey valen 10
      - 4..7 conservan su valor
      Esta funcion se usa en ResolveToolPlay para distinguir juego de punto,
      por lo que NO puede usar el rango nominal de la carta.
    */
    For i=0:1:cards.%Size()-1 {
        Set rank = ..ExtractRank(cards.%Get(i))

        If (rank = 1) || (rank = 2) {
            Set total = total + 1
        } ElseIf (rank = 3) || (rank >= 10) {
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

ClassMethod ParseFinalTransport(text As %String, phase As %String) As %String
{
    Try {
        Set text = $ZSTRIP(text, "<>W")
        If text = "" {
            Return ""
        }

        /*
          Normalizacion puramente lexical del transporte.
          Algunos runs de llama.cpp han devuelto "F|" aunque el prompt exige
          literalmente "FINAL|". Si la respuesta EMPIEZA exactamente por "F|",
          la expandimos a "FINAL|" sin cambiar actionType, amount, strength,
          confidence ni ninguna decision estrategica.
        */
        If $Extract(text, 1, 2) = "F|" {
            Set text = "FINAL|"_$Extract(text, 3, *)
        }

        /*
          FINAL| representa una unica decision.
          Si el modelo devuelve varios FINAL|, la salida es ambigua y se
          rechaza mecanicamente. Asi evitamos que ejemplos posteriores
          sobrescriban los campos de la primera decision.
        */
        Set firstAfter = $Find(text, "FINAL|")
        If firstAfter = 0 {
            Return ""
        }

        Set secondAfter = $Find(text, "FINAL|", firstAfter)
        If secondAfter '= 0 {
            Return ""
        }

        /*
          $Find devuelve la posicion posterior a FINAL|.
          Solo parseamos la linea de la decision.
        */
        Set transport = $Extract(text, firstAfter, *)

        Set crPos = $Find(transport, $Char(13))
        Set lfPos = $Find(transport, $Char(10))
        Set lineEnd = 0

        If crPos > 0 {
            Set lineEnd = crPos - 2
        }

        If lfPos > 0 {
            Set candidateEnd = lfPos - 2
            If (lineEnd = 0) || (candidateEnd < lineEnd) {
                Set lineEnd = candidateEnd
            }
        }

        If lineEnd > 0 {
            Set transport = $Extract(transport, 1, lineEnd)
        }

        Set fields = {}

        For i=1:1:$Length(transport, "|") {
            Set piece = $Piece(transport, "|", i)
            If piece = "" {
                Continue
            }

            Set eq = $Find(piece, "=")
            If eq = 0 {
                Continue
            }

            Set key = $ZSTRIP($Extract(piece, 1, eq-2), "<>W")
            Set value = $ZSTRIP($Extract(piece, eq, *), "<>W")

            If key '= "" {
                Do fields.%Set(key, value)
            }
        }

        Set actionType = ..NormalizeActionType(fields.%Get("actionType", ""))
        If actionType = "" {
            Return ""
        }

        /*
          Normalizacion mecanica de confidence.
          El modelo puede devolver 0..1 o un porcentaje 0..100.
          No afecta a la estrategia, solo al formato del contrato.
        */
        Set confidence = +fields.%Get("confidence", 0)

        If confidence > 1 {
            If confidence <= 100 {
                Set confidence = confidence / 100
            } Else {
                Set confidence = 1
            }
        }

        If confidence < 0 {
            Set confidence = 0
        }

        If confidence > 1 {
            Set confidence = 1
        }

        Set result = {
            "actionType": (actionType),
            "amount": (+fields.%Get("amount", 0)),
            "discards": [],
            "confidence": (+confidence)
        }

        Set phase = ..NormalizePhase(phase)

        If phase = "descartes" {
            /*
              En descartes amount no tiene semantica estrategica: siempre es 0.
              Normalizacion mecanica del contrato.
            */
            Do result.%Set("amount", 0)

            Set discardsText = fields.%Get("discards", "")
            Set discards = []

            If discardsText '= "" {
                For j=1:1:$Length(discardsText, ",") {
                    Set card = $ZSTRIP($Piece(discardsText, ",", j), "<>W")
                    If card '= "" {
                        Do discards.%Push(card)
                    }
                }
            }

            Do result.%Set("discards", discards)

            Set reason = {
                "globalStrength": (fields.%Get("globalStrength", "")),
                "recommendedBias": (fields.%Get("recommendedBias", ""))
            }
            Do result.%Set("reason", reason)
        } Else {
            Set reason = {
                "strength": (fields.%Get("strength", ""))
            }
            Do result.%Set("reason", reason)
        }

        Return result.%ToJSON()
    } Catch ex {
        Return ""
    }
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
