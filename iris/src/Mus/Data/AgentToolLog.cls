Class Mus.Data.AgentToolLog Extends %RegisteredObject
{

ClassMethod NowMs() As %BigInt
{
    Set h = $HOROLOG
    Return ($Piece(h, ",", 1) * 86400000) + ($Piece(h, ",", 2) * 1000)
}

ClassMethod ElapsedMs(startMs As %BigInt) As %Integer
{
    Try {
        Set elapsed = ..NowMs() - startMs
        If elapsed < 0 { Return 0 }
        Return elapsed
    } Catch ex {
        Return 0
    }
}

ClassMethod BeginDecision(llmContext As %DynamicObject, playerId As %String) As %String
{
    Set decisionId = $System.Util.CreateGUID()
    Set startedAt = $ZDATETIME($HOROLOG, 3, 1)

    Set ^||MusAgentToolLog("decisionId") = decisionId
    Set ^MusAgentToolLog(decisionId, "startedAt") = startedAt
    Set ^MusAgentToolLog(decisionId, "status") = "running"
    Set ^MusAgentToolLog(decisionId, "playerId") = playerId
    Set ^MusAgentToolLog(decisionId, "toolCount") = 0

    If $IsObject(llmContext) {
        Set gameId = llmContext.%Get("gameId", "")
        Set phase = llmContext.%Get("phase", "")
        Set ^MusAgentToolLog(decisionId, "gameId") = gameId
        Set ^MusAgentToolLog(decisionId, "phase") = phase
        Set ^MusAgentToolLog(decisionId, "context") = $Extract(llmContext.%ToJSON(), 1, 8000)

        If gameId '= "" {
            Set idx = $Increment(^MusAgentToolLog("game", gameId))
            Set ^MusAgentToolLog("game", gameId, idx) = decisionId
        }
    }

    Set recent = $Increment(^MusAgentToolLog("recent"))
    Set ^MusAgentToolLog("recent", recent) = decisionId

    Return decisionId
}

ClassMethod EndDecision(decisionId As %String, status As %String = "ok", rawResponse As %String = "", errorMessage As %String = "") As %Status
{
    If decisionId = "" {
        Set decisionId = $Get(^||MusAgentToolLog("decisionId"))
    }

    If decisionId '= "" {
        Set ^MusAgentToolLog(decisionId, "endedAt") = $ZDATETIME($HOROLOG, 3, 1)
        Set ^MusAgentToolLog(decisionId, "status") = status

        If rawResponse '= "" {
            Set ^MusAgentToolLog(decisionId, "rawResponse") = $Extract(rawResponse, 1, 12000)
        }

        If errorMessage '= "" {
            Set ^MusAgentToolLog(decisionId, "errorMessage") = $Extract(errorMessage, 1, 2000)
        }
    }

    Kill ^||MusAgentToolLog("decisionId")
    Return $$$OK
}

ClassMethod RecordToolCall(toolName As %String, input As %DynamicObject, outputs As %DynamicObject, elapsedMs As %Integer = 0) As %Status
{
    Set decisionId = $Get(^||MusAgentToolLog("decisionId"))

    If decisionId = "" {
        Set decisionId = $System.Util.CreateGUID()
        Set ^MusAgentToolLog(decisionId, "startedAt") = $ZDATETIME($HOROLOG, 3, 1)
        Set ^MusAgentToolLog(decisionId, "status") = "standalone"
        Set ^MusAgentToolLog(decisionId, "toolCount") = 0
        Set recent = $Increment(^MusAgentToolLog("recent"))
        Set ^MusAgentToolLog("recent", recent) = decisionId
    }
    Set idx = $Increment(^MusAgentToolLog(decisionId, "toolCount"))
    Set ^MusAgentToolLog(decisionId, "tools", idx, "name") = toolName
    Set ^MusAgentToolLog(decisionId, "tools", idx, "at") = $ZDATETIME($HOROLOG, 3, 1)
    Set ^MusAgentToolLog(decisionId, "tools", idx, "elapsedMs") = +elapsedMs

    If $IsObject(input) {
        Set ^MusAgentToolLog(decisionId, "tools", idx, "input") = $Extract(input.%ToJSON(), 1, 4000)
    }
    If $IsObject(outputs) {
        Set ^MusAgentToolLog(decisionId, "tools", idx, "output") = $Extract(outputs.%ToJSON(), 1, 4000)
    }
    Return $$$OK
}

