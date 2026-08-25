Class Mus.BP.AgentDecisionProcess Extends Ens.BusinessProcess
{

Property TargetOperation As %String [ InitialExpression = "Mus.BO.AgentDecisionOperation" ];

Method OnRequest(pRequest As Mus.Msg.AgentDecisionRequest, Output pResponse As Mus.Msg.AgentDecisionResponse) As %Status
{
    Try {
        If '$IsObject(pRequest) { Return $$$ERROR($$$GeneralError, "Invalid AgentDecisionRequest") }
        Set sc = ..SendRequestSync(..TargetOperation, pRequest, .pResponse)
        If $$$ISERR(sc) { Return sc }
        Return $$$OK
    } Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

Storage Default
{
<Data name="AgentDecisionProcessDefaultData">
<Subscript>"AgentDecisionProcess"</Subscript>
<Value name="1">
<Value>TargetOperation</Value>
</Value>
</Data>
<DefaultData>AgentDecisionProcessDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
