module interactable_common shared
require ecs
require math
require math.base
require DagorMath
require Grid


def find_interactable(grid_name_hash : uint; tm : float3x4; player_tm : float3x4; rad : float; ignore_checks : bool;
                      find_check : block<(eid : EntityId) : bool>)
  var minDist = FLT_MAX
  var bestEntity = INVALID_ENTITY_ID
  for_each_entity_in_grid(grid_name_hash, BSphere3(tm[3], rad), GridEntCheck BOUNDING) <| $(eid : EntityId)
    if !invoke(find_check, eid)
      return
    query(eid) <| $ [es] (interactCheckOffset : float3 = float3(0.0, 0.0, 0.0);
                          interactable : bool = true;
                          interactDist : float = 1.5;
                          isAlive : bool = true;
                          interactAngleLimits : float2 = float2(-60.0, 60.0);
                          transform : float3x4)
      if !interactable || !isAlive
        return
      var entityTM = transform
      entityTM[3] = transform * interactCheckOffset
      let dirToHands = entityTM[3] - tm[3]
      let dirToPlayer = entityTM[3] - player_tm[3]
      let curDistSq = length_sq(dirToHands)
      let curDist2DSq = length_sq(dirToHands.xz)
      if !ignore_checks && curDist2DSq > length_sq(dirToPlayer.xz)
        return
      let dot = dot(dirToHands * safeinv(sqrt(curDistSq)), tm[0])
      let dirDot = (1.0 - dot) * curDistSq
      if !ignore_checks && (curDistSq > square(interactDist) || dirDot > minDist)
        return
      let itm = inverse(entityTM)
      let localPos = itm * tm[3]
      let localPosToPlayer = itm * player_tm[3]
      let angleLimits = DEG_TO_RAD * interactAngleLimits
      let horzAngle = atan2(localPos.x, localPos.z)
      let horzAngleToPlayer = atan2(localPosToPlayer.x, localPosToPlayer.z)
      if !ignore_checks && (max(horzAngle, horzAngleToPlayer) > angleLimits.y || min(horzAngle, horzAngleToPlayer) < angleLimits.x)
        return
      minDist = dirDot
      bestEntity = eid
  return bestEntity


def find_interactable(grid_name_hash : uint; eid : EntityId; rad : float; ignore_checks : bool;
                      find_check : block<(eid : EntityId) : bool>)
  var found = INVALID_ENTITY_ID
  query(eid) <| $ [es] (transform : float3x4;
                        human__aimTm : float3x4;
                        human_weap__throwMode : bool = false;
                        human_net_phys__isClimbing : bool = false)
    if human_net_phys__isClimbing || human_weap__throwMode
      return
    found = find_interactable(grid_name_hash, human__aimTm, transform, rad, ignore_checks, find_check);
  return found
