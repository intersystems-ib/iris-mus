Class Mus.Msg.SimulateTournamentTableRequest Extends Ens.Request
{

Property TableId As %Integer;

Property MaxHands As %Integer;

Property MaxActions As %Integer;

Property CorrelationId As %String;

Storage Default
{
<Data name="SimulateTournamentTableRequestDefaultData">
<Subscript>"SimulateTournamentTableRequest"</Subscript>
<Value name="1">
<Value>TableId</Value>
</Value>
<Value name="2">
<Value>MaxHands</Value>
</Value>
<Value name="3">
<Value>MaxActions</Value>
</Value>
<Value name="4">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>SimulateTournamentTableRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
