Class Mus.Data.Tournament Extends %Persistent
{

Property Name As %String(MAXLEN = 200);

Property Status As %String(MAXLEN = 50);

Property Format As %String(MAXLEN = 50);

Property TargetScore As %Integer;

Property CreatedAt As %TimeStamp;

Property StartedAt As %TimeStamp;

Property FinishedAt As %TimeStamp;

Index StatusIndex On Status;

Storage Default
{
<Data name="TournamentDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Status</Value>
</Value>
<Value name="4">
<Value>Format</Value>
</Value>
<Value name="5">
<Value>TargetScore</Value>
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
<DataLocation>^Mus.Data.TournamentD</DataLocation>
<DefaultData>TournamentDefaultData</DefaultData>
<IdLocation>^Mus.Data.TournamentD</IdLocation>
<IndexLocation>^Mus.Data.TournamentI</IndexLocation>
<StreamLocation>^Mus.Data.TournamentS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
