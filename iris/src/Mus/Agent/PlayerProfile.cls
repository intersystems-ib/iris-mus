Class Mus.Agent.PlayerProfile Extends %RegisteredObject
{

ClassMethod GetProfile(playerId As %String, player As %DynamicObject = "", gameState As %DynamicObject = "") As %DynamicObject
{
    If $IsObject(player) {
        Set declaredProfile = ..BuildProfileFromPlayerDeclaration(playerId, player)
        If $IsObject(declaredProfile) {
            Return declaredProfile
        }
    }

    If $IsObject(gameState) {
        Set gamePlayer = ..GetPlayerFromGameState(gameState, playerId)

        If $IsObject(gamePlayer) {
            Set declaredProfile = ..BuildProfileFromPlayerDeclaration(playerId, gamePlayer)
            If $IsObject(declaredProfile) {
                Return declaredProfile
            }
        }
    }

    Return ..GetDefaultProfile(playerId)
}

ClassMethod GetProfileForGameState(gameState As %DynamicObject, playerId As %String) As %DynamicObject
{
    Return ..GetProfile(playerId, "", gameState)
}

ClassMethod GetDefaultProfile(playerId As %String) As %DynamicObject
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

ClassMethod BuildProfileFromPlayerDeclaration(playerId As %String, player As %DynamicObject) As %DynamicObject
{
    If '$IsObject(player) {
        Return ""
    }

    Set declared = ""
    Set rawProfile = player.%Get("profile", "")

    If $IsObject(rawProfile) {
        Set declared = rawProfile.%Get("style", "")
        If declared = "" {
            Set declared = rawProfile.%Get("profileId", "")
        }
        If declared = "" {
            Set declared = rawProfile.%Get("id", "")
        }
        If declared = "" {
            Set declared = rawProfile.%Get("name", "")
        }
    } ElseIf rawProfile '= "" {
        Set declared = rawProfile
    }

    If declared = "" {
        Set declared = player.%Get("agentProfile", "")
    }

    If declared = "" {
        Set declared = player.%Get("profileId", "")
    }

    If declared = "" {
        Set declared = player.%Get("style", "")
    }

    If declared = "" {
        Set declared = player.%Get("personality", "")
    }

    Set normalized = ..NormalizeProfileId(declared)

    If normalized = "" {
        If $IsObject(rawProfile) {
            Set normalized = ..NormalizeProfileId(rawProfile.%Get("agentProfile", ""))
        }
    }

    If normalized = "" {
        Return ""
    }

    Set profile = ..BuildProfileById(playerId, normalized)
    Do profile.%Set("declaredProfile", declared)
    Do profile.%Set("profileId", normalized)
    Do profile.%Set("id", normalized)

    Set playerName = player.%Get("name", player.%Get("displayName", ""))
    If playerName '= "" {
        Do profile.%Set("playerName", playerName)
    }

    If $IsObject(rawProfile) {
        Do ..ApplyProfileOverrides(.profile, rawProfile)
    }

    Return profile
}

ClassMethod BuildProfileById(playerId As %String, profileId As %String) As %DynamicObject
{
    Set normalized = ..NormalizeProfileId(profileId)

    If normalized = "conservative" {
        Return ..Conservative(playerId)
    }

    If normalized = "aggressive" {
        Return ..Aggressive(playerId)
    }

    If normalized = "bluffer" {
        Return ..Bluffer(playerId)
    }

    If normalized = "balanced" {
        Return ..Balanced(playerId)
    }

    Return ..Balanced(playerId)
}

ClassMethod NormalizeProfileId(value As %String) As %String
{
    Set text = $ZCONVERT($ZSTRIP(value, "<>W"), "L")
    Set text = $Replace(text, "á", "a")
    Set text = $Replace(text, "é", "e")
    Set text = $Replace(text, "í", "i")
    Set text = $Replace(text, "ó", "o")
    Set text = $Replace(text, "ú", "u")
    Set text = $Replace(text, "_", "")
    Set text = $Replace(text, "-", "")
    Set text = $Replace(text, " ", "")

    If (text = "conservative") || (text = "conservador") || (text = "prudente") {
        Return "conservative"
    }

    If (text = "aggressive") || (text = "agresivo") || (text = "atacante") {
        Return "aggressive"
    }

    If (text = "bluffer") || (text = "farolero") || (text = "farol") || (text = "imprevisible") {
        Return "bluffer"
    }

    If (text = "balanced") || (text = "equilibrado") || (text = "mixto") {
        Return "balanced"
    }

    Return ""
}

