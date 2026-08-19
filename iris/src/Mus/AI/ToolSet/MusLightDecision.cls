Class Mus.AI.ToolSet.MusLightDecision Extends %AI.ToolSet [ DependsOn = (Mus.AI.Tools.HandStrengthTools, Mus.AI.Tools.ScorePressureTools, Mus.AI.Tools.DiscardHandValueTools) ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet ligero para decisiones rapidas de Mus.
        No recibe gameStateJson ni contexto completo.
        Solo evalua fuerza por lance, presion de marcador y valor global de descarte.
    </Description>

    <Include Class="Mus.AI.Tools.HandStrengthTools"></Include>
    <Include Class="Mus.AI.Tools.ScorePressureTools"></Include>
    <Include Class="Mus.AI.Tools.DiscardHandValueTools"></Include>
</ToolSet>
}

}
