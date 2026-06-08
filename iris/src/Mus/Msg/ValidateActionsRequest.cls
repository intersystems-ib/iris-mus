Class Mus.Msg.ValidateActionRequest Extends Ens.Request
{

Property GameId As %Integer;

Property GameStateJson As %String(MAXLEN = "");

Property PlayerId As %String(MAXLEN = 50);

Property ActionType As %String(MAXLEN = 50);

Property Phase As %String(MAXLEN = 50);

Property Amount As %Integer;

Property PayloadJson As %String(MAXLEN = "");

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="ValidateActionRequestDefaultData">
<Subscript>"ValidateActionRequest"</Subscript>
<Value name="1">
<Value>GameId</Value>
</Value>
<Value name="2">
<Value>GameStateJson</Value>
</Value>
<Value name="3">
<Value>PlayerId</Value>
</Value>
<Value name="4">
<Value>ActionType</Value>
</Value>
<Value name="5">
<Value>Phase</Value>
</Value>
<Value name="6">
<Value>Amount</Value>
</Value>
<Value name="7">
<Value>PayloadJson</Value>
</Value>
<Value name="8">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>ValidateActionRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
