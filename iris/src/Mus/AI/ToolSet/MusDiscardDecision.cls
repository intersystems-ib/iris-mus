Class Mus.AI.ToolSet.MusDiscardDecision Extends %AI.ToolSet [ DependsOn = Mus.AI.Tools.DiscardHandValueTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet ligero para fase de descartes de Mus.
        Solo expone EvaluateDiscardHandValue.
    </Description>

    <Include Class="Mus.AI.Tools.DiscardHandValueTools" Tool="EvaluateDiscardHandValue"/>
</ToolSet>
}

}
