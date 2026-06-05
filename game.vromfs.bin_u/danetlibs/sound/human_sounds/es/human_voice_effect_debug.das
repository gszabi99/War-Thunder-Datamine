options no_aot
require ecs
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sounds_events
require DagorConsole


def get_human_eid()
  var target = INVALID_ENTITY_ID
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid : EntityId)
    target = eid
  query() <| $ [es(REQUIRE=daeditor__selected)] (eid : EntityId)
    target = eid
  return target


[console_cmd(name="snd.set_human_voice_effect")]
def sound_set_human_voice_effect(name : string; enabled : bool)
  query(get_human_eid()) <| $ [es] (var human_voice_effect__activeEffects : Object&)
    set_human_voice_effect(name, enabled, human_voice_effect__activeEffects)



[console_cmd(name="snd.human_voice_effect")]
def sound_human_voice_effect(phrase : string)
  sendEvent(get_human_eid(), CmdHumanVoiceEffect(phrase = phrase))
