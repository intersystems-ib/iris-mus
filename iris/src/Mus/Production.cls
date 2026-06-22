Class Mus.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Mus.Production" LogGeneralTraceEvents="true">
  <Description>Mus game interoperability production</Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="Mus.BS.InternalEntryPoint" Category="Mus" ClassName="Mus.BS.InternalEntryPoint" PoolSize="1" Enabled="true" Foreground="false" Comment="Internal entry point used by external %CSP.REST API" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="TargetConfigName">Mus.BP.GameCoordinator</Setting>
  </Item>
  <Item Name="Mus.BP.GameCoordinator" Category="Mus" ClassName="Mus.BP.GameCoordinator" PoolSize="1" Enabled="true" Foreground="false" Comment="Main game coordinator" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="PersistenceTarget">Mus.BO.PersistenceOperation</Setting>
    <Setting Target="Host" Name="RuleEngineTarget">Mus.BP.RuleEngine</Setting>
  </Item>
  <Item Name="Mus.BP.RuleEngine" Category="Mus" ClassName="Mus.BP.RuleEngine" PoolSize="1" Enabled="true" Foreground="false" Comment="Mus rule validation engine" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Mus.BO.PersistenceOperation" Category="Mus" ClassName="Mus.BO.PersistenceOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="Game persistence operation" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Mus.BO.TournamentPersistenceOperation" Category="" ClassName="Mus.BO.TournamentPersistenceOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Mus.BP.TournamentCoordinator" Category="" ClassName="Mus.BP.TournamentCoordinator" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Mus.BO.AgentGameSimulationOperation" Category="" ClassName="Mus.BO.AgentGameSimulationOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
</Production>
}

}
