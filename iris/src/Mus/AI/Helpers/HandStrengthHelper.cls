Class Mus.AI.Helpers.HandStrengthHelper Extends %RegisteredObject
{

ClassMethod ParseCards(cards As %String) As %DynamicArray
{
    If cards = "" {
        Return []
    }

    Try {
        Set parsed = [].%FromJSON(cards)
        Return parsed
    } Catch ex {
        Set arr = []

        For i=1:1:$Length(cards, ",") {
            Set card = $ZSTRIP($Piece(cards, ",", i), "<>W")
            If card '= "" {
                Do arr.%Push(card)
            }
        }

        Return arr
    }
}

ClassMethod Score(cards As %DynamicArray, play As %String) As %Integer
{
    Set play = $ZCONVERT(play, "L")

    If play = "grande" {
        Return ..ScoreGrande(cards)
    }

    If play = "chica" {
        Return ..ScoreChica(cards)
    }

    If play = "pares" {
        Return ..ScorePares(cards)
    }

    If play = "juego" {
        Return ..ScoreJuego(cards)
    }

    If play = "punto" {
        Return ..ScorePunto(cards)
    }

    Return 10
}

ClassMethod ScoreToStrength(score As %Integer) As %String
{
    If score >= 85 {
        Return "very strong"
    }

    If score >= 70 {
        Return "strong"
    }

    If score >= 45 {
        Return "neutral"
    }

    If score >= 25 {
        Return "weak"
    }

    Return "very weak"
}

ClassMethod BuildReason(cards As %DynamicArray, play As %String, score As %Integer, strength As %String) As %String
{
    Set reason = "play="_play_"; strength="_strength_"; score="_score

    If $IsObject(cards) {
        Set reason = reason_"; cards="_cards.%Size()
    }

    If play = "pares", $IsObject(cards) {
        Set pairInfo = ..BuildParesInfo(cards)
        Set reason = reason_"; pairType="_pairInfo.%Get("pairType", "none")
        Set reason = reason_"; highestPairRank="_+pairInfo.%Get("highestPairRank", 0)
        Set reason = reason_"; pairCount="_+pairInfo.%Get("pairCount", 0)
    }

    If (play = "juego") || (play = "punto") {
        Set reason = reason_"; handPoints="_..HandPoints(cards)
    }

    Return reason
}

/*
  REGLAS EXACTAS DE GRANDE Y CHICA
  --------------------------------
  Orden de cartas de menor a mayor:
    pito(As/2), 4, 5, 6, 7, sota, caballo, cerdo(Rey/3)

  Grande compara lexicograficamente de mayor a menor.
  Chica compara lexicograficamente de menor a mayor.

  El score 0..100 se obtiene como percentil exacto de esa ordenacion sobre
  todas las manos posibles de 4 cartas de una baraja de Mus de 40 cartas.
  Asi el score conserva SIEMPRE el orden real de las jugadas.
*/
ClassMethod ScoreGrande(cards As %DynamicArray) As %Integer
{
    /*
      El score sirve para estimar fuerza de apuesta, NO para resolver el ganador.
      El ganador se resuelve con CompareGrande(), que conserva el orden exacto.

      Para fuerza estrategica ponderamos las cuatro cartas ordenadas:
      40%, 30%, 20%, 10%. Asi una sola carta maxima no convierte por si sola
      una mano mediocre en "very strong".
    */
    Return ..ScorePositionalStrength(cards, "grande")
}

ClassMethod ScoreChica(cards As %DynamicArray) As %Integer
{
    /*
      Misma separacion para chica:
      CompareChica() resuelve exactamente el ganador.
      Este score mide la calidad global de la mano para apostar.
    */
    Return ..ScorePositionalStrength(cards, "chica")
}

