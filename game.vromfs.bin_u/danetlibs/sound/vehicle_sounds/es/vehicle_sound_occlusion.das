require ecs
require soundEvent



[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def vehicle_sound_occlusion_update(evt : Event;
                                   transform : float3x4;
                                   is_watched_sound : bool;
                                   isAlive : bool = true;
                                   vehicle_sound_occlusion__radius : float;
                                   var vehicle_sound_occlusion__blob : SoundOcclusionBlob&)

  let shouldPlay = !is_watched_sound && isAlive
  if shouldPlay
    if is_valid_handle_value(vehicle_sound_occlusion__blob)
      set_pos(vehicle_sound_occlusion__blob, transform[3] + transform[1] * vehicle_sound_occlusion__radius)
    else
      vehicle_sound_occlusion__blob |> create_blob(transform[3] + transform[1] * vehicle_sound_occlusion__radius, 0., vehicle_sound_occlusion__radius)
  elif is_valid_handle_value(vehicle_sound_occlusion__blob)
    vehicle_sound_occlusion__blob |> delete_blob()
