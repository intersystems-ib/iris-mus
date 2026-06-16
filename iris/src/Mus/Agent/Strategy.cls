Class Mus.Agent.Strategy Extends %RegisteredObject
{

ClassMethod RecommendFallback(context As %DynamicObject) As %DynamicObject
{
    Set legalActions = context.%Get("legalActions", "")
    Set profile = context.%Get("profile", "")
    Set bettingGuidance = context.%Get("bettingGuidance", "")

    Set scorePressure = context.%Get("scorePressure", "")
    If '$IsObject(scorePressure), $IsObject(bettingGuidance) {
        Set scorePressure = bettingGuidance.%Get("scorePressure", "")
    }

    Set ordagoPressure = "none"
    Set isEmergency = 0
    Set isDesperationMode = 0

    If $IsObject(scorePressure) {
        Set ordagoPressure = scorePressure.%Get("ordagoPressure", "none")
        Set isEmergency = +scorePressure.%Get("isEmergency", 0)
        Set isDesperationMode = +scorePressure.%Get("isDesperationMode", 0)
    }

    Set actionType = "pasar"
    Set amount = 0
    Set reason = "Fallback determinista por seguridad"

    If '$IsObject(legalActions) || legalActions.%Size() = 0 {
        Return {
            "actionType": "pasar",
            "amount": 0,
            "reason": "Fallback sin acciones legales",
            "confidence": 0
        }
    }

    Set style = "balanced"
    Set handStrength = "unknown"
    Set riskTolerance = 0.5
    Set bluffFrequency = 0

    If $IsObject(profile) {
        Set style = profile.%Get("style", "balanced")
        Set riskTolerance = +profile.%Get("riskTolerance", 0.5)
        Set bluffFrequency = +profile.%Get("bluffFrequency", 0)
    }

    If $IsObject(bettingGuidance) {
        Set handStrength = bettingGuidance.%Get("handStrength", "unknown")
    }

    /*
      Si hay pendingBet, envidar ya no significa abrir envite,
      sino subir el envite actual.
    */
    Set pendingBet = ..GetPendingBet(context)

    If $IsObject(pendingBet) {
        Set pendingDecision = ..RecommendPendingBetResponse(context, pendingBet)
        Return pendingDecision
    }

    /*
      Bloque anterior: respuesta simple a apuestas pendientes.
      Lo dejamos como fallback de compatibilidad por si el contexto
      trae querer/no_querer pero no trae phaseState.pendingBet.
    */
    If ..ArrayContains(legalActions, "querer") || ..ArrayContains(legalActions, "no_querer") {
        If style = "aggressive" {
            If ..ArrayContains(legalActions, "querer") {
                Return {
                    "actionType": "querer",
                    "amount": 0,
                    "reason": "Fallback agresivo: acepta la apuesta pendiente",
                    "confidence": 0.35
                }
            }
        }

        If (handStrength = "strong") || (handStrength = "veryStrong") {
            If ..ArrayContains(legalActions, "querer") {
                Return {
                    "actionType": "querer",
                    "amount": 0,
                    "reason": "Fallback: mano fuerte, acepta la apuesta pendiente",
                    "confidence": 0.45
                }
            }
        }

        If ..ArrayContains(legalActions, "no_querer") {
            Return {
                "actionType": "no_querer",
                "amount": 0,
                "reason": "Fallback prudente: rechaza la apuesta pendiente",
                "confidence": 0.4
            }
        }
    }

    If ..ArrayContains(legalActions, "ordago") {
        If isDesperationMode {
            If (handStrength = "strong") || (handStrength = "veryStrong") {
                Return {
                    "actionType": "ordago",
                    "amount": 999,
                    "reason": "Ordago por presion extrema de marcador: el rival esta a un punto de ganar y la mano permite asumir riesgo",
                    "confidence": 0.82
                }
            }
        }

        If isEmergency {
            If handStrength = "veryStrong" {
                Return {
                    "actionType": "ordago",
                    "amount": 999,
                    "reason": "Ordago por emergencia de marcador con mano muy fuerte",
                    "confidence": 0.88
                }
            }
        }
    }

    If ..ArrayContains(legalActions, "envidar") {
        If (handStrength = "veryStrong") {
            Set amount = 5

            If style = "aggressive" {
                Set amount = 6
            }

            If style = "conservative" {
                Set amount = 4
            }

            Return {
                "actionType": "envidar",
                "amount": (amount),
                "reason": "Fallback: mano muy fuerte, envida mas de 2",
                "confidence": 0.5
            }
        }

        If (handStrength = "strong") {
            Set amount = 3

            If style = "aggressive" {
                Set amount = 4
            }

            Return {
                "actionType": "envidar",
                "amount": (amount),
                "reason": "Fallback: mano fuerte, envida",
                "confidence": 0.45
            }
        }

        If style = "bluffer" {
            Return {
                "actionType": "envidar",
                "amount": 2,
                "reason": "Fallback farolero: envida como farol controlado",
                "confidence": 0.25
            }
        }
    }

    If ..ArrayContains(legalActions, "pasar") {
        Return {
            "actionType": "pasar",
            "amount": 0,
            "reason": "Fallback: pasar es la opcion segura",
            "confidence": 0.5
        }
    }

    Set actionType = legalActions.%Get(0)

    Return {
        "actionType": (actionType),
        "amount": 0,
        "reason": "Fallback: primera accion legal disponible",
        "confidence": 0.2
    }
}

