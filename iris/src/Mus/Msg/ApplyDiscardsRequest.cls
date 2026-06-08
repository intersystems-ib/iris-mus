Class Mus.Msg.ApplyDiscardsRequest Extends Ens.Request
{

Property GameId As %Integer;

Property DiscardsJson As %String(MAXLEN = "");

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="ApplyDiscardsRequestDefaultData">
<Subscript>"ApplyDiscardsRequest"</Subscript>
<Value name="1">
<Value>GameId</Value>
</Value>
<Value name="2">
<Value>DiscardsJson</Value>
</Value>
<Value name="3">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>ApplyDiscardsRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
