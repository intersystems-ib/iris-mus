Class Mus.Msg.GenerateTournamentTeamsRequest Extends Ens.Request
{

Property TeamCount As %Integer;

Property TargetScore As %Integer;

Property HumanPlayerName As %String(MAXLEN = 200);

Property PayloadJson As %String(MAXLEN = "");

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="GenerateTournamentTeamsRequestDefaultData">
<Subscript>"GenerateTournamentTeamsRequest"</Subscript>
<Value name="1">
<Value>TeamCount</Value>
</Value>
<Value name="2">
<Value>TargetScore</Value>
</Value>
<Value name="3">
<Value>HumanPlayerName</Value>
</Value>
<Value name="4">
<Value>PayloadJson</Value>
</Value>
<Value name="5">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>GenerateTournamentTeamsRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
