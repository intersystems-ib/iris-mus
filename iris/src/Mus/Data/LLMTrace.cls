Class Mus.Data.LLMTrace Extends %Persistent
{

Property CorrelationId As %String(MAXLEN = 100);

Property GameId As %Integer;

Property TournamentId As %Integer;

Property TableId As %Integer;

Property PlayerId As %String(MAXLEN = 50);

Property Phase As %String(MAXLEN = 50);

Property Provider As %String(MAXLEN = 100);

Property Model As %String(MAXLEN = 200);

Property Backend As %String(MAXLEN = 50);

Property Status As %String(MAXLEN = 50);

Property StartedAt As %TimeStamp;

Property FinishedAt As %TimeStamp;

Property DurationMs As %Integer;

Property RequestJson As %String(MAXLEN = "");

Property ResponseJson As %String(MAXLEN = "");

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Index CorrelationIndex On CorrelationId;

Index GameIndex On GameId;

Index TournamentIndex On TournamentId;

Index PlayerIndex On (GameId, PlayerId, Phase);

Storage Default
{
<Data name="LLMTraceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CorrelationId</Value>
</Value>
<Value name="3">
<Value>GameId</Value>
</Value>
<Value name="4">
<Value>TournamentId</Value>
</Value>
<Value name="5">
<Value>TableId</Value>
</Value>
<Value name="6">
<Value>PlayerId</Value>
</Value>
<Value name="7">
<Value>Phase</Value>
</Value>
<Value name="8">
<Value>Provider</Value>
</Value>
<Value name="9">
<Value>Model</Value>
</Value>
<Value name="10">
<Value>Backend</Value>
</Value>
<Value name="11">
<Value>Status</Value>
</Value>
<Value name="12">
<Value>StartedAt</Value>
</Value>
<Value name="13">
<Value>FinishedAt</Value>
</Value>
<Value name="14">
<Value>DurationMs</Value>
</Value>
<Value name="15">
<Value>RequestJson</Value>
</Value>
<Value name="16">
<Value>ResponseJson</Value>
</Value>
<Value name="17">
<Value>ErrorCode</Value>
</Value>
<Value name="18">
<Value>ErrorMessage</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.LLMTraceD</DataLocation>
<DefaultData>LLMTraceDefaultData</DefaultData>
<IdLocation>^Mus.Data.LLMTraceD</IdLocation>
<IndexLocation>^Mus.Data.LLMTraceI</IndexLocation>
<StreamLocation>^Mus.Data.LLMTraceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
