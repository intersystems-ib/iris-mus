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

ClassMethod BuildInitialPhaseState(phase As %String) As %DynamicObject
{
    Set phaseState = {
        "name": (phase),
        "status": "open",
        "passedPlayers": [],
        "pendingBet": null,
        "acceptedBet": null,
        "lastAggressorPlayerId": "",
        "lastAggressorTeam": "",
        "respondingTeam": "",
        "pointsAtStake": 1
    }

    Return phaseState
}

ClassMethod BuildParesPhaseState(gameState As %DynamicObject) As %DynamicObject
{
    Set participants = []
    Set eligibility = {}

    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return ..BuildInitialPhaseState("pares")
    }

    Set cards = hand.%Get("cards", "")
    If '$IsObject(cards) {
        Return ..BuildInitialPhaseState("pares")
    }

    Set players = ["P1", "P2", "P3", "P4"]

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Continue
        }

        Set paresInfo = ..AnalyzePares(playerCards)

        Do eligibility.%Set(playerId, paresInfo)

        If paresInfo.%Get("hasPares", 0) {
            Do participants.%Push(playerId)
        }
    }

    Set phaseState = ..BuildInitialPhaseState("pares")
    Do phaseState.%Set("participants", participants)
    Do phaseState.%Set("eligibility", eligibility)

    Return phaseState
}

ClassMethod BuildJuegoPhaseState(gameState As %DynamicObject) As %DynamicObject
{
    Set participants = []
    Set eligibility = {}

    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return ..BuildInitialPhaseState("juego")
    }

    Set cards = hand.%Get("cards", "")
    If '$IsObject(cards) {
        Return ..BuildInitialPhaseState("juego")
    }

    Set players = ["P1", "P2", "P3", "P4"]

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Continue
        }

        Set juegoInfo = ..AnalyzeJuego(playerCards)

        Do eligibility.%Set(playerId, juegoInfo)

        If juegoInfo.%Get("hasJuego", 0) {
            Do participants.%Push(playerId)
        }
    }

    Set phaseState = ..BuildInitialPhaseState("juego")
    Do phaseState.%Set("participants", participants)
    Do phaseState.%Set("eligibility", eligibility)

    Return phaseState
}

ClassMethod BuildPuntoPhaseState(gameState As %DynamicObject) As %DynamicObject
{
    Set participants = []
    Set eligibility = {}

    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return ..BuildInitialPhaseState("punto")
    }

    Set cards = hand.%Get("cards", "")
    If '$IsObject(cards) {
        Return ..BuildInitialPhaseState("punto")
    }

    Set players = ["P1", "P2", "P3", "P4"]

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Continue
        }

        Set puntoInfo = ..AnalyzePunto(playerCards)

        Do eligibility.%Set(playerId, puntoInfo)
        Do participants.%Push(playerId)
    }

    Set phaseState = ..BuildInitialPhaseState("punto")
    Do phaseState.%Set("participants", participants)
    Do phaseState.%Set("eligibility", eligibility)

    Return phaseState
}

