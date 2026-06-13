Class Mus.AI.AIHubClient Extends %RegisteredObject
{

Parameter ProviderName = "nim";

Parameter BaseURL = "http://llama:8000/v1";

Parameter ApiKey = "not-needed";

Parameter Model = "qwen3-4b-agent";

Parameter Temperature = 0.2;

Parameter MaxTokens = 400;

Parameter TopP = 0.9;

ClassMethod ChatJson(systemPrompt As %String, userPrompt As %String, Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Try {
        Set provider = ..CreateProvider()
        If '$IsObject(provider) {
            Return $$$ERROR($$$GeneralError, "AI Hub provider could not be created")
        }

        Set messages = []
        Do messages.%Push({
            "role": "system",
            "content": (systemPrompt)
        })
        Do messages.%Push({
            "role": "user",
            "content": (userPrompt)
        })

        Set response = provider.ChatComplete(
            ..#Model,
            messages,
            ..#Temperature,
            ..#MaxTokens,
            ..#TopP
        )

        If '$IsObject(response) {
            Return $$$ERROR($$$GeneralError, "AI Hub returned no response object")
        }

        Set rawResponse = ..ExtractResponseText(response)

        If rawResponse = "" {
            Return $$$ERROR($$$GeneralError, "AI Hub returned empty response. Raw object: "_response.%ToJSON())
        }

        Set rawResponse = ..ExtractJsonObject(rawResponse)

        If rawResponse = "" {
            Return $$$ERROR($$$GeneralError, "AI Hub returned no JSON object. Raw object: "_response.%ToJSON())
        }

        Return $$$OK
    }
    Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

ClassMethod CreateProvider() As %RegisteredObject
{
    /*
      Para llama.cpp queremos endpoint OpenAI-compatible local.
      Probamos con provider "nim" porque AI Hub documenta base_url para NIM.
    */
    Set settings = {
        "base_url": (..#BaseURL),
        "api_key": (..#ApiKey)
    }

    Return ##class(%AI.Provider).Create(..#ProviderName, settings)
}

ClassMethod ExtractResponseText(response As %RegisteredObject) As %String
{
    /*
      Intentamos varias formas porque %AI.LLM.Response puede variar según build EAP.
    */

    Try {
        Set text = response.Text
        If text '= "" {
            Return text
        }
    }
    Catch ex1 {
    }

    Try {
        Set text = response.Content
        If text '= "" {
            Return text
        }
    }
    Catch ex2 {
    }

    Try {
        Set text = response.Message
        If text '= "" {
            Return text
        }
    }
    Catch ex3 {
    }

    Try {
        Set text = response.%Get("text", "")
        If text '= "" {
            Return text
        }
    }
    Catch ex4 {
    }

    Try {
        Set text = response.%Get("content", "")
        If text '= "" {
            Return text
        }
    }
    Catch ex5 {
    }

    Try {
        Set text = response.%ToJSON()
        If text '= "" {
            Return text
        }
    }
    Catch ex6 {
    }

    Return ""
}

ClassMethod ExtractJsonObject(text As %String) As %String
{
    Set text = $ZSTRIP(text, "<W")

    If text = "" {
        Return ""
    }

    /*
      Si ya es JSON puro, lo devolvemos.
    */
    If $Extract(text, 1) = "{" {
        Return text
    }

    /*
      Si el modelo devuelve texto alrededor, recortamos desde el primer {
      hasta el último }.
    */
    Set first = $Find(text, "{")
    If first = 0 {
        Return ""
    }

    Set start = first - 1
    Set last = 0

    For i=$Length(text):-1:1 {
        If $Extract(text, i) = "}" {
            Set last = i
            Quit
        }
    }

    If last < start {
        Return ""
    }

    Return $Extract(text, start, last)
}

ClassMethod Ping(Output rawResponse As %String) As %Status
{
    Set rawResponse = ""

    Set sc = ..ChatJson(
        "Responde siempre solo con JSON valido. No incluyas markdown.",
        "Devuelve exactamente este JSON: {""ok"":true}",
        .rawResponse
    )

    Return sc
}

ClassMethod DebugProvider(Output debugJson As %String) As %Status
{
    Set debugJson = ""

    Try {
        Set provider = ..CreateProvider()

        If '$IsObject(provider) {
            Set debug = {
                "success": false,
                "error": "Provider could not be created",
                "providerName": (..#ProviderName),
                "baseURL": (..#BaseURL)
            }

            Set debugJson = debug.%ToJSON()
            Return $$$OK
        }

        Set debug = {
            "success": true,
            "providerClass": ($ClassName(provider)),
            "providerName": (..#ProviderName),
            "baseURL": (..#BaseURL)
        }

        Try {
            Set caps = provider.GetCapabilities()
            If $IsObject(caps) {
                Do debug.%Set("capabilities", caps)
            }
        }
        Catch exCaps {
            Do debug.%Set("capabilitiesError", exCaps.DisplayString())
        }

        Try {
            Set models = provider.ListModels()
            If $IsObject(models) {
                Do debug.%Set("models", models)
            }
        }
        Catch exModels {
            Do debug.%Set("modelsError", exModels.DisplayString())
        }

        Set debugJson = debug.%ToJSON()
        Return $$$OK
    }
    Catch ex {
        Return $$$ERROR($$$GeneralError, ex.DisplayString())
    }
}

}
