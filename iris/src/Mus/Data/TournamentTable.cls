Class Mus.Data.TournamentTable Extends %Persistent
{

Property TournamentId As %Integer;

Property RoundId As %Integer;

Property RoundNumber As %Integer;

Property TableNumber As %Integer;

Property Status As %String(MAXLEN = 50);

// created | playing | finished

Property TeamAId As %Integer;

Property TeamBId As %Integer;

Property WinnerTeamId As %Integer;

Property GameId As %Integer;

Property CreatedAt As %TimeStamp;

Property StartedAt As %TimeStamp;

Property FinishedAt As %TimeStamp;

Index TournamentIndex On TournamentId;

Index RoundIndex On RoundId;

Index RoundTableIndex On (TournamentId, RoundNumber, TableNumber) [ Unique ];

Storage Default
{
<Data name="TournamentTableDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TournamentId</Value>
</Value>
<Value name="3">
<Value>RoundId</Value>
</Value>
<Value name="4">
<Value>RoundNumber</Value>
</Value>
<Value name="5">
<Value>TableNumber</Value>
</Value>
<Value name="6">
<Value>Status</Value>
</Value>
<Value name="7">
<Value>TeamAId</Value>
</Value>
<Value name="8">
<Value>TeamBId</Value>
</Value>
<Value name="9">
<Value>WinnerTeamId</Value>
</Value>
<Value name="10">
<Value>GameId</Value>
</Value>
<Value name="11">
<Value>CreatedAt</Value>
</Value>
<Value name="12">
<Value>StartedAt</Value>
</Value>
<Value name="13">
<Value>FinishedAt</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.TournamentTableD</DataLocation>
<DefaultData>TournamentTableDefaultData</DefaultData>
<IdLocation>^Mus.Data.TournamentTableD</IdLocation>
<IndexLocation>^Mus.Data.TournamentTableI</IndexLocation>
<StreamLocation>^Mus.Data.TournamentTableS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
