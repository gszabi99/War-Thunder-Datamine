require ecs
require WTPhysActor
require DngHuman
require HumanPhys
require math
require math.base
require math.ang
require DagorMath
require DagorMathUtils
require AnimV20
require app
require %game.events
require %appGame.infantry.es.human_weap_common

[es(after=after_net_phys_sync, REQUIRE=watchedHero, REQUIRE_NOT=deadEntity)]
def human_look_dir_camera_es(info : ParallelUpdateFrameDelayed;
                             
                             human_net_phys : HumanActor;
                             camera__gunAimOffset : float2;
                             var camera__shootOffset : float2&;
                             var camera__prevLookDir : float3&;
                             var camera__lookDir : float3&;
                             camera__shootOffsetTau : float = 0.05f)

  
  

  camera__prevLookDir = camera__lookDir

  assume ct = human_net_phys.phys.producedCT
  let interpK = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)

  var ang : float2
  if (int(human_net_phys.role) & int(NetRole.URF_LOCAL_CONTROL)) != 0
    ang = dir_to_angles(ct.wishLookDir)
  else
    
    
    ang = dir_to_angles(human_net_phys.phys.currentState.gunDir)

  var aimOffs = lerp(human_net_phys.phys.previousState.gunAimOffset, human_net_phys.phys.currentState.gunAimOffset, float2(interpK))
  aimOffs += camera__gunAimOffset

  camera__shootOffset = approach(camera__shootOffset, aimOffs, info.dt, camera__shootOffsetTau)
  ang += camera__shootOffset

  ang.y = clamp(ang.y, -SAFE_HALF_PI, SAFE_HALF_PI)
  camera__lookDir = angles_to_dir(ang)


[es(after=human_look_dir_camera_es, REQUIRE=watchedHero, REQUIRE=deadEntity)]
def human_look_dir_dead_camera_es(info : ParallelUpdateFrameDelayed;
                                  eid : EntityId;
                                  transform : float3x4&;
                                  death_cam__killer : EntityId;
                                  death_cam__followTime : float;
                                  deatch_cam__viscosity : float2;
                                  var death_cam__startedAt : float&;
                                  var camera__lookDir : float3&)
  if death_cam__killer == eid
    return

  let killerTm = get_TMatrix(death_cam__killer, "transform")
  if killerTm != null
    if death_cam__startedAt < 0.0
      death_cam__startedAt = info.curTime
    if info.curTime > death_cam__startedAt + death_cam__followTime
      return

    let wishLookDir = normalize((*killerTm)[3] - transform[3])
    let viscosityPercent = cvt(info.curTime, death_cam__startedAt, death_cam__startedAt + death_cam__followTime, 0.0, 1.0)
    let viscosity = deatch_cam__viscosity[0] + deatch_cam__viscosity[1] * viscosityPercent * viscosityPercent
    camera__lookDir = approach(camera__lookDir, wishLookDir, info.dt, viscosity)














[es(after=human_look_dir_camera_es, REQUIRE=watchedHero, tag=ui)]
def look_hero_compass_angle_es(info : UpdateStageInfoAct;
                               var compass__forwardAngle : int&;
                               camera__lookDir : float3)
  let lookAngles = dir_to_angles(camera__lookDir)
  let angle = roundi(rad_to_deg(lookAngles.x)) + 90
  compass__forwardAngle = (angle + 360) % 360
