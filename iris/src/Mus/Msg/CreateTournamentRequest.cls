Class Mus.Msg.CreateTournamentRequest Extends Ens.Request
{

Property Name As %String(MAXLEN = 200);

Property Format As %String(MAXLEN = 50);

Property TargetScore As %Integer;

Property PayloadJson As %String(MAXLEN = "");

Property CorrelationId As %String(MAXLEN = 100);

Storage Default
{
<Data name="CreateTournamentRequestDefaultData">
<Subscript>"CreateTournamentRequest"</Subscript>
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>Format</Value>
</Value>
<Value name="3">
<Value>TargetScore</Value>
</Value>
<Value name="4">
<Value>PayloadJson</Value>
</Value>
<Value name="5">
<Value>CorrelationId</Value>
</Value>
</Data>
<DefaultData>CreateTournamentRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
