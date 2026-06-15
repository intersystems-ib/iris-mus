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

        If $IsObject(legalActions), legalActions.%Size() = 1 {
            Set onlyAction = legalActions.%Get(0)

            Set recommendation = {
                "actionType": (onlyAction),
                "amount": 0,
                "reason": "Unica accion legal disponible",
                "confidence": 1.0
            }

            Set recommendation = ..NormalizeRecommendation(recommendation, context)
            Return recommendation
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

        If '..IsValidRecommendation(recommendation, legalActions, context) {
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

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Reglas sobre envites y subidas:"_$Char(10)
    Set prompt = prompt_"- Si no existe pendingBet, envidar significa abrir un nuevo envite."_$Char(10)
    Set prompt = prompt_"- Si existe pendingBet y legalActions contiene envidar, envidar significa subir el envite actual, no abrir uno nuevo."_$Char(10)
    Set prompt = prompt_"- Cuando subas un envite pendiente, amount debe ser estrictamente mayor que pendingBet.amount."_$Char(10)
    Set prompt = prompt_"- Si pendingBet.type es ordago, nunca elijas envidar ni ordago otra vez."_$Char(10)
    Set prompt = prompt_"- Si legalActions contiene querer, no_querer, envidar y ordago, significa que debes responder a un envite pendiente y tambien puedes subirlo."_$Char(10)
    Set prompt = prompt_"- Ante un envite pendiente, querer acepta el importe actual completo de pendingBet.amount."_$Char(10)
    Set prompt = prompt_"- Ante un envite pendiente, no_querer descarga el envite y concede puntos al equipo que hizo la ultima subida."_$Char(10)
    Set prompt = prompt_"- Si rechazas una subida con no_querer, tu equipo pierde la cantidad previa comprometida, no la cantidad subida."_$Char(10)
    Set prompt = prompt_"- Si subes un envite, usa una cantidad razonable: normalmente pendingBet.amount + 1, +2 o +3."_$Char(10)
    Set prompt = prompt_"- No uses cantidades absurdas salvo ordago, que debe tener amount 999."_$Char(10)

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
    Set prompt = prompt_"El JSON de salida debe tener exactamente estas claves: actionType, amount, reason, confidence."_$Char(10)
    Set prompt = prompt_"confidence debe ser un numero entre 0 y 1."_$Char(10)

    Return prompt
}

ClassMethod BuildUserPrompt(context As %DynamicObject) As %String
{
    Set prompt = ""
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
    Set prompt = prompt_"9. Si existe pendingBet y legalActions incluye envidar, puedes subir el envite, pero amount debe ser mayor que pendingBet.amount."_$Char(10)
    Set prompt = prompt_"10. Si existe pendingBet y legalActions incluye ordago, puedes subir a ordago solo en casos excepcionales."_$Char(10)
    Set prompt = prompt_"11. Si pendingBet.type es ordago, solo debes elegir querer o no_querer."_$Char(10)
    Set prompt = prompt_"12. Si eliges pasar o no_querer, amount debe ser 0."_$Char(10)
    Set prompt = prompt_"13. Si eliges ordago, amount debe ser 999."_$Char(10)
    Set prompt = prompt_"14. No inventes cartas, puntuaciones ni acciones."_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Devuelve solo JSON valido con esta forma:"_$Char(10)
    Set prompt = prompt_"{""actionType"":""pasar|envidar|querer|no_querer|ordago"",""amount"":0,""reason"":""motivo breve"",""confidence"":0.0}"_$Char(10)

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

    Set actionType = recommendation.%Get("actionType", "")

    If actionType = "" {
        Return 0
    }

    If '##class(Mus.Agent.Strategy).ArrayContains(legalActions, actionType) {
        Return 0
    }

    Set amount = +recommendation.%Get("amount", 0)
    Set pendingBet = ..GetPendingBet(context)

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

    Set actionType = recommendation.%Get("actionType", "")
    Set pendingBet = ..GetPendingBet(context)

    If actionType = "querer", $IsObject(pendingBet) {
        Do recommendation.%Set("amount", +pendingBet.%Get("amount", 0))
    }

    If actionType = "envidar" {
        Set amount = +recommendation.%Get("amount", 0)

        If $IsObject(pendingBet) {
            Set currentAmount = +pendingBet.%Get("amount", 0)

            If amount <= currentAmount {
                Set amount = currentAmount + 1
            }
        } Else {
            If amount < 2 {
                Set amount = 2
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

}
