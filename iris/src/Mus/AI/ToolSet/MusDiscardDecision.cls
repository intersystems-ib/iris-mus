Class Mus.AI.ToolSet.MusDiscardDecision Extends %AI.ToolSet [ DependsOn = Mus.AI.Tools.DiscardHandValueTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet ligero para fase de descartes de Mus.
        Solo permite valorar la mano globalmente para decidir entre pedir MUS o cortar MUS.
    </Description>

    <Include Class="Mus.AI.Tools.DiscardHandValueTools"></Include>
</ToolSet>
}

}
