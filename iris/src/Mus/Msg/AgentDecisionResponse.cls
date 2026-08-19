Class Mus.Msg.AgentDecisionResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String;

Property ErrorMessage As %String(MAXLEN = "");

Property RequestType As %String;

Property GameId As %Integer;

Property PlayerId As %String;

Property Phase As %String;

Property TurnPlayerId As %String;

Property GameStateJson As %String(MAXLEN = "");

Property RecommendationJson As %String(MAXLEN = "");

Property CorrelationId As %String;

Storage Default
{
<Data name="AgentDecisionResponseDefaultData">
<Subscript>"AgentDecisionResponse"</Subscript>
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
<Value>RequestType</Value>
</Value>
<Value name="6">
<Value>GameId</Value>
</Value>
<Value name="7">
<Value>PlayerId</Value>
</Value>
<Value name="8">
<Value>Phase</Value>
</Value>
<Value name="9">
<Value>TurnPlayerId</Value>
</Value>
<Value name="10">
<Value>GameStateJson</Value>
</Value>
<Value name="11">
<Value>RecommendationJson</Value>
</Value>
<Value name="12">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>AgentDecisionResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
