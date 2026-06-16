Class Mus.BS.InternalEntryPoint Extends Ens.BusinessService
{

Parameter ADAPTER;

Parameter SETTINGS = "TargetConfigName";

Property TargetConfigName As %String(MAXLEN = 200) [ InitialExpression = "Mus.BP.GameCoordinator" ];

Method OnProcessInput(pInput As Ens.Request, Output pOutput As Ens.Response) As %Status
{
    If pInput.%IsA("Mus.Msg.CreateTournamentRequest") {
        Return ..SendRequestSync(
            "Mus.BP.TournamentCoordinator",
            pInput,
            .pOutput
        )
    }

    If pInput.%IsA("Mus.Msg.GetTournamentRequest") {
        Return ..SendRequestSync(
            "Mus.BP.TournamentCoordinator",
            pInput,
            .pOutput
        )
    }

    If pInput.%IsA("Mus.Msg.StartTournamentTableRequest") {
        Return ..SendRequestSync(
            "Mus.BP.TournamentCoordinator",
            pInput,
            .pOutput
        )
    }

    If pInput.%IsA("Mus.Msg.CompleteTournamentTableRequest") {
        Return ..SendRequestSync(
            "Mus.BP.TournamentCoordinator",
            pInput,
            .pOutput
        )
    }

    If pInput.%IsA("Mus.Msg.ListTournamentsRequest") {
        Return ..SendRequestSync(
            "Mus.BP.TournamentCoordinator",
            pInput,
            .pOutput
        )
    }
    
    Return ..SendRequestSync(..TargetConfigName, pInput, .pOutput)
}

}
