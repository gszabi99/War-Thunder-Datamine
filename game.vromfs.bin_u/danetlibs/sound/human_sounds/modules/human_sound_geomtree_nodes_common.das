module human_sound_geomtree_nodes_common shared

require ecs
require AnimV20
require soundSystem
require GeomNodeTree
require sound_utils.modules.sound_occlusion_common


def get_human_voice_3d_pos(is_watched_sound : bool; transform : float3x4; head_node_id  : int; animchar : AnimcharBaseComponent const?)
  if is_watched_sound
    return get_listener_pos()
  let pos = head_node_id >= 0 && animchar != null ? geomtree_getNodeWpos(*(*animchar).nodeTree, head_node_id) : transform[3]
  return prevent_wall_sound_occlusion(pos, transform[1])
