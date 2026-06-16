Class Mus.Msg.ListTournamentsResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Property TournamentsJson As %String(MAXLEN = "");

Property Total As %Integer;

Storage Default
{
<Data name="ListTournamentsResponseDefaultData">
<Subscript>"ListTournamentsResponse"</Subscript>
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
<Value>TournamentsJson</Value>
</Value>
<Value name="6">
<Value>Total</Value>
</Value>
</Data>
<DefaultData>ListTournamentsResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