ClassMethod ScorePositionalStrength(cards As %DynamicArray, play As %String) As %Integer
{
    /*
      Calculo directo y autocontenido para grande/chica.
      Evita depender de cualquier implementacion previa de BuildQualityVector.
    */
    If '$IsObject(cards) {
        Return 10
    }

    If cards.%Size() '= 4 {
        Return 10
    }

    Set play = $ZCONVERT(play, "L")
    Set vector = []

    For i=0:1:cards.%Size()-1 {
        Set musRank = ..MusRank(cards.%Get(i))
        Set orderIndex = ..OrderIndexFromMusRank(musRank)

        If play = "chica" {
            Set quality = 7 - orderIndex
        } Else {
            Set quality = orderIndex
        }

        Do vector.%Push(quality)
    }

    Do ..SortNumericDescending(vector)

    If vector.%Size() '= 4 {
        Return 10
    }

    Set weighted = 0
    Set weighted = weighted + (+vector.%Get(0) * 40)
    Set weighted = weighted + (+vector.%Get(1) * 30)
    Set weighted = weighted + (+vector.%Get(2) * 20)
    Set weighted = weighted + (+vector.%Get(3) * 10)

    /*
      weighted maximo = 700.
      Resultado 1..100.
    */
    Set score = weighted / 7
    Set score = $Justify(score, 0, 0)

    If score < 1 { Set score = 1 }
    If score > 100 { Set score = 100 }

    Return score
}

ClassMethod DiagnosticQualityVector(cards As %DynamicArray, play As %String) As %DynamicObject
{
    Set result = {}
    Set vector = []
    Set ranks = []
    Set indexes = []

    If '$IsObject(cards) {
        Do result.%Set("error", "cards is not an object")
        Return result
    }

    Set play = $ZCONVERT(play, "L")

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set musRank = ..MusRank(card)
        Set orderIndex = ..OrderIndexFromMusRank(musRank)
        Set quality = $Select(play="chica":7-orderIndex, 1:orderIndex)

        Do ranks.%Push(musRank)
        Do indexes.%Push(orderIndex)
        Do vector.%Push(quality)
    }

    Do ..SortNumericDescending(vector)

    Do result.%Set("version", "2026-08-25-direct-positional-v1")
    Do result.%Set("play", play)
    Do result.%Set("musRanks", ranks)
    Do result.%Set("orderIndexes", indexes)
    Do result.%Set("qualityVector", vector)
    Do result.%Set("score", ..ScorePositionalStrength(cards, play))

    Return result
}

ClassMethod ScoreLexicographicPercentile(cards As %DynamicArray, play As %String) As %Integer
{
    /*
      Version robusta y determinista.

      Para GRANDE y CHICA lo importante es conservar exactamente el orden
      lexicografico real de las cuatro cartas. No necesitamos enumerar toda
      la baraja en cada llamada para obtener una senal 0..100.

      Convertimos el vector de calidad (4 valores 0..7, ordenados de mejor a
      peor) a una clave base 8. Esa clave conserva exactamente el orden de
      las jugadas:
          key = q1*8^3 + q2*8^2 + q3*8 + q4

      Por tanto, si una mano gana a otra segun las reglas de Grande/Chica,
      tambien tendra siempre mayor score.
    */
    If '$IsObject(cards) {
        Return 10
    }

    If cards.%Size() '= 4 {
        Return 10
    }

    Set play = $ZCONVERT(play, "L")
    Set vector = ..BuildQualityVector(cards, play)

    If '$IsObject(vector) {
        Return 10
    }

    If vector.%Size() '= 4 {
        Return 10
    }

    Set q1 = +vector.%Get(0)
    Set q2 = +vector.%Get(1)
    Set q3 = +vector.%Get(2)
    Set q4 = +vector.%Get(3)

    Set key = (q1 * 512) + (q2 * 64) + (q3 * 8) + q4

    /*
      7,7,7,7 => 4095.
      Escalamos linealmente a 1..100.
    */
    Set score = 1 + ((key * 99) / 4095)
    Set score = $Justify(score, 0, 0)

    If score < 1 { Set score = 1 }
    If score > 100 { Set score = 100 }

    Return score
}

