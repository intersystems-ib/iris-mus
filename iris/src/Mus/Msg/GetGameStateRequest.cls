Class Mus.Msg.GetGameStateRequest Extends Ens.Request
{

Property GameId As %Integer;

Property PlayerId As %String(MAXLEN = 50);

Property CorrelationId As %String(MAXLEN = 100);

}