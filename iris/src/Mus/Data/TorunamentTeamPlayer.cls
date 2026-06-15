Class Mus.Data.TournamentTeamPlayer Extends %Persistent
{

Property TournamentId As %Integer;

Property TeamId As %Integer;

Property PlayerNumber As %Integer;

// 1 | 2

Property DisplayName As %String(MAXLEN = 200);

Property PlayerType As %String(MAXLEN = 50);

// human | agent

Property AgentProfile As %String(MAXLEN = 50);

Index TeamIndex On TeamId;

Index TeamPlayerIndex On (TeamId, PlayerNumber) [ Unique ];

Storage Default
{
<Data name="TournamentTeamPlayerDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TournamentId</Value>
</Value>
<Value name="3">
<Value>TeamId</Value>
</Value>
<Value name="4">
<Value>PlayerNumber</Value>
</Value>
<Value name="5">
<Value>DisplayName</Value>
</Value>
<Value name="6">
<Value>PlayerType</Value>
</Value>
<Value name="7">
<Value>AgentProfile</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.TournamentTeamPlayerD</DataLocation>
<DefaultData>TournamentTeamPlayerDefaultData</DefaultData>
<IdLocation>^Mus.Data.TournamentTeamPlayerD</IdLocation>
<IndexLocation>^Mus.Data.TournamentTeamPlayerI</IndexLocation>
<StreamLocation>^Mus.Data.TournamentTeamPlayerS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
