require ecs
require net
require Unit
require %game.unit.unit_events
require MPlayer
require %game.player_events
require %game.dm.dm_events
require %appGame.infantry.es.hitpoints_common
require PropsManager


[es(tag=server)]
def move_crew_out_es(evt : CmdMoveCrewOut;
                     eid : EntityId;
                     ownedByPlr : EntityId)
  var player = player_get_by_eid(ownedByPlr)
  if player == null
    return
  player_crew_get(*player) <| $(crew)
    var switch_requested = false
    let crewToMoveOut = min(length(crew), evt.num_alive_members)
    for u, _ in crew, range(0, crewToMoveOut)
      if u.inVehicle.eid == eid
        sendEventImmediate(u.unit.eid, CmdRequestUnitCrewLeaveVehicle())
        if !switch_requested
          switch_requested = true
          sendEventImmediate(ownedByPlr, CmdPlayerSetControlledUnit(toEid = u.unit.eid))


[es(tag=server)]
def vehicle_seats_kill_crew_on_unit_became_dead_es(evt : EventUnitBecameDead;
                                                   eid : EntityId;
                                                   killerEid : EntityId;
                                                   vehicle_seats__seatEids : EidList)
  let offender = !!killerEid ? killerEid : eid
  var driverSwitched = false
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__playerEid : EntityId;
                              seat__ownerEid : EntityId;
                              seatOwnsEntityControl : bool)
      if !driverSwitched && seatOwnsEntityControl && !!seat__playerEid && !!seat__ownerEid
        driverSwitched = true
        sendEventImmediate(seat__playerEid, CmdPlayerSetControlledUnit(toEid = seat__ownerEid))
      if !!seat__ownerEid
        sendEvent(seat__ownerEid, CmdKill(offender = offender,
                                          damageType = uint16(int(DamageType.DM_EXPLOSION)),
                                          packedGunPropsId = props_pack_for_net(PropsId()),
                                          shellId = -1))


[es(tag=server, REQUIRE=vehicle_seats__seatEids)]
def human_vehicle_set_dead_es(evt : EventUnitBecameDead;
                              var isAlive : bool&)
  isAlive = false


[es(tag=server, REQUIRE=vehicle_seats__seatEids, on_event=EventUnitSpawned, on_event=EventUnitRespawn)]
def human_vehicle__set_alive_es(evt : Event;
                                var isAlive : bool&)
  isAlive = true
