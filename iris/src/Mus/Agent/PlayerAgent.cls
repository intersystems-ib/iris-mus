Include Ensemble

Class Mus.Agent.PlayerAgent Extends %RegisteredObject
{

ClassMethod RecommendAction(gameStateJson As %String, playerId As %String) As %DynamicObject
{
    Try {
        If gameStateJson = "" {
            Return {
                "actionType": "pasar",
                "amount": 0,
                "reason": "Fallback porque GameStateJson esta vacio",
                "confidence": 0
            }
        }

        Set gameState = {}.%FromJSON(gameStateJson)
        Set context = ##class(Mus.Agent.ContextBuilder).BuildForPlayer(gameState, playerId)

        Set fallback = ..BuildFallbackRecommendation(context)
        Set fallback = ..NormalizeRecommendation(fallback, context)

        Set legalActions = context.%Get("legalActions", "")
        If '$IsObject(legalActions) || legalActions.%Size() = 0 {
            Return fallback
        }

        If $IsObject(legalActions), legalActions.%Size() = 1 {
            Set onlyAction = legalActions.%Get(0)

            Set recommendation = {
                "actionType": (onlyAction),
                "amount": 0,
                "reason": "Unica accion legal disponible",
                "confidence": 1.0
            }

            If onlyAction = "cortar_mus" {
                Do recommendation.%Set("discards", [])
            }

            Set recommendation = ..NormalizeRecommendation(recommendation, context)
            Return recommendation
        }
        Set llmContext = ..BuildMinimalLLMContext(context)
        Set systemPrompt = ..BuildSystemPrompt()
        Set userPrompt = ..BuildUserPrompt(context)
        Set raw = ""
        Set sc = ##class(Mus.AI.Provider).ChatJson(..BuildCompactSystemPrompt(llmContext), userPrompt, .raw)
        If $$$ISERR(sc) {
            Do fallback.%Set("reason", "Fallback por error LLM")
            Do fallback.%Set("llmError", $Extract($System.Status.GetErrorText(sc), 1, 500))
            Do ..TraceLLMInfo("LLM_STATUS_ERROR", context, raw, "", "", fallback, legalActions, $System.Status.GetErrorText(sc), systemPrompt, userPrompt)
            Return fallback
        }
        
        Do ..TraceLLMInfo("LLM_RAW_RESPONSE", context, raw, "", "", "", legalActions, "", systemPrompt, userPrompt)
        
        Set parsedRecommendation = ""
        Set recommendation = ""
        Try {
            Set parsedRecommendation = {}.%FromJSON(raw)

            /*
            %DynamicObject no expone %ConstructClone(). Necesitamos conservar dos
            versiones para la traza:
            - parsedRecommendation: JSON original parseado.
            - recommendation: JSON normalizado por las reglas del agente.
            */
            Set recommendation = {}.%FromJSON(parsedRecommendation.%ToJSON())
            Set recommendation = ..NormalizeRecommendation(recommendation, context)
        } Catch exJson {
            Do fallback.%Set("reason", "Fallback por JSON invalido del LLM")
            Do fallback.%Set("rawModelOutput", raw)
            Do ..TraceLLMInfo("LLM_JSON_INVALID", context, raw, parsedRecommendation, "", fallback, legalActions, exJson.DisplayString(), systemPrompt, userPrompt)
            Return fallback
        }
        
        If '..IsValidRecommendation(recommendation, legalActions, context) {
            Do fallback.%Set("reason", "Fallback por recomendacion ilegal del LLM")
            Do fallback.%Set("rawModelOutput", raw)
            Do ..TraceLLMInfo("LLM_ILLEGAL_RECOMMENDATION", context, raw, parsedRecommendation, recommendation, fallback, legalActions, "La recomendacion normalizada no encaja con legalActions", systemPrompt, userPrompt)
            Return fallback
        }
        
        Do ..TraceLLMInfo("LLM_VALID_RECOMMENDATION", context, raw, parsedRecommendation, recommendation, "", legalActions, "", systemPrompt, userPrompt)
        
        If 'recommendation.%IsDefined("amount") {
            Do recommendation.%Set("amount", 0)
        }

        If 'recommendation.%IsDefined("reason") {
            Do recommendation.%Set("reason", "")
        }

        If 'recommendation.%IsDefined("confidence") {
            Do recommendation.%Set("confidence", 0.5)
        }

        Return recommendation
    }
    Catch ex {
        Return {
            "actionType": "pasar",
            "amount": 0,
            "reason": ("Fallback por excepcion: "_ex.DisplayString()),
            "confidence": 0
        }
    }
}

