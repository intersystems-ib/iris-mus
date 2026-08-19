Class Mus.AI.ToolSet.MusBettingDecision Extends %AI.ToolSet [ DependsOn = (Mus.AI.Tools.HandStrengthTools, Mus.AI.Tools.ScorePressureTools) ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet ligero para fases de apuesta de Mus.
        Solo permite evaluar fuerza de mano para el lance actual y presion de marcador.
        No contiene herramientas de descarte.
    </Description>

    <Include Class="Mus.AI.Tools.HandStrengthTools"></Include>
    <Include Class="Mus.AI.Tools.ScorePressureTools"></Include>
</ToolSet>
}

}
