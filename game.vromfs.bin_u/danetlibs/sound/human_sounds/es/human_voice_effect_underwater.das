require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sounds_events
require DagorMath


[es(tag=sound, on_appear, before=human_voice_effect_on_change, track=human_breath__isUnderWater, REQUIRE=humanVoiceEffectUnderwater)]
def human_voice_effect_underwater__track_underwater(evt : Event;
                                                    eid : EntityId;
                                                    human_breath__timer : float;
                                                    human_breath__isUnderWater : bool;
                                                    human_breath__maxHoldBreathTime : float;
                                                    var sound_flags : Object&;
                                                    var sound_tags : Object&;
                                                    var human_voice_effect__activeEffects : Object&)
  if !human_breath__isUnderWater
    clear_sound_tag("headIsUnderwater", sound_flags)
    clear_sound_tag("headIsUnderwater", sound_tags)
  set_human_voice_effect("underwater", human_breath__isUnderWater, human_voice_effect__activeEffects)
  if !human_breath__isUnderWater
    let holdBreathTime = saturate(safediv(human_breath__timer, human_breath__maxHoldBreathTime))
    sendEvent(eid, CmdHumanVoiceEffect(phrase = "underwaterEnd", varName = "noairtime", varValue = holdBreathTime))


[es(tag=sound, track=human_voice_effect__activeEffects, REQUIRE=human_voice_effect__activeEffects, after=human_voice_effect_on_change)]
def human_voice_effect_underwater__after_apply_effect(evt : Event;
                                                      human_breath__isUnderWater : bool;
                                                      human_breath__timer : float;
                                                      human_breath__maxHoldBreathTime : float;
                                                      human_voice_effect__event : SoundEvent&;
                                                      var sound_flags : Object&)
  if human_breath__isUnderWater
    raise_sound_tag("headIsUnderwater", sound_flags) 

  if human_breath__timer > 0.
    let holdBreathTime = saturate(safediv(human_breath__timer, human_breath__maxHoldBreathTime))
    set_var_optional(human_voice_effect__event, "noairtime", holdBreathTime)
