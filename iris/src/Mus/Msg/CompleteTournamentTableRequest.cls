Class Mus.Msg.CompleteTournamentTableRequest Extends Ens.Request
{

Property TableId As %Integer;

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="CompleteTournamentTableRequestDefaultData">
<Subscript>"CompleteTournamentTableRequest"</Subscript>
<Value name="1">
<Value>TableId</Value>
</Value>
<Value name="2">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>CompleteTournamentTableRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