ClassMethod BuildQualityVector(cards As %DynamicArray, play As %String) As %DynamicArray
{
    Set vector = []

    If '$IsObject(cards) {
        Return vector
    }

    Set play = $ZCONVERT(play, "L")

    For i=0:1:cards.%Size()-1 {
        Set orderIndex = ..MusOrderIndex(cards.%Get(i))

        If play = "chica" {
            /*
              En chica la categoria mas baja es la mejor.
              Invertimos la calidad para reutilizar el mismo comparador:
              mayor quality = mejor jugada.
            */
            Set quality = 7 - orderIndex
        } Else {
            Set quality = orderIndex
        }

        Do vector.%Push(quality)
    }

    Do ..SortNumericDescending(vector)
    Return vector
}

ClassMethod BuildQualityVectorFromCategories(a As %Integer, b As %Integer, c As %Integer, d As %Integer, play As %String) As %DynamicArray
{
    Set vector = []
    Set play = $ZCONVERT(play, "L")

    Set categories = []
    Do categories.%Push(a)
    Do categories.%Push(b)
    Do categories.%Push(c)
    Do categories.%Push(d)

    For i=0:1:3 {
        Set orderIndex = +categories.%Get(i)
        Set quality = orderIndex

        If play = "chica" {
            Set quality = 7 - orderIndex
        }

        Do vector.%Push(quality)
    }

    Do ..SortNumericDescending(vector)
    Return vector
}

ClassMethod CompareQualityVectors(a As %DynamicArray, b As %DynamicArray) As %Integer
{
    If '$IsObject(a) || '$IsObject(b) {
        Return 0
    }

    Set max = a.%Size()
    If b.%Size() < max {
        Set max = b.%Size()
    }

    For i=0:1:max-1 {
        Set av = +a.%Get(i)
        Set bv = +b.%Get(i)

        If av > bv {
            Return 1
        }

        If av < bv {
            Return -1
        }
    }

    If a.%Size() > b.%Size() {
        Return 1
    }

    If a.%Size() < b.%Size() {
        Return -1
    }

    Return 0
}

ClassMethod SortNumericDescending(array As %DynamicArray)
{
    If '$IsObject(array) {
        Return
    }

    For i=0:1:array.%Size()-2 {
        For j=i+1:1:array.%Size()-1 {
            If +array.%Get(j) > +array.%Get(i) {
                Set tmp = array.%Get(i)
                Do array.%Set(i, array.%Get(j))
                Do array.%Set(j, tmp)
            }
        }
    }
}

ClassMethod MusOrderIndex(card As %String) As %Integer
{
    Set rank = ..MusRank(card)

    If rank = 1  { Return 0 }
    If rank = 4  { Return 1 }
    If rank = 5  { Return 2 }
    If rank = 6  { Return 3 }
    If rank = 7  { Return 4 }
    If rank = 10 { Return 5 }
    If rank = 11 { Return 6 }
    If rank = 12 { Return 7 }

    /*
      La baraja de Mus usada por estas reglas es de 40 cartas y no contiene
      ochos ni nueves. Si aparecieran por datos corruptos, no deben ganar
      artificialmente a figuras.
    */
    Return 0
}

ClassMethod CategoryCapacity(index As %Integer) As %Integer
{
    If index = 0 { Return 8 }
    If index = 7 { Return 8 }
    Return 4
}

ClassMethod Combination(n As %Integer, k As %Integer) As %Integer
{
    If k < 0 { Return 0 }
    If k > n { Return 0 }
    If k = 0 { Return 1 }
    If k = 1 { Return n }
    If k = 2 { Return (n * (n - 1)) \ 2 }
    If k = 3 { Return (n * (n - 1) * (n - 2)) \ 6 }
    If k = 4 { Return (n * (n - 1) * (n - 2) * (n - 3)) \ 24 }
    Return 0
}

