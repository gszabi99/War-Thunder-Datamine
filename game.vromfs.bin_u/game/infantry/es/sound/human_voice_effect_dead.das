require ecs
require human_sounds.modules.human_voice_effect_common


[es(tag=sound, on_appear, before=human_voice_effect_on_change, track=isAlive)]
def human_voice_effect_dead(evt : Event;
                            isAlive : bool;
                            var human_voice_effect__activeEffects : Object&)
  set_human_voice_effect("dead", !isAlive, human_voice_effect__activeEffects)
