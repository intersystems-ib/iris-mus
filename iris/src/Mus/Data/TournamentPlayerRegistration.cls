Include %occStatus

Class Mus.Data.TournamentPlayerRegistration Extends %Persistent
{

Property TournamentId As %Integer [ Required ];

Property PlayerName As %String(MAXLEN = 200) [ Required ];

Property Email As %String(MAXLEN = 320) [ Required ];

Property CorrelationId As %String(MAXLEN = 100);

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($HOROLOG,3)} ];

Index TournamentIdIndex On TournamentId;

Index EmailIndex On Email;

ClassMethod Register(tournamentId As %Integer, playerName As %String, email As %String, correlationId As %String = "") As %Status
{
    Set playerName = $ZSTRIP(playerName, "<>W")
    Set email = $ZCONVERT($ZSTRIP(email, "<>W"), "L")

    If tournamentId <= 0 {
        Return $$$ERROR($$$GeneralError, "Invalid tournament id")
    }

    If playerName = "" {
        Return $$$ERROR($$$GeneralError, "Player name is required")
    }

    If email = "" {
        Return $$$ERROR($$$GeneralError, "Player email is required")
    }

    If (email '[ "@") || (email '[ ".") {
        Return $$$ERROR($$$GeneralError, "Invalid player email")
    }

    Set registration = ..%New()
    Set registration.TournamentId = tournamentId
    Set registration.PlayerName = playerName
    Set registration.Email = email
    Set registration.CorrelationId = correlationId
    Set registration.CreatedAt = $ZDATETIME($HOROLOG, 3)

    Return registration.%Save()
}

Storage Default
{
<Data name="TournamentPlayerRegistrationDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TournamentId</Value>
</Value>
<Value name="3">
<Value>PlayerName</Value>
</Value>
<Value name="4">
<Value>Email</Value>
</Value>
<Value name="5">
<Value>CorrelationId</Value>
</Value>
<Value name="6">
<Value>CreatedAt</Value>
</Value>
</Data>
<DataLocation>^Mus.Data.TournamentP5BF3D</DataLocation>
<DefaultData>TournamentPlayerRegistrationDefaultData</DefaultData>
<IdLocation>^Mus.Data.TournamentP5BF3D</IdLocation>
<IndexLocation>^Mus.Data.TournamentP5BF3I</IndexLocation>
<StreamLocation>^Mus.Data.TournamentP5BF3S</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
