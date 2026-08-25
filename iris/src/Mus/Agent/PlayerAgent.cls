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
        Set raw = ""

        Set sc = ##class(Mus.AI.MusAgentClient).RecommendActionWithLightTools(
            llmContext,
            playerId,
            .raw
        )

        If $$$ISERR(sc) {
            Do fallback.%Set("reason", "Fallback por error en agente LLM")
            Do fallback.%Set("llmError", $Extract($System.Status.GetErrorText(sc), 1, 500))
            Return fallback
        }
                
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

    Set actionType = ..NormalizeActionType(
        recommendation.%Get(
            "actionType",
            recommendation.%Get(
                "type",
                recommendation.%Get("action", "")
            )
        )
    )

    If actionType '= "" {
        Do recommendation.%Set("actionType", actionType)
    }

    Set pendingBet = ..GetPendingBet(context)

    /*
      Esta funcion solo hace normalizacion mecanica/estructural.
      No debe cambiar una decision valida del LLM por motivos de fuerza,
      perfil, marcador, presion, numero de subidas ni estrategia.

      Las decisiones estrategicas pertenecen al LLM y a sus tools.
      IsValidRecommendation se encarga de rechazar resultados incompatibles
      con las reglas del protocolo.
    */

    If (actionType = "pasar") || (actionType = "no_querer") {
        Do recommendation.%Set("amount", 0)
    }

    If actionType = "querer" {
        If $IsObject(pendingBet) {
            Do recommendation.%Set("amount", +pendingBet.%Get("amount", 0))
        }
    }

    If actionType = "ordago" {
        Do recommendation.%Set("amount", 999)
    }

    If actionType = "cortar_mus" {
        Do recommendation.%Set("amount", 0)
        Do recommendation.%Set("discards", [])
    }

    If actionType = "descartar" {
        Do recommendation.%Set("amount", 0)
        /*
          No filtramos ni inventamos descartes.
          Si los descartes del LLM son invalidos, IsValidRecommendation
          rechazara la recomendacion y se usara el fallback explicito.
        */
    }

    If actionType = "envidar" {
        /*
          Conservamos exactamente el importe elegido por el LLM.
          No lo bajamos a 2, no lo incrementamos automaticamente y no
          decidimos querer/no_querer en su lugar.

          IsValidRecommendation valida:
          - amount >= 2
          - amount <= 20
          - si existe pendingBet, amount > pendingBet.amount
        */
        If 'recommendation.%IsDefined("amount") {
            Do recommendation.%Set("amount", 0)
        }
    }

    If 'recommendation.%IsDefined("reason") {
        Do recommendation.%Set("reason", "")
    }

    If 'recommendation.%IsDefined("confidence") {
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

    If (actionType = "envidar") || (actionType = "envido") || (actionType = "enviar") || (actionType = "raise") || (actionType = "bet") {
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

ClassMethod BuildMinimalLLMContext(context As %DynamicObject) As %DynamicObject
{
    Set compact = {}

    If '$IsObject(context) {
        Return compact
    }

    /*
      Solo enviamos al LLM datos que realmente consume MusAgentClient.
      No copiamos GameState, historicos, bettingGuidance, discardGuidance,
      handStrength ni scorePressure precalculados.

      La evaluacion estrategica y la decision final deben hacerlas el LLM
      mediante las tools. PlayerAgent solo orquesta, normaliza estructura y valida.
    */
    Do ..CopyIfDefined(context, compact, "phase")
    Do ..CopyIfDefined(context, compact, "team")
    Do ..CopyIfDefined(context, compact, "legalActions")
    Do ..CopyIfDefined(context, compact, "cards")
    Do ..CopyIfDefined(context, compact, "targetScore")

    Set profile = ..BuildCompactLLMProfile(context)
    If $IsObject(profile), profile.%Size() > 0 {
        Do compact.%Set("profile", profile)
    }

    Set phase = $ZCONVERT(context.%Get("phase", ""), "L")

    If phase = "descartes" {
        Set discardTurnInfo = ..BuildCompactDiscardTurnInfo(context)
        If $IsObject(discardTurnInfo) {
            Do compact.%Set("discardTurnInfo", discardTurnInfo)
        }

        Return compact
    }

    /*
      En apuestas el marcador solo se necesita para que el LLM pueda llamar
      evaluate_score_pressure cuando proceda.
    */
    Do ..CopyIfDefined(context, compact, "score")

    Set pendingBet = ..BuildCompactPendingBet(context)
    If $IsObject(pendingBet), pendingBet.%Size() > 0 {
        Do compact.%Set("pendingBet", pendingBet)
    }

    Return compact
}

