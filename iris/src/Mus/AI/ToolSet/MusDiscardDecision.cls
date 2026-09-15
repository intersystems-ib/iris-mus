Class Mus.AI.ToolSet.MusDiscardDecision Extends %AI.ToolSet [ DependsOn = Mus.AI.Tools.DiscardHandValueTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet ligero para fase de descartes de Mus.
        Solo expone EvaluateDiscardHandValue.
    </Description>

    <Policies>
        <Audit Class="Mus.AI.Policy.ToolAuditPolicy"/>
    </Policies>

    <Include Class="Mus.AI.Tools.DiscardHandValueTools" Tool="EvaluateDiscardHandValue"/>
</ToolSet>
}

}
