Class Mus.AI.Tools.ScorePressureTools Extends %AI.Tool
{

ClassMethod EvaluateScorePressure(myScore As %Integer, opponentScore As %Integer, targetScore As %Integer = 40) As %DynamicObject
{
    Set result = {
        "success": false,
        "pressure": "low",
        "reason": "",
        "myScore": (+myScore),
        "opponentScore": (+opponentScore),
        "targetScore": (+targetScore),
        "myDistanceToTarget": 0,
        "opponentDistanceToTarget": 0,
        "trailing": false,
        "leading": false
    }
    Try {
        Set myScore = +myScore
        Set opponentScore = +opponentScore
        Set targetScore = +targetScore

        If targetScore <= 0 {
            Set targetScore = 40
        }

        Set myDistance = targetScore - myScore
        Set opponentDistance = targetScore - opponentScore

        If myDistance < 0 { Set myDistance = 0 }
        If opponentDistance < 0 { Set opponentDistance = 0 }

        Set trailing = opponentScore > myScore
        Set leading = myScore > opponentScore

        Do result.%Set("targetScore", targetScore)
        Do result.%Set("myDistanceToTarget", myDistance)
        Do result.%Set("opponentDistanceToTarget", opponentDistance)
        Do result.%Set("trailing", trailing)
        Do result.%Set("leading", leading)

        Set pressure = "low"
        Set reason = "Opponent is not close to target score"

        If opponentDistance <= 1 {
            Set pressure = "very high"
            Set reason = "Opponent is one point or less from winning"
        } ElseIf opponentDistance <= 3 {
            If trailing {
                Set pressure = "very high"
                Set reason = "Opponent is very close to winning and we are trailing"
            } Else {
                Set pressure = "high"
                Set reason = "Opponent is very close to target score"
            }
        } ElseIf opponentDistance <= 6 {
            If trailing {
                Set pressure = "high"
                Set reason = "Opponent is close to target score and we are trailing"
            } Else {
                Set pressure = "medium"
                Set reason = "Opponent is close to target score"
            }
        } ElseIf trailing && ((opponentScore - myScore) >= 8) {
            Set pressure = "medium"
            Set reason = "We are significantly behind"
        }

        If (pressure = "high") && (myDistance <= 3) {
            Set pressure = "medium"
            Set reason = "Both teams are close to winning; pressure is controlled"
        }

        Do result.%Set("success", "true")
        Do result.%Set("pressure", pressure)
        Do result.%Set("reason", reason)

        Return result
    } Catch ex {
        Do result.%Set("success", "false")
        Do result.%Set("pressure", "low")
        Do result.%Set("reason", ex.DisplayString())
        Return result
    }
}

}
