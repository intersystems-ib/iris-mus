Class Mus.BS.InternalEntryPoint Extends Ens.BusinessService
{

Parameter ADAPTER;

Parameter SETTINGS = "TargetConfigName";

Property TargetConfigName As %String(MAXLEN = 200) [ InitialExpression = "Mus.BP.GameCoordinator" ];

Method OnProcessInput(pInput As Ens.Request, Output pOutput As Ens.Response) As %Status
{
    Return ..SendRequestSync(..TargetConfigName, pInput, .pOutput)
}

}
