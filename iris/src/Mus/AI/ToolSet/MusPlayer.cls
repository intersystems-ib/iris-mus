Class Mus.AI.ToolSet.MusPlayer Extends %AI.ToolSet [ DependsOn = Mus.AI.Tools.GameTools ]
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="MusPlayer">
    <Description>
        Herramientas seguras para analizar el estado de una partida de Mus,
        construir contexto de jugador, recomendar acciones fallback y validar
        recomendaciones. Estas herramientas no modifican la partida.
    </Description>

    <Tool Name="get_player_context" Class="Mus.AI.Tools.GameTools" Method="GetPlayerContext">
        <Description>
            Construye el contexto visible y legal para un jugador concreto.
            Incluye fase, turno, cartas del jugador, acciones legales, perfil,
            fuerza estimada y estado de apuestas.
        </Description>
    </Tool>

    <Tool Name="recommend_fallback_action" Class="Mus.AI.Tools.GameTools" Method="RecommendFallbackAction">
        <Description>
            Genera una recomendacion determinista y segura usando la estrategia
            fallback del motor de Mus. No llama al LLM y no ejecuta acciones.
        </Description>
    </Tool>

    <Tool Name="validate_recommendation" Class="Mus.AI.Tools.GameTools" Method="ValidateRecommendation">
        <Description>
            Valida si una recomendacion JSON es legal para el contexto actual.
            Debe usarse antes de aceptar cualquier accion sugerida por el modelo.
        </Description>
    </Tool>

    <Tool Name="get_score_pressure" Class="Mus.AI.Tools.GameTools" Method="GetScorePressure">
        <Description>
            Calcula la presion de marcador para un jugador: distancia a 40 puntos,
            si el rival esta cerca de ganar, si hay emergencia, modo desesperacion,
            multiplicador de agresividad y presion de ordago.
        </Description>
    </Tool>
</ToolSet>
}

}
