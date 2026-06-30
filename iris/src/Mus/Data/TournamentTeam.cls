Class Mus.Data.TournamentTeam Extends %Persistent
{

Property TournamentId As %Integer;

Property Name As %String(MAXLEN = 200);

Property Status As %String(MAXLEN = 50);

// active | eliminated | winner

Property Seed As %Integer;

Property CreatedAt As %TimeStamp;

Index TournamentIndex On TournamentId;

Index TournamentSeedIndex On (TournamentId, Seed) [ Unique ];

Storage Default
{
<Data name="TournamentTeamDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TournamentId</Value>
</Value>
<Value name="3">
<Value>Name</Value>
</Value>
<Value name="4">
<Value>Status</Value>
</Value>
<Value name="5">
<Value>Seed</Value>
</Value>
<Value name="6">
<Value>CreatedAt</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.TournamentTeamD</DataLocation>
<DefaultData>TournamentTeamDefaultData</DefaultData>
<IdLocation>^Mus.Data.TournamentTeamD</IdLocation>
<IndexLocation>^Mus.Data.TournamentTeamI</IndexLocation>
<StreamLocation>^Mus.Data.TournamentTeamS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
