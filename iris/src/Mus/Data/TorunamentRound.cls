Class Mus.Data.TournamentRound Extends %Persistent
{

Property TournamentId As %Integer;

Property RoundNumber As %Integer;

Property Name As %String(MAXLEN = 100);

Property Status As %String(MAXLEN = 50);

// created | playing | finished

Property CreatedAt As %TimeStamp;

Property StartedAt As %TimeStamp;

Property FinishedAt As %TimeStamp;

Index TournamentRoundIndex On (TournamentId, RoundNumber) [ Unique ];

Storage Default
{
<Data name="TournamentRoundDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TournamentId</Value>
</Value>
<Value name="3">
<Value>RoundNumber</Value>
</Value>
<Value name="4">
<Value>Name</Value>
</Value>
<Value name="5">
<Value>Status</Value>
</Value>
<Value name="6">
<Value>CreatedAt</Value>
</Value>
<Value name="7">
<Value>StartedAt</Value>
</Value>
<Value name="8">
<Value>FinishedAt</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.TournamentRoundD</DataLocation>
<DefaultData>TournamentRoundDefaultData</DefaultData>
<IdLocation>^Mus.Data.TournamentRoundD</IdLocation>
<IndexLocation>^Mus.Data.TournamentRoundI</IndexLocation>
<StreamLocation>^Mus.Data.TournamentRoundS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
