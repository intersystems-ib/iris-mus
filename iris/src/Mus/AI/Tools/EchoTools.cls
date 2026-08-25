Class Mus.AI.Tools.EchoTools Extends %AI.Tool
{

ClassMethod Echo(value As %String) As %DynamicObject
{
    Set result = {
        "value": (value)
    }

    Return result
}

}
