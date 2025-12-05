module human_common shared

require ecs
require DngHuman
require DagorMath


def move_human_to_wish_pos(var human_net_phys : HumanActor; wishPos : float3)
  assume humanPhys     = human_net_phys.phys
  assume humanCurState = human_net_phys.phys.currentState

  var ccdTm : float3x4
  location_toTM(humanPhys.currentState.location, ccdTm)

  let ccdPos = humanPhys.ccdPos
  let prevWorldCcdPos = ccdTm * ccdPos

  humanCurState.location.P = DPoint3(wishPos)
  humanCurState.velocity = float3(0.f)
  humanCurState.breathOffset = float2(0.f)
  humanCurState.moveState = HUMoveState.EMS_STAND

  location_toTM(humanPhys.currentState.location, ccdTm)

  let collRad = humanPhys.collRad
  let ccdRad  = humanPhys.ccdRad
  let speedCollisionHardness = humanPhys.speedCollisionHardness
  let ccdToPos = ccdTm * ccdPos
  let totalOffset = ccdToPos - prevWorldCcdPos
  return humanPhys |> human_phys_processCcdOffset(ccdTm, ccdToPos, totalOffset, collRad - ccdRad, speedCollisionHardness, true, ccdPos)
