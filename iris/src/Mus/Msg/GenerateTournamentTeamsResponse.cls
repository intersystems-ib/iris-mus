Class Mus.Msg.GenerateTournamentTeamsResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Property ResultJson As %String(MAXLEN = "");

Storage Default
{
<Data name="GenerateTournamentTeamsResponseDefaultData">
<Subscript>"GenerateTournamentTeamsResponse"</Subscript>
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
<Value>ResultJson</Value>
</Value>
</Data>
<DefaultData>GenerateTournamentTeamsResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
