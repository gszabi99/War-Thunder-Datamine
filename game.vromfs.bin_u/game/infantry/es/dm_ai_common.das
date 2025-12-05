module dm_ai_common shared
require math


enum DMAIPoint
  BODY = 0
  TURRET = 1
  BARREL = 2
  TRACK = 3
  WHEEL = 4
  ENGINE = 5
  CREW = 6


enum DMAIPointValue
  NONE
  PRIMARY
  SECONDARY

def evaluate_dm_ai_point_for_shot(pos : float3; transform : float3x4; shoot_pos : float3; no_crew : bool; allow_from_front : bool; part_type : int)
  let normDir = normalize(pos - transform[3])
  let lookDir = normalize(pos - shoot_pos)
  let headDir = transform[0]
  let lookCos = dot(lookDir.xz, normDir.xz)
  let headCos = dot(lookDir.xz, headDir.xz)

  let SIDE_HEIGHT_SIN = 0.3 
  let INFRONT_DIR_COS = 0.8 

  let fromBelow = lookDir.y > SIDE_HEIGHT_SIN
  let fromAbove = lookDir.y < -SIDE_HEIGHT_SIN
  let fromFront = headCos < -INFRONT_DIR_COS
  let fromBack = headCos > INFRONT_DIR_COS
  let fromSide = !fromFront && !fromBack
  let normLook = lookCos < -INFRONT_DIR_COS

  if part_type == int(DMAIPoint.BODY) || part_type == int(DMAIPoint.TURRET)
    return (!fromFront || allow_from_front) ? DMAIPointValue.SECONDARY : DMAIPointValue.NONE
  if part_type == int(DMAIPoint.BARREL)
    return normLook ? DMAIPointValue.PRIMARY : DMAIPointValue.NONE
  if part_type == int(DMAIPoint.TRACK) || part_type == int(DMAIPoint.WHEEL)
    return (fromSide && normLook) ? DMAIPointValue.PRIMARY : DMAIPointValue.NONE
  if part_type == int(DMAIPoint.ENGINE)
    return (fromAbove || fromSide || normLook) ? DMAIPointValue.PRIMARY : DMAIPointValue.NONE
  if part_type == int(DMAIPoint.CREW)
    return (!no_crew && (fromAbove || (!fromFront && !fromBelow && normLook))) ? DMAIPointValue.PRIMARY : DMAIPointValue.NONE

  return DMAIPointValue.NONE
