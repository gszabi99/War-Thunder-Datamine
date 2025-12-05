require ecs
require soundEvent
require soundSystem
require soundHash
require math
require DngPlane
require DagorMath


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def plane_dive_siren(evt : Event;
                     plane_net_phys : PlaneActor;
                     transform : float3x4;
                     dive_siren__path : string;
                     dive_siren__threshold : float;
                     dive_siren__thresholdMul = 0.9;
                     dive_siren__enabled : bool;
                     var sound_event_group : SoundEventGroup&;
                     isAlive : bool)
  let spdSq = length_sq(float3(plane_net_phys.phys.vel))
  let id = sound_hash("diveSiren")
  let has = has_sound(sound_event_group, id)
  if !has && (isAlive && dive_siren__enabled && spdSq >= dive_siren__threshold * dive_siren__threshold && sound_banks_is_master_preset_loaded())
    add_sound(sound_event_group, id, play(dive_siren__path, transform[3]))
  elif has && (!isAlive || !dive_siren__enabled || spdSq < dive_siren__threshold * dive_siren__threshold * dive_siren__thresholdMul || !sound_banks_is_master_preset_loaded())
    if isAlive
      reject_sound(sound_event_group, id)
    else
      release_sound(sound_event_group, id)