ClassMethod AnalyzePares(cards As %DynamicArray) As %DynamicObject
{
    Set counts = {}

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)

        /*
          GetMusCardValue ya aplica equivalencias:
          1/2 -> 1
          3/12 -> 10
        */
        Set value = ..GetMusCardValue(card)
        Set key = ""_value
        Set current = +counts.%Get(key, 0)

        Do counts.%Set(key, current + 1)
    }

    Set pairValues = []
    Set tripleValues = []
    Set fourValues = []

    Set iter = counts.%GetIterator()

    While iter.%GetNext(.key, .count) {
        Set value = +key

        If count >= 4 {
            Do fourValues.%Push(value)
        } ElseIf count = 3 {
            Do tripleValues.%Push(value)
        } ElseIf count = 2 {
            Do pairValues.%Push(value)
        }
    }

    Set pairValues = ..SortDescending(pairValues)
    Set tripleValues = ..SortDescending(tripleValues)
    Set fourValues = ..SortDescending(fourValues)

    If fourValues.%Size() > 0 {
        Set value = fourValues.%Get(0)

        Return {
            "hasPares": 1,
            "type": "duples",
            "rank": 3,
            "vector": [3, (value), (value)]
        }
    }

    If pairValues.%Size() >= 2 {
        Return {
            "hasPares": 1,
            "type": "duples",
            "rank": 3,
            "vector": [3, (pairValues.%Get(0)), (pairValues.%Get(1))]
        }
    }

    If tripleValues.%Size() > 0 {
        Return {
            "hasPares": 1,
            "type": "medias",
            "rank": 2,
            "vector": [2, (tripleValues.%Get(0))]
        }
    }

    If pairValues.%Size() = 1 {
        Return {
            "hasPares": 1,
            "type": "pares",
            "rank": 1,
            "vector": [1, (pairValues.%Get(0))]
        }
    }

    Return {
        "hasPares": 0,
        "type": "none",
        "rank": 0,
        "vector": [0]
    }
}

ClassMethod AnalyzeJuego(cards As %DynamicArray) As %DynamicObject
{
    Set total = ..GetJuegoTotal(cards)
    Set hasJuego = 0

    If total >= 31 {
        Set hasJuego = 1
    }

    Set rankWeight = ..GetJuegoRankWeight(total)

    Return {
        "hasJuego": (hasJuego),
        "total": (total),
        "rankWeight": (rankWeight),
        "vector": [(rankWeight), (total)]
    }
}

ClassMethod AnalyzePunto(cards As %DynamicArray) As %DynamicObject
{
    Set total = ..GetJuegoTotal(cards)

    Return {
        "total": (total),
        "vector": [(total)]
    }
}

ClassMethod ResolvePhaseWinner(gameState As %DynamicObject, phase As %String) As %DynamicObject
{
    If phase = "grande" {
        Return ..ResolveGrandeWinner(gameState)
    }

    If phase = "chica" {
        Return ..ResolveChicaWinner(gameState)
    }

    If phase = "pares" {
        Return ..ResolveParesWinner(gameState)
    }

    If phase = "juego" {
        Return ..ResolveJuegoWinner(gameState)
    }

    If phase = "punto" {
        Return ..ResolvePuntoWinner(gameState)
    }

    Set result = {
        "playerId": "",
        "team": "",
        "phase": (phase),
        "error": "Unsupported phase winner resolution"
    }

    Return result
}

ClassMethod ResolveGrandeWinner(gameState As %DynamicObject) As %DynamicObject
{
    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return {
            "playerId": "",
            "team": "",
            "phase": "grande",
            "error": "Hand not found"
        }
    }

    Set cards = hand.%Get("cards", "")
    If '$IsObject(cards) {
        Return {
            "playerId": "",
            "team": "",
            "phase": "grande",
            "error": "Cards not found"
        }
    }

    Set players = ["P1", "P2", "P3", "P4"]

    Set bestPlayerId = ""
    Set bestVector = ""

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Continue
        }

        Set vector = ..GetGrandeVector(playerCards)

        If bestPlayerId = "" {
            Set bestPlayerId = playerId
            Set bestVector = vector
        } Else {
            Set cmp = ..CompareVectors(vector, bestVector)

            If cmp > 0 {
                Set bestPlayerId = playerId
                Set bestVector = vector
            }
        }
    }

    Set bestTeam = ..GetPlayerTeam(gameState, bestPlayerId)

    Set result = {
        "phase": "grande",
        "playerId": (bestPlayerId),
        "team": (bestTeam),
        "vector": (bestVector)
    }

    Return result
}

