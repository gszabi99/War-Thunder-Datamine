module camera_common shared
require ecs
require math.base


def get_active_camera_tm()
  var tm = IDENT_TM
  query() <| $ [es] (camera__active : bool;
                     transform : float3x4)
    if camera__active
      tm = transform
  return tm
