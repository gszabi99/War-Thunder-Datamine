require ecs
require AnimV20
require GeomNodeTree
require soundEvent
require sound_utils.modules.sound_control_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed)]
def human_sound_occlusion_update(evt : Event;
                                 sound_control__state : int;
                                 is_watched_sound : bool = false;
                                 isAlive : bool = true;
                                 human_sound_geomtree_nodes__pelvisNodeId : int = -1;
                                 animchar : AnimcharBaseComponent&;
                                 transform : float3x4;
                                 human_sound_occlusion__blobRadius : float;
                                 var human_sound_occlusion__blob : SoundOcclusionBlob&)
  let shouldPlay = have_sound(sound_control__state) && !is_watched_sound && isAlive
  if shouldPlay
    let pos = human_sound_geomtree_nodes__pelvisNodeId >= 0 ? geomtree_getNodeWpos(*animchar.nodeTree, human_sound_geomtree_nodes__pelvisNodeId) : transform[3] + transform[1] * human_sound_occlusion__blobRadius
    if is_inside_active_occlusion_range(pos)
      if is_valid_handle_value(human_sound_occlusion__blob)
        set_pos(human_sound_occlusion__blob, pos)
      else
        human_sound_occlusion__blob |> create_blob(pos, 0., human_sound_occlusion__blobRadius)
      return
  if is_valid_handle_value(human_sound_occlusion__blob)
    human_sound_occlusion__blob |> delete_blob()