ClassMethod ResolveChicaWinner(gameState As %DynamicObject) As %DynamicObject
{
    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return {
            "playerId": "",
            "team": "",
            "phase": "chica",
            "error": "Hand not found"
        }
    }

    Set cards = hand.%Get("cards", "")
    If '$IsObject(cards) {
        Return {
            "playerId": "",
            "team": "",
            "phase": "chica",
            "error": "Cards not found"
        }
    }

    Set players = ["P1", "P2", "P3", "P4"]

    Set bestPlayerId = ""
    Set bestVector = ""

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Continue
        }

        Set vector = ..GetChicaVector(playerCards)

        If bestPlayerId = "" {
            Set bestPlayerId = playerId
            Set bestVector = vector
        } Else {
            Set cmp = ..CompareVectors(vector, bestVector)

            If cmp < 0 {
                Set bestPlayerId = playerId
                Set bestVector = vector
            }
        }
    }

    Set bestTeam = ..GetPlayerTeam(gameState, bestPlayerId)

    Set result = {
        "phase": "chica",
        "playerId": (bestPlayerId),
        "team": (bestTeam),
        "vector": (bestVector)
    }

    Return result
}

ClassMethod ResolveParesWinner(gameState As %DynamicObject) As %DynamicObject
{
    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return {
            "playerId": "",
            "team": "",
            "phase": "pares",
            "error": "Hand not found"
        }
    }

    Set cards = hand.%Get("cards", "")
    If '$IsObject(cards) {
        Return {
            "playerId": "",
            "team": "",
            "phase": "pares",
            "error": "Cards not found"
        }
    }

    Set players = ["P1", "P2", "P3", "P4"]

    Set bestPlayerId = ""
    Set bestInfo = ""

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Continue
        }

        Set paresInfo = ..AnalyzePares(playerCards)

        If 'paresInfo.%Get("hasPares", 0) {
            Continue
        }

        If bestPlayerId = "" {
            Set bestPlayerId = playerId
            Set bestInfo = paresInfo
        } Else {
            Set cmp = ..CompareVectors(
                paresInfo.%Get("vector"),
                bestInfo.%Get("vector")
            )

            If cmp > 0 {
                Set bestPlayerId = playerId
                Set bestInfo = paresInfo
            }
        }
    }

    Set bestTeam = ..GetPlayerTeam(gameState, bestPlayerId)

    Return {
        "phase": "pares",
        "playerId": (bestPlayerId),
        "team": (bestTeam),
        "pares": (bestInfo)
    }
}

ClassMethod ResolveJuegoWinner(gameState As %DynamicObject) As %DynamicObject
{
    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return { "playerId": "", "team": "", "phase": "juego", "error": "Hand not found" }
    }

    Set cards = hand.%Get("cards", "")
    If '$IsObject(cards) {
        Return { "playerId": "", "team": "", "phase": "juego", "error": "Cards not found" }
    }

    Set players = ["P1", "P2", "P3", "P4"]
    Set manoPlayerId = ..GetInitialTurnPlayerIdForGameState(gameState)
    Set bestPlayerId = ""
    Set bestInfo = ""
    Set bestCards = ""

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId, "")
        If '$IsObject(playerCards) {
            Continue
        }

        Set juegoInfo = ..AnalyzeJuego(playerCards)
        If 'juegoInfo.%Get("hasJuego", 0) {
            Continue
        }

        If bestPlayerId = "" {
            Set bestPlayerId = playerId
            Set bestInfo = juegoInfo
            Set bestCards = playerCards
        } Else {
            Set cmp = ..CompareJuegoCandidates(playerId, playerCards, juegoInfo, bestPlayerId, bestCards, bestInfo, manoPlayerId)
            If cmp > 0 {
                Set bestPlayerId = playerId
                Set bestInfo = juegoInfo
                Set bestCards = playerCards
            }
        }
    }

    Set bestTeam = ..GetPlayerTeam(gameState, bestPlayerId)
    Return { "phase": "juego", "playerId": (bestPlayerId), "team": (bestTeam), "juego": (bestInfo), "tieBreak": { "manoPlayerId": (manoPlayerId), "isLaReal": (..IsLaRealJuego(bestCards)), "figureCount": (..CountJuegoFigures(bestCards)) } }
}

