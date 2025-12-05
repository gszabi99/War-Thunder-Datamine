require ecs
require net
require WTInput
require %game.input.input_events

require %appGame.wt_events


[es(tag=input, REQUIRE=(human_mining_wall__wallEid, hero))]
def mining_wall_input_action_triggered(evt : EventOnKeyDown;
                                       eid : EntityId;
                                       input__enabled : bool = true;
                                       human_mining_wall__plantingPos : float3;
                                       human_mining_wall__plantingNorm : float3;
                                       human_mining_wall__wallEid : EntityId;
                                       human_mining_wall__isPlantingAvailable : bool;
                                       human_mining_wall__plantingStartTime : float;
                                       human_mining_wall__isReassemblingAvailable : bool;
                                       human_mining_wall__reassemblingPosition : float3;
                                       human_mining_wall__reassemblingEntityId : EntityId)
  if !input__enabled || human_mining_wall__plantingStartTime > 0.0
    return

  if evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    if human_mining_wall__isPlantingAvailable
      send_net_event(eid, CmdStartPlantingMineOnWall(
        pos = human_mining_wall__plantingPos,
        norm = human_mining_wall__plantingNorm,
        wallEid = human_mining_wall__wallEid
      ))
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_USE_ALT)
    if human_mining_wall__isReassemblingAvailable
      send_net_event(eid, CmdStartReassemblingWall(
        wallEid = human_mining_wall__reassemblingEntityId,
        position = human_mining_wall__reassemblingPosition
      ))


[es(tag=input, REQUIRE=(human_mining_wall__wallEid, hero))]
def mining_wall_input_action_terminated(evt : EventOnKeyUp;
                                        eid : EntityId;
                                        input__enabled : bool = true)
  if input__enabled && evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    send_net_event(eid, CmdStopPlantingMineOnWall())
  if input__enabled && evt.eventId == int(ShortcutEventId.ID_HUMAN_USE_ALT)
    send_net_event(eid, CmdStopReassemblingWall())
