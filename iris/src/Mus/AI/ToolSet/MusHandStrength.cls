Class Mus.AI.ToolSet.MusHandStrength Extends %AI.ToolSet [ DependsOn = Mus.AI.Tools.HandStrengthTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet diagnostico minimo para fases de apuesta de Mus.
        Solo expone EvaluatePlayStrength.
    </Description>

    <Include Class="Mus.AI.Tools.HandStrengthTools" Tool="EvaluatePlayStrength"/>
</ToolSet>
}

}
