Class Mus.Msg.ValidateActionResponse Extends Ens.Response
{

Property Success As %Boolean;

Property IsLegal As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Property LegalActionsJson As %String(MAXLEN = "");

Storage Default
{
<Data name="ValidateActionResponseDefaultData">
<Subscript>"ValidateActionResponse"</Subscript>
<Value name="1">
<Value>Success</Value>
</Value>
<Value name="2">
<Value>IsLegal</Value>
</Value>
<Value name="3">
<Value>StatusCode</Value>
</Value>
<Value name="4">
<Value>ErrorCode</Value>
</Value>
<Value name="5">
<Value>ErrorMessage</Value>
</Value>
<Value name="6">
<Value>LegalActionsJson</Value>
</Value>
</Data>
<DefaultData>ValidateActionResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
