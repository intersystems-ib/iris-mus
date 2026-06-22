Class Mus.Msg.SimulateTournamentTableResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String;

Property ErrorMessage As %String;

Property TournamentId As %Integer;

Property TableId As %Integer;

Property GameId As %Integer;

Property WinnerTeamId As %Integer;

Property WinnerTeam As %String;

Property TableJson As %String(MAXLEN = "");

Property TournamentJson As %String(MAXLEN = "");

Property SimulationJson As %String(MAXLEN = "");

Storage Default
{
<Data name="SimulateTournamentTableResponseDefaultData">
<Subscript>"SimulateTournamentTableResponse"</Subscript>
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
<Value>WinnerTeamId</Value>
</Value>
<Value name="9">
<Value>WinnerTeam</Value>
</Value>
<Value name="10">
<Value>TableJson</Value>
</Value>
<Value name="11">
<Value>TournamentJson</Value>
</Value>
<Value name="12">
<Value>SimulationJson</Value>
</Value>
</Data>
<DefaultData>SimulateTournamentTableResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
