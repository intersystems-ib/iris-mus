Class Mus.AI.Tools.GameTools Extends %RegisteredObject
{

Parameter REQUIRESAUTH = 0;

Parameter DISCOVERYLIMIT = 20;

/// Devuelve el contexto visible para un jugador.
ClassMethod GetPlayerContext(gameStateJson As %String, playerId As %String) As %DynamicObject
{
    Set result = {
        "success": false,
        "errorCode": "",
        "errorMessage": "",
        "context": null
    }

    Try {
        If gameStateJson = "" {
            Do result.%Set("errorCode", "EMPTY_GAME_STATE")
            Do result.%Set("errorMessage", "gameStateJson is empty")
            Return result
        }

        If playerId = "" {
            Do result.%Set("errorCode", "EMPTY_PLAYER_ID")
            Do result.%Set("errorMessage", "playerId is empty")
            Return result
        }

        Set gameState = {}.%FromJSON(gameStateJson)
        Set context = ##class(Mus.Agent.ContextBuilder).BuildForPlayer(gameState, playerId)

        Do result.%Set("success", "true")
        Do result.%Set("context", context)

        Return result
    }
    Catch ex {
        Do result.%Set("errorCode", "GET_PLAYER_CONTEXT_EXCEPTION")
        Do result.%Set("errorMessage", ex.DisplayString())
        Return result
    }
}

/// Devuelve una recomendación determinista/fallback usando nuestras reglas actuales.
/// No llama al LLM y no ejecuta nada.
ClassMethod RecommendFallbackAction(contextJson As %String) As %DynamicObject
{
    Set result = {
        "success": false,
        "errorCode": "",
        "errorMessage": "",
        "recommendation": null
    }

    Try {
        If contextJson = "" {
            Do result.%Set("errorCode", "EMPTY_CONTEXT")
            Do result.%Set("errorMessage", "contextJson is empty")
            Return result
        }

        Set context = {}.%FromJSON(contextJson)
        Set recommendation = ##class(Mus.Agent.Strategy).RecommendFallback(context)

        Do result.%Set("success", "true")
        Do result.%Set("recommendation", recommendation)

        Return result
    }
    Catch ex {
        Do result.%Set("errorCode", "RECOMMEND_FALLBACK_EXCEPTION")
        Do result.%Set("errorMessage", ex.DisplayString())
        Return result
    }
}

/// Valida que una recomendación sea legal para el contexto dado.
ClassMethod ValidateRecommendation(contextJson As %String, recommendationJson As %String) As %DynamicObject
{
    Set result = {
        "success": false,
        "valid": false,
        "errorCode": "",
        "errorMessage": ""
    }

    Try {
        If contextJson = "" {
            Do result.%Set("errorCode", "EMPTY_CONTEXT")
            Do result.%Set("errorMessage", "contextJson is empty")
            Return result
        }

        If recommendationJson = "" {
            Do result.%Set("errorCode", "EMPTY_RECOMMENDATION")
            Do result.%Set("errorMessage", "recommendationJson is empty")
            Return result
        }

        Set context = {}.%FromJSON(contextJson)
        Set recommendation = {}.%FromJSON(recommendationJson)

        Set legalActions = context.%Get("legalActions", "")
        Set valid = ##class(Mus.Agent.PlayerAgent).IsValidRecommendation(
            recommendation,
            legalActions
        )

        Do result.%Set("success", "true")
        Do result.%Set("valid", valid)

        If 'valid {
            Do result.%Set("errorCode", "ILLEGAL_RECOMMENDATION")
            Do result.%Set("errorMessage", "Recommendation is not legal for current context")
        }

        Return result
    }
    Catch ex {
        Do result.%Set("errorCode", "VALIDATE_RECOMMENDATION_EXCEPTION")
        Do result.%Set("errorMessage", ex.DisplayString())
        Return result
    }
}

ClassMethod GetScorePressure(gameStateJson As %String, playerId As %String) As %DynamicObject
{
    Set result = {
        "success": false,
        "errorCode": "",
        "errorMessage": "",
        "scorePressure": null
    }

    Try {
        If gameStateJson = "" {
            Do result.%Set("errorCode", "EMPTY_GAME_STATE")
            Do result.%Set("errorMessage", "gameStateJson is empty")
            Return result
        }

        If playerId = "" {
            Do result.%Set("errorCode", "EMPTY_PLAYER_ID")
            Do result.%Set("errorMessage", "playerId is empty")
            Return result
        }

        Set gameState = {}.%FromJSON(gameStateJson)

        Set pressure = ##class(Mus.Agent.ContextBuilder).BuildScorePressure(
            gameState,
            playerId
        )

        Do result.%Set("success", "true")
        Do result.%Set("scorePressure", pressure)

        Return result
    }
    Catch ex {
        Do result.%Set("errorCode", "GET_SCORE_PRESSURE_EXCEPTION")
        Do result.%Set("errorMessage", ex.DisplayString())
        Return result
    }
}

}
