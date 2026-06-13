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

        Set fallback = ##class(Mus.Agent.Strategy).RecommendFallback(context)
        Set fallback = ..NormalizeRecommendation(fallback, context)

        Set legalActions = context.%Get("legalActions", "")
        If '$IsObject(legalActions) || legalActions.%Size() = 0 {
            Return fallback
        }

        Set raw = ""
        Set sc = ##class(Mus.AI.Provider).ChatJson(
            ..BuildSystemPrompt(),
            ..BuildUserPrompt(context),
            .raw
        )
        If $$$ISERR(sc) {
            Do fallback.%Set("reason", "Fallback por error LLM")
            Do fallback.%Set("llmError", $Extract($System.Status.GetErrorText(sc), 1, 500))
            Return fallback
        }

        Set recommendation = ""
        Try {
            Set recommendation = {}.%FromJSON(raw)

            Set recommendation = ..NormalizeRecommendation(recommendation, context)
        }
        Catch exJson {
            Do fallback.%Set("reason", "Fallback por JSON invalido del LLM")
            Do fallback.%Set("rawModelOutput", raw)
            Return fallback
        }

        If '..IsValidRecommendation(recommendation, legalActions) {
            Do fallback.%Set("reason", "Fallback por recomendacion ilegal del LLM")
            Do fallback.%Set("rawModelOutput", raw)
            Return fallback
        }

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
    Set prompt = prompt_"Eres un agente jugador de Mus."_ $Char(10)
    Set prompt = prompt_"Debes recomendar una unica accion para el jugador actual."_ $Char(10)
    Set prompt = prompt_"Responde exclusivamente JSON valido, sin markdown, sin explicaciones fuera del JSON."_ $Char(10)
    Set prompt = prompt_"La lista legalActions del contexto es vinculante. Nunca elijas una accion que no aparezca ahi."_ $Char(10)
    Set prompt = prompt_"Si legalActions solo contiene pasar, debes elegir pasar."_ $Char(10)
    Set prompt = prompt_"Si existe pendingBet y legalActions contiene querer/no_querer, debes responder a la apuesta pendiente."_ $Char(10)
    Set prompt = prompt_"Puedes elegir envidar solo si envidar aparece en legalActions."_ $Char(10)
    Set prompt = prompt_"Puedes elegir ordago solo si ordago aparece en legalActions, y debe ser muy excepcional."_ $Char(10)
    Set prompt = prompt_"Si eliges envidar, amount debe ser un entero positivo. El minimo normal es 2."_ $Char(10)
    Set prompt = prompt_"Con mano buena puedes envidar mas de 2: por ejemplo 3, 4, 5 o 6."_ $Char(10)
    Set prompt = prompt_"Con mano muy fuerte puedes envidar aun mas, pero evita cantidades absurdas salvo ordago."_ $Char(10)
    Set prompt = prompt_"Debes respetar la personalidad del jugador indicada en profile."_ $Char(10)
    Set prompt = prompt_"Un jugador conservador debe arriesgar poco."_ $Char(10)
    Set prompt = prompt_"Un jugador agresivo puede presionar y aceptar mas riesgos."_ $Char(10)
    Set prompt = prompt_"Un jugador farolero puede envidar sin buena mano ocasionalmente."_ $Char(10)
    Set prompt = prompt_"No digas que una accion es legal si no aparece en legalActions."_ $Char(10)
    Set prompt = prompt_"Si legalActions tiene sólo un valor, debes elegir ese valor. Sin excepciones."_ $Char(10)
    Set prompt = prompt_"Nunca elijas envidar u ordago cuando legalActions no los contenga, incluso si tu mano es muy fuerte."_ $Char(10)
    Set prompt = prompt_"El JSON de salida debe tener exactamente estas claves: actionType, amount, reason, confidence."_ $Char(10)
    Set prompt = prompt_"confidence debe ser un numero entre 0 y 1."_ $Char(10)

    Return prompt
}

ClassMethod BuildUserPrompt(context As %DynamicObject) As %String
{
    Set prompt = ""
    Set prompt = prompt_"Contexto completo de la partida y del jugador actual:"_$Char(10)
    Set prompt = prompt_context.%ToJSON()_$Char(10)
    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Instrucciones de decision:"_$Char(10)
    Set prompt = prompt_"1. Mira legalActions. Solo puedes elegir una accion incluida ahi."_ $Char(10)
    Set prompt = prompt_"2. Mira profile. Ajusta tu riesgo a esa personalidad."_ $Char(10)
    Set prompt = prompt_"3. Mira bettingGuidance.handStrength."_ $Char(10)
    Set prompt = prompt_"4. Si la mano es strong o veryStrong y legalActions incluye envidar, puedes elegir amount mayor que 2."_ $Char(10)
    Set prompt = prompt_"5. Si profile.style es bluffer, puedes hacer farol ocasional con envidar aunque handStrength sea weak o medium."_ $Char(10)
    Set prompt = prompt_"6. Si existe pendingBet, decide querer o no_querer segun tu perfil, fuerza y riesgo."_ $Char(10)
    Set prompt = prompt_"7. No inventes cartas, puntuaciones ni acciones."_ $Char(10)
    Set prompt = prompt_"8. If you choose querer, set amount to the pendingBet amount when available."_ $Char(10)
    Set prompt = prompt_"9. If you choose no_querer or pasar, set amount to 0."_ $Char(10)
    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Devuelve solo JSON valido con esta forma:"_$Char(10)
    Set prompt = prompt_"{""actionType"":""pasar|envidar|querer|no_querer|ordago"",""amount"":0,""reason"":""motivo breve"",""confidence"":0.0}"_$Char(10)

    Return prompt
}

ClassMethod IsValidRecommendation(recommendation As %DynamicObject, legalActions As %DynamicArray) As %Boolean
{
    If '$IsObject(recommendation) {
        Return 0
    }

    If '$IsObject(legalActions) {
        Return 0
    }

    Set actionType = recommendation.%Get("actionType", "")

    If actionType = "" {
        Return 0
    }

    If '##class(Mus.Agent.Strategy).ArrayContains(legalActions, actionType) {
        Return 0
    }

    Set amount = +recommendation.%Get("amount", 0)

    If actionType = "envidar" {
        If amount < 2 {
            Return 0
        }

        If amount > 20 {
            Return 0
        }

        Return 1
    }

    If actionType = "ordago" {
        Return 1
    }

    If actionType = "querer" {
        If amount < 0 {
            Return 0
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

    Set actionType = recommendation.%Get("actionType", "")

    Set phaseState = ""
    Set pendingBet = ""

    If $IsObject(context) {
        Set phaseState = context.%Get("phaseState", "")

        If $IsObject(phaseState) {
            Set pendingBet = phaseState.%Get("pendingBet", "")
        }
    }

    If actionType = "querer", $IsObject(pendingBet) {
        Do recommendation.%Set("amount", +pendingBet.%Get("amount", 0))
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

}
