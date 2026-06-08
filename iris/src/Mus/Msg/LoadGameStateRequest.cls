Class Mus.Msg.LoadGameStateRequest Extends Ens.Request
{

Property GameId As %Integer;

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="LoadGameStateRequestDefaultData">
<Subscript>"LoadGameStateRequest"</Subscript>
<Value name="1">
<Value>GameId</Value>
</Value>
<Value name="2">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>LoadGameStateRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
