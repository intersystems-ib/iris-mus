Class Mus.Msg.DeleteTournamentRequest Extends Ens.Request
{

Property TournamentId As %Integer;

Property CorrelationId As %String;

Storage Default
{
<Data name="DeleteTournamentRequestDefaultData">
<Subscript>"DeleteTournamentRequest"</Subscript>
<Value name="1">
<Value>TournamentId</Value>
</Value>
<Value name="2">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>DeleteTournamentRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