ClassMethod BuildSystemPrompt() As %String
{
    Set prompt = ""
    Set prompt = prompt_"Eres un agente jugador de Mus."_$Char(10)
    Set prompt = prompt_"Debes recomendar una unica accion para el jugador actual."_$Char(10)
    Set prompt = prompt_"Responde exclusivamente JSON valido, sin markdown, sin explicaciones fuera del JSON."_$Char(10)
    Set prompt = prompt_"La lista legalActions del contexto es vinculante. Nunca elijas una accion que no aparezca ahi."_$Char(10)
    Set prompt = prompt_"Si legalActions solo contiene pasar, debes elegir pasar."_$Char(10)
    Set prompt = prompt_"Si legalActions tiene solo un valor, debes elegir ese valor. Sin excepciones."_$Char(10)
    Set prompt = prompt_"No digas que una accion es legal si no aparece en legalActions."_$Char(10)
    Set prompt = prompt_"Nunca elijas envidar u ordago cuando legalActions no los contenga, incluso si tu mano es muy fuerte."_$Char(10)
    Set prompt = prompt_"Puedes elegir envidar solo si envidar aparece en legalActions."_$Char(10)
    Set prompt = prompt_"Puedes elegir ordago solo si ordago aparece en legalActions, y debe ser muy excepcional."_$Char(10)
    Set prompt = prompt_"- El ordago solo debe usarse en situaciones extremas."_$Char(10)
    Set prompt = prompt_"- Puedes lanzar ordago con mano muy fuerte si el rival esta cerca de ganar o si tu equipo esta cerca de cerrar la partida."_$Char(10)
    Set prompt = prompt_"- Si estas desesperado y tienes mano fuerte o muy fuerte, considera ordago."_$Char(10)
    Set prompt = prompt_"- Si eres aggressive o bluffer y la apuesta ya ha escalado, puedes convertirla en ordago solo con mano muy fuerte."_$Char(10)
    Set prompt = prompt_"- No lances ordago con mano debil salvo farol extremo y situacion critica."_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Reglas sobre envites y subidas:"_$Char(10)
    Set prompt = prompt_"- Si no existe pendingBet, envidar significa abrir un nuevo envite."_$Char(10)
    Set prompt = prompt_"- Si existe pendingBet y legalActions contiene envidar, envidar significa subir el envite actual, no abrir uno nuevo."_$Char(10)
    Set prompt = prompt_"- Cuando subas un envite pendiente, amount debe ser estrictamente mayor que pendingBet.amount."_$Char(10)
    Set prompt = prompt_"- Si pendingBet.type es ordago, nunca elijas envidar ni ordago otra vez."_$Char(10)
    Set prompt = prompt_"- Si legalActions contiene querer, no_querer, envidar y ordago, significa que debes responder a un envite pendiente. Aunque puedas subir, lo normal es querer o no_querer."_$Char(10)
    Set prompt = prompt_"- Ante un envite pendiente, querer acepta el importe actual completo de pendingBet.amount."_$Char(10)
    Set prompt = prompt_"- Ante un envite pendiente, no_querer descarga el envite y concede puntos al equipo que hizo la ultima subida."_$Char(10)
    Set prompt = prompt_"- Si rechazas una subida con no_querer, tu equipo pierde la cantidad previa comprometida, no la cantidad subida."_$Char(10)
    Set prompt = prompt_"- No debes aceptar siempre los envites pendientes."_$Char(10)
    Set prompt = prompt_"- Regla estrategica fuerte: ante un envite pendiente, si bettingGuidance.handStrength es weak, debes escoger no_querer salvo que el contexto muestre una razon extraordinaria y explicita para aceptar."_$Char(10)
    Set prompt = prompt_"- Una mano weak no debe querer por defecto ni por ser farolero. El perfil bluffer puede abrir algun farol, pero no debe pagar envites con jugada mala."_$Char(10)
    Set prompt = prompt_"- Usa no_querer cuando tu mano sea debil, aunque el importe sea 2. El envite minimo tambien se rechaza si la jugada no merece pagar."_$Char(10)
    Set prompt = prompt_"- Con mano medium, querer es razonable ante envites pequenos; con mano weak, no_querer es la respuesta normal."_$Char(10)
    Set prompt = prompt_"- Regla practica: weak pendingBet => no_querer; medium pendingBet >=4 => normalmente no_querer; strong/veryStrong pueden querer o subir segun marcador."_$Char(10)
    Set prompt = prompt_"- Si eres conservative, rechaza con mas frecuencia. Si eres bluffer, puedes farolear, pero debes abandonar el farol ante importes altos."_$Char(10)
    Set prompt = prompt_"- No conviertas cada envite en una guerra de subidas. Algunas respuestas deben ser no_querer."_$Char(10)
    Set prompt = prompt_"- Si subes un envite, usa una cantidad razonable: normalmente pendingBet.amount 1, +2 o +3."_$Char(10)
    Set prompt = prompt_"- No uses cantidades absurdas salvo ordago, que debe tener amount 999."_$Char(10)
    Set prompt = prompt_"- Mira discardGuidance.paresSummary antes de decidir."_$Char(10)
    Set prompt = prompt_"- Si paresSummary.type=medias, no digas que no tienes pares ni que la mano es floja."_$Char(10)
    Set prompt = prompt_"- Con medias, cortar MUS es una decision muy razonable aunque exista una carta suelta descartable."_$Char(10)
    Set prompt = prompt_"- Para pares, 1 y 2 son equivalentes: 1+1+2 son medias."_$Char(10)
    Set prompt = prompt_"- Para pares, 3 y 12 son equivalentes: 3+3+12 son medias."_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Reglas de fase descartes:"_$Char(10)
    Set prompt = prompt_"- Si legalActions contiene descartar y cortar_mus, estas en fase de descartes."_$Char(10)
    Set prompt = prompt_"- En descartes, discardGuidance es tu herramienta principal de analisis."_$Char(10)
    Set prompt = prompt_"- decisionBias y expertPlan no son imposiciones, pero representan la recomendacion experta que debes tomar muy en serio."_$Char(10)
    Set prompt = prompt_"- cortar_mus significa cortar MUS y conservar la mano actual."_$Char(10)
    Set prompt = prompt_"- descartar significa pedir MUS y proponer cartas concretas a descartar."_$Char(10)
    Set prompt = prompt_"- Jerarquia estrategica: juego hecho > medias/duples > pares simples > mano sin estructura."_$Char(10)
    Set prompt = prompt_"- Si tienes juego hecho, normalmente debes cortar MUS."_$Char(10)
    Set prompt = prompt_"- Si tienes juego y pares, cortar MUS debe ser la decision natural salvo razon extraordinaria."_$Char(10)
    Set prompt = prompt_"- Si tienes medias o duples, normalmente debes cortar MUS."_$Char(10)
    Set prompt = prompt_"- Si tienes par simple sin juego, puedes pedir MUS solo si conservas la pareja y descartas cartas sueltas claramente peores."_$Char(10)
    Set prompt = prompt_"- Si no tienes pares ni juego, pedir MUS suele ser la decision humana mas natural: no hay una jugada fuerte que proteger."_$Char(10)
    Set prompt = prompt_"- No digas que una mano sin pares ni juego justifica cortar MUS por ser debil; normalmente una mano debil justifica pedir MUS."_$Char(10)
    Set prompt = prompt_"- No rompas pares, medias ni duples."_$Char(10)
    Set prompt = prompt_"- El 3 equivale al rey; evita descartarlo igual que evitarias descartar un rey."_$Char(10)
    Set prompt = prompt_"- Las sotas, caballos y reyes valen 10 puntos para juego; evita descartarlos salvo mejora muy clara."_$Char(10)
    Set prompt = prompt_"- El 1 y el 2 son valiosos para chica; no los descartes automaticamente."_$Char(10)
    Set prompt = prompt_"- Si eliges descartar, devuelve discards con una o mas cartas exactas de cards."_$Char(10)
    Set prompt = prompt_"- Si eliges cortar_mus, devuelve discards: [] y amount: 0."_$Char(10)
    Set prompt = prompt_"- Nunca incluyas cartas que no esten en cards."_$Char(10)
    Set prompt = prompt_"- No repitas cartas en discards."_$Char(10)
    Set prompt = prompt_"- Si decides contra decisionBias o expertPlan, explica el motivo con claridad."_$Char(10)
    Set prompt = prompt_"- Mira discardGuidance.pairSummary: si hasPair=1, esas cartas forman pares y no debes romperlas."_$Char(10)
    Set prompt = prompt_"- Si pairSummary.message indica pares, mencionarlo en la razon ayuda a justificar tu decision."_$Char(10)
    Set prompt = prompt_"- Para pares, el 1 y el 2 son equivalentes: si tienes 1 y 2, tienes pares."_$Char(10)
    Set prompt = prompt_"- Para pares, el 3 y el 12 son equivalentes: si tienes 3 y 12, tienes pares."_$Char(10)
    Set prompt = prompt_"- No rompas pares formados por equivalencias 1/2 o 3/12."_$Char(10)
    Set prompt = prompt_"- Usa pairRank y sameRankCount en discardCandidates para detectar pares equivalentes."_$Char(10)
    Set prompt = prompt_"- Juego a 31 normalmente es fuerte y suele cortar MUS."_$Char(10)
    Set prompt = prompt_"- Excepcion: si tienes 31 sin pares fuertes y sin reyes/caballos, puedes considerar pedir MUS para mejorar grande y pares."_$Char(10)
    Set prompt = prompt_"- No rompas 31 si tambien tienes pares, medias, duples, reyes o caballos fuertes."_$Char(10)
    Set prompt = prompt_"- Si discardGuidance.juegoBreakAnalysis.canConsiderBreakingJuego=1, puedes elegir descartar aunque haya juego a 31, pero debes explicarlo como linea agresiva."_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Reglas de personalidad:"_$Char(10)
    Set prompt = prompt_"- Debes respetar la personalidad del jugador indicada en profile."_$Char(10)
    Set prompt = prompt_"- Un jugador conservador debe arriesgar poco y tender a querer o no_querer antes que subir."_$Char(10)
    Set prompt = prompt_"- Un jugador agresivo puede presionar, aceptar mas riesgos y subir envites con manos fuertes."_$Char(10)
    Set prompt = prompt_"- Un jugador farolero puede envidar o subir ocasionalmente sin buena mano, pero siempre dentro de legalActions."_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Reglas de importes:"_$Char(10)
    Set prompt = prompt_"- Si eliges envidar sin pendingBet, amount debe ser un entero positivo. El minimo normal es 2."_$Char(10)
    Set prompt = prompt_"- Con mano buena puedes envidar mas de 2: por ejemplo 3, 4, 5 o 6."_$Char(10)
    Set prompt = prompt_"- Si eliges envidar con pendingBet, amount debe ser mayor que pendingBet.amount."_$Char(10)
    Set prompt = prompt_"- Si eliges querer, amount debe ser pendingBet.amount cuando exista pendingBet."_$Char(10)
    Set prompt = prompt_"- Si eliges no_querer o pasar, amount debe ser 0."_$Char(10)
    Set prompt = prompt_"- Si eliges ordago, amount debe ser 999."_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"El JSON de salida debe tener estas claves: actionType, amount, reason, confidence."_$Char(10)
    Set prompt = prompt_"Si actionType es descartar, tambien debe incluir discards como array de cartas exactas de la mano."_$Char(10)
    Set prompt = prompt_"Si actionType es cortar_mus, discards debe ser un array vacio."_$Char(10)
    Set prompt = prompt_"confidence debe ser un numero entre 0 y 1."_$Char(10)
    Set prompt = prompt_"- Si discardGuidance.expertPlan.mustFollow = 1, sigue expertPlan.recommendedAction. Tu tarea es explicar la decision, no contradecirla."_$Char(10)
    Set prompt = prompt_"- Si expertPlan.recommendedAction es cortar_mus, devuelve actionType=cortar_mus y discards=[]."_$Char(10)
    Set prompt = prompt_"- Nunca pidas MUS si expertPlan.category es juego_and_pares, juego, medias o duples."_$Char(10)

    Return prompt
}

