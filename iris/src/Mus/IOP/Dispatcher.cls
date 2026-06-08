Class Mus.IOP.Dispatcher
{

ClassMethod Send(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status
{
    Set sc = ##class(Ens.Director).CreateBusinessService("Mus.BS.InternalEntryPoint", .svc)
    If $$$ISERR(sc) {
        Return sc
    }

    Set sc = svc.OnProcessInput(pRequest, .pResponse)
    Return sc
}

}
