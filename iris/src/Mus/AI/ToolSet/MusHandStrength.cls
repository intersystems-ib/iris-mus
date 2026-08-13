Class Mus.AI.ToolSet.MusHandStrength Extends %AI.ToolSet [ DependsOn = Mus.AI.Tools.HandStrengthTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet ultraligero para valorar la fuerza de una mano de Mus.
        Sólo recibe cartas y lance. No recibe contexto de partida.
    </Description>

    <Tool Name="evaluate_play_strength"
          Class="Mus.AI.Tools.HandStrengthTools"
          Method="EvaluatePlayStrength">
        <Description>
            Evalúa la fuerza de una mano para un lance concreto de Mus.
            Entrada: cards como array JSON o texto separado por comas, y play como grande, chica, pares, juego o punto.
            Salida: very strong, strong, neutral, weak o very weak.
        </Description>
    </Tool>
</ToolSet>
}

}
