Class Mus.Data.TournamentTableSeat Extends %Persistent
{

Property TournamentId As %Integer;

Property TableId As %Integer;

Property TeamId As %Integer;

Property Seat As %String(MAXLEN = 10);

// P1..P4

Property GamePlayerId As %String(MAXLEN = 50);

// P1..P4

Property DisplayName As %String(MAXLEN = 200);

Property PlayerType As %String(MAXLEN = 50);

// human | agent

Property AgentProfile As %String(MAXLEN = 50);

Property CreatedAt As %TimeStamp;

Index TableIndex On TableId;

Index TableSeatIndex On (TableId, Seat) [ Unique ];

Storage Default
{
<Data name="TournamentTableSeatDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TournamentId</Value>
</Value>
<Value name="3">
<Value>TableId</Value>
</Value>
<Value name="4">
<Value>TeamId</Value>
</Value>
<Value name="5">
<Value>Seat</Value>
</Value>
<Value name="6">
<Value>GamePlayerId</Value>
</Value>
<Value name="7">
<Value>DisplayName</Value>
</Value>
<Value name="8">
<Value>PlayerType</Value>
</Value>
<Value name="9">
<Value>AgentProfile</Value>
</Value>
<Value name="10">
<Value>CreatedAt</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.TournamentTableSeatD</DataLocation>
<DefaultData>TournamentTableSeatDefaultData</DefaultData>
<IdLocation>^Mus.Data.TournamentTableSeatD</IdLocation>
<IndexLocation>^Mus.Data.TournamentTableSeatI</IndexLocation>
<StreamLocation>^Mus.Data.TournamentTableSeatS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