ClassMethod BuildUserPrompt(context As %DynamicObject) As %String
{
    Set prompt = ""

    If $IsObject(context), context.%Get("phase", "") = "descartes" {
        Set prompt = prompt_"Contexto de descarte para el jugador actual:"_$Char(10)
        Set prompt = prompt_context.%ToJSON()_$Char(10)
        Set prompt = prompt_$Char(10)
        Set prompt = prompt_"Instrucciones especificas de descarte:"_$Char(10)
        Set prompt = prompt_"1. Primero mira discardGuidance.decisionBias. Es la recomendacion estrategica principal."_$Char(10)
        Set prompt = prompt_"2. Mira discardGuidance.expertPlan. Es el plan experto sugerido para esta mano."_$Char(10)
        Set prompt = prompt_"3. Si tienes juego hecho, normalmente debes elegir cortar_mus."_$Char(10)
        Set prompt = prompt_"4. Si tienes juego y pares, cortar_mus debe ser la opcion casi siempre."_$Char(10)
        Set prompt = prompt_"5. Si tienes medias o duples, normalmente debes elegir cortar_mus."_$Char(10)
        Set prompt = prompt_"6. Si no tienes pares ni juego, normalmente debes elegir descartar porque no hay jugada fuerte que proteger."_$Char(10)
        Set prompt = prompt_"7. Si eliges descartar, usa preferentemente las cartas marcadas como discardable y evita las marcadas como avoidDiscard."_$Char(10)
        Set prompt = prompt_"8. No descartes cartas que formen pareja, medias o duples."_$Char(10)
        Set prompt = prompt_"9. No descartes 3, 10, 11, 12, 1 o 2 salvo una mejora excepcional y explicada."_$Char(10)
        Set prompt = prompt_"10. Si decides contra expertPlan, debes explicar claramente por que."_$Char(10)
        Set prompt = prompt_"- Si expertPlan.mustFollow=1, copia su recommendedAction."_$Char(10)
        Set prompt = prompt_"- Si expertPlan dice cortar_mus, no propongas descartes."_$Char(10)
        Set prompt = prompt_$Char(10)
        Set prompt = prompt_"Devuelve solo JSON valido con esta forma:"_$Char(10)
        Set prompt = prompt_"{""actionType"":""descartar|cortar_mus"",""amount"":0,""discards"":[],""reason"":""motivo breve"",""confidence"":0.0}"_$Char(10)
        Return prompt
    }
    
    Set prompt = prompt_"Contexto completo de la partida y del jugador actual:"_$Char(10)
    Set prompt = prompt_context.%ToJSON()_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Instrucciones de decision:"_$Char(10)
    Set prompt = prompt_"1. Mira legalActions. Solo puedes elegir una accion incluida ahi."_$Char(10)
    Set prompt = prompt_"2. Mira profile. Ajusta tu riesgo a esa personalidad."_$Char(10)
    Set prompt = prompt_"3. Mira bettingGuidance.handStrength para estimar si tu mano es weak, medium, strong o veryStrong."_$Char(10)
    Set prompt = prompt_"4. Si no existe pendingBet y la mano es strong o veryStrong, puedes abrir envite si legalActions incluye envidar."_$Char(10)
    Set prompt = prompt_"5. Si profile.style es bluffer, puedes hacer farol ocasional con envidar aunque handStrength sea weak o medium."_$Char(10)
    Set prompt = prompt_"6. Si existe pendingBet, estas respondiendo a un envite pendiente."_$Char(10)
    Set prompt = prompt_"7. Si existe pendingBet y eliges querer, acepta pendingBet.amount."_$Char(10)
    Set prompt = prompt_"8. Si existe pendingBet y eliges no_querer, descarga el envite y amount debe ser 0."_$Char(10)
    Set prompt = prompt_"8b. Si existe pendingBet y bettingGuidance.handStrength es weak, la decision correcta por defecto es no_querer, incluso si pendingBet.amount es 2."_$Char(10)
    Set prompt = prompt_"8c. Solo acepta un envite con handStrength weak si hay una razon extraordinaria en el marcador o en la estrategia, y debes explicarla explicitamente en reason."_$Char(10)
    Set prompt = prompt_"8d. Ser bluffer no justifica querer envites con mano weak. Un farol puede abrir envite, pero pagar un envite rival con jugada mala suele ser incorrecto."_$Char(10)
    Set prompt = prompt_"8e. Si existe pendingBet y handStrength es medium, considera no_querer cuando el importe sea 4 o mas, salvo situacion desesperada."_$Char(10)
    Set prompt = prompt_"8f. No respondas siempre querer o envidar. Debe haber rechazos si el riesgo no compensa."_$Char(10)
    Set prompt = prompt_"8e. Considera ordago solo en casos extremos: mano veryStrong, rival cerca de ganar, tu equipo cerca de ganar, o situacion desesperada."_$Char(10)
    Set prompt = prompt_"8f. Si legalActions contiene ordago pero la mano no es fuerte ni la situacion critica, evita ordago."_$Char(10)
    Set prompt = prompt_"9. Si existe pendingBet y legalActions incluye envidar, puedes subir el envite, pero amount debe ser mayor que pendingBet.amount."_$Char(10)
    Set prompt = prompt_"10. Si existe pendingBet y legalActions incluye ordago, puedes subir a ordago solo en casos excepcionales."_$Char(10)
    Set prompt = prompt_"11. Si pendingBet.type es ordago, solo debes elegir querer o no_querer."_$Char(10)
    Set prompt = prompt_"12. Si eliges pasar o no_querer, amount debe ser 0."_$Char(10)
    Set prompt = prompt_"13. Si eliges ordago, amount debe ser 999."_$Char(10)
    Set prompt = prompt_"14. No inventes cartas, puntuaciones ni acciones."_$Char(10)
    Set prompt = prompt_"15. Antes de devolver JSON haz esta comprobacion: si pendingBet existe y handStrength=weak, tu actionType debe ser no_querer salvo excepcion extraordinaria explicada."_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Devuelve solo JSON valido con esta forma:"_$Char(10)
    Set prompt = prompt_"{""actionType"":""pasar|envidar|querer|no_querer|ordago|descartar|cortar_mus"",""amount"":0,""discards"":[],""reason"":""motivo breve"",""confidence"":0.0}"_$Char(10)

    Return prompt
}

