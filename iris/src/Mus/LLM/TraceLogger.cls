Class Mus.LLM.TraceLogger Extends %RegisteredObject
{

ClassMethod StartLLMTrace(meta As %DynamicObject, request As %DynamicObject) As %Integer
{
    Set trace = ##class(Mus.Data.LLMTrace).%New()

    Set trace.CorrelationId = meta.%Get("correlationId", "")
    Set trace.GameId = +meta.%Get("gameId", 0)
    Set trace.TournamentId = +meta.%Get("tournamentId", 0)
    Set trace.TableId = +meta.%Get("tableId", 0)
    Set trace.PlayerId = meta.%Get("playerId", "")
    Set trace.Phase = meta.%Get("phase", "")
    Set trace.Provider = meta.%Get("provider", "")
    Set trace.Model = meta.%Get("model", "")
    Set trace.Backend = meta.%Get("backend", "")
    Set trace.Status = "started"
    Set trace.StartedAt = $ZDATETIME($HOROLOG, 3)

    If $IsObject(request) {
        Set trace.RequestJson = request.%ToJSON()
    }

    Set sc = trace.%Save()
    If $$$ISERR(sc) {
        Return 0
    }

    Return trace.%Id()
}

ClassMethod FinishLLMTrace(traceId As %Integer, response As %DynamicObject = "", errorCode As %String = "", errorMessage As %String = "") As %Status
{
    If traceId <= 0 {
        Return $$$OK
    }

    Set trace = ##class(Mus.Data.LLMTrace).%OpenId(traceId)

    If '$IsObject(trace) {
        Return $$$OK
    }

    Set trace.FinishedAt = $ZDATETIME($HOROLOG, 3)
    Set trace.DurationMs = ..DiffMs(trace.StartedAt, trace.FinishedAt)

    If errorCode '= "" {
        Set trace.Status = "error"
        Set trace.ErrorCode = errorCode
        Set trace.ErrorMessage = errorMessage
    } Else {
        Set trace.Status = "success"
    }

    If $IsObject(response) {
        Set trace.ResponseJson = response.%ToJSON()
    }

    Return trace.%Save()
}

ClassMethod LogToolCall(llmTraceId As %Integer, meta As %DynamicObject, toolName As %String, arguments As %DynamicObject, result As %DynamicObject = "", errorCode As %String = "", errorMessage As %String = "") As %Status
{
    Set trace = ##class(Mus.Data.LLMToolTrace).%New()

    Set trace.LLMTraceId = llmTraceId
    Set trace.CorrelationId = meta.%Get("correlationId", "")
    Set trace.GameId = +meta.%Get("gameId", 0)
    Set trace.TournamentId = +meta.%Get("tournamentId", 0)
    Set trace.TableId = +meta.%Get("tableId", 0)
    Set trace.PlayerId = meta.%Get("playerId", "")
    Set trace.Phase = meta.%Get("phase", "")
    Set trace.ToolName = toolName
    Set trace.StartedAt = $ZDATETIME($HOROLOG, 3)
    Set trace.FinishedAt = trace.StartedAt
    Set trace.DurationMs = 0

    If errorCode '= "" {
        Set trace.Status = "error"
        Set trace.ErrorCode = errorCode
        Set trace.ErrorMessage = errorMessage
    } Else {
        Set trace.Status = "success"
    }

    If $IsObject(arguments) {
        Set trace.ArgumentsJson = arguments.%ToJSON()
    }

    If $IsObject(result) {
        Set trace.ResultJson = result.%ToJSON()
    }

    Return trace.%Save()
}

ClassMethod DiffMs(startTs As %String, endTs As %String) As %Integer
{
    /*
      Suficiente para trazas funcionales. Si luego quieres precisión real
      de milisegundos, cambiamos a $ZHOROLOG.
    */
    Set startH = $ZDATETIMEH(startTs, 3)
    Set endH = $ZDATETIMEH(endTs, 3)

    Set seconds = $PIECE(endH, ",", 2) - $PIECE(startH, ",", 2)
    Set days = $PIECE(endH, ",", 1) - $PIECE(startH, ",", 1)

    Return ((days * 86400) + seconds) * 1000
}

}
