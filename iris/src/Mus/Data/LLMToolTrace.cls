Class Mus.Data.LLMToolTrace Extends %Persistent
{

Property LLMTraceId As %Integer;

Property CorrelationId As %String(MAXLEN = 100);

Property GameId As %Integer;

Property TournamentId As %Integer;

Property TableId As %Integer;

Property PlayerId As %String(MAXLEN = 50);

Property Phase As %String(MAXLEN = 50);

Property ToolName As %String(MAXLEN = 200);

Property Status As %String(MAXLEN = 50);

Property StartedAt As %TimeStamp;

Property FinishedAt As %TimeStamp;

Property DurationMs As %Integer;

Property ArgumentsJson As %String(MAXLEN = "");

Property ResultJson As %String(MAXLEN = "");

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Index LLMTraceIndex On LLMTraceId;

Index CorrelationIndex On CorrelationId;

Index GameIndex On GameId;

Index ToolIndex On ToolName;

Storage Default
{
<Data name="LLMToolTraceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>LLMTraceId</Value>
</Value>
<Value name="3">
<Value>CorrelationId</Value>
</Value>
<Value name="4">
<Value>GameId</Value>
</Value>
<Value name="5">
<Value>TournamentId</Value>
</Value>
<Value name="6">
<Value>TableId</Value>
</Value>
<Value name="7">
<Value>PlayerId</Value>
</Value>
<Value name="8">
<Value>Phase</Value>
</Value>
<Value name="9">
<Value>ToolName</Value>
</Value>
<Value name="10">
<Value>Status</Value>
</Value>
<Value name="11">
<Value>StartedAt</Value>
</Value>
<Value name="12">
<Value>FinishedAt</Value>
</Value>
<Value name="13">
<Value>DurationMs</Value>
</Value>
<Value name="14">
<Value>ArgumentsJson</Value>
</Value>
<Value name="15">
<Value>ResultJson</Value>
</Value>
<Value name="16">
<Value>ErrorCode</Value>
</Value>
<Value name="17">
<Value>ErrorMessage</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.LLMToolTraceD</DataLocation>
<DefaultData>LLMToolTraceDefaultData</DefaultData>
<IdLocation>^Mus.Data.LLMToolTraceD</IdLocation>
<IndexLocation>^Mus.Data.LLMToolTraceI</IndexLocation>
<StreamLocation>^Mus.Data.LLMToolTraceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