ClassMethod IsValidRecommendation(recommendation As %DynamicObject, legalActions As %DynamicArray, context As %DynamicObject = "") As %Boolean
{
    If '$IsObject(recommendation) {
        Return 0
    }

    If '$IsObject(legalActions) {
        Return 0
    }

    Set actionType = ..NormalizeActionType(recommendation.%Get("actionType", recommendation.%Get("type", recommendation.%Get("action", ""))))

    If actionType = "" {
        Return 0
    }

    Do recommendation.%Set("actionType", actionType)

    If '##class(Mus.Agent.Strategy).ArrayContains(legalActions, actionType) {
        Return 0
    }

    Set amount = +recommendation.%Get("amount", 0)
    Set pendingBet = ..GetPendingBet(context)

    If actionType = "cortar_mus" {
        Set discards = recommendation.%Get("discards", "")
        If $IsObject(discards), discards.%Size() > 0 {
            Return 0
        }
        Return 1
    }

    If actionType = "descartar" {
        Set cards = context.%Get("cards", "")
        If '$IsObject(cards) {
            Return 0
        }

        Set discards = recommendation.%Get("discards", "")
        If '$IsObject(discards) {
            Return 0
        }

        If discards.%Size() = 0 {
            Return 0
        }

        Set seen = []

        For i=0:1:discards.%Size()-1 {
            Set card = discards.%Get(i)

            If '##class(Mus.Agent.Strategy).ArrayContains(cards, card) {
                Return 0
            }

            If ..ArrayContains(seen, card) {
                Return 0
            }

            Do seen.%Push(card)
        }

        Return 1
    }

    If actionType = "envidar" {
        If amount < 2 {
            Return 0
        }

        If amount > 20 {
            Return 0
        }

        If $IsObject(pendingBet) {
            If pendingBet.%Get("type", "") = "ordago" {
                Return 0
            }

            Set currentAmount = +pendingBet.%Get("amount", 0)

            If amount <= currentAmount {
                Return 0
            }
        }

        Return 1
    }

    If actionType = "ordago" {
        If $IsObject(pendingBet) {
            If pendingBet.%Get("type", "") = "ordago" {
                Return 0
            }
        }

        Return 1
    }

    If actionType = "querer" {
        If amount < 0 {
            Return 0
        }

        If $IsObject(pendingBet) {
            If amount '= +pendingBet.%Get("amount", 0) {
                Return 0
            }
        }

        Return 1
    }

    If (actionType = "pasar") || (actionType = "no_querer") {
        If amount '= 0 {
            Return 0
        }

        Return 1
    }

    Return 0
}

ClassMethod NormalizeRecommendation(recommendation As %DynamicObject, context As %DynamicObject) As %DynamicObject
{
    If '$IsObject(recommendation) {
        Return recommendation
    }

    Set actionType = ..NormalizeActionType(recommendation.%Get("actionType", recommendation.%Get("type", recommendation.%Get("action", ""))))

    If actionType '= "" {
        Do recommendation.%Set("actionType", actionType)
    }

    Set pendingBet = ..GetPendingBet(context)

    /*
      Si estamos respondiendo a un envite pendiente, primero frenamos
      escaladas absurdas. Esto se aplica antes de cualquier normalizacion
      de ordago o de importe para que un perfil farolero no convierta cada
      respuesta en otra subida.
    */
    If $IsObject(pendingBet) {
        If actionType = "envidar" {
            Set antiEscalationDecision = ..BuildAntiEscalationDecisionIfNeeded(context, pendingBet, recommendation)

            If $IsObject(antiEscalationDecision) {
                Return antiEscalationDecision
            }
        }
    }

    Set ordagoDecision = ..BuildOrdagoDecisionIfNeeded(context, pendingBet)

    If $IsObject(ordagoDecision) {
        Return ordagoDecision
    }

    If actionType = "cortar_mus" {
        Do recommendation.%Set("amount", 0)
        Do recommendation.%Set("discards", [])
        If recommendation.%Get("reason", "") = "" {
            Do recommendation.%Set("reason", "El agente decide cortar MUS")
        }
        If recommendation.%Get("confidence", "") = "" {
            Do recommendation.%Set("confidence", 0.5)
        }
        Return recommendation
    }

    If actionType = "descartar" {
        Do recommendation.%Set("amount", 0)

        Set cards = context.%Get("cards", "")
        Set rawDiscards = recommendation.%Get("discards", "")
        Set normalizedDiscards = []

        If $IsObject(rawDiscards), $IsObject(cards) {
            For i=0:1:rawDiscards.%Size()-1 {
                Set card = rawDiscards.%Get(i)

                If ##class(Mus.Agent.Strategy).ArrayContains(cards, card) {
                    If '..ArrayContains(normalizedDiscards, card) {
                        Do normalizedDiscards.%Push(card)
                    }
                }
            }
        }

        If normalizedDiscards.%Size() = 0 {
            Set normalizedDiscards = ..BuildFallbackDiscardsFromContext(context)
        }

        If normalizedDiscards.%Size() = 0 {
            Do recommendation.%Set("actionType", "cortar_mus")
            Do recommendation.%Set("amount", 0)
            Do recommendation.%Set("discards", [])

            If recommendation.%Get("reason", "") = "" {
                Do recommendation.%Set("reason", "Normalizado: el LLM pidio MUS pero no propuso descartes validos; se corta MUS")
            }

            If recommendation.%Get("confidence", "") = "" {
                Do recommendation.%Set("confidence", 0.5)
            }

            Return recommendation
        }

        Do recommendation.%Set("discards", normalizedDiscards)

        If recommendation.%Get("reason", "") = "" {
            Do recommendation.%Set("reason", "El agente decide pedir MUS y descartar")
        }

        If recommendation.%Get("confidence", "") = "" {
            Do recommendation.%Set("confidence", 0.5)
        }

        Return recommendation
    }

    /*
      Si hay envite pendiente y el LLM quiere aceptar, subir u ordaguear,
      aplicamos una politica defensiva para forzar no_querer en casos de riesgo.
    */
    If $IsObject(pendingBet) {
        If (actionType = "querer") || (actionType = "envidar") || (actionType = "ordago") {
            Set rejectDecision = ..BuildNoQuererDecisionIfNeeded(context, pendingBet)

            If $IsObject(rejectDecision) {
                Return rejectDecision
            }
        }
    }

    If actionType = "querer", $IsObject(pendingBet) {
        Do recommendation.%Set("amount", +pendingBet.%Get("amount", 0))
    }

    If actionType = "envidar" {
        Set amount = +recommendation.%Get("amount", 0)

        If $IsObject(pendingBet) {
            Set currentAmount = +pendingBet.%Get("amount", 0)
            Set raiseCount = +pendingBet.%Get("raiseCount", 0)

            /*
              Si la subida ya esta demasiado alta, no sigas subiendo.
              Esta decision puede haber sido convertida antes a no_querer.
              Si no se ha rechazado, aceptar el importe actual.
            */
            If (currentAmount >= 8) || (raiseCount >= 3) {
                Do recommendation.%Set("actionType", "querer")
                Do recommendation.%Set("amount", currentAmount)

                If recommendation.%Get("reason", "") = "" {
                    Do recommendation.%Set("reason", "Normalizado: se acepta porque la escalada de envites ya es alta")
                }

                Return recommendation
            }

            If amount <= currentAmount {
                Set amount = currentAmount + 1
            }
        } Else {
            If amount < 2 {
                Set amount = 2
            }

            /*
              Abrir envite por 2 es la jugada normal. Los perfiles faroleros
              no deben abrir sistematicamente por 3, 4 o mas. Solo dejamos
              importes superiores con mano muy fuerte o marcador critico.
            */
            Set openingHandStrength = ..GetHandStrength(context)
            Set openingPressure = context.%Get("scorePressure", "")
            Set openingDesperate = 0

            If $IsObject(openingPressure) {
                Set openingDesperate = +openingPressure.%Get("desperate", 0)
            }

            If amount > 2 {
                If (openingHandStrength '= "veryStrong") && 'openingDesperate {
                    Set amount = 2
                } ElseIf amount > 4 {
                    Set amount = 4
                }
            }
        }

        If amount > 20 {
            Set amount = 20
        }

        Do recommendation.%Set("amount", amount)
    }

    If (actionType = "pasar") || (actionType = "no_querer") {
        Do recommendation.%Set("amount", 0)
    }

    If actionType = "ordago" {
        Do recommendation.%Set("amount", 999)
    }

    If '$IsObject(recommendation.%Get("reason", "")) {
        Set reason = recommendation.%Get("reason", "")

        If reason = "" {
            Do recommendation.%Set("reason", "Decision del agente")
        }
    }

    If recommendation.%Get("confidence", "") = "" {
        Do recommendation.%Set("confidence", 0.5)
    }

    Return recommendation
}