ClassMethod CompareJuegoCandidates(candidatePlayerId As %String, candidateCards As %DynamicArray, candidateInfo As %DynamicObject, bestPlayerId As %String, bestCards As %DynamicArray, bestInfo As %DynamicObject, manoPlayerId As %String) As %Integer
{
    Set cmp = ..CompareVectors(candidateInfo.%Get("vector"), bestInfo.%Get("vector"))
    If cmp '= 0 { Return cmp }

    Set candidateTotal = +candidateInfo.%Get("total", 0)
    Set bestTotal = +bestInfo.%Get("total", 0)
    If candidateTotal '= bestTotal { Return 0 }

    If candidateTotal = 31 {
        Set candidateReal = ..IsLaRealJuego(candidateCards)
        Set bestReal = ..IsLaRealJuego(bestCards)
        If candidateReal && 'bestReal { Return 1 }
        If bestReal && 'candidateReal { Return -1 }
    }

    If candidatePlayerId = manoPlayerId, bestPlayerId '= manoPlayerId { Return 1 }
    If bestPlayerId = manoPlayerId, candidatePlayerId '= manoPlayerId { Return -1 }

    Set candidateFigures = ..CountJuegoFigures(candidateCards)
    Set bestFigures = ..CountJuegoFigures(bestCards)
    If candidateFigures > bestFigures { Return 1 }
    If candidateFigures < bestFigures { Return -1 }

    Return 0
}

ClassMethod IsLaRealJuego(cards As %DynamicArray) As %Boolean
{
    If '$IsObject(cards) { Return 0 }
    If cards.%Size() '= 4 { Return 0 }
    If ..GetJuegoTotal(cards) '= 31 { Return 0 }

    Set sevenCount = 0
    Set figureCount = 0
    For i=0:1:cards.%Size()-1 {
        Set rank = ..GetCardRank(cards.%Get(i))
        If rank = 7 { Set sevenCount = sevenCount + 1 }
        ElseIf ..IsJuegoFigureRank(rank) { Set figureCount = figureCount + 1 }
    }

   Return (sevenCount = 3) && (figureCount = 1)
}

ClassMethod CountJuegoFigures(cards As %DynamicArray) As %Integer
{
    Set count = 0
    If '$IsObject(cards) { Return count }
    For i=0:1:cards.%Size()-1 {
        If ..IsJuegoFigureRank(..GetCardRank(cards.%Get(i))) { Set count = count + 1 }
    }
    Return count
}

ClassMethod IsJuegoFigureRank(rank As %Integer) As %Boolean
{
    Return (rank = 3) || (rank = 10) || (rank = 11) || (rank = 12)
}

ClassMethod GetCardRank(card As %String) As %Integer
{
    Set rankText = ""
    For i=1:1:$Length(card) {
        Set ch = $Extract(card, i)
        If ch?1N { Set rankText = rankText_ch } Else { Quit }
    }
    If rankText = "" { Return 0 }
    Return +rankText
}

ClassMethod ResolvePuntoWinner(gameState As %DynamicObject) As %DynamicObject
{
    Set hand = gameState.%Get("hand", "")
    If '$IsObject(hand) {
        Return {
            "playerId": "",
            "team": "",
            "phase": "punto",
            "error": "Hand not found"
        }
    }

    Set cards = hand.%Get("cards", "")
    If '$IsObject(cards) {
        Return {
            "playerId": "",
            "team": "",
            "phase": "punto",
            "error": "Cards not found"
        }
    }

    Set players = ["P1", "P2", "P3", "P4"]

    Set bestPlayerId = ""
    Set bestInfo = ""

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)
        Set playerCards = cards.%Get(playerId, "")

        If '$IsObject(playerCards) {
            Continue
        }

        Set puntoInfo = ..AnalyzePunto(playerCards)

        If bestPlayerId = "" {
            Set bestPlayerId = playerId
            Set bestInfo = puntoInfo
        } Else {
            Set cmp = ..CompareVectors(
                puntoInfo.%Get("vector"),
                bestInfo.%Get("vector")
            )

            If cmp > 0 {
                Set bestPlayerId = playerId
                Set bestInfo = puntoInfo
            }
        }
    }

    Set bestTeam = ..GetPlayerTeam(gameState, bestPlayerId)

    Return {
        "phase": "punto",
        "playerId": (bestPlayerId),
        "team": (bestTeam),
        "punto": (bestInfo)
    }
}

