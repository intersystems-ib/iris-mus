Class Mus.AI.ToolSet.MusEcho Extends %AI.ToolSet [ DependsOn = Mus.AI.Tools.EchoTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet>
    <Description>
        ToolSet diagnostico minimo para medir el overhead de %AI.Agent con tool calling.
        Expone exclusivamente la herramienta Echo.
    </Description>

    <Policies>
        <Audit Class="Mus.AI.Policy.ToolAuditPolicy"/>
    </Policies>

    <Include Class="Mus.AI.Tools.EchoTools"></Include>
</ToolSet>
}

}
