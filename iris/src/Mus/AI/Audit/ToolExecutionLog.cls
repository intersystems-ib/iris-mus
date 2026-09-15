Class Mus.AI.Audit.ToolExecutionLog Extends %Persistent
{

Property Timestamp As %TimeStamp;

Property ToolCallId As %String(MAXLEN = 128);

Property ToolName As %String(MAXLEN = 256);

Property Arguments As %String(MAXLEN = "");

Property Success As %Boolean;

Property DurationMs As %Integer;

Property ResultSize As %Integer;

Property ResultPreview As %String(MAXLEN = 2000);

Property Error As %String(MAXLEN = "");

Property MetadataJson As %String(MAXLEN = "");

Index TimestampIndex On Timestamp;

Index ToolNameIndex On ToolName;

Index SuccessIndex On Success;

Storage Default
{
<Data name="ToolExecutionLogDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Timestamp</Value>
</Value>
<Value name="3">
<Value>ToolCallId</Value>
</Value>
<Value name="4">
<Value>ToolName</Value>
</Value>
<Value name="5">
<Value>Arguments</Value>
</Value>
<Value name="6">
<Value>Success</Value>
</Value>
<Value name="7">
<Value>DurationMs</Value>
</Value>
<Value name="8">
<Value>ResultSize</Value>
</Value>
<Value name="9">
<Value>ResultPreview</Value>
</Value>
<Value name="10">
<Value>Error</Value>
</Value>
<Value name="11">
<Value>MetadataJson</Value>
</Value>
</Data>
<DataLocation>^Mus.AI.Audit.ToolExecutionLogD</DataLocation>
<DefaultData>ToolExecutionLogDefaultData</DefaultData>
<IdLocation>^Mus.AI.Audit.ToolExecutionLogD</IdLocation>
<IndexLocation>^Mus.AI.Audit.ToolExecutionLogI</IndexLocation>
<StreamLocation>^Mus.AI.Audit.ToolExecutionLogS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