ClassMethod NormalizeActionType(value As %String) As %String
{
    Set actionType = $ZConvert($ZStrip(value, "<>W"), "L")
    Set actionType = $Replace(actionType, "-", "_")
    Set actionType = $Replace(actionType, " ", "_")

    If (actionType = "pasar") || (actionType = "pass") {
        Return "pasar"
    }

    If (actionType = "envidar") || (actionType = "envido") || (actionType = "raise") || (actionType = "bet") {
        Return "envidar"
    }

    If (actionType = "querer") || (actionType = "accept") || (actionType = "aceptar") || (actionType = "call") {
        Return "querer"
    }

    If (actionType = "no_querer") || (actionType = "noquerer") || (actionType = "reject") || (actionType = "rechazar") || (actionType = "fold") {
        Return "no_querer"
    }

    If (actionType = "ordago") || (actionType = "órdago") {
        Return "ordago"
    }

    If (actionType = "descartar") || (actionType = "discard") || (actionType = "pedir_mus") || (actionType = "mus") || (actionType = "quiero_mus") {
        Return "descartar"
    }

    If (actionType = "cortar_mus") || (actionType = "cortar") || (actionType = "cut") || (actionType = "no_mus") || (actionType = "corto_mus") {
        Return "cortar_mus"
    }

    Return actionType
}

ClassMethod BuildFallbackDiscardsFromContext(context As %DynamicObject) As %DynamicArray
{
    Set result = []

    If '$IsObject(context) {
        Return result
    }

    Set cards = context.%Get("cards", "")
    If '$IsObject(cards) {
        Return result
    }

    Set discardGuidance = context.%Get("discardGuidance", "")

    If $IsObject(discardGuidance) {
        Set candidates = discardGuidance.%Get("discardCandidates", "")

        If $IsObject(candidates) {
            For i=0:1:candidates.%Size()-1 {
                Set candidate = candidates.%Get(i)

                If '$IsObject(candidate) {
                    Continue
                }

                Set card = candidate.%Get("card", "")

                If card = "" {
                    Continue
                }

                If '##class(Mus.Agent.Strategy).ArrayContains(cards, card) {
                    Continue
                }

                If ..ArrayContains(result, card) {
                    Continue
                }

                Set avoidDiscard = +candidate.%Get("avoidDiscard", 0)
                Set protected = +candidate.%Get("protected", 0)
                Set discardable = +candidate.%Get("discardable", 0)
                Set recommended = +candidate.%Get("recommended", 0)
                Set canDiscard = +candidate.%Get("canDiscard", 0)

                If 'avoidDiscard && 'protected && (discardable || recommended || canDiscard) {
                    Do result.%Push(card)
                }
            }
        }
    }

    If result.%Size() > 0 {
        Return result
    }

    /* Ultimo recurso seguro: solo descartar una carta que no forme par equivalente
       y que no sea figura/rey. Si no existe, se devuelve vacio y se normaliza a cortar_mus. */
    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set musValue = ##class(Mus.Util.MusRules).GetMusCardValue(card)

        If musValue >= 10 {
            Continue
        }

        Set sameCount = 0

        For j=0:1:cards.%Size()-1 {
            If ##class(Mus.Util.MusRules).GetMusCardValue(cards.%Get(j)) = musValue {
                Set sameCount = sameCount + 1
            }
        }

        If sameCount < 2 {
            Do result.%Push(card)
            Return result
        }
    }

    Return result
}

ClassMethod BuildOrdagoDecisionIfNeeded(context As %DynamicObject, pendingBet As %DynamicObject) As %DynamicObject
{
    If '$IsObject(context) {
        Return ""
    }

    Set legalActions = context.%Get("legalActions", "")

    If '$IsObject(legalActions) {
        Return ""
    }

    If '##class(Mus.Agent.Strategy).ArrayContains(legalActions, "ordago") {
        Return ""
    }

    If $IsObject(pendingBet) {
        If pendingBet.%Get("type", "") = "ordago" {
            Return ""
        }
    }

    Set handStrength = ..GetHandStrength(context)
    Set profileId = ..GetProfileId(context)
    Set playerTeam = ..GetPlayerTeam(context)

    Set desperate = 0
    Set leading = 0
    Set myScore = 0
    Set opponentScore = 0
    Set targetScore = 40

    /*
      Primero intentamos calcular el marcador desde el contexto directo.
      Esto evita depender de nombres concretos dentro de scorePressure.
    */
    Set score = context.%Get("score", "")

    If $IsObject(score) {
        If playerTeam = "A" {
            Set myScore = +score.%Get("teamA", 0)
            Set opponentScore = +score.%Get("teamB", 0)
        } ElseIf playerTeam = "B" {
            Set myScore = +score.%Get("teamB", 0)
            Set opponentScore = +score.%Get("teamA", 0)
        }
    }

    Set targetScore = +context.%Get("targetScore", 40)

    If targetScore <= 0 {
        Set targetScore = 40
    }

    Set scorePressure = context.%Get("scorePressure", "")

    If $IsObject(scorePressure) {
        Set desperate = +scorePressure.%Get("desperate", 0)
        Set leading = +scorePressure.%Get("leading", 0)

        If myScore = 0 {
            Set myScore = +scorePressure.%Get("myScore", 0)
        }

        If opponentScore = 0 {
            Set opponentScore = +scorePressure.%Get("opponentScore", 0)
        }

        If targetScore <= 0 {
            Set targetScore = +scorePressure.%Get("targetScore", 40)
        }
    }

    If targetScore <= 0 {
        Set targetScore = 40
    }

    Set distanceToTarget = targetScore - myScore
    Set opponentDistanceToTarget = targetScore - opponentScore

    /*
      Si ya hay envite pendiente, no uses ordago como escalada de rutina.
      Solo puede aparecer con mano muy fuerte y marcador realmente critico.
      El perfil farolero no basta para convertir respuestas en ordagos.
    */
    If $IsObject(pendingBet) {
        If (handStrength '= "veryStrong") {
            Return ""
        }

        If (distanceToTarget > 3) && (opponentDistanceToTarget > 3) && 'desperate {
            Return ""
        }
    }

    /*
      Caso prioritario:
      Mano muy fuerte y la partida esta a punto de decidirse.
      Este caso captura situaciones como 38-14 o rival a 38.
    */
    If ((distanceToTarget <= 2) || (opponentDistanceToTarget <= 2) || (myScore >= (targetScore - 2)) || (opponentScore >= (targetScore - 2))) {
        If (handStrength = "strong") || (handStrength = "veryStrong") {
            Return ..BuildOrdagoDecision(
                "Lanzo ordago: mano fuerte o muy fuerte y la partida esta a dos puntos de decidirse",
                0.94
            )
        }

        If ((profileId = "aggressive") || (profileId = "bluffer") || (profileId = "farolero")) && (handStrength = "medium") {
            Return ..BuildOrdagoDecision(
                "Lanzo ordago como recurso extremo: marcador a dos puntos y perfil de riesgo",
                0.78
            )
        }
    }

    If (opponentDistanceToTarget <= 5) && ((profileId = "aggressive") || (profileId = "bluffer") || (profileId = "farolero")) {
        If (handStrength = "medium") || (handStrength = "strong") || (handStrength = "veryStrong") {
            Return ..BuildOrdagoDecision(
                "Lanzo ordago: el rival esta cerca de ganar y mi perfil permite asumir riesgo extremo",
                0.82
            )
        }
    }

    /*
      Mano muy fuerte y el rival esta cerca de ganar.
    */
    If (handStrength = "veryStrong") && (opponentDistanceToTarget <= 5) {
        Return ..BuildOrdagoDecision(
            "Lanzo ordago: mano muy fuerte y el rival esta a punto de ganar",
            0.92
        )
    }

    /*
      Mano muy fuerte y nuestro equipo esta cerca de cerrar la partida.
    */
    If (handStrength = "veryStrong") && (distanceToTarget <= 5) {
        Return ..BuildOrdagoDecision(
            "Lanzo ordago: mano muy fuerte y estamos cerca de ganar la partida",
            0.9
        )
    }

    /*
      Situacion desesperada con mano al menos fuerte.
    */
    If desperate && ((handStrength = "strong") || (handStrength = "veryStrong")) {
        Return ..BuildOrdagoDecision(
            "Lanzo ordago: situacion desesperada y mano suficientemente fuerte",
            0.88
        )
    }

    /*
      Perfil agresivo/farolero, mano muy fuerte y apuesta escalando.
    */
    If $IsObject(pendingBet) {
        Set amount = +pendingBet.%Get("amount", 0)
        Set raiseCount = +pendingBet.%Get("raiseCount", 0)

        If (handStrength = "veryStrong") && ((profileId = "aggressive") || (profileId = "bluffer") || (profileId = "farolero")) {
            If (amount >= 5) || (raiseCount >= 2) {
                Return ..BuildOrdagoDecision(
                    "Lanzo ordago: mano muy fuerte y la apuesta ya esta escalando",
                    0.86
                )
            }
        }
    }

    /*
      Farol extremo: solo farolero, situacion critica y al menos mano media.
    */
    If ((profileId = "bluffer") || (profileId = "farolero")) && desperate && (opponentDistanceToTarget <= 6) {
        If (handStrength = "medium") || (handStrength = "strong") || (handStrength = "veryStrong") {
            Return ..BuildOrdagoDecision(
                "Lanzo ordago como recurso extremo de farol: estamos en situacion critica",
                0.72
            )
        }
    }

    Return ""
}