ClassMethod FinishToolCall(toolName As %String, input As %DynamicObject, outputs As %DynamicObject, startedAtMs As %BigInt = 0) As %DynamicObject
{
    Set elapsedMs = 0
    If +startedAtMs > 0 {
        Set elapsedMs = ..ElapsedMs(startedAtMs) 
    }
    Do ..RecordToolCall(toolName, input, outputs, elapsedMs)
    Return outputs
}

ClassMethod GetToolCalls(decisionId As %String) As %DynamicArray
{
    Set calls = []
    If decisionId = "" { Return calls }

    Set idx = 0
    For {
        Set idx = $Order(^MusAgentToolLog(decisionId, "tools", idx))
        Quit:idx=""

        Set call = {
            "index": (+idx),
            "name": ($Get(^MusAgentToolLog(decisionId, "tools", idx, "name"))),
            "at": ($Get(^MusAgentToolLog(decisionId, "tools", idx, "at"))),
            "elapsedMs": (+$Get(^MusAgentToolLog(decisionId, "tools", idx, "elapsedMs"), 0))
        }

        Set inputJson = $Get(^MusAgentToolLog(decisionId, "tools", idx, "input"))
        If inputJson '= "" {
            Try { Do call.%Set("input", {}.%FromJSON(inputJson)) } Catch exInput { Do call.%Set("inputRaw", inputJson) }
        }

        Set outputJson = $Get(^MusAgentToolLog(decisionId, "tools", idx, "output"))
        If outputJson '= "" {
            Try { Do call.%Set("output", {}.%FromJSON(outputJson)) } Catch exOutput { Do call.%Set("outputRaw", outputJson) }
        }

        Do calls.%Push(call)
    }

    Return calls
}

ClassMethod GetDecision(decisionId As %String) As %DynamicObject
{
    Set result = {"decisionId": (decisionId), "toolCalls": []}
    If decisionId = "" { Return result }

    Do result.%Set("status", $Get(^MusAgentToolLog(decisionId, "status")))
    Do result.%Set("gameId", $Get(^MusAgentToolLog(decisionId, "gameId")))
    Do result.%Set("playerId", $Get(^MusAgentToolLog(decisionId, "playerId")))
    Do result.%Set("phase", $Get(^MusAgentToolLog(decisionId, "phase")))
    Do result.%Set("startedAt", $Get(^MusAgentToolLog(decisionId, "startedAt")))
    Do result.%Set("endedAt", $Get(^MusAgentToolLog(decisionId, "endedAt")))
    Do result.%Set("toolCalls", ..GetToolCalls(decisionId))

    Set errorMessage = $Get(^MusAgentToolLog(decisionId, "errorMessage"))
    If errorMessage '= "" { Do result.%Set("errorMessage", errorMessage) }

    Return result
}

ClassMethod GetRecent(limit As %Integer = 20) As %DynamicArray
{
    Set result = []
    If limit <= 0 { Set limit = 20 }

    Set idx = $Order(^MusAgentToolLog("recent", ""), -1)
    For count=1:1:limit {
        Quit:idx=""
        Set decisionId = $Get(^MusAgentToolLog("recent", idx))
        If decisionId '= "" {
            Do result.%Push(..GetDecision(decisionId))
        }
        Set idx = $Order(^MusAgentToolLog("recent", idx), -1)
    }

    Return result
}

ClassMethod Reset() As %Status
{
    Kill ^MusAgentToolLog
    Return $$$OK
}

}
