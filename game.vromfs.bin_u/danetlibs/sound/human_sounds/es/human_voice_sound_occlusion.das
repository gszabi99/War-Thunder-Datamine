require ecs
require AnimV20
require soundEvent
require sound_utils.modules.sound_control_common
require human_sounds.modules.human_sound_geomtree_nodes_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def human_voice_sound_occlusion_update(evt : Event;
                                       transform : float3x4;
                                       is_watched_sound : bool;
                                       human_sound_geomtree_nodes__headNodeId : int;
                                       animchar : AnimcharBaseComponent&;
                                       isAlive : bool = true;
                                       sound_control__state : int;
                                       human_voice_sound_occlusion__radius : float;
                                       human_voice_sound_occlusion__attachRadius : float;
                                       var human_voice_sound_occlusion__blob : SoundOcclusionBlob&)

  let shouldPlay = !is_watched_sound && isAlive && have_sound(sound_control__state)
  if shouldPlay
    let voicePos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
    if is_valid_handle_value(human_voice_sound_occlusion__blob)
      set_pos(human_voice_sound_occlusion__blob, voicePos)
    else
      human_voice_sound_occlusion__blob |> create_blob(voicePos, human_voice_sound_occlusion__attachRadius, human_voice_sound_occlusion__radius)
  elif is_valid_handle_value(human_voice_sound_occlusion__blob)
    human_voice_sound_occlusion__blob |> delete_blob()