ClassMethod BuildOrdagoDecision(reason As %String, confidence As %Numeric = 0.85) As %DynamicObject
{
    Set result = {
        "actionType": "ordago",
        "amount": 999,
        "reason": (reason),
        "confidence": (confidence)
    }

    Return result
}

ClassMethod BuildAntiEscalationDecisionIfNeeded(context As %DynamicObject, pendingBet As %DynamicObject, recommendation As %DynamicObject) As %DynamicObject
{
    If '$IsObject(context) {
        Return ""
    }

    If '$IsObject(pendingBet) {
        Return ""
    }

    Set legalActions = context.%Get("legalActions", "")

    If '$IsObject(legalActions) {
        Return ""
    }

    If pendingBet.%Get("type", "") = "ordago" {
        Return ""
    }

    Set canQuerer = ##class(Mus.Agent.Strategy).ArrayContains(legalActions, "querer")
    Set canNoQuerer = ##class(Mus.Agent.Strategy).ArrayContains(legalActions, "no_querer")

    If 'canQuerer && 'canNoQuerer {
        Return ""
    }

    Set currentAmount = +pendingBet.%Get("amount", 0)
    Set raiseCount = +pendingBet.%Get("raiseCount", 0)
    Set handStrength = ..GetHandStrength(context)
    Set profileId = ..GetProfileId(context)

    Set scorePressure = context.%Get("scorePressure", "")
    Set desperate = 0
    Set leading = 0

    If $IsObject(scorePressure) {
        Set desperate = +scorePressure.%Get("desperate", 0)
        Set leading = +scorePressure.%Get("leading", 0)
    }

    /*
      Primero cortamos faroles caros. Un farolero puede iniciar algun envite,
      pero no debe convertir cada respuesta en otra subida.
    */
    If canNoQuerer {
        If ((profileId = "bluffer") || (profileId = "farolero")) {
            If (handStrength = "weak") && (currentAmount >= 3) {
                Return ..BuildNoQuererDecision(
                    "Evito escalada: perfil farolero abandona farol debil ante envite",
                    0.88
                )
            }

            If (handStrength = "medium") && ((currentAmount >= 5) || (raiseCount >= 1)) {
                Return ..BuildNoQuererDecision(
                    "Evito escalada: perfil farolero no sigue subiendo con mano media",
                    0.84
                )
            }
        }

        If (handStrength = "weak") && (currentAmount >= 4) {
            Return ..BuildNoQuererDecision(
                "Evito escalada: mano debil ante importe ya comprometido",
                0.86
            )
        }

        If leading && ((handStrength = "weak") || (handStrength = "medium")) && (currentAmount >= 3) {
            Return ..BuildNoQuererDecision(
                "Evito escalada: vamos por delante y no compensa seguir la guerra",
                0.86
            )
        }
    }

    /*
      Regla principal: responder a un envite subiendo es excepcional.
      Lo normal es QUERER si la mano acompana.
    */
    If canQuerer {
        If (handStrength '= "veryStrong") {
            Return {
                "actionType": "querer",
                "amount": (currentAmount),
                "reason": "Evito escalada: ante envite pendiente lo normal es querer, no reenvidar",
                "confidence": 0.9
            }
        }

        If (raiseCount >= 1) && 'desperate {
            Return {
                "actionType": "querer",
                "amount": (currentAmount),
                "reason": "Evito escalada repetida: con envite ya subido prefiero querer",
                "confidence": 0.88
            }
        }

        If (currentAmount >= 5) && 'desperate {
            Return {
                "actionType": "querer",
                "amount": (currentAmount),
                "reason": "Evito escalada: el importe ya es suficiente y prefiero querer",
                "confidence": 0.88
            }
        }

        If ((profileId = "bluffer") || (profileId = "farolero")) && 'desperate {
            Return {
                "actionType": "querer",
                "amount": (currentAmount),
                "reason": "Evito escalada: ser farolero no implica reenvidar siempre",
                "confidence": 0.9
            }
        }
    }

    /*
      Solo dejamos subir si no hemos devuelto querer/no_querer: mano muy fuerte,
      primera subida, importe bajo y presion real. Normalizamos al minimo: +1.
    */
    If $IsObject(recommendation) {
        Do recommendation.%Set("amount", currentAmount + 1)

        If recommendation.%Get("reason", "") = "" {
            Do recommendation.%Set("reason", "Subida excepcional: mano muy fuerte y situacion justificada")
        }

        If recommendation.%Get("confidence", "") = "" {
            Do recommendation.%Set("confidence", 0.72)
        }
    }

    Return ""
}

