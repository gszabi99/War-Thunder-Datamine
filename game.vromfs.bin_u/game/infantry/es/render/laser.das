require ecs
require DagorMath
require math.base
require AnimV20
require %game.events
require GeomNodeTree
require Dacoll
require PhysMat
require DagorSystem
require %appGame.infantry.es.camera_common

[es(tag=render, before=update_lasers_es, after=slot_attach_init_tms_es, parallel_for=1)]
def update_lasers_traces_es(info : ParallelUpdateFrameDelayed;
                            animchar_attach__attachedTo : EntityId;
                            laserBeamMaxLength : float;
                            laserStartIntensity : float;
                            laserMaxIntensity : float;
                            laserBeamStartOffset : float3;
                            laserActive : bool;
                            laserAlpha : float;
                            laserCrownAngle : float;
                            var laser_data__rayHit : float3&;
                            var laser_data__fxPos : float3&;
                            var laserAvailable : bool&;
                            var laser_data__fxDir : float3&;
                            var laser_data__laserLen : float&;
                            var laser_data__gunOwner : EntityId&;
                            var laser_data__intesity : float&;
                            var laser_data__crownSize : float&;
                            animchar aka laser_animchar : AnimcharBaseComponent const?;
                            laser__fxNodeIdx : int = -1)
  laser_data__gunOwner = INVALID_ENTITY_ID
  laser_data__fxPos = float3(0, 0, 0)
  laser_data__fxDir = float3(1, 0, 0)
  var hasGun = false

  query(animchar_attach__attachedTo) <| $ [es] (animchar aka weapon_animchar : AnimcharBaseComponent;
                                                weapon_frontsight_node__nodeIdx : int;
                                                weapon_rearsight_node__nodeIdx : int;
                                                gun__owner : EntityId = INVALID_ENTITY_ID)
    laser_data__gunOwner = gun__owner

    if weapon_frontsight_node__nodeIdx >= 0 && weapon_rearsight_node__nodeIdx >= 0
      hasGun = true
      let p1 = geomtree_getNodeWpos(*weapon_animchar.nodeTree, weapon_frontsight_node__nodeIdx)
      let p2 = geomtree_getNodeWpos(*weapon_animchar.nodeTree, weapon_rearsight_node__nodeIdx)

      laser_data__fxPos = p2
      laser_data__fxDir = normalize(p1 - p2)

  if !hasGun || laser_data__gunOwner == INVALID_ENTITY_ID
    laserAvailable = false
    return

  if !laserActive || !laserAvailable
    return

  if laser_animchar != null && laser__fxNodeIdx >= 0
    laser_data__fxPos = geomtree_getNodeWpos(*laser_animchar.nodeTree, laser__fxNodeIdx)

  laser_data__fxPos += laserBeamStartOffset
  var outVel = float3()
  laser_data__laserLen = laserBeamMaxLength
  var norm = float3()
  traceray_normalized(laser_data__fxPos, laser_data__fxDir, laser_data__laserLen, norm, ETF_ALL)
  trace_game_objects(laser_data__fxPos, laser_data__fxDir, laser_data__laserLen, outVel, int(uint(animchar_attach__attachedTo)), int(PHYSMAT_DEFAULT))

  laser_data__rayHit = laser_data__fxPos + laser_data__laserLen * laser_data__fxDir

  let camTm = get_active_camera_tm()
  let cameraPos = camTm[3]

  let camLaserSqDist = length(cameraPos - laser_data__fxPos)
  let dotCamLaserDir = dot(laser_data__fxDir, normalize(cameraPos - laser_data__fxPos))
  let tanCrownAngle = tan(laserCrownAngle * DEG_TO_RAD)
  let cosCrownAngle = cos(laserCrownAngle * DEG_TO_RAD)
  let cos2CrownAngle = cos((2.0 * laserCrownAngle) * DEG_TO_RAD)
  let angleFactor = clamp(((dotCamLaserDir - cos2CrownAngle) / (cosCrownAngle - cos2CrownAngle)), 0.0, 1.0)
  let fallOffFactor = exp(-laserAlpha * camLaserSqDist)
  laser_data__intesity = clamp(laserStartIntensity * fallOffFactor, 0.0, laserMaxIntensity)
  laser_data__crownSize = tanCrownAngle * angleFactor

[es(track=human_gun_attached)]
def update_laser_on_weapon_change_es(evt : Event;
                                     eid : EntityId;
                                     human_gun_attached : bool)
  query() <| $ [es] (animchar_attach__attachedTo : EntityId; var laserAvailable : bool&)
    if animchar_attach__attachedTo == eid
      laserAvailable = human_gun_attached
