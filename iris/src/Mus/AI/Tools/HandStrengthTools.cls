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
          AI Hub deberia entregar cards como %DynamicArray porque la firma
          publica un array de strings. Algunos modelos, sin embargo, pueden
          generar el argumento de la tool como una cadena que contiene una lista,
          por ejemplo:
            ['5E','10C','12O','2O']

          Normalizamos defensivamente ese caso sin cambiar ninguna decision
          estrategica.
        */
        Set cardsArray = cards

        If '$IsObject(cardsArray) {
            Set cardsArray = ..NormalizeCardsArgument(cards)
        }

        If '$IsObject(cardsArray) || cardsArray.%Size() = 0 {
            Do result.%Set("success", 0)
            Do result.%Set("strength", "")
            Do result.%Set("reason", "Invalid or empty cards argument")
            Return result
        }

        If (play '= "grande") &&
           (play '= "chica") &&
           (play '= "pares") &&
           (play '= "juego") &&
           (play '= "punto") {
            Do result.%Set("success", 0)
            Do result.%Set("strength", "")
            Do result.%Set("reason", "Unsupported play")
            Return result
        }

        Set score = ##class(Mus.AI.Helpers.HandStrengthHelper).Score(cardsArray, play)
        Set strength = ##class(Mus.AI.Helpers.HandStrengthHelper).ScoreToStrength(score)

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

            Do result.%Set(
                "pairType",
                pairInfo.%Get("pairType", "none")
            )
            Do result.%Set(
                "highestPairRank",
                +pairInfo.%Get("highestPairRank", 0)
            )
            Do result.%Set(
                "pairCount",
                +pairInfo.%Get("pairCount", 0)
            )
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
        If $IsObject(cards) {
            Return cards
        }

        Set text = $ZSTRIP(cards, "<>W")

        If text = "" {
            Return arr
        }

        /*
          Caso correcto si llega como texto JSON:
            ["5E","10C","12O","2O"]
        */
        Try {
            Set parsed = [].%FromJSON(text)
            If $IsObject(parsed) {
                Return parsed
            }
        } Catch exJson {
        }

        /*
          Workaround para modelos que generan:
            ['5E','10C','12O','2O']
        */
        If ($Extract(text, 1) = "[") && ($Extract(text, $Length(text)) = "]") {
            Set inner = $Extract(text, 2, $Length(text) - 1)

            For i=1:1:$Length(inner, ",") {
                Set card = $ZSTRIP($Piece(inner, ",", i), "<>W")
                Set card = $Replace(card, "'", "")
                Set card = $Replace(card, """", "")
                Set card = $ZSTRIP(card, "<>W")

                If card '= "" {
                    Do arr.%Push(card)
                }
            }

            Return arr
        }
    } Catch ex {
    }

    Return arr
}

}
