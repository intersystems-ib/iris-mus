Class Mus.Data.Hand Extends %Persistent
{

Property GameId As %Integer;

Property HandNumber As %Integer;

Property Status As %String(MAXLEN = 50);

Property DealerPlayerId As %String(MAXLEN = 50);

Property TurnPlayerId As %String(MAXLEN = 50);

Property CardsJson As %String(MAXLEN = "");

Property StateJson As %String(MAXLEN = "");

Property CreatedAt As %TimeStamp;

Property UpdatedAt As %TimeStamp;

Index GameIdx On GameId;

}