ClassMethod GetParesCountPoints(paresInfo As %DynamicObject) As %Integer
{
    Set type = paresInfo.%Get("type", "")

    If type = "pares" {
        Return 1
    }

    If type = "medias" {
        Return 2
    }

    If type = "duples" {
        Return 3
    }

    Return 0
}

ClassMethod GetPlayerParesCountPoints(gameState As %DynamicObject, playerId As %String) As %Integer
{
    Set hand = gameState.%Get("hand", "")

    If '$IsObject(hand) {
        Return 0
    }

    Set cards = hand.%Get("cards", "")

    If '$IsObject(cards) {
        Return 0
    }

    Set playerCards = cards.%Get(playerId, "")

    If '$IsObject(playerCards) {
        Return 0
    }

    Set paresInfo = ..AnalyzePares(playerCards)

    If 'paresInfo.%Get("hasPares", 0) {
        Return 0
    }

    Return ..GetParesCountPoints(paresInfo)
}

ClassMethod GetParesCountPointsForTeam(gameState As %DynamicObject, team As %String) As %Integer
{
    Set total = 0
    Set players = ["P1", "P2", "P3", "P4"]

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)

        If ..GetPlayerTeam(gameState, playerId) '= team {
            Continue
        }

        Set total = total + ..GetPlayerParesCountPoints(gameState, playerId)
    }

    Return total
}

ClassMethod GetParesCountPointsByTeam(gameState As %DynamicObject) As %DynamicObject
{
    Set result = {"A": 0, "B": 0}

    Do result.%Set("A", ..GetParesCountPointsForTeam(gameState, "A"))
    Do result.%Set("B", ..GetParesCountPointsForTeam(gameState, "B"))

    Return result
}

ClassMethod GetWinnerParesCountPoints(gameState As %DynamicObject) As %Integer
{
    Set winner = ..ResolveParesWinner(gameState)
    Set winnerTeam = winner.%Get("team", "")

    If winnerTeam = "" {
        Return 0
    }

    Return ..GetParesCountPointsForTeam(gameState, winnerTeam)
}

ClassMethod GetJuegoCountPoints(juegoInfo As %DynamicObject) As %Integer
{
    Set total = +juegoInfo.%Get("total", 0)

    If total = 31 {
        Return 3
    }

    If total >= 32 {
        Return 2
    }

    Return 0
}

ClassMethod GetPlayerJuegoCountPoints(gameState As %DynamicObject, playerId As %String) As %Integer
{
    Set hand = gameState.%Get("hand", "")

    If '$IsObject(hand) {
        Return 0
    }

    Set cards = hand.%Get("cards", "")

    If '$IsObject(cards) {
        Return 0
    }

    Set playerCards = cards.%Get(playerId, "")

    If '$IsObject(playerCards) {
        Return 0
    }

    Set juegoInfo = ..AnalyzeJuego(playerCards)

    If 'juegoInfo.%Get("hasJuego", 0) {
        Return 0
    }

    Return ..GetJuegoCountPoints(juegoInfo)
}

ClassMethod GetJuegoCountPointsForTeam(gameState As %DynamicObject, team As %String) As %Integer
{
    Set total = 0
    Set players = ["P1", "P2", "P3", "P4"]

    For i=0:1:players.%Size()-1 {
        Set playerId = players.%Get(i)

        If ..GetPlayerTeam(gameState, playerId) '= team {
            Continue
        }

        Set total = total + ..GetPlayerJuegoCountPoints(gameState, playerId)
    }

    Return total
}

