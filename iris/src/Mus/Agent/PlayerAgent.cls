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

    Set actionType = ..NormalizeActionType(recommendation.%Get("actionType", recommendation.%Get("type", recommendation.%Get("action", ""))))

    If actionType '= "" {
        Do recommendation.%Set("actionType", actionType)
    }

    Set pendingBet = ..GetPendingBet(context)

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
        } ElseIf amount < 2 {
            Set amount = 2
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
    Do ..CopyIfDefined(context, compact, "targetScore")

    Set discardTurnInfo = ..BuildDiscardTurnInfo(context)
    If $IsObject(discardTurnInfo) {
        Do compact.%Set("discardTurnInfo", discardTurnInfo)
    }

    Return compact
}

ClassMethod BuildDiscardTurnInfo(context As %DynamicObject) As %DynamicObject
{
    If '$IsObject(context) {
        Return ""
    }

    Set existing = context.%Get("discardTurnInfo", "")
    If $IsObject(existing) {
        Return existing
    }

    Set info = {
        "isLastToSpeak": false,
        "rivalMusCount": 0,
        "teammateMusCount": 0
    }

    Set phase = $ZConvert(context.%Get("phase", ""), "L")
    If (phase '= "descartes") && (phase '= "discard") && (phase '= "mus") {
        Return info
    }

    Set playerId = context.%Get("playerId", "")
    Set playerTeam = ..GetPlayerTeam(context)
    Set phaseState = context.%Get("phaseState", "")

    If '$IsObject(phaseState) {
        Set hand = context.%Get("hand", "")
        If $IsObject(hand) {
            Set phaseState = hand.%Get("phaseState", "")
        }
    }

    If '$IsObject(phaseState) {
        Return info
    }

    Set musPlayers = ..GetFirstArrayProperty(phaseState, "musPlayers,askedMusPlayers,playersAskingMus,requestedMusPlayers,passedPlayers")
    If '$IsObject(musPlayers) {
        Return info
    }

    Set players = context.%Get("players", "")

    For i=0:1:musPlayers.%Size()-1 {
        Set musPlayerId = musPlayers.%Get(i)
        Set musTeam = ..FindPlayerTeam(players, musPlayerId)

        If playerTeam '= "", musTeam '= "" {
            If musTeam = playerTeam {
                Do info.%Set("teammateMusCount", +info.%Get("teammateMusCount", 0) + 1)
            } Else {
                Do info.%Set("rivalMusCount", +info.%Get("rivalMusCount", 0) + 1)
            }
        }
    }

    Set order = ..GetFirstArrayProperty(phaseState, "turnOrder,discardOrder,playersOrder,order")
    If $IsObject(order), playerId '= "" {
        For i=0:1:order.%Size()-1 {
            If order.%Get(i) = playerId {
                If i = order.%Size()-1 {
                    Do info.%Set("isLastToSpeak", "true")
                }
                Quit
            }
        }
    }

    Return info
}

ClassMethod GetFirstArrayProperty(source As %DynamicObject, names As %String) As %DynamicArray
{
    If '$IsObject(source) {
        Return ""
    }

    For i=1:1:$Length(names, ",") {
        Set name = $Piece(names, ",", i)
        Set value = source.%Get(name, "")
        If $IsObject(value) {
            Return value
        }
    }

    Return ""
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

    Set playerTeam = context.%Get("team", "")
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

ClassMethod FindPlayerTeam(players As %DynamicArray, playerId As %String) As %String
{
    If '$IsObject(players) || playerId = "" {
        Return ""
    }

    For i=0:1:players.%Size()-1 {
        Set player = players.%Get(i)
        If '$IsObject(player) {
            Continue
        }

        If player.%Get("id", "") = playerId {
            Return player.%Get("team", "")
        }
    }

    Return ""
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
