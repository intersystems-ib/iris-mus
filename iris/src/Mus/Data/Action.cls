Class Mus.Data.Action Extends %Persistent
{

Property GameId As %Integer;

Property HandId As %Integer;

Property PlayerId As %String(MAXLEN = 50);

Property ActionType As %String(MAXLEN = 50);

Property Phase As %String(MAXLEN = 50);

Property Amount As %Integer;

Property PayloadJson As %String(MAXLEN = "");

Property CreatedAt As %TimeStamp;

Property CorrelationId As %String(MAXLEN = 100);

Index GameIdx On GameId;

Index HandIdx On HandId;

}