ClassMethod GetJuegoCountPointsByTeam(gameState As %DynamicObject) As %DynamicObject
{
    Set result = {"A": 0, "B": 0}

    Do result.%Set("A", ..GetJuegoCountPointsForTeam(gameState, "A"))
    Do result.%Set("B", ..GetJuegoCountPointsForTeam(gameState, "B"))

    Return result
}

ClassMethod GetWinnerJuegoCountPoints(gameState As %DynamicObject) As %Integer
{
    Set winner = ..ResolveJuegoWinner(gameState)
    Set winnerTeam = winner.%Get("team", "")

    If winnerTeam = "" {
        Return 0
    }

    Return ..GetJuegoCountPointsForTeam(gameState, winnerTeam)
}

ClassMethod GetWinnerPuntoCountPoints(gameState As %DynamicObject) As %Integer
{
    Return 1
}

ClassMethod GetNextPhase(phase As %String) As %String
{
    If phase = "grande" {
        Return "chica"
    }

    If phase = "chica" {
        Return "pares"
    }

    If phase = "pares" {
        Return "juego"
    }

    If phase = "juego" {
        Return "manoCerrada"
    }

    If phase = "punto" {
        Return "manoCerrada"
    }

    Return ""
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

ClassMethod GetTargetScore(gameState As %DynamicObject) As %Integer
{
    Set targetScore = +gameState.%Get("targetScore", 40)

    If targetScore <= 0 {
        Set targetScore = 40
    }

    Return targetScore
}

ClassMethod GetWinningTeam(gameState As %DynamicObject) As %String
{
    Set score = gameState.%Get("score", "")

    If '$IsObject(score) {
        Return ""
    }

    Set targetScore = ..GetTargetScore(gameState)
    Set teamA = +score.%Get("teamA", 0)
    Set teamB = +score.%Get("teamB", 0)

    If teamA >= targetScore, teamA >= teamB {
        Return "A"
    }

    If teamB >= targetScore, teamB >= teamA {
        Return "B"
    }

    Return ""
}

ClassMethod IsGameFinished(gameState As %DynamicObject) As %Boolean
{
    If gameState.%Get("status", "") = "finished" {
        Return 1
    }

    If ..GetWinningTeam(gameState) '= "" {
        Return 1
    }

    Return 0
}

ClassMethod GetHandDealerPlayerId(gameState As %DynamicObject) As %String
{
    Set hand = gameState.%Get("hand", "")

    If $IsObject(hand) {
        Set dealerPlayerId = hand.%Get("dealerPlayerId", "")

        If dealerPlayerId '= "" {
            Return dealerPlayerId
        }
    }

    Return gameState.%Get("dealerPlayerId", "")
}

ClassMethod GetInitialTurnPlayerIdForGameState(gameState As %DynamicObject) As %String
{
    /*
      En este proyecto dealerPlayerId identifica al jugador mano de la mano
      actual. Por tanto las jugadas/lances deben empezar por ese jugador, no
      por GetNextPlayerId(dealerPlayerId). Se mantienen aliases explicitos para
      estados nuevos, pero el fallback compatible usa dealerPlayerId tal cual.
    */
    Set hand = gameState.%Get("hand", "")

    If $IsObject(hand) {
        Set candidate = hand.%Get("manoPlayerId", "")
        If ..IsPlayerId(candidate) { Return candidate }

        Set candidate = hand.%Get("handPlayerId", "")
        If ..IsPlayerId(candidate) { Return candidate }

        Set candidate = hand.%Get("startPlayerId", "")
        If ..IsPlayerId(candidate) { Return candidate }

        Set candidate = hand.%Get("initialTurnPlayerId", "")
        If ..IsPlayerId(candidate) { Return candidate }

        Set candidate = hand.%Get("dealerPlayerId", "")
        If ..IsPlayerId(candidate) { Return candidate }
    }

    Set candidate = gameState.%Get("manoPlayerId", "")
    If ..IsPlayerId(candidate) { Return candidate }

    Set candidate = gameState.%Get("handPlayerId", "")
    If ..IsPlayerId(candidate) { Return candidate }

    Set candidate = gameState.%Get("startPlayerId", "")
    If ..IsPlayerId(candidate) { Return candidate }

    Set candidate = gameState.%Get("initialTurnPlayerId", "")
    If ..IsPlayerId(candidate) { Return candidate }

    Set candidate = gameState.%Get("dealerPlayerId", "")
    If ..IsPlayerId(candidate) { Return candidate }

    Return "P1"
}

