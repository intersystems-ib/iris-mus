Class Mus.Agent.PlayerProfile Extends %RegisteredObject
{

ClassMethod GetProfile(playerId As %String) As %DynamicObject
{
    If playerId = "P1" {
        Return ..Conservative(playerId)
    }

    If playerId = "P2" {
        Return ..Aggressive(playerId)
    }

    If playerId = "P3" {
        Return ..Bluffer(playerId)
    }

    If playerId = "P4" {
        Return ..Balanced(playerId)
    }

    Return ..Balanced(playerId)
}

ClassMethod Conservative(playerId As %String) As %DynamicObject
{
    Return {
        "playerId": (playerId),
        "name": "Conservador",
        "style": "conservative",
        "description": "Jugador prudente. Prefiere pasar o no querer si no tiene ventaja clara. Solo envida fuerte con una mano claramente superior.",
        "riskTolerance": 0.25,
        "bluffFrequency": 0.05,
        "baseEnvidoAmount": 2,
        "strongHandEnvidoAmount": 3,
        "veryStrongHandEnvidoAmount": 4,
        "ordagoFrequency": 0.02,
        "instructions": [
            "Evita riesgos innecesarios.",
            "Si tienes dudas, pasa.",
            "No aceptes envites con mano mediocre.",
            "Solo envida más de 2 si la mano es claramente fuerte.",
            "Casi nunca hagas farol."
        ]
    }
}

ClassMethod Aggressive(playerId As %String) As %DynamicObject
{
    Return {
        "playerId": (playerId),
        "name": "Agresivo",
        "style": "aggressive",
        "description": "Jugador atacante. Presiona con envites frecuentes, acepta más apuestas y sube más de 2 cuando ve una oportunidad.",
        "riskTolerance": 0.8,
        "bluffFrequency": 0.15,
        "baseEnvidoAmount": 2,
        "strongHandEnvidoAmount": 4,
        "veryStrongHandEnvidoAmount": 6,
        "ordagoFrequency": 0.06,
        "instructions": [
            "Tiende a presionar al rival.",
            "Si tienes una mano razonable, puedes envidar.",
            "Con buena mano, envida 4 o más.",
            "Puedes aceptar envites con manos medias si hay potencial.",
            "Puedes lanzar órdago muy ocasionalmente con mano excelente."
        ]
    }
}

ClassMethod Bluffer(playerId As %String) As %DynamicObject
{
    Return {
        "playerId": (playerId),
        "name": "Farolero",
        "style": "bluffer",
        "description": "Jugador imprevisible. Puede envidar sin cartas buenas para presionar, pero no debe hacerlo siempre.",
        "riskTolerance": 0.65,
        "bluffFrequency": 0.35,
        "baseEnvidoAmount": 2,
        "strongHandEnvidoAmount": 3,
        "veryStrongHandEnvidoAmount": 5,
        "ordagoFrequency": 0.08,
        "instructions": [
            "Puedes envidar aunque tu mano no sea fuerte si quieres representar fuerza.",
            "No hagas farol siempre; debe ser imprevisible.",
            "Con mano mala puedes envidar 2 como farol.",
            "Con mano buena puedes envidar 3, 4 o 5.",
            "Puedes aceptar envites para sostener un farol, pero no de forma suicida."
        ]
    }
}

ClassMethod Balanced(playerId As %String) As %DynamicObject
{
    Return {
        "playerId": (playerId),
        "name": "Equilibrado",
        "style": "balanced",
        "description": "Jugador mixto. Combina prudencia y presión. Envida cuando tiene señales positivas y pasa cuando la situación es débil.",
        "riskTolerance": 0.5,
        "bluffFrequency": 0.12,
        "baseEnvidoAmount": 2,
        "strongHandEnvidoAmount": 3,
        "veryStrongHandEnvidoAmount": 5,
        "ordagoFrequency": 0.04,
        "instructions": [
            "Juega de forma equilibrada.",
            "Envida si tienes ventaja razonable.",
            "Con mano fuerte puedes envidar más de 2.",
            "No aceptes siempre; evalúa el riesgo.",
            "Haz faroles ocasionales, pero no frecuentes."
        ]
    }
}

ClassMethod GetAllProfiles() As %DynamicObject
{
    Return {
        "P1": (..GetProfile("P1")),
        "P2": (..GetProfile("P2")),
        "P3": (..GetProfile("P3")),
        "P4": (..GetProfile("P4"))
    }
}

}
