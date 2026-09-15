Class Mus.AI.ToolSet.MusHandStrength Extends %AI.ToolSet [ DependsOn = Mus.AI.Tools.HandStrengthTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet diagnostico minimo para fases de apuesta de Mus.
        Solo expone EvaluatePlayStrength.
    </Description>

    <Policies>
        <Audit Class="Mus.AI.Policy.ToolAuditPolicy"/>
    </Policies>

    <Include Class="Mus.AI.Tools.HandStrengthTools" Tool="EvaluatePlayStrength"/>
</ToolSet>
}

}
