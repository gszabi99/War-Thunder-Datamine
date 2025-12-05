options no_aot
require ecs
require DagorConsole


[console_cmd(name="camouflage.debug_track", hint="Enable camouflage recreating material on track")]
def camouflage_debug_track(enable : bool = true)
  query() <| $ [es(REQUIRE=camouflage_override)] (eid : EntityId;
                                                  camouflage_override_debug : Tag const?)
    if enable
      if camouflage_override_debug == null
        addSubTemplate(eid, "camouflage_override_debug_track")
    else
      if camouflage_override_debug != null
        removeSubTemplate(eid, "camouflage_override_debug_track")
