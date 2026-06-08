Class Mus.Msg.ApplyDiscardsResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Property GameId As %Integer;

Property GameStateJson As %String(MAXLEN = "");

Storage Default
{
<Data name="ApplyDiscardsResponseDefaultData">
<Subscript>"ApplyDiscardsResponse"</Subscript>
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
<Value>GameStateJson</Value>
</Value>
</Data>
<DefaultData>ApplyDiscardsResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
