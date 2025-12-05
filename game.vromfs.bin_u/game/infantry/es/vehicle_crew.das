require ecs
require net
require Unit
require %game.unit.unit_events
require MPlayer
require %game.player_events


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