ClassMethod RecommendPendingBetResponse(context As %DynamicObject, pendingBet As %DynamicObject) As %DynamicObject
{
    Set result = {
        "actionType": "querer",
        "amount": 0,
        "confidence": 0.75,
        "reason": "Aceptar envite pendiente por defecto"
    }

    If '$IsObject(context) {
        Do result.%Set("actionType", "no_querer")
        Do result.%Set("reason", "No hay contexto suficiente para aceptar el envite")
        Return result
    }

    If '$IsObject(pendingBet) {
        Return result
    }

    Set amount = +pendingBet.%Get("amount", 0)
    Set raiseCount = +pendingBet.%Get("raiseCount", 0)
    Set pendingType = pendingBet.%Get("type", "")

    Set profile = context.%Get("profile", "")
    Set profileId = ""

    If $IsObject(profile) {
        Set profileId = profile.%Get("id", "")
    }

    Set bettingGuidance = context.%Get("bettingGuidance", "")
    Set handStrength = ""

    If $IsObject(bettingGuidance) {
        Set handStrength = bettingGuidance.%Get("handStrength", "")
    }

    Set scorePressure = context.%Get("scorePressure", "")
    Set leading = 0
    Set desperate = 0

    If $IsObject(scorePressure) {
        Set leading = +scorePressure.%Get("leading", 0)
        Set desperate = +scorePressure.%Get("desperate", 0)
    }

    /*
      Rechazo duro: ordago no se acepta salvo mano muy fuerte o desesperacion.
    */
    If pendingType = "ordago" {
        If (handStrength = "veryStrong") || desperate {
            Do result.%Set("actionType", "querer")
            Do result.%Set("amount", amount)
            Do result.%Set("confidence", 0.85)
            Do result.%Set("reason", "Aceptar ordago por mano muy fuerte o situacion desesperada")
            Return result
        }

        Do result.%Set("actionType", "no_querer")
        Do result.%Set("amount", 0)
        Do result.%Set("confidence", 0.95)
        Do result.%Set("reason", "Rechazo ordago sin mano muy fuerte")
        Return result
    }

    /*
      Si vamos claramente por delante, no entrar en guerras con mano media/debil.
    */
    If leading && ((handStrength = "weak") || (handStrength = "medium")) && (amount >= 3) {
        Do result.%Set("actionType", "no_querer")
        Do result.%Set("amount", 0)
        Do result.%Set("confidence", 0.9)
        Do result.%Set("reason", "Rechazo envite: vamos por delante y la mano no justifica el riesgo")
        Return result
    }

    /*
      Reglas por perfil.
    */
    If profileId = "conservative" {
        If ((handStrength = "weak") || (handStrength = "medium")) && (amount >= 3) {
            Do result.%Set("actionType", "no_querer")
            Do result.%Set("amount", 0)
            Do result.%Set("confidence", 0.9)
            Do result.%Set("reason", "Perfil conservador rechaza envite con mano no fuerte")
            Return result
        }

        If (handStrength = "strong") && (amount > 4) {
            Do result.%Set("actionType", "no_querer")
            Do result.%Set("amount", 0)
            Do result.%Set("confidence", 0.8)
            Do result.%Set("reason", "Perfil conservador rechaza importe alto con mano solo fuerte")
            Return result
        }
    }

    If profileId = "balanced" {
        If (handStrength = "weak") && (amount >= 3) {
            Do result.%Set("actionType", "no_querer")
            Do result.%Set("amount", 0)
            Do result.%Set("confidence", 0.85)
            Do result.%Set("reason", "Perfil equilibrado rechaza envite con mano debil")
            Return result
        }

        If (handStrength = "medium") && (amount >= 5) {
            Do result.%Set("actionType", "no_querer")
            Do result.%Set("amount", 0)
            Do result.%Set("confidence", 0.8)
            Do result.%Set("reason", "Perfil equilibrado rechaza importe alto con mano media")
            Return result
        }
    }

    If profileId = "aggressive" {
        If (handStrength = "weak") && (amount >= 5) {
            Do result.%Set("actionType", "no_querer")
            Do result.%Set("amount", 0)
            Do result.%Set("confidence", 0.8)
            Do result.%Set("reason", "Perfil agresivo rechaza envite alto con mano debil")
            Return result
        }

        If (handStrength = "medium") && (amount >= 7) {
            Do result.%Set("actionType", "no_querer")
            Do result.%Set("amount", 0)
            Do result.%Set("confidence", 0.75)
            Do result.%Set("reason", "Perfil agresivo rechaza guerra de envites con mano media")
            Return result
        }
    }

    If profileId = "bluffer" {
        If (handStrength = "weak") && (amount >= 5) {
            Do result.%Set("actionType", "no_querer")
            Do result.%Set("amount", 0)
            Do result.%Set("confidence", 0.75)
            Do result.%Set("reason", "Perfil farolero abandona farol cuando el coste ya es alto")
            Return result
        }

        If (handStrength = "medium") && (amount >= 7) {
            Do result.%Set("actionType", "no_querer")
            Do result.%Set("amount", 0)
            Do result.%Set("confidence", 0.75)
            Do result.%Set("reason", "Perfil farolero rechaza envite excesivo con mano media")
            Return result
        }
    }

    /*
      Corte general: no aceptar guerras largas salvo mano muy fuerte.
    */
    If (raiseCount >= 3) && (handStrength '= "veryStrong") {
        Do result.%Set("actionType", "no_querer")
        Do result.%Set("amount", 0)
        Do result.%Set("confidence", 0.85)
        Do result.%Set("reason", "Rechazo tras varias subidas sin mano muy fuerte")
        Return result
    }

    /*
      Aceptacion normal.
    */
    Do result.%Set("actionType", "querer")
    Do result.%Set("amount", amount)
    Do result.%Set("confidence", 0.8)
    Do result.%Set("reason", "Acepto envite pendiente con riesgo asumible")

    Return result
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