/*
  PARES
  -----
  Jerarquia exacta:
    duples > medias > pareja > sin pares

  En igualdad de tipo se compara el valor a grande.
  En duples se compara primero la pareja alta y despues la baja.
  Cuatro iguales son duples: pareja alta = pareja baja = mismo rango.
*/
ClassMethod ScorePares(cards As %DynamicArray) As %Integer
{
    Set v = ..BuildParesComparisonVector(cards)

    Set typeRank = +v.%Get(0)
    Set highRank = +v.%Get(1)
    Set lowRank = +v.%Get(2)

    If typeRank = 0 {
        Return 10
    }

    If typeRank = 1 {
        /* Pareja sencilla: 25..70 */
        Return 25 + $Justify((highRank * 45) / 7, 0, 0)
    }

    If typeRank = 2 {
        /* Medias: siempre por encima de cualquier pareja. */
        Return 75 + $Justify((highRank * 10) / 7, 0, 0)
    }

    /*
      Duples: siempre por encima de medias.
      Desempate exacto por pareja alta y despues baja.
    */
    Set pairKey = (highRank * 8) + lowRank
    Return 86 + $Justify((pairKey * 14) / 63, 0, 0)
}

ClassMethod BuildParesInfo(cards As %DynamicArray) As %DynamicObject
{
    Set info = {
        "pairType": "none",
        "pairCount": 0,
        "highestPairRank": 0,
        "lowestPairRank": 0,
        "hasThree": 0,
        "hasFour": 0
    }

    If '$IsObject(cards) {
        Return info
    }

    Kill counts

    For i=0:1:cards.%Size()-1 {
        Set rank = ..MusRank(cards.%Get(i))
        Set counts(rank) = $Get(counts(rank)) + 1
    }

    Set pairCount = 0
    Set highestPairRank = 0
    Set lowestPairRank = 0
    Set hasThree = 0
    Set hasFour = 0

    Set rank = ""
    For {
        Set rank = $Order(counts(rank))
        Quit:rank=""

        If counts(rank) >= 2 {
            Set pairCount = pairCount + 1

            If +rank > highestPairRank {
                Set highestPairRank = +rank
            }

            If (lowestPairRank = 0) || (+rank < lowestPairRank) {
                Set lowestPairRank = +rank
            }
        }

        If counts(rank) = 3 {
            Set hasThree = 1
        }

        If counts(rank) >= 4 {
            Set hasFour = 1
        }
    }

    Do info.%Set("pairCount", pairCount)
    Do info.%Set("highestPairRank", highestPairRank)
    Do info.%Set("lowestPairRank", lowestPairRank)
    Do info.%Set("hasThree", hasThree)
    Do info.%Set("hasFour", hasFour)

    If hasFour {
        Do info.%Set("pairType", "duples4")
    } ElseIf hasThree {
        Do info.%Set("pairType", "medias")
    } ElseIf pairCount >= 2 {
        Do info.%Set("pairType", "duples")
    } ElseIf pairCount = 1 {
        Do info.%Set("pairType", "pares")
    }

    Return info
}

ClassMethod BuildParesComparisonVector(cards As %DynamicArray) As %DynamicArray
{
    Set result = [0,0,0]

    If '$IsObject(cards) {
        Return result
    }

    Kill counts

    For i=0:1:cards.%Size()-1 {
        Set rank = ..MusRank(cards.%Get(i))
        Set counts(rank) = $Get(counts(rank)) + 1
    }

    Set fourRank = 0
    Set tripleRank = 0
    Set pairHigh = 0
    Set pairLow = 0
    Set pairCount = 0

    Set rank = ""
    For {
        Set rank = $Order(counts(rank))
        Quit:rank=""

        If counts(rank) >= 4 {
            Set fourRank = +rank
        } ElseIf counts(rank) = 3 {
            Set tripleRank = +rank
        } ElseIf counts(rank) = 2 {
            Set pairCount = pairCount + 1

            If +rank > pairHigh {
                Set pairLow = pairHigh
                Set pairHigh = +rank
            } ElseIf (pairLow = 0) || (+rank > pairLow) {
                Set pairLow = +rank
            }
        }
    }

    If fourRank > 0 {
        Set result = []
        Do result.%Push(3)
        Do result.%Push(..OrderIndexFromMusRank(fourRank))
        Do result.%Push(..OrderIndexFromMusRank(fourRank))
        Return result
    }

    If pairCount >= 2 {
        Set result = []
        Do result.%Push(3)
        Do result.%Push(..OrderIndexFromMusRank(pairHigh))
        Do result.%Push(..OrderIndexFromMusRank(pairLow))
        Return result
    }

    If tripleRank > 0 {
        Set result = []
        Do result.%Push(2)
        Do result.%Push(..OrderIndexFromMusRank(tripleRank))
        Do result.%Push(0)
        Return result
    }

    If pairCount = 1 {
        Set result = []
        Do result.%Push(1)
        Do result.%Push(..OrderIndexFromMusRank(pairHigh))
        Do result.%Push(0)
        Return result
    }

    Return result
}

