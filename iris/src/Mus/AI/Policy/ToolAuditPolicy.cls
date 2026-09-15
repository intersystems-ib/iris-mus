Include %AI

Class Mus.AI.Policy.ToolAuditPolicy Extends %AI.Policy.Audit
{

Method %LogExecution(call As %DynamicObject, metadata As %DynamicObject, result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
    Try {
        Set log = ##class(Mus.AI.Audit.ToolExecutionLog).%New()

        Set log.Timestamp = $ZDATETIME($HOROLOG, 3)

        Set log.ToolCallId = call.%Get("id", "")
        Set log.ToolName = call.%Get("name", "")

        Set args = call.%Get("arguments", "")
        If $IsObject(args) {
            Set log.Arguments = args.%ToJSON()
        } Else {
            Set log.Arguments = args
        }

        If $IsObject(metadata) {
            Set log.MetadataJson = metadata.%ToJSON()
        }

        Set log.Success = $$$ISOK(status)
        Set log.DurationMs = duration

        /*
          result puede ser null si la tool falla.
        */
        If $IsObject(result) {
            Set resultJson = result.%ToJSON()
            Set log.ResultSize = $Length(resultJson)

            If $$$ISOK(status) {
                Set log.ResultPreview = $Extract(resultJson, 1, 2000)
            }
        } Else {
            Set log.ResultSize = 0
            Set log.ResultPreview = ""
        }

        If $$$ISERR(status) {
            Set log.Error = $SYSTEM.Status.GetErrorText(status)
        }

        Set saveStatus = log.%Save()

        /*
          No propagamos un fallo del sistema de auditoria
          hacia la ejecucion normal de la tool.
        */
        Return $$$OK

    } Catch ex {
        Return $$$OK
    }
}

}
