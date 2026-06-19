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
    Set prompt = prompt_"- Si legalActions contiene querer, no_querer, envidar y ordago, significa que debes responder a un envite pendiente y tambien puedes subirlo."_$Char(10)
    Set prompt = prompt_"- Ante un envite pendiente, querer acepta el importe actual completo de pendingBet.amount."_$Char(10)
    Set prompt = prompt_"- Ante un envite pendiente, no_querer descarga el envite y concede puntos al equipo que hizo la ultima subida."_$Char(10)
    Set prompt = prompt_"- Si rechazas una subida con no_querer, tu equipo pierde la cantidad previa comprometida, no la cantidad subida."_$Char(10)
    Set prompt = prompt_"- No debes aceptar siempre los envites pendientes."_$Char(10)
    Set prompt = prompt_"- Usa no_querer cuando tu mano sea debil, el importe sea alto, haya varias subidas, o tu equipo vaya claramente por delante y no necesite asumir riesgo."_$Char(10)
    Set prompt = prompt_"- Regla practica: con mano debil rechaza importes de 3 o mas; con mano media rechaza importes de 5 o mas salvo perfil agresivo o situacion desesperada."_$Char(10)
    Set prompt = prompt_"- Si eres conservative, rechaza con mas frecuencia. Si eres bluffer, puedes farolear, pero debes abandonar el farol ante importes altos."_$Char(10)
    Set prompt = prompt_"- No conviertas cada envite en una guerra de subidas. Algunas respuestas deben ser no_querer."_$Char(10)
    Set prompt = prompt_"- Si subes un envite, usa una cantidad razonable: normalmente pendingBet.amount + 1, +2 o +3."_$Char(10)
    Set prompt = prompt_"- No uses cantidades absurdas salvo ordago, que debe tener amount 999."_$Char(10)

    Set prompt = prompt_$Char(10)
    Set prompt = prompt_"Reglas de fase descartes:"_$Char(10)
    Set prompt = prompt_"- Si legalActions contiene descartar y cortar_mus, estas en fase de descartes."_$Char(10)
    Set prompt = prompt_"- Usa discardGuidance como herramientas de analisis, no como una orden mecanica."_$Char(10)
    Set prompt = prompt_"- Debes decidir como un jugador humano: valora riesgo, mejora potencial, pares, juego, chica y grande."_$Char(10)
    Set prompt = prompt_"- descartar significa pedir MUS y proponer cartas concretas a descartar."_$Char(10)
    Set prompt = prompt_"- cortar_mus significa cortar MUS y conservar la mano actual."_$Char(10)
    Set prompt = prompt_"- Si eliges descartar, devuelve discards con una o mas cartas exactas de cards."_$Char(10)
    Set prompt = prompt_"- Si eliges cortar_mus, devuelve discards: [] y amount: 0."_$Char(10)
    Set prompt = prompt_"- Nunca incluyas cartas que no esten en cards."_$Char(10)
    Set prompt = prompt_"- No repitas cartas en discards."_$Char(10)
    Set prompt = prompt_"- El 3 equivale al rey; no lo valores como carta baja."_$Char(10)
    Set prompt = prompt_"- El 1 y el 2 son valiosos para chica; no los descartes automaticamente."_$Char(10)
    Set prompt = prompt_"- Tener pares no obliga a cortar, pero no rompas jugadas hechas sin una razon clara."_$Char(10)
    Set prompt = prompt_"- Tener juego, medias o duples aumenta mucho el valor de cortar MUS, pero debes explicar tu decision."_$Char(10)
    Set prompt = prompt_"- Si pides MUS, explica que mejora concreta buscas con el descarte."_$Char(10)
    Set prompt = prompt_"- Si cortas MUS, explica que valor estas protegiendo."_$Char(10)

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
    Set prompt = prompt_"8b. Si existe pendingBet, considera seriamente no_querer cuando handStrength sea weak, cuando el importe sea alto, o cuando ya haya varias subidas."_$Char(10)
    Set prompt = prompt_"8c. No respondas siempre querer o envidar. Debe haber rechazos si el riesgo no compensa."_$Char(10)
    Set prompt = prompt_"8d. Considera ordago solo en casos extremos: mano veryStrong, rival cerca de ganar, tu equipo cerca de ganar, o situacion desesperada."_$Char(10)
    Set prompt = prompt_"8e. Si legalActions contiene ordago pero la mano no es fuerte ni la situacion critica, evita ordago."_$Char(10)
    Set prompt = prompt_"9. Si existe pendingBet y legalActions incluye envidar, puedes subir el envite, pero amount debe ser mayor que pendingBet.amount."_$Char(10)
    Set prompt = prompt_"10. Si existe pendingBet y legalActions incluye ordago, puedes subir a ordago solo en casos excepcionales."_$Char(10)
    Set prompt = prompt_"11. Si pendingBet.type es ordago, solo debes elegir querer o no_querer."_$Char(10)
    Set prompt = prompt_"12. Si eliges pasar o no_querer, amount debe ser 0."_$Char(10)
    Set prompt = prompt_"13. Si eliges ordago, amount debe ser 999."_$Char(10)
    Set prompt = prompt_"14. No inventes cartas, puntuaciones ni acciones."_$Char(10)

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

    Set actionType = recommendation.%Get("actionType", "")

    If actionType = "" {
        Return 0
    }

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

    Set actionType = recommendation.%Get("actionType", "")
    Set pendingBet = ..GetPendingBet(context)

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

ClassMethod GetLowestCards(cards As %DynamicArray, maxCount As %Integer = 2) As %DynamicArray
{
    Set protectedRanks = []
    Set result = ..GetDiscardableCardsByWeight(cards, protectedRanks, maxCount, 0)

    /*
      Solo como recurso secundario permitimos 1/2,
      y solo una carta.
    */
    If result.%Size() = 0 {
        Set result = ..GetDiscardableCardsByWeight(cards, protectedRanks, 1, 1)
    }

    Return result
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