ClassMethod BuildCompactLLMProfile(context As %DynamicObject) As %DynamicObject
{
    Set result = {}

    If '$IsObject(context) {
        Return result
    }

    Set profile = context.%Get("profile", "")

    If $IsObject(profile) {
        /* Identidad de estilo */
        Do ..CopyIfDefined(profile, result, "id")
        Do ..CopyIfDefined(profile, result, "profileId")
        Do ..CopyIfDefined(profile, result, "style")

        /* Parametros que pueden cambiar la agresividad de la decision */
        Do ..CopyIfDefined(profile, result, "riskTolerance")
        Do ..CopyIfDefined(profile, result, "bluffFrequency")
        Do ..CopyIfDefined(profile, result, "baseEnvidoAmount")
        Do ..CopyIfDefined(profile, result, "strongHandEnvidoAmount")
        Do ..CopyIfDefined(profile, result, "veryStrongHandEnvidoAmount")
        Do ..CopyIfDefined(profile, result, "ordagoFrequency")

        Return result
    }

    /* Compatibilidad con contextos que exponen solo profileId. */
    Set profileId = context.%Get("profileId", "")
    If profileId '= "" {
        Do result.%Set("id", profileId)
        Do result.%Set("profileId", profileId)
        Do result.%Set("style", profileId)
    }

    Return result
}

ClassMethod BuildCompactPendingBet(context As %DynamicObject) As %DynamicObject
{
    Set result = {}

    If '$IsObject(context) {
        Return result
    }

    Set pendingBet = ..GetPendingBet(context)

    If '$IsObject(pendingBet) {
        Return result
    }

    /*
      Para la decision solo importan el tipo y la cuantia actual.
      previousAmount/raiseCount se conservan por si el prompt o una reparacion
      posterior necesita distinguir apertura de subida sin arrastrar arrays,
      timestamps ni metadatos del backend.
    */
    Do ..CopyIfDefined(pendingBet, result, "type")
    Do ..CopyIfDefined(pendingBet, result, "amount")
    Do ..CopyIfDefined(pendingBet, result, "previousAmount")
    Do ..CopyIfDefined(pendingBet, result, "raiseCount")

    Return result
}

ClassMethod BuildCompactDiscardTurnInfo(context As %DynamicObject) As %DynamicObject
{
    Set result = {
        "isLastToSpeak": 0,
        "rivalMusCount": 0,
        "teammateMusCount": 0
    }

    If '$IsObject(context) {
        Return result
    }

    Set source = context.%Get("discardTurnInfo", "")

    If $IsObject(source) {
        Do result.%Set("isLastToSpeak", +source.%Get("isLastToSpeak", 0))
        Do result.%Set("rivalMusCount", +source.%Get("rivalMusCount", 0))
        Do result.%Set("teammateMusCount", +source.%Get("teammateMusCount", 0))
        Return result
    }

    /*
      Compatibilidad con ContextBuilder anteriores que pudieran exponer estos
      valores directamente en el contexto.
    */
    If context.%IsDefined("isLastToSpeak") {
        Do result.%Set("isLastToSpeak", +context.%Get("isLastToSpeak", 0))
    }
    If context.%IsDefined("rivalMusCount") {
        Do result.%Set("rivalMusCount", +context.%Get("rivalMusCount", 0))
    }
    If context.%IsDefined("teammateMusCount") {
        Do result.%Set("teammateMusCount", +context.%Get("teammateMusCount", 0))
    }

    Return result
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