ClassMethod ApplyProfileOverrides(ByRef profile As %DynamicObject, declaredProfile As %DynamicObject) As %Status
{
    If '$IsObject(profile) || '$IsObject(declaredProfile) {
        Return $$$OK
    }

    Set keys = [
        "name",
        "description",
        "riskTolerance",
        "bluffFrequency",
        "baseEnvidoAmount",
        "strongHandEnvidoAmount",
        "veryStrongHandEnvidoAmount",
        "ordagoFrequency",
        "instructions"
    ]

    For i=0:1:keys.%Size()-1 {
        Set key = keys.%Get(i)
        If declaredProfile.%IsDefined(key) {
            Do profile.%Set(key, declaredProfile.%Get(key))
        }
    }

    Return $$$OK
}

ClassMethod ApplyDeclaredProfilesToPlayers(players As %DynamicAbstractObject) As %DynamicAbstractObject
{
    If '$IsObject(players) {
        Return players
    }

    Set firstPlayer = players.%Get(0, "")

    If $IsObject(firstPlayer) {
        For i=0:1:players.%Size()-1 {
            Set player = players.%Get(i)
            If $IsObject(player) {
                Set playerId = player.%Get("id", "")
                If playerId = "" {
                    Set playerId = player.%Get("playerId", "")
                }
                Do ..ApplyDeclaredProfileToPlayer(.player, playerId)
                Do players.%Set(i, player)
            }
        }

        Return players
    }

    Set iter = players.%GetIterator()
    While iter.%GetNext(.playerId, .player) {
        If $IsObject(player) {
            If player.%Get("id", "") = "" {
                Do player.%Set("id", playerId)
            }
            Do ..ApplyDeclaredProfileToPlayer(.player, playerId)
            Do players.%Set(playerId, player)
        }
    }

    Return players
}

ClassMethod ApplyDeclaredProfileToPlayer(ByRef player As %DynamicObject, playerId As %String) As %Status
{
    If '$IsObject(player) {
        Return $$$OK
    }

    If playerId = "" {
        Set playerId = player.%Get("id", player.%Get("playerId", ""))
    }

    If playerId = "" {
        Return $$$OK
    }

    Set profile = ..GetProfile(playerId, player)

    If '$IsObject(profile) {
        Return $$$OK
    }

    Do player.%Set("profile", profile)
    Do player.%Set("profileId", profile.%Get("profileId", profile.%Get("style", "")))
    Do player.%Set("agentProfile", profile.%Get("style", ""))

    Return $$$OK
}

ClassMethod GetPlayerFromGameState(gameState As %DynamicObject, playerId As %String) As %DynamicObject
{
    If '$IsObject(gameState) || (playerId = "") {
        Return ""
    }

    Set players = gameState.%Get("players", "")

    If '$IsObject(players) {
        Return ""
    }

    Set firstPlayer = players.%Get(0, "")

    If $IsObject(firstPlayer) {
        For i=0:1:players.%Size()-1 {
            Set player = players.%Get(i)
            If '$IsObject(player) {
                Continue
            }

            Set candidateId = player.%Get("id", player.%Get("playerId", ""))
            If candidateId = playerId {
                Return player
            }
        }

        Return ""
    }

    Set player = players.%Get(playerId, "")
    If $IsObject(player) {
        Return player
    }

    Return ""
}

ClassMethod Conservative(playerId As %String) As %DynamicObject
{
    Return {
        "playerId": (playerId),
        "id": "conservative",
        "profileId": "conservative",
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
        "id": "aggressive",
        "profileId": "aggressive",
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
        "id": "bluffer",
        "profileId": "bluffer",
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
        "id": "balanced",
        "profileId": "balanced",
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
        "P1": (..GetDefaultProfile("P1")),
        "P2": (..GetDefaultProfile("P2")),
        "P3": (..GetDefaultProfile("P3")),
        "P4": (..GetDefaultProfile("P4"))
    }
}

}