ClassMethod IsPlayerId(playerId As %String) As %Boolean
{
    If playerId = "P1" { Return 1 }
    If playerId = "P2" { Return 1 }
    If playerId = "P3" { Return 1 }
    If playerId = "P4" { Return 1 }
    Return 0
}

ClassMethod GetInitialTurnPlayerIdForHand(dealerPlayerId As %String) As %String
{
    If ..IsPlayerId(dealerPlayerId) {
        Return dealerPlayerId
    }

    Return "P1"
}

ClassMethod GetNextDealerPlayerId(currentDealerPlayerId As %String) As %String
{
    If currentDealerPlayerId = "" {
        Return "P1"
    }

    Return ..GetNextPlayerId(currentDealerPlayerId)
}

ClassMethod GetPlayerOrderFrom(firstPlayerId As %String) As %DynamicArray
{
    Set order = []

    If firstPlayerId = "" {
        Set firstPlayerId = "P1"
    }

    Set current = firstPlayerId

    For i=1:1:4 {
        Do order.%Push(current)
        Set current = ..GetNextPlayerId(current)
    }

    Return order
}

ClassMethod OrderParticipantsFrom(participants As %DynamicArray, firstPlayerId As %String) As %DynamicArray
{
    Set ordered = []
    Set order = ..GetPlayerOrderFrom(firstPlayerId)

    For i=0:1:order.%Size()-1 {
        Set playerId = order.%Get(i)

        For j=0:1:participants.%Size()-1 {
            If participants.%Get(j) = playerId {
                Do ordered.%Push(playerId)
            }
        }
    }

    Return ordered
}

ClassMethod GetFirstParticipantFrom(participants As %DynamicArray, firstPlayerId As %String) As %String
{
    Set ordered = ..OrderParticipantsFrom(participants, firstPlayerId)

    If ordered.%Size() = 0 {
        Return ""
    }

    Return ordered.%Get(0)
}

ClassMethod FinishGameForTeam(gameState As %DynamicObject, winningTeam As %String) As %DynamicObject
{
    Set targetScore = ..GetTargetScore(gameState)

    Set score = gameState.%Get("score", "")
    If '$IsObject(score) {
        Set score = {"teamA": 0, "teamB": 0}
    }

    /*
      La partida se muestra con marcador recortado al objetivo configurado
      (40 por defecto). La liquidacion de cierre debe ejecutarse antes de
      llegar aqui; FinishGameForTeam solo normaliza el marcador final visible.
    */
    If winningTeam = "A" {
        Do score.%Set("teamA", targetScore)
    } ElseIf winningTeam = "B" {
        Do score.%Set("teamB", targetScore)
    }

    Do gameState.%Set("score", score)
    Do gameState.%Set("status", "finished")
    Do gameState.%Set("winnerTeam", winningTeam)
    Do gameState.%Set("finishedAt", $ZDATETIME($HOROLOG, 3))
    Do gameState.%Set("nextAction", "")
    Do gameState.%Set("turnPlayerId", "")

    Set hand = gameState.%Get("hand", "")
    If $IsObject(hand) {
        Do hand.%Set("status", "closed")
        Do hand.%Set("phase", "manoCerrada")
        Do hand.%Set("turnPlayerId", "")
        Do gameState.%Set("hand", hand)
    }

    Do gameState.%Set("phase", "manoCerrada")

    Return gameState
}

