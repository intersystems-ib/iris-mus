Class Mus.LLM.Client Extends %RegisteredObject
{

Parameter Server = "llama";

Parameter Port = 8000;

ClassMethod ChatJson(systemPrompt As %String, userPrompt As %String, Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Try {
        Set requestBody = {
            "model": "qwen3-4b-agent",
            "messages": [
                {
                    "role": "system",
                    "content": (systemPrompt)
                },
                {
                    "role": "user",
                    "content": (userPrompt)
                }
            ],
            "temperature": 0.2,
            "top_p": 0.9,
            "max_tokens": 400,
            "stream": false,
            "response_format": {
                "type": "json_object"
            }
        }

        Set http = ##class(%Net.HttpRequest).%New()
        Set http.Server = ..#Server
        Set http.Port = ..#Port
        Set http.Https = 0

        Set http.ContentType = "application/json"
        Set http.ContentCharset = "utf-8"

        Do http.SetHeader("Accept", "application/json")
        Do http.SetHeader("Accept-Charset", "utf-8")
        Do http.SetHeader("Content-Type", "application/json; charset=utf-8")

        Do requestBody.%ToJSON(http.EntityBody)

        Do http.EntityBody.Rewind()

        Set sc = http.Post("/v1/chat/completions")
        If $$$ISERR(sc) {
            Return sc
        }

        If '$IsObject(http.HttpResponse) {
            Return $$$ERROR($$$GeneralError, "LLM returned no HTTP response")
        }

        Set responseText = http.HttpResponse.Data.Read()

        If http.HttpResponse.StatusCode < 200 || http.HttpResponse.StatusCode >= 300 {
            Return $$$ERROR($$$GeneralError, "LLM HTTP error "_http.HttpResponse.StatusCode_": "_responseText)
        }

        If responseText = "" {
            Return $$$ERROR($$$GeneralError, "LLM returned empty response")
        }

        Set response = {}.%FromJSON(responseText)

        If response.%IsDefined("error") {
            Return $$$ERROR($$$GeneralError, "LLM error response: "_responseText)
        }

        Set choices = response.%Get("choices", "")
        If '$IsObject(choices) {
            Return $$$ERROR($$$GeneralError, "LLM response has no choices. Raw response: "_responseText)
        }

        If choices.%Size() = 0 {
            Return $$$ERROR($$$GeneralError, "LLM response choices is empty. Raw response: "_responseText)
        }

        Set choice = choices.%Get(0)
        If '$IsObject(choice) {
            Return $$$ERROR($$$GeneralError, "LLM choice is not an object. Raw response: "_responseText)
        }

        Set message = choice.%Get("message", "")
        If '$IsObject(message) {
            Return $$$ERROR($$$GeneralError, "LLM response has no message. Raw response: "_responseText)
        }

        Set rawResponse = message.%Get("content", "")

        If rawResponse = "" {
            Return $$$ERROR($$$GeneralError, "LLM message content is empty. Raw response: "_responseText)
        }

        Return $$$OK
    }
    Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod Ping(Output responseText As %String) As %Status
{
    Set responseText = ""

    Try {
        Set http = ##class(%Net.HttpRequest).%New()
        Set http.Server = ..#Server
        Set http.Port = ..#Port
        Set http.Https = 0

        Do http.SetHeader("Accept", "application/json")

        Set sc = http.Get("/health")
        If $$$ISERR(sc) {
            Return sc
        }

        If '$IsObject(http.HttpResponse) {
            Return $$$ERROR($$$GeneralError, "LLM returned no HTTP response")
        }

        Set responseText = http.HttpResponse.Data.Read()

        If http.HttpResponse.StatusCode < 200 || http.HttpResponse.StatusCode >= 300 {
            Return $$$ERROR($$$GeneralError, "LLM health HTTP error "_http.HttpResponse.StatusCode_": "_responseText)
        }

        Return $$$OK
    }
    Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

}
