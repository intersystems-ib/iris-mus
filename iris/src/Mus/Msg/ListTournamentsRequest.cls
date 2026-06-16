Class Mus.Msg.ListTournamentsRequest Extends Ens.Request
{

Property Status As %String(MAXLEN = 50);

Property Limit As %Integer;

Property Offset As %Integer;

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="ListTournamentsRequestDefaultData">
<Subscript>"ListTournamentsRequest"</Subscript>
<Value name="1">
<Value>Status</Value>
</Value>
<Value name="2">
<Value>Limit</Value>
</Value>
<Value name="3">
<Value>Offset</Value>
</Value>
<Value name="4">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>ListTournamentsRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
