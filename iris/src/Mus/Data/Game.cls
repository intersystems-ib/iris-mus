Class Mus.Data.Game Extends %Persistent
{

Property Status As %String(MAXLEN = 50);

Property CreatedAt As %TimeStamp;

Property UpdatedAt As %TimeStamp;

Property CurrentHandId As %Integer;

Property TurnPlayerId As %String(MAXLEN = 50);

Property ScoreTeamA As %Integer;

Property ScoreTeamB As %Integer;

Property StateJson As %String(MAXLEN = "");

Index StatusIdx On Status;

}