ClassMethod BuildNoQuererDecisionIfNeeded(context As %DynamicObject, pendingBet As %DynamicObject) As %DynamicObject
{
    If '$IsObject(context) {
        Return ""
    }

    If '$IsObject(pendingBet) {
        Return ""
    }

    Set legalActions = context.%Get("legalActions", "")

    If '$IsObject(legalActions) {
        Return ""
    }

    If '##class(Mus.Agent.Strategy).ArrayContains(legalActions, "no_querer") {
        Return ""
    }

    Set amount = +pendingBet.%Get("amount", 0)
    Set raiseCount = +pendingBet.%Get("raiseCount", 0)
    Set pendingType = pendingBet.%Get("type", "")

    Set handStrength = ..GetHandStrength(context)
    Set profileId = ..GetProfileId(context)

    Set scorePressure = context.%Get("scorePressure", "")
    Set leading = 0
    Set desperate = 0

    If $IsObject(scorePressure) {
        Set leading = +scorePressure.%Get("leading", 0)
        Set desperate = +scorePressure.%Get("desperate", 0)
    }

    Set ordagoLegal = ##class(Mus.Agent.Strategy).ArrayContains(legalActions, "ordago")

    If ordagoLegal && desperate && ((handStrength = "strong") || (handStrength = "veryStrong")) {
        Return ""
    }

    /*
      Ordago: rechazar salvo mano muy fuerte o situacion desesperada.
    */
    If pendingType = "ordago" {
        If (handStrength '= "veryStrong") && 'desperate {
            Return ..BuildNoQuererDecision(
                "Rechazo ordago: no tengo una mano muy fuerte ni una situacion desesperada",
                0.95
            )
        }

        Return ""
    }

    /*
      Si vamos por delante, evitar riesgos innecesarios.
    */
    If leading && ((handStrength = "weak") || (handStrength = "medium")) && (amount >= 3) {
        Return ..BuildNoQuererDecision(
            "Rechazo envite: vamos por delante y la mano no justifica asumir riesgo",
            0.9
        )
    }

    /*
      Perfil conservador: debe rechazar con mas frecuencia.
    */
    If profileId = "conservative" {
        If ((handStrength = "weak") || (handStrength = "medium")) && (amount >= 3) {
            Return ..BuildNoQuererDecision(
                "Perfil conservador rechaza envite con mano no fuerte",
                0.9
            )
        }

        If (handStrength = "strong") && (amount > 4) {
            Return ..BuildNoQuererDecision(
                "Perfil conservador rechaza importe alto con mano solo fuerte",
                0.85
            )
        }
    }

    /*
      Perfil equilibrado.
    */
    If profileId = "balanced" {
        If (handStrength = "weak") && (amount >= 3) {
            Return ..BuildNoQuererDecision(
                "Perfil equilibrado rechaza envite con mano debil",
                0.85
            )
        }

        If (handStrength = "medium") && (amount >= 5) {
            Return ..BuildNoQuererDecision(
                "Perfil equilibrado rechaza importe alto con mano media",
                0.8
            )
        }
    }

    /*
      Perfil agresivo: acepta mas riesgo, pero no cualquier guerra.
    */
    If profileId = "aggressive" {
        If (handStrength = "weak") && (amount >= 5) {
            Return ..BuildNoQuererDecision(
                "Perfil agresivo rechaza envite alto con mano debil",
                0.8
            )
        }

        If (handStrength = "medium") && (amount >= 7) {
            Return ..BuildNoQuererDecision(
                "Perfil agresivo corta la guerra de envites con mano media",
                0.75
            )
        }
    }

    /*
      Perfil farolero: puede farolear, pero debe abandonar faroles caros.
    */
    If (profileId = "bluffer") || (profileId = "farolero") {
        If (handStrength = "weak") && (amount >= 5) {
            Return ..BuildNoQuererDecision(
                "Perfil farolero abandona el farol porque el coste ya es alto",
                0.75
            )
        }

        If (handStrength = "medium") && (amount >= 7) {
            Return ..BuildNoQuererDecision(
                "Perfil farolero rechaza envite excesivo con mano media",
                0.75
            )
        }
    }

    /*
      Corte general: demasiadas subidas sin mano muy fuerte.
    */
    If (raiseCount >= 3) && (handStrength '= "veryStrong") {
        Return ..BuildNoQuererDecision(
            "Rechazo tras varias subidas sin mano muy fuerte",
            0.85
        )
    }

    /*
      Corte general por importe.
    */
    If (amount >= 8) && (handStrength '= "veryStrong") {
        Return ..BuildNoQuererDecision(
            "Rechazo envite de importe alto sin mano muy fuerte",
            0.85
        )
    }

    Return ""
}

ClassMethod BuildNoQuererDecision(reason As %String, confidence As %Numeric = 0.85) As %DynamicObject
{
    Set result = {
        "actionType": "no_querer",
        "amount": 0,
        "reason": (reason),
        "confidence": (confidence)
    }

    Return result
}

ClassMethod GetHandStrength(context As %DynamicObject) As %String
{
    If '$IsObject(context) {
        Return ""
    }

    Set bettingGuidance = context.%Get("bettingGuidance", "")

    If $IsObject(bettingGuidance) {
        Return bettingGuidance.%Get("handStrength", "")
    }

    Return ""
}

ClassMethod GetProfileId(context As %DynamicObject) As %String
{
    If '$IsObject(context) {
        Return ""
    }

    Set profile = context.%Get("profile", "")

    If $IsObject(profile) {
        Set profileId = profile.%Get("id", "")

        If profileId '= "" {
            Return profileId
        }

        Set profileId = profile.%Get("profileId", "")

        If profileId '= "" {
            Return profileId
        }

        Set profileId = profile.%Get("style", "")

        If profileId '= "" {
            Return profileId
        }
    }

    Return context.%Get("profileId", "")
}

ClassMethod GetPlayerTeam(context As %DynamicObject) As %String
{
    If '$IsObject(context) {
        Return ""
    }

    Set playerTeam = context.%Get("playerTeam", "")

    If playerTeam '= "" {
        Return playerTeam
    }

    Set player = context.%Get("player", "")

    If $IsObject(player) {
        Set playerTeam = player.%Get("team", "")

        If playerTeam '= "" {
            Return playerTeam
        }
    }

    Return ""
}

ClassMethod GetPendingBet(context As %DynamicObject) As %DynamicObject
{
    If '$IsObject(context) {
        Return ""
    }

    Set pendingBet = context.%Get("pendingBet", "")
    If $IsObject(pendingBet) {
        Return pendingBet
    }

    Set phaseState = context.%Get("phaseState", "")
    If $IsObject(phaseState) {
        Set pendingBet = phaseState.%Get("pendingBet", "")
        If $IsObject(pendingBet) {
            Return pendingBet
        }
    }

    Set hand = context.%Get("hand", "")
    If $IsObject(hand) {
        Set phaseState = hand.%Get("phaseState", "")
        If $IsObject(phaseState) {
            Set pendingBet = phaseState.%Get("pendingBet", "")
            If $IsObject(pendingBet) {
                Return pendingBet
            }
        }
    }

    Return ""
}

ClassMethod BuildFallbackRecommendation(context As %DynamicObject) As %DynamicObject
{
    If '$IsObject(context) {
        Return {
            "actionType": "pasar",
            "amount": 0,
            "reason": "Fallback sin contexto",
            "confidence": 0
        }
    }

    If context.%Get("phase", "") = "descartes" {
        Return {
            "actionType": "cortar_mus",
            "amount": 0,
            "discards": [],
            "reason": "Fallback seguro: el LLM no pudo decidir descartes",
            "confidence": 0.2
        }
    }

    Set fallback = ##class(Mus.Agent.Strategy).RecommendFallback(context)
    Return ..NormalizeRecommendation(fallback, context)
}

