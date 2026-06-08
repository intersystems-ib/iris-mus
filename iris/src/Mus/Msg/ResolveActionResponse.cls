Class Mus.Msg.ResolveActionResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Property GameId As %Integer;

Property UpdatedGameStateJson As %String(MAXLEN = "");

Property ActionEventJson As %String(MAXLEN = "");

Property PhaseClosed As %Boolean;

Property PointsAwardedJson As %String(MAXLEN = "");

Property NextPlayerId As %String(MAXLEN = 50);

Storage Default
{
<Data name="ResolveActionResponseDefaultData">
<Subscript>"ResolveActionResponse"</Subscript>
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
<Value>UpdatedGameStateJson</Value>
</Value>
<Value name="7">
<Value>ActionEventJson</Value>
</Value>
<Value name="8">
<Value>PhaseClosed</Value>
</Value>
<Value name="9">
<Value>PointsAwardedJson</Value>
</Value>
<Value name="10">
<Value>NextPlayerId</Value>
</Value>
</Data>
<DefaultData>ResolveActionResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
