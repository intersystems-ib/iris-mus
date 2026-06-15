Class Mus.Msg.GetTournamentRequest Extends Ens.Request
{

Property TournamentId As %Integer;

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="GetTournamentRequestDefaultData">
<Subscript>"GetTournamentRequest"</Subscript>
<Value name="1">
<Value>TournamentId</Value>
</Value>
<Value name="2">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>GetTournamentRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