ClassMethod TraceLLMInfo(eventType As %String, context As %DynamicObject = "", rawModelOutput As %String = "", parsedRecommendation As %DynamicObject = "", normalizedRecommendation As %DynamicObject = "", fallbackRecommendation As %DynamicObject = "", legalActions As %DynamicArray = "", errorText As %String = "", systemPrompt As %String = "", userPrompt As %String = "") As %Integer
{
    Try {
        Set traceId = ##class(Mus.Data.AgentLLMTrace).Log(
            eventType,
            context,
            rawModelOutput,
            parsedRecommendation,
            normalizedRecommendation,
            fallbackRecommendation,
            legalActions,
            errorText,
            systemPrompt,
            userPrompt
        )
        Return traceId
    } Catch ex {
        Return 0
    }
}

ClassMethod BuildMinimalLLMContext(context As %DynamicObject) As %DynamicObject
{
    Set compact = {}

    If '$IsObject(context) {
        Return compact
    }

    Do ..CopyIfDefined(context, compact, "gameId")
    Do ..CopyIfDefined(context, compact, "playerId")
    Do ..CopyIfDefined(context, compact, "phase")
    Do ..CopyIfDefined(context, compact, "turnPlayerId")
    Do ..CopyIfDefined(context, compact, "team")
    Do ..CopyIfDefined(context, compact, "legalActions")
    Do ..CopyIfDefined(context, compact, "cards")
    Do ..CopyIfDefined(context, compact, "profile")
    Do ..CopyIfDefined(context, compact, "pendingBet")
    Do ..CopyIfDefined(context, compact, "score")
    Do ..CopyIfDefined(context, compact, "scorePressure")

    Set bettingGuidance = context.%Get("bettingGuidance", "")
    If $IsObject(bettingGuidance) {
        Set bg = {}
        Do ..CopyIfDefined(bettingGuidance, bg, "phase")
        Do ..CopyIfDefined(bettingGuidance, bg, "handStrength")
        Do ..CopyIfDefined(bettingGuidance, bg, "summary")
        Do ..CopyIfDefined(bettingGuidance, bg, "recommendedAction")
        Do ..CopyIfDefined(bettingGuidance, bg, "recommendedAmount")
        Do ..CopyIfDefined(bettingGuidance, bg, "risk")
        Do ..CopyIfDefined(bettingGuidance, bg, "reason")
        Do compact.%Set("bettingGuidance", bg)
    }

    Set discardGuidance = context.%Get("discardGuidance", "")
    If $IsObject(discardGuidance) {
        Set dg = {}
        Do ..CopyIfDefined(discardGuidance, dg, "decisionBias")
        Do ..CopyIfDefined(discardGuidance, dg, "reason")
        Do ..CopyIfDefined(discardGuidance, dg, "summary")
        Do ..CopyIfDefined(discardGuidance, dg, "paresSummary")
        Do ..CopyIfDefined(discardGuidance, dg, "pairSummary")
        Do ..CopyIfDefined(discardGuidance, dg, "juegoSummary")
        Do ..CopyIfDefined(discardGuidance, dg, "juegoBreakAnalysis")

        Set expertPlan = discardGuidance.%Get("expertPlan", "")
        If $IsObject(expertPlan) {
            Set ep = {}
            Do ..CopyIfDefined(expertPlan, ep, "category")
            Do ..CopyIfDefined(expertPlan, ep, "mustFollow")
            Do ..CopyIfDefined(expertPlan, ep, "recommendedAction")
            Do ..CopyIfDefined(expertPlan, ep, "recommendedDiscards")
            Do ..CopyIfDefined(expertPlan, ep, "reason")
            Do dg.%Set("expertPlan", ep)
        }

        Set candidates = discardGuidance.%Get("discardCandidates", "")
        If $IsObject(candidates) {
            Set compactCandidates = []
            For i=0:1:candidates.%Size()-1 {
                Set candidate = candidates.%Get(i)
                If '$IsObject(candidate) { Continue }
                Set c = {}
                Do ..CopyIfDefined(candidate, c, "card")
                Do ..CopyIfDefined(candidate, c, "discardable")
                Do ..CopyIfDefined(candidate, c, "recommended")
                Do ..CopyIfDefined(candidate, c, "avoidDiscard")
                Do ..CopyIfDefined(candidate, c, "protected")
                Do ..CopyIfDefined(candidate, c, "sameRankCount")
                Do ..CopyIfDefined(candidate, c, "pairRank")
                Do compactCandidates.%Push(c)
            }
            Do dg.%Set("discardCandidates", compactCandidates)
        }

        Do compact.%Set("discardGuidance", dg)
    }

    Return compact
}

ClassMethod CopyIfDefined(source As %DynamicObject, target As %DynamicObject, propertyName As %String) As %Status
{
    If '$IsObject(source) { Return $$$OK }
    If '$IsObject(target) { Return $$$OK }
    If source.%IsDefined(propertyName) {
        Do target.%Set(propertyName, source.%Get(propertyName))
    }
    Return $$$OK
}

ClassMethod BuildCompactSystemPrompt(context As %DynamicObject) As %String
{
    Set isDiscard = 0
    If $IsObject(context), context.%Get("phase", "") = "descartes" { Set isDiscard = 1 }

    Set prompt = ""
    Set prompt = prompt_"Eres un agente jugador de Mus. Responde solo JSON valido, sin markdown."_$Char(10)
    Set prompt = prompt_"Elige exactamente una accion incluida en legalActions. Si no aparece en legalActions, esta prohibida."_$Char(10)
    Set prompt = prompt_"Salida obligatoria: {""actionType"":""..."",""amount"":0,""discards"":[],""reason"":""breve"",""confidence"":0.0}."_$Char(10)

    If isDiscard {
        Set prompt = prompt_"Fase descartes: actionType debe ser descartar o cortar_mus."_$Char(10)
        Set prompt = prompt_"Si expertPlan.mustFollow=1, sigue expertPlan.recommendedAction."_$Char(10)
        Set prompt = prompt_"Con juego hecho, juego+pares, medias o duples, normalmente cortar_mus."_$Char(10)
        Set prompt = prompt_"Si descartar, usa solo cartas exactas de cards; no repitas; no rompas pares/medias/duples."_$Char(10)
        Set prompt = prompt_"3 equivale a rey para pares; 1 y 2 son equivalentes para pares."_$Char(10)
        Return prompt
    }

    Set prompt = prompt_"Fase apuestas: si pendingBet existe, estas respondiendo al envite pendiente."_$Char(10)
    Set prompt = prompt_"pendingBet + handStrength weak => no_querer por defecto, incluso amount=2, salvo excepcion extraordinaria explicada."_$Char(10)
    Set prompt = prompt_"No conviertas cada envite en subida. Con pendingBet, querer/no_querer suele ser normal."_$Char(10)
    Set prompt = prompt_"envidar sin pendingBet abre envite, minimo normal 2. envidar con pendingBet debe subir amount."_$Char(10)
    Set prompt = prompt_"ordago solo en situaciones extremas; si pendingBet.type=ordago, solo querer/no_querer."_$Char(10)
    Set prompt = prompt_"Importes: pasar/no_querer=0; querer=pendingBet.amount; ordago=999."_$Char(10)
    Return prompt
}

ClassMethod BuildCompactUserPrompt(context As %DynamicObject) As %String
{
    Set prompt = "Contexto minimo de decision:"_$Char(10)
    If $IsObject(context) {
        Set prompt = prompt_context.%ToJSON()_$Char(10)
    } Else {
        Set prompt = prompt_"{}"_$Char(10)
    }
    Set prompt = prompt_"Devuelve solo JSON valido. No incluyas texto adicional."_$Char(10)
    Return prompt
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

}
