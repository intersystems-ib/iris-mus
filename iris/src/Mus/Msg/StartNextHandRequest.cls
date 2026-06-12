Class Mus.Msg.StartNextHandRequest Extends Ens.Request
{

Property GameId As %Integer;

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="StartNextHandRequestDefaultData">
<Subscript>"StartNextHandRequest"</Subscript>
<Value name="1">
<Value>GameId</Value>
</Value>
<Value name="2">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>StartNextHandRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