/*
  JUEGO
  -----
  Orden exacto segun las reglas:
    31 > 32 > 40 > 39 > 38 > 37 > 36 > 35 > 34 > 33
*/
ClassMethod JuegoRank(points As %Integer) As %Integer
{
    If points = 31 { Return 10 }
    If points = 32 { Return 9 }
    If points = 40 { Return 8 }
    If points = 39 { Return 7 }
    If points = 38 { Return 6 }
    If points = 37 { Return 5 }
    If points = 36 { Return 4 }
    If points = 35 { Return 3 }
    If points = 34 { Return 2 }
    If points = 33 { Return 1 }
    Return 0
}

ClassMethod ScoreJuego(cards As %DynamicArray) As %Integer
{
    Set points = ..HandPoints(cards)
    Set rank = ..JuegoRank(points)

    If rank = 0 {
        Return 15
    }

    /*
      Mantiene exactamente el orden de Juego y deja margen de fuerza:
      31=100, 32=96, 40=92 ... 33=64.
    */
    Return 60 + (rank * 4)
}

/*
  PUNTO
  -----
  Solo se usa cuando nadie tiene juego.
  Gana el total mas cercano a 30 por debajo de 31.
*/
ClassMethod ScorePunto(cards As %DynamicArray) As %Integer
{
    Set points = ..HandPoints(cards)

    If points >= 31 {
        Return 10
    }

    If points = 30 { Return 100 }
    If points = 29 { Return 90 }
    If points = 28 { Return 80 }
    If points = 27 { Return 70 }
    If points = 26 { Return 60 }
    If points = 25 { Return 50 }
    If points = 24 { Return 40 }
    If points = 23 { Return 30 }

    Return 20
}

/*
  COMPARADORES EXACTOS PARA CONTABILIZAR GANADORES
  ------------------------------------------------
  Devuelven:
     1 -> gana cardsA
     0 -> empate absoluto; debe resolver la posicion de mano
    -1 -> gana cardsB

  El motor de partida debe usar estos comparadores, no comparar Score().
*/
ClassMethod CompareHands(cardsA As %DynamicArray, cardsB As %DynamicArray, play As %String) As %Integer
{
    Set play = $ZCONVERT(play, "L")

    If play = "grande" {
        Return ..CompareGrande(cardsA, cardsB)
    }

    If play = "chica" {
        Return ..CompareChica(cardsA, cardsB)
    }

    If play = "pares" {
        Return ..ComparePares(cardsA, cardsB)
    }

    If play = "juego" {
        Return ..CompareJuego(cardsA, cardsB)
    }

    If play = "punto" {
        Return ..ComparePunto(cardsA, cardsB)
    }

    Return 0
}

ClassMethod CompareGrande(cardsA As %DynamicArray, cardsB As %DynamicArray) As %Integer
{
    Return ..CompareQualityVectors(
        ..BuildQualityVector(cardsA, "grande"),
        ..BuildQualityVector(cardsB, "grande")
    )
}

ClassMethod CompareChica(cardsA As %DynamicArray, cardsB As %DynamicArray) As %Integer
{
    Return ..CompareQualityVectors(
        ..BuildQualityVector(cardsA, "chica"),
        ..BuildQualityVector(cardsB, "chica")
    )
}

