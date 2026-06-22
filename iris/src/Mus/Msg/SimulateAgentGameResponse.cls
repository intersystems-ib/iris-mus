Class Mus.Msg.SimulateAgentGameResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String;

Property ErrorMessage As %String;

Property GameId As %Integer;

Property WinnerTeam As %String;

Property SimulationJson As %String(MAXLEN = "");

Property FinalGameStateJson As %String(MAXLEN = "");

Storage Default
{
<Data name="SimulateAgentGameResponseDefaultData">
<Subscript>"SimulateAgentGameResponse"</Subscript>
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
<Value>GameId</Value>
</Value>
<Value name="6">
<Value>WinnerTeam</Value>
</Value>
<Value name="7">
<Value>SimulationJson</Value>
</Value>
<Value name="8">
<Value>FinalGameStateJson</Value>
</Value>
</Data>
<DefaultData>SimulateAgentGameResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
