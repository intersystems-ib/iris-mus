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
        Set currentAmount = +pendingBet.%Get("amount", 0)
        Set pendingType = pendingBet.%Get("type", "envidar")

        Set raiseCount = +pendingBet.%Get("raiseCount", 0)

        If (currentAmount >= 8) || (raiseCount >= 3) {
            If ..ArrayContains(legalActions, "querer") {
                If (handStrength = "strong") || (handStrength = "veryStrong") || (style = "aggressive") {
                    Return {
                        "actionType": "querer",
                        "amount": (currentAmount),
                        "reason": "Fallback: acepta el envite pendiente porque ya ha habido suficientes subidas",
                        "confidence": 0.74
                    }
                }
            }

            If ..ArrayContains(legalActions, "no_querer") {
                Return {
                    "actionType": "no_querer",
                    "amount": 0,
                    "reason": "Fallback: descarga el envite porque la escalada de subidas ya es demasiado alta",
                    "confidence": 0.72
                }
            }
        }

        /*
          Si hay ordago pendiente, solo tiene sentido querer/no_querer.
          No se puede subir un ordago.
        */
        If pendingType = "ordago" {
            If (handStrength = "veryStrong") || isDesperationMode {
                If ..ArrayContains(legalActions, "querer") {
                    Return {
                        "actionType": "querer",
                        "amount": (currentAmount),
                        "reason": "Fallback: acepta el ordago pendiente por fuerza de mano o presion de marcador",
                        "confidence": 0.72
                    }
                }
            }

            If style = "aggressive" {
                If (handStrength = "strong") || (handStrength = "veryStrong") {
                    If ..ArrayContains(legalActions, "querer") {
                        Return {
                            "actionType": "querer",
                            "amount": (currentAmount),
                            "reason": "Fallback agresivo: acepta el ordago pendiente con mano suficiente",
                            "confidence": 0.62
                        }
                    }
                }
            }

            If ..ArrayContains(legalActions, "no_querer") {
                Return {
                    "actionType": "no_querer",
                    "amount": 0,
                    "reason": "Fallback prudente: rechaza el ordago pendiente",
                    "confidence": 0.7
                }
            }
        }

        /*
          Si hay envite pendiente, podemos querer, no querer,
          subir el envite o lanzar ordago.
        */

        If ..ArrayContains(legalActions, "ordago") {
            If isDesperationMode {
                If (handStrength = "strong") || (handStrength = "veryStrong") {
                    Return {
                        "actionType": "ordago",
                        "amount": 999,
                        "reason": "Fallback: sube el envite pendiente a ordago por presion extrema de marcador",
                        "confidence": 0.78
                    }
                }
            }

            If isEmergency {
                If handStrength = "veryStrong" {
                    Return {
                        "actionType": "ordago",
                        "amount": 999,
                        "reason": "Fallback: sube el envite pendiente a ordago por emergencia de marcador con mano muy fuerte",
                        "confidence": 0.82
                    }
                }
            }
        }

        If ..ArrayContains(legalActions, "envidar") {
            If handStrength = "veryStrong" {
                Set raiseAmount = currentAmount + 2

                If style = "aggressive" {
                    Set raiseAmount = currentAmount + 3
                }

                If style = "conservative" {
                    Set raiseAmount = currentAmount + 1
                }

                Return {
                    "actionType": "envidar",
                    "amount": (raiseAmount),
                    "reason": "Fallback: mano muy fuerte, sube el envite pendiente",
                    "confidence": 0.58
                }
            }

            If (handStrength = "strong") && (style = "aggressive") {
                Set raiseAmount = currentAmount + 1

                Return {
                    "actionType": "envidar",
                    "amount": (raiseAmount),
                    "reason": "Fallback agresivo: sube moderadamente el envite pendiente",
                    "confidence": 0.46
                }
            }

            If (style = "bluffer") && (bluffFrequency > 0.35) && (currentAmount <= 3) {
                Set raiseAmount = currentAmount + 1

                Return {
                    "actionType": "envidar",
                    "amount": (raiseAmount),
                    "reason": "Fallback farolero: sube el envite pendiente como farol controlado",
                    "confidence": 0.28
                }
            }
        }

        If ..ArrayContains(legalActions, "querer") {
            If (handStrength = "strong") || (handStrength = "veryStrong") {
                Return {
                    "actionType": "querer",
                    "amount": (currentAmount),
                    "reason": "Fallback: acepta el envite pendiente con mano suficiente",
                    "confidence": 0.68
                }
            }

            If style = "aggressive" {
                If handStrength '= "weak" {
                    Return {
                        "actionType": "querer",
                        "amount": (currentAmount),
                        "reason": "Fallback agresivo: acepta el envite pendiente",
                        "confidence": 0.5
                    }
                }
            }

            If isDesperationMode && (handStrength '= "weak") {
                Return {
                    "actionType": "querer",
                    "amount": (currentAmount),
                    "reason": "Fallback: acepta por presion de marcador",
                    "confidence": 0.52
                }
            }
        }

        If ..ArrayContains(legalActions, "no_querer") {
            Return {
                "actionType": "no_querer",
                "amount": 0,
                "reason": "Fallback prudente: descarga el envite pendiente",
                "confidence": 0.65
            }
        }
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
