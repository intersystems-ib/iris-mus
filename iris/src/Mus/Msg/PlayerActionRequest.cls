Class Mus.Msg.PlayerActionRequest Extends Ens.Request
{

Property GameId As %Integer;

Property PlayerId As %String(MAXLEN = 50);

Property ActionType As %String(MAXLEN = 50);

Property Phase As %String(MAXLEN = 50);

Property Amount As %Integer;

Property PayloadJson As %String(MAXLEN = "");

Property CorrelationId As %String(MAXLEN = 100);

}