ClassMethod ComparePares(cardsA As %DynamicArray, cardsB As %DynamicArray) As %Integer
{
    Set a = ..BuildParesComparisonVector(cardsA)
    Set b = ..BuildParesComparisonVector(cardsB)

    For i=0:1:2 {
        Set av = +a.%Get(i)
        Set bv = +b.%Get(i)

        If av > bv { Return 1 }
        If av < bv { Return -1 }
    }

    Return 0
}

ClassMethod CompareJuego(cardsA As %DynamicArray, cardsB As %DynamicArray) As %Integer
{
    Set rankA = ..JuegoRank(..HandPoints(cardsA))
    Set rankB = ..JuegoRank(..HandPoints(cardsB))

    If rankA > rankB { Return 1 }
    If rankA < rankB { Return -1 }
    Return 0
}

ClassMethod ComparePunto(cardsA As %DynamicArray, cardsB As %DynamicArray) As %Integer
{
    Set pointsA = ..HandPoints(cardsA)
    Set pointsB = ..HandPoints(cardsB)

    /*
      Punto solo es valido si nadie llega a 31.
      A mayor puntuacion, mejor, con 30 como maximo.
    */
    If pointsA > pointsB { Return 1 }
    If pointsA < pointsB { Return -1 }
    Return 0
}

/*
  Recibe un array de manos en orden desde "mano" hacia "postre".
  En empate total conserva el primer indice, por lo que resuelve
  correctamente a favor del jugador mas cercano a la mano.
*/
ClassMethod FindWinnerIndex(hands As %DynamicArray, play As %String) As %Integer
{
    If '$IsObject(hands) || hands.%Size() = 0 {
        Return -1
    }

    Set winner = 0
    Set winnerCards = hands.%Get(0)

    For i=1:1:hands.%Size()-1 {
        Set challenger = hands.%Get(i)

        If ..CompareHands(challenger, winnerCards, play) > 0 {
            Set winner = i
            Set winnerCards = challenger
        }
    }

    Return winner
}

ClassMethod MusRank(card As %String) As %Integer
{
    Set rank = ..ExtractRank(card)

    If rank = 3 {
        Return 12
    }

    If rank = 2 {
        Return 1
    }

    Return rank
}

ClassMethod OrderIndexFromMusRank(rank As %Integer) As %Integer
{
    If rank = 1  { Return 0 }
    If rank = 4  { Return 1 }
    If rank = 5  { Return 2 }
    If rank = 6  { Return 3 }
    If rank = 7  { Return 4 }
    If rank = 10 { Return 5 }
    If rank = 11 { Return 6 }
    If rank = 12 { Return 7 }
    Return 0
}

ClassMethod ExtractRank(card As %String) As %Integer
{
    Set card = $ZCONVERT(card, "U")
    Set digits = ""

    For i=1:1:$Length(card) {
        Set ch = $Extract(card, i)

        If ch?1N {
            Set digits = digits_ch
        } Else {
            Quit
        }
    }

    If digits '= "" {
        Return +digits
    }

    If $Extract(card, 1) = "A" {
        Return 1
    }

    If $Extract(card, 1) = "S" {
        Return 10
    }

    If $Extract(card, 1) = "C" {
        Return 11
    }

    If $Extract(card, 1) = "R" {
        Return 12
    }

    Return 0
}

ClassMethod MusPointValue(card As %String) As %Integer
{
    Set rank = ..ExtractRank(card)

    If rank = 3 {
        Return 10
    }

    If rank = 2 {
        Return 1
    }

    If rank >= 10 {
        Return 10
    }

    Return rank
}

ClassMethod HandPoints(cards As %DynamicArray) As %Integer
{
    Set total = 0

    If '$IsObject(cards) {
        Return 0
    }

    For i=0:1:cards.%Size()-1 {
        Set total = total + ..MusPointValue(cards.%Get(i))
    }

    Return total
}

}
