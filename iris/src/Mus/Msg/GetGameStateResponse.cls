Class Mus.Msg.GetGameStateResponse Extends Ens.Response
{

Property Success As %Boolean;

Property StatusCode As %Integer;

Property ErrorCode As %String(MAXLEN = 100);

Property ErrorMessage As %String(MAXLEN = "");

Property GameId As %Integer;

Property GameStateJson As %String(MAXLEN = "");

}