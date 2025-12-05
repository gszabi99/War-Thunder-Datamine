options no_aot
require ecs
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sounds_events
require DagorConsole


[console_cmd(name="snd.set_human_voice_effect")]
def sound_set_human_voice_effect(name : string; enabled : bool)
  ecs::query() <| $ [es(REQUIRE=hero)] (var human_voice_effect__activeEffects : Object&)
    set_human_voice_effect(name, enabled, human_voice_effect__activeEffects)



[console_cmd(name="snd.human_voice_effect")]
def sound_human_voice_effect(phrase : string)
  ecs::query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    sendEvent(eid, CmdHumanVoiceEffect(phrase = phrase))
