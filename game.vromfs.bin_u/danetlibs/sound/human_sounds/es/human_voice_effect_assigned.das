require ecs
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sounds_events


[es(tag=sound, on_appear)]
def human_voice_effect_assigned_appear(evt : Event;
                                       human_voice_effect_assigned__effect : string;
                                       var human_voice_effect__activeEffects : Object&)
  raise_human_voice_effect(human_voice_effect_assigned__effect, human_voice_effect__activeEffects)


[es(tag=sound, on_disappear)]
def human_voice_effect_assigned_disappear(evt : Event;
                                          eid : EntityId;
                                          human_voice_effect_assigned__effect : string;
                                          human_voice_effect_assigned__onDisappear : string;
                                          var human_voice_effect__activeEffects : Object&)
  clear_human_voice_effect(human_voice_effect_assigned__effect, human_voice_effect__activeEffects)
  if !empty(human_voice_effect_assigned__onDisappear)
    sendEvent(eid, CmdHumanVoiceEffect(phrase = human_voice_effect_assigned__onDisappear))
