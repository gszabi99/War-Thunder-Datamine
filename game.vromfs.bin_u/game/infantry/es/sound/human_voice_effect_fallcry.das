require ecs
require app
require human_sounds.modules.human_voice_effect_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def human_voice_effect_fallcry_with_spawn_update(evt : Event;
                                                 transform : float3x4;
                                                 human_net_phys__isUnderwater : bool;
                                                 human_net_phys__deltaVelIgnoreAmount : float;
                                                 human_net_phys__velocity : float3;
                                                 human_voice_effect_fallcry__threshold : float;
                                                 human_spawn_sound__inSpawn : bool = false;
                                                 var human_voice_effect_fallcry__isFalling : bool&;
                                                 var human_voice_effect_fallcry__prevHTVel : float3&)
  let curTime = get_sync_time()
  let dt = max(0.0, curTime - human_voice_effect_fallcry__prevHTVel.x)
  if dt > 0.0
    let vertPos = transform[3].y
    let vertVel = (vertPos - human_voice_effect_fallcry__prevHTVel.y) / dt
    human_voice_effect_fallcry__prevHTVel = float3(curTime, vertPos, vertVel)
  let isRealFalling = human_voice_effect_fallcry__prevHTVel.z < -5.0
  human_voice_effect_fallcry__isFalling = (isRealFalling && human_net_phys__velocity.y < -human_voice_effect_fallcry__threshold &&
                                           human_net_phys__deltaVelIgnoreAmount <= 0. &&
                                           !human_spawn_sound__inSpawn &&
                                           !human_net_phys__isUnderwater)


[es(tag=sound, on_appear, before=human_voice_effect_on_change, track=(human_voice_effect_fallcry__enabled, human_voice_effect_fallcry__isFalling))]
def human_voice_effect_fallcry(evt : Event;
                               human_voice_effect_fallcry__enabled : bool;
                               human_voice_effect_fallcry__isFalling : bool;
                               var human_voice_effect__activeEffects : Object&)
  set_human_voice_effect("fallcry", human_voice_effect_fallcry__enabled && human_voice_effect_fallcry__isFalling, human_voice_effect__activeEffects)
