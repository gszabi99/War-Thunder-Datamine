require ecs
require app
require net
require WTInput
require DagorSystem
require %game.events
require %game.player_events
require %game.input.input_events

require %appGame.wt_events


[es(tag=input, REQUIRE=(isDrone, controlledHero))]
def drone_input_triggers(evt : EventOnKeyDown;
                         eid aka drone_eid : EntityId;
                         drone__owner : EntityId)
  if int(evt.eventId) == int(ShortcutEventId.ID_LEAVE_DRONE_CONTROLLING)
    sendEvent(drone_eid, CmdDroneReleaseControls())
  elif int(evt.eventId) == int(ShortcutEventId.ID_DRONE_SELF_DESTROY)
    send_net_event(drone__owner, CmdRequestDestroyDrone(droneEid = drone_eid))
