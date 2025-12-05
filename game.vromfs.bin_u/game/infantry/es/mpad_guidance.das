require ecs
require GuidanceLock
require %game.events


[es(track=human_gun_attached, REQUIRE=guidance_lock)]
def reset_guidance_lock_on_mpad_es(evt : Event; eid : EntityId; human_gun_attached : bool)
  if !human_gun_attached
    sendEventImmediate(eid, CmdGuidanceLockSwitch(on = false))
