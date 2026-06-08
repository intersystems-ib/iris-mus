Class Mus.Msg.PersistResolvedActionRequest Extends Ens.Request
{

Property GameId As %Integer;

Property PlayerId As %String(MAXLEN = 50);

Property ActionType As %String(MAXLEN = 50);

Property Phase As %String(MAXLEN = 50);

Property Amount As %Integer;

Property PayloadJson As %String(MAXLEN = "");

Property ActionEventJson As %String(MAXLEN = "");

Property UpdatedGameStateJson As %String(MAXLEN = "");

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="PersistResolvedActionRequestDefaultData">
<Subscript>"PersistResolvedActionRequest"</Subscript>
<Value name="1">
<Value>GameId</Value>
</Value>
<Value name="2">
<Value>PlayerId</Value>
</Value>
<Value name="3">
<Value>ActionType</Value>
</Value>
<Value name="4">
<Value>Phase</Value>
</Value>
<Value name="5">
<Value>Amount</Value>
</Value>
<Value name="6">
<Value>PayloadJson</Value>
</Value>
<Value name="7">
<Value>ActionEventJson</Value>
</Value>
<Value name="8">
<Value>UpdatedGameStateJson</Value>
</Value>
<Value name="9">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>PersistResolvedActionRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
