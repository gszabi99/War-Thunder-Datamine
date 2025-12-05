require ecs
require %game.dm.dm_events
require %appGame.infantry.es.hitpoints_common
require PropsManager


[es(on_event=CmdRequestSuicide, tag=server, REQUIRE=hitpoints)]
def human_suicide_es(evt : Event;
                     eid aka hero_eid : EntityId)
                    
  
  query(hero_eid) <| $ [es] (vehicle__lastEid, possessedByPlr : EntityId; isInVehicle : bool)
    if !isInVehicle
      return

    query(vehicle__lastEid) <| $ [es] (ownedByPlayer : EntityId; vehicle_seats__seatEids : EidList)
      if ownedByPlayer != possessedByPlr
        return
      for seatEid in vehicle_seats__seatEids
        query(seatEid) <| $ [es] (seat__ownerEid : EntityId; seat__isOwnerAlive : bool)
          if seat__isOwnerAlive
            query(seat__ownerEid) <| $ [es] (eid aka crew_member_eid : EntityId)
              sendEvent(crew_member_eid, CmdKill(offender = hero_eid, damageType = uint16(int(DamageType.DM_EXPLOSION)), packedGunPropsId = props_pack_for_net(PropsId()), shellId = -1))
      sendEvent(vehicle__lastEid, CmdKillVehicle(offender = hero_eid))

  sendEvent(eid, CmdKill(offender = eid, damageType = uint16(int(DamageType.DM_MELEE)), packedGunPropsId = props_pack_for_net(PropsId()), shellId = -1))
