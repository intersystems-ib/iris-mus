Class Mus.AI.Provider Extends %RegisteredObject
{

Parameter Backend = "AIHUB";

ClassMethod ChatJson(systemPrompt As %String, userPrompt As %String, Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Set backend = ..#Backend

    If backend = "HTTP" {
        Return ##class(Mus.LLM.Client).ChatJson(
            systemPrompt,
            userPrompt,
            .rawResponse
        )
    }

    If backend = "AIHUB" {
        Return ##class(Mus.AI.AIHubClient).ChatJson(
            systemPrompt,
            userPrompt,
            .rawResponse
        )
    }

    Return $$$ERROR($$$GeneralError, "Unsupported AI backend: "_backend)
}

ClassMethod GetBackend() As %String
{
    Return ..#Backend
}

}
