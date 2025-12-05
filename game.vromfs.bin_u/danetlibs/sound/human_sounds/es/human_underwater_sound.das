require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sounds_events
require DagorMath


[es(tag=sound, on_appear, before=human_voice_effect_on_change, track=human_breath__isUnderWater)]
def human_underwater_sound_set(evt : Event;
                               eid : EntityId;
                               var sound_flags : Object&;
                               var sound_tags : Object&;
                               human_breath__isUnderWater : bool;
                               human_breath__maxHoldBreathTime : float;
                               var human_voice_effect__activeEffects : Object&)
  if !human_breath__isUnderWater
    clear_sound_tag("headIsUnderwater", sound_flags)
    clear_sound_tag("headIsUnderwater", sound_tags)
  set_human_voice_effect("underwater", human_breath__isUnderWater, human_voice_effect__activeEffects)
  if !human_breath__isUnderWater
    sendEvent(eid, CmdHumanVoiceEffect(phrase = "underwaterEnd", varName = "noairtime", varValue = human_breath__maxHoldBreathTime))



[es(tag=sound, track=human_voice_effect__activeEffects, REQUIRE=human_voice_effect__activeEffects, after=human_voice_effect_on_change)]
def human_underwater_sound_track(evt : Event;
                                 var sound_flags : Object&;
                                 human_breath__isUnderWater : bool)
  if human_breath__isUnderWater
    raise_sound_tag("headIsUnderwater", sound_flags)


[es(tag=sound, after=human_voice_effect_on_change, track=human_voice_effect__activeEffects, REQUIRE=human_voice_effect__activeEffects)]
def human_underwater_sound_set_var(evt : Event;
                                   human_breath__timer : float;
                                   human_breath__maxHoldBreathTime : float;
                                   human_voice_effect__event : SoundEvent&)
  if human_breath__timer > 0.
    set_var_optional(human_voice_effect__event, "noairtime", safediv(human_breath__timer, human_breath__maxHoldBreathTime))
