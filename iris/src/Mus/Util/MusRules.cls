Class Mus.Util.MusRules
{

ClassMethod GetPlayerTeam(gameState As %DynamicObject, playerId As %String) As %String
{
    Set players = gameState.%Get("players", "")

    If '$IsObject(players) {
        Return ""
    }

    For i=0:1:players.%Size()-1 {
        Set player = players.%Get(i)

        If player.%Get("id", "") = playerId {
            Return player.%Get("team", "")
        }
    }

    Return ""
}

ClassMethod GetNextPlayerId(playerId As %String) As %String
{
    If playerId = "P1" {
        Return "P2"
    }

    If playerId = "P2" {
        Return "P3"
    }

    If playerId = "P3" {
        Return "P4"
    }

    Return "P1"
}

ClassMethod GetTeamOpponent(team As %String) As %String
{
    If team = "A" {
        Return "B"
    }

    If team = "B" {
        Return "A"
    }

    Return ""
}

ClassMethod GetCardGrandeValue(card As %String) As %Integer
{
    Set rank = +$Extract(card, 1, *-1)

    /*
      Mus grande:
      3 y rey valen alto.
      2 y as valen bajo.
    */

    If rank = 3 {
        Return 10
    }

    If rank = 12 {
        Return 10
    }

    If rank = 11 {
        Return 9
    }

    If rank = 10 {
        Return 8
    }

    If rank = 7 {
        Return 7
    }

    If rank = 6 {
        Return 6
    }

    If rank = 5 {
        Return 5
    }

    If rank = 4 {
        Return 4
    }

    If rank = 2 {
        Return 1
    }

    If rank = 1 {
        Return 1
    }

    Return 0
}

ClassMethod GetGrandeVector(cards As %DynamicArray) As %DynamicArray
{
    Set values = []

    For i=0:1:cards.%Size()-1 {
        Do values.%Push(..GetCardGrandeValue(cards.%Get(i)))
    }

    Return ..SortDescending(values)
}

ClassMethod SortDescending(values As %DynamicArray) As %DynamicArray
{
    Set sorted = []

    For i=0:1:values.%Size()-1 {
        Do sorted.%Push(values.%Get(i))
    }

    For i=0:1:sorted.%Size()-2 {
        For j=i+1:1:sorted.%Size()-1 {
            If sorted.%Get(j) > sorted.%Get(i) {
                Set tmp = sorted.%Get(i)
                Do sorted.%Set(i, sorted.%Get(j))
                Do sorted.%Set(j, tmp)
            }
        }
    }

    Return sorted
}

ClassMethod CompareGrandeVectors(left As %DynamicArray, right As %DynamicArray) As %Integer
{
    For i=0:1:3 {
        If left.%Get(i) > right.%Get(i) {
            Return 1
        }

        If left.%Get(i) < right.%Get(i) {
            Return -1
        }
    }

    Return 0
}

ClassMethod ResolveGrandeWinner(gameState As %DynamicObject) As %DynamicObject
{
    Set hand = gameState.%Get("hand")
    Set cards = hand.%Get("cards")

    Set players = ["P1", "P2", "P3", "P4"]

    Set bestPlayerId = ""
    Set bestVector = ""

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId)
        Set vector = ..GetGrandeVector(playerCards)

        If bestPlayerId = "" {
            Set bestPlayerId = playerId
            Set bestVector = vector
        } Else {
            Set cmp = ..CompareGrandeVectors(vector, bestVector)

            If cmp > 0 {
                Set bestPlayerId = playerId
                Set bestVector = vector
            }
        }
    }

    Set bestTeam = ..GetPlayerTeam(gameState, bestPlayerId)

    Set result = {
        "playerId": (bestPlayerId),
        "team": (bestTeam),
        "vector": (bestVector)
    }

    Return result
}

ClassMethod AddPoints(gameState As %DynamicObject, team As %String, points As %Integer) As %DynamicObject
{
    Set score = gameState.%Get("score", "")

    If '$IsObject(score) {
        Set score = {
            "teamA": 0,
            "teamB": 0
        }
    }

    If team = "A" {
        Set current = +score.%Get("teamA", 0)
        Do score.%Set("teamA", current + points)
    }

    If team = "B" {
        Set current = +score.%Get("teamB", 0)
        Do score.%Set("teamB", current + points)
    }

    Do gameState.%Set("score", score)

    Return gameState
}

}
