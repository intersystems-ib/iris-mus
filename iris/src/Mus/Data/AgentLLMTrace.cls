Class Mus.Data.AgentLLMTrace Extends %Persistent
{

Property CreatedAt As %TimeStamp;

Property EventType As %String(MAXLEN = 80);

Property Backend As %String(MAXLEN = 40);

Property GameId As %String(MAXLEN = 80);

Property PlayerId As %String(MAXLEN = 40);

Property Phase As %String(MAXLEN = 40);

Property TurnPlayerId As %String(MAXLEN = 40);

Property ProfileId As %String(MAXLEN = 80);

Property Success As %Boolean;

Property ErrorText As %String(MAXLEN = 1000);

Property RawModelOutput As %Stream.GlobalCharacter;

Property ParsedRecommendationJson As %Stream.GlobalCharacter;

Property NormalizedRecommendationJson As %Stream.GlobalCharacter;

Property FallbackJson As %Stream.GlobalCharacter;

Property LegalActionsJson As %Stream.GlobalCharacter;

Property ContextJson As %Stream.GlobalCharacter;

Property SystemPrompt As %Stream.GlobalCharacter;

Property UserPrompt As %Stream.GlobalCharacter;

Index CreatedAtIdx On CreatedAt;

Index GamePlayerIdx On (GameId, PlayerId, CreatedAt);

Index EventTypeIdx On EventType;

ClassMethod Log(eventType As %String, context As %DynamicObject = "", rawModelOutput As %String = "", parsedRecommendation As %DynamicObject = "", normalizedRecommendation As %DynamicObject = "", fallbackRecommendation As %DynamicObject = "", legalActions As %DynamicArray = "", errorText As %String = "", systemPrompt As %String = "", userPrompt As %String = "") As %Integer
{
    Try {
        Set trace = ..%New()
        Set trace.CreatedAt = $ZDATETIME($HOROLOG, 3, 1, 3)
        Set trace.EventType = $Extract(eventType, 1, 80)
        Set trace.Backend = $Extract(##class(Mus.AI.Provider).GetBackend(), 1, 40)
        Set trace.Success = $Select(errorText="":1, 1:0)
        Set trace.ErrorText = $Extract(errorText, 1, 1000)

        If $IsObject(context) {
            Set trace.GameId = $Extract(..GetContextValue(context, "gameId"), 1, 80)
            Set trace.PlayerId = $Extract(..GetContextValue(context, "playerId"), 1, 40)
            Set trace.Phase = $Extract(..GetContextValue(context, "phase"), 1, 40)
            Set trace.TurnPlayerId = $Extract(..GetContextValue(context, "turnPlayerId"), 1, 40)

            Set profile = context.%Get("profile", "")
            If $IsObject(profile) {
                Set trace.ProfileId = $Extract(profile.%Get("id", profile.%Get("style", "")), 1, 80)
            }

            Do ..WriteStream(trace.ContextJson, context.%ToJSON())
        }

        If '$IsObject(legalActions), $IsObject(context) {
            Set legalActions = context.%Get("legalActions", "")
        }
        If $IsObject(legalActions) {
            Do ..WriteStream(trace.LegalActionsJson, legalActions.%ToJSON())
        }

        Do ..WriteStream(trace.RawModelOutput, rawModelOutput)
        If $IsObject(parsedRecommendation) {
            Do ..WriteStream(trace.ParsedRecommendationJson, parsedRecommendation.%ToJSON())
        }
        If $IsObject(normalizedRecommendation) {
            Do ..WriteStream(trace.NormalizedRecommendationJson, normalizedRecommendation.%ToJSON())
        }
        If $IsObject(fallbackRecommendation) {
            Do ..WriteStream(trace.FallbackJson, fallbackRecommendation.%ToJSON())
        }
        Do ..WriteStream(trace.SystemPrompt, systemPrompt)
        Do ..WriteStream(trace.UserPrompt, userPrompt)

        Set sc = trace.%Save()
        If $$$ISERR(sc) {
            Return 0
        }

        Return trace.%Id()
    } Catch ex {
        Return 0
    }
}

ClassMethod GetContextValue(context As %DynamicObject, key As %String) As %String
{
    If '$IsObject(context) { Return "" }
    Set value = context.%Get(key, "")
    If value '= "" { Return value }

    Set gameState = context.%Get("gameState", "")
    If $IsObject(gameState) {
        Set value = gameState.%Get(key, "")
        If value '= "" { Return value }
    }

    Set hand = context.%Get("hand", "")
    If $IsObject(hand), key="phase" {
        Set value = hand.%Get("phase", "")
        If value '= "" { Return value }
    }

    Return ""
}

ClassMethod WriteStream(ByRef stream As %Stream.GlobalCharacter, value As %String)
{
    Set stream = ##class(%Stream.GlobalCharacter).%New()
    If value '= "" {
        Do stream.Write(value)
        Do stream.Rewind()
    }
}

ClassMethod ReadStream(stream As %Stream.GlobalCharacter) As %String
{
    If '$IsObject(stream) { Return "" }
    Do stream.Rewind()
    Return stream.Read(3200000)
}

ClassMethod ReadRawModelOutput(id As %Integer) As %String
{
    Set trace = ..%OpenId(id)
    If '$IsObject(trace) { Return "" }
    Return ..ReadStream(trace.RawModelOutput)
}

Query Recent(limit As %Integer = 100) As %SQLQuery
{
    SELECT TOP :limit
        ID,
        CreatedAt,
        EventType,
        Backend,
        GameId,
        PlayerId,
        Phase,
        TurnPlayerId,
        ProfileId,
        Success,
        ErrorText
    FROM Mus_Data.AgentLLMTrace
    ORDER BY CreatedAt DESC
}

Storage Default
{
<Data name="AgentLLMTraceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CreatedAt</Value>
</Value>
<Value name="3">
<Value>EventType</Value>
</Value>
<Value name="4">
<Value>Backend</Value>
</Value>
<Value name="5">
<Value>GameId</Value>
</Value>
<Value name="6">
<Value>PlayerId</Value>
</Value>
<Value name="7">
<Value>Phase</Value>
</Value>
<Value name="8">
<Value>TurnPlayerId</Value>
</Value>
<Value name="9">
<Value>ProfileId</Value>
</Value>
<Value name="10">
<Value>Success</Value>
</Value>
<Value name="11">
<Value>ErrorText</Value>
</Value>
<Value name="12">
<Value>RawModelOutput</Value>
</Value>
<Value name="13">
<Value>ParsedRecommendationJson</Value>
</Value>
<Value name="14">
<Value>NormalizedRecommendationJson</Value>
</Value>
<Value name="15">
<Value>FallbackJson</Value>
</Value>
<Value name="16">
<Value>LegalActionsJson</Value>
</Value>
<Value name="17">
<Value>ContextJson</Value>
</Value>
<Value name="18">
<Value>SystemPrompt</Value>
</Value>
<Value name="19">
<Value>UserPrompt</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.AgentLLMTraceD</DataLocation>
<DefaultData>AgentLLMTraceDefaultData</DefaultData>
<IdLocation>^Mus.Data.AgentLLMTraceD</IdLocation>
<IndexLocation>^Mus.Data.AgentLLMTraceI</IndexLocation>
<StreamLocation>^Mus.Data.AgentLLMTraceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
