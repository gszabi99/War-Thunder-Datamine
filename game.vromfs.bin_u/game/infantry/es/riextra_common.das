module riextra_common shared
require ecs
require ecs.safe

require RendInst
require DagorSystem


def ensure_riextra_res_idx(riextra_name : string)
  var resIndex = get_rigen_extra_res_idx(riextra_name)
  if resIndex < 0
    
    
    resIndex = rendinst_addRIGenExtraResIdx(riextra_name)
    if resIndex < 0
      logerr("Failed to add evt.riExtra=<{riextra_name}>({resIndex})!")
    else
      rendinst_addRiGenExtraDebris(uint(resIndex), 0)
  return resIndex


def preload_riextra_res_lod(riextra_name : string;
                            lod : uint = 0u)
  let resIdx = ensure_riextra_res_idx(riextra_name)
  if resIdx >= 0
    rendinst_updateRiExtraReqLod(uint(resIdx), lod)


def normalize_rendinst_rotation_angle(angle : float)
  var newAngle = angle
  while newAngle > 180.0
    newAngle -= 360.0
  while newAngle < -180.0
    newAngle += 360.0
  return newAngle
