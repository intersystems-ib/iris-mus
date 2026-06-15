Class Mus.Msg.PersistTournamentResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Property TournamentId As %Integer;

Property TournamentJson As %String(MAXLEN = "");

Storage Default
{
<Data name="PersistTournamentResponseDefaultData">
<Subscript>"PersistTournamentResponse"</Subscript>
<Value name="1">
<Value>Success</Value>
</Value>
<Value name="2">
<Value>StatusCode</Value>
</Value>
<Value name="3">
<Value>ErrorCode</Value>
</Value>
<Value name="4">
<Value>ErrorMessage</Value>
</Value>
<Value name="5">
<Value>TournamentId</Value>
</Value>
<Value name="6">
<Value>TournamentJson</Value>
</Value>
</Data>
<DefaultData>PersistTournamentResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