ClassMethod GetGrandeVector(cards As %DynamicArray) As %DynamicArray
{
    Set values = []

    For i=0:1:cards.%Size()-1 {
        Do values.%Push(..GetMusCardValue(cards.%Get(i)))
    }

    Return ..SortDescending(values)
}

ClassMethod GetChicaVector(cards As %DynamicArray) As %DynamicArray
{
    Set values = []

    For i=0:1:cards.%Size()-1 {
        Do values.%Push(..GetMusCardValue(cards.%Get(i)))
    }

    Return ..SortAscending(values)
}

ClassMethod GetMusCardValue(card As %String) As %Integer
{
    Set rank = +$Extract(card, 1, *-1)

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

ClassMethod GetJuegoCardValue(card As %String) As %Integer
{
    Set rank = +$Extract(card, 1, *-1)

    If rank = 3 {
        Return 10
    }

    If rank = 12 {
        Return 10
    }

    If rank = 11 {
        Return 10
    }

    If rank = 10 {
        Return 10
    }

    If rank = 2 {
        Return 1
    }

    If rank = 1 {
        Return 1
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

    Return 0
}

ClassMethod GetJuegoTotal(cards As %DynamicArray) As %Integer
{
    Set total = 0

    For i=0:1:cards.%Size()-1 {
        Set total = total + ..GetJuegoCardValue(cards.%Get(i))
    }

    Return total
}

ClassMethod GetJuegoRankWeight(total As %Integer) As %Integer
{
    /*
      Vector mayor gana.

      Orden implementado:
      31 > 32 > 40 > 37 > 36 > 35 > 34 > 33

      En baraja espanola sin ochos ni nueves, los totales habituales con juego
      son 31, 32, 33, 34, 35, 36, 37 y 40.
    */

    If total = 31 {
        Return 8
    }

    If total = 32 {
        Return 7
    }

    If total = 40 {
        Return 6
    }

    If total = 37 {
        Return 5
    }

    If total = 36 {
        Return 4
    }

    If total = 35 {
        Return 3
    }

    If total = 34 {
        Return 2
    }

    If total = 33 {
        Return 1
    }

    Return 0
}

ClassMethod HasPeterete(cards As %DynamicArray) As %Boolean
{
    If '$IsObject(cards) {
        Return 0
    }

    If cards.%Size() '= 4 {
        Return 0
    }

    Set has4 = 0
    Set has5 = 0
    Set has6 = 0
    Set has7 = 0

    For i=0:1:cards.%Size()-1 {
        Set card = cards.%Get(i)
        Set value = ..GetMusCardValue(card)

        If value = 4 {
            Set has4 = 1
        } ElseIf value = 5 {
            Set has5 = 1
        } ElseIf value = 6 {
            Set has6 = 1
        } ElseIf value = 7 {
            Set has7 = 1
        }
    }

    If has4 && has5 && has6 && has7 {
        Return 1
    }

    Return 0
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

ClassMethod SortAscending(values As %DynamicArray) As %DynamicArray
{
    Set sorted = []

    For i=0:1:values.%Size()-1 {
        Do sorted.%Push(values.%Get(i))
    }

    For i=0:1:sorted.%Size()-2 {
        For j=i+1:1:sorted.%Size()-1 {
            If sorted.%Get(j) < sorted.%Get(i) {
                Set tmp = sorted.%Get(i)
                Do sorted.%Set(i, sorted.%Get(j))
                Do sorted.%Set(j, tmp)
            }
        }
    }

    Return sorted
}

ClassMethod CompareVectors(left As %DynamicArray, right As %DynamicArray) As %Integer
{
    Set max = left.%Size()

    If right.%Size() < max {
        Set max = right.%Size()
    }

    For i=0:1:max-1 {
        If left.%Get(i) > right.%Get(i) {
            Return 1
        }

        If left.%Get(i) < right.%Get(i) {
            Return -1
        }
    }

    Return 0
}

}
