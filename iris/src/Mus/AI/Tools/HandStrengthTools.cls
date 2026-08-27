Class Mus.AI.Tools.HandStrengthTools Extends %AI.Tool
{

ClassMethod EvaluatePlayStrength(cards As %DynamicArray(ELEMENTTYPE="%String"), play As %String) As %DynamicObject
{
    Set result = {
        "success": 0,
        "strength": "",
        "play": (play),
        "reason": ""
    }

    Try {
        Set play = $ZCONVERT(play, "L")
        Do result.%Set("play", play)

        /*
          Normalizamos SIEMPRE el argumento. Si ya es %DynamicArray,
          NormalizeCardsArgument lo copia y limpia carta a carta.
          Si llega como texto JSON o como lista estilo Python, lo parsea.
        */
        Set cardsArray = ..NormalizeCardsArgument(cards)

        If '$IsObject(cardsArray) {
            Do result.%Set("reason", "Invalid cards argument")
            Return result
        }

        If cardsArray.%Size() '= 4 {
            Do result.%Set("reason", "Expected exactly 4 cards")
            Do result.%Set("normalizedCardCount", cardsArray.%Size())
            Do result.%Set("normalizedCards", cardsArray)
            Return result
        }

        Do result.%Set("normalizedCardCount", cardsArray.%Size())
        Do result.%Set("normalizedCards", cardsArray)

        If (play '= "grande") &&
           (play '= "chica") &&
           (play '= "pares") &&
           (play '= "juego") &&
           (play '= "punto") {
            Do result.%Set("reason", "Unsupported play")
            Return result
        }

        Set score = ##class(Mus.AI.Helpers.HandStrengthHelper).Score(cardsArray, play)
        Set strength = ##class(Mus.AI.Helpers.HandStrengthHelper).EvaluateStrength(cardsArray, play)

        Do result.%Set("success", 1)
        Do result.%Set("strength", strength)
        Do result.%Set("score", score)
        Do result.%Set(
            "reason",
            ##class(Mus.AI.Helpers.HandStrengthHelper).BuildReason(
                cardsArray,
                play,
                score,
                strength
            )
        )

        If play = "pares" {
            Set pairInfo = ##class(Mus.AI.Helpers.HandStrengthHelper).BuildParesInfo(cardsArray)

            Do result.%Set("pairType", pairInfo.%Get("pairType", "none"))
            Do result.%Set("highestPairRank", +pairInfo.%Get("highestPairRank", 0))
            Do result.%Set("pairCount", +pairInfo.%Get("pairCount", 0))
        }

        Return result
    } Catch ex {
        Do result.%Set("success", 0)
        Do result.%Set("strength", "")
        Do result.%Set("reason", ex.DisplayString())
        Return result
    }
}

ClassMethod NormalizeCardsArgument(cards) As %DynamicArray
{
    Set arr = []

    Try {
        /*
          Si AI Hub ya ha materializado un array, NO lo devolvemos sin mas:
          copiamos y limpiamos cada elemento para evitar valores como
          ['12C' o '6C'] si el proveedor hizo una coercion parcial.
        */
        If $IsObject(cards) {
            For i=0:1:cards.%Size()-1 {
                Set card = ..NormalizeSingleCard(cards.%Get(i))
                If card '= "" {
                    Do arr.%Push(card)
                }
            }
            Return arr
        }

        Set text = $ZSTRIP(cards, "<>W")
        If text = "" {
            Return arr
        }

        /*
          JSON correcto:
            ["12C","6B","11O","6C"]
        */
        Try {
            Set parsed = [].%FromJSON(text)

            If $IsObject(parsed) {
                For i=0:1:parsed.%Size()-1 {
                    Set card = ..NormalizeSingleCard(parsed.%Get(i))
                    If card '= "" {
                        Do arr.%Push(card)
                    }
                }
                Return arr
            }
        } Catch exJson {
        }

        /*
          Lista estilo Python:
            ['12C', '6B', '11O', '6C']
        */
        If ($Extract(text, 1) = "[") && ($Extract(text, $Length(text)) = "]") {
            Set text = $Extract(text, 2, $Length(text)-1)
        }

        For i=1:1:$Length(text, ",") {
            Set card = ..NormalizeSingleCard($Piece(text, ",", i))
            If card '= "" {
                Do arr.%Push(card)
            }
        }
    } Catch ex {
    }

    Return arr
}

ClassMethod NormalizeSingleCard(value) As %String
{
    Set card = $ZSTRIP(value, "<>W")

    /*
      Limpiar restos de listas serializadas y comillas.
    */
    Set card = $Replace(card, "[", "")
    Set card = $Replace(card, "]", "")
    Set card = $Replace(card, "'", "")
    Set card = $Replace(card, """", "")
    Set card = $ZSTRIP(card, "<>W")
    Set card = $ZCONVERT(card, "U")

    Return card
}

}
