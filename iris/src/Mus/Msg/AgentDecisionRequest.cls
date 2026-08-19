Class Mus.Msg.AgentDecisionRequest Extends Ens.Request
{

Property RequestType As %String;

// action | discard

Property GameId As %Integer;

Property PlayerId As %String;

Property GameStateJson As %String(MAXLEN = "");

Property CorrelationId As %String;

Property Source As %String;

Property CreatedAt As %TimeStamp;

Storage Default
{
<Data name="AgentDecisionRequestDefaultData">
<Subscript>"AgentDecisionRequest"</Subscript>
<Value name="1">
<Value>RequestType</Value>
</Value>
<Value name="2">
<Value>GameId</Value>
</Value>
<Value name="3">
<Value>PlayerId</Value>
</Value>
<Value name="4">
<Value>GameStateJson</Value>
</Value>
<Value name="5">
<Value>CorrelationId</Value>
</Value>
<Value name="6">
<Value>Source</Value>
</Value>
<Value name="7">
<Value>CreatedAt</Value>
</Value>
</Data>
<DefaultData>AgentDecisionRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
