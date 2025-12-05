require ecs

require %appGame.wt_events


[es(tag=server)]
def shell_expl_disorientated_es(evt : EventShellExplodedServer;
                                disorientated__tinnitusRad : float2;
                                disorientated__tinnitusPower : float2;
                                disorientated__flashRad : float2 = float2();
                                disorientated__flashPower : float2 = float2();
                                disorientated__flashDistExp : float = 1.0;
                                disorientated__tinnitusDistExp : float = 1.0)
  find_query() <| $ [es(REQUIRE=msg_sink)] (eid : EntityId)
    sendEvent(
      eid,
      EventFlashExploded(
        pos = evt.pos,
        tinnitusRad = disorientated__tinnitusRad,
        flashRad = disorientated__flashRad,
        tinnitusPower = disorientated__tinnitusPower,
        flashPower = disorientated__flashPower,
        flashDistExp = disorientated__flashDistExp,
        tinnitusDistExp = disorientated__tinnitusDistExp,
        ignoreEid = INVALID_ENTITY_ID))
    return true
