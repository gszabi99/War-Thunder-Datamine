require ecs
require human_sounds.modules.human_voice_effect_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE_NOT=human_spawn_sound__inSpawn)]
def human_voice_effect_fallcry_update(evt : Event;
                                      human_net_phys__isUnderwater : bool;
                                      human_net_phys__deltaVelIgnoreAmount : float;
                                      human_net_phys__velocity : float3;
                                      human_voice_effect_fallcry__threshold : float;
                                      var human_voice_effect_fallcry__isFalling : bool&)
  human_voice_effect_fallcry__isFalling = (human_net_phys__velocity.y < -human_voice_effect_fallcry__threshold &&
                                           human_net_phys__deltaVelIgnoreAmount <= 0. &&
                                           !human_net_phys__isUnderwater)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def human_voice_effect_fallcry_with_spawn_update(evt : Event;
                                                 human_net_phys__isUnderwater : bool;
                                                 human_net_phys__deltaVelIgnoreAmount : float;
                                                 human_net_phys__velocity : float3;
                                                 human_voice_effect_fallcry__threshold : float;
                                                 human_spawn_sound__inSpawn : bool;
                                                 var human_voice_effect_fallcry__isFalling : bool&)
  human_voice_effect_fallcry__isFalling = (human_net_phys__velocity.y < -human_voice_effect_fallcry__threshold &&
                                           human_net_phys__deltaVelIgnoreAmount <= 0. &&
                                           !human_spawn_sound__inSpawn &&
                                           !human_net_phys__isUnderwater)


[es(tag=sound, on_appear, before=human_voice_effect_on_change, track=(human_voice_effect_fallcry__enabled, human_voice_effect_fallcry__isFalling))]
def human_voice_effect_fallcry(evt : Event;
                               human_voice_effect_fallcry__enabled : bool;
                               human_voice_effect_fallcry__isFalling : bool;
                               var human_voice_effect__activeEffects : Object&)
  set_human_voice_effect("fallcry", human_voice_effect_fallcry__enabled && human_voice_effect_fallcry__isFalling, human_voice_effect__activeEffects)
