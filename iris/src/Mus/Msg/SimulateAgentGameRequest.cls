Class Mus.Msg.SimulateAgentGameRequest Extends Ens.Request
{

Property GameId As %Integer;

Property MaxHands As %Integer;

Property MaxActions As %Integer;

Property CorrelationId As %String;

Storage Default
{
<Data name="SimulateAgentGameRequestDefaultData">
<Subscript>"SimulateAgentGameRequest"</Subscript>
<Value name="1">
<Value>GameId</Value>
</Value>
<Value name="2">
<Value>MaxHands</Value>
</Value>
<Value name="3">
<Value>MaxActions</Value>
</Value>
<Value name="4">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>SimulateAgentGameRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
