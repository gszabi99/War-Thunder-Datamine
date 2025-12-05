require ecs
require human_sounds.modules.human_voice_effect_common


[es(tag=sound, on_appear, before=human_voice_effect_on_change, track=burning__isBurning, REQUIRE=humanVoiceEffectBurning)]
def human_voice_effect_burning(evt : Event;
                               burning__isBurning : bool;
                               var human_voice_effect__activeEffects : Object&)
  set_human_voice_effect("burn", burning__isBurning, human_voice_effect__activeEffects)
