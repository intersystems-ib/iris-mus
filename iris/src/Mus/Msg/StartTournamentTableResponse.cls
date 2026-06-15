Class Mus.Msg.StartTournamentTableResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Property TournamentId As %Integer;

Property TableId As %Integer;

Property GameId As %Integer;

Property TableJson As %String(MAXLEN = "");

Storage Default
{
<Data name="StartTournamentTableResponseDefaultData">
<Subscript>"StartTournamentTableResponse"</Subscript>
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
<Value>TableId</Value>
</Value>
<Value name="7">
<Value>GameId</Value>
</Value>
<Value name="8">
<Value>TableJson</Value>
</Value>
</Data>
<DefaultData>StartTournamentTableResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
