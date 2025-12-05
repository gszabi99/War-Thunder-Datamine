require ecs
require net
require Unit
require DagorDebug3D
require %game.unit.unit_events
require DagorMath
require DagorSystem
require WTCamera
require WarShipModel
require %game.events
require app
require DagorDataBlock
require WTHangar
require Dacoll

require %appGame.wt_events
require %gameDev.dev_events

def sq(v : float) : float
  return v * v

def isDetectedBySpeed(unit__ref : UnitRef; distSq : float) : bool
  let ship = unit__ref.unit |> as_ship()
  if ship != null
    let speedRangeSq = ship.currentNoiseFromSpeed
    return speedRangeSq >= distSq
  return false

def isDetectedByThrottle(unit__ref : UnitRef; distSq : float)
  let ship = unit__ref.unit |> as_ship()
  if ship != null
    let throttleRangeSq = ship.currentNoiseFromThrottle
    return throttleRangeSq >= distSq
  return false

def canUseHydrophone(eid : EntityId) : bool
  var res = false
  ecs::query(eid) <| $ [es(REQUIRE = unit_tag__ship)] (unit__ref : UnitRef;
                                                       hydrophone_props__enabled : bool;
                                                       hydrophone_props__works_when_surfaced : bool)
    if !hydrophone_props__enabled
      res = false
      return
    res = unit__ref.unit.isFullyUnderWater || hydrophone_props__works_when_surfaced
  return res

[es(tag=gameClient, REQUIRE = controlledHero, REQUIRE = unit_tag__ship), unused_argument(evt)]
def toggle_hydrophone_mode(evt : EventToggleHydrophoneMode;
                           eid : EntityId;
                           hydrophone__is_in_active_mode : bool)
  setHydrophoneMode(eid, !hydrophone__is_in_active_mode)

def setHydrophoneMode(eid : EntityId; isActive : bool)
  ecs::query(eid) <| $ [es] (var hydrophone__is_in_active_mode : bool&;
                             hydrophone_props__has_active_mode : bool)
    if isActive
      if canUseHydrophone(eid) && hydrophone_props__has_active_mode
        hydrophone__is_in_active_mode = true
        get_app().flightControlMode.cameraControl.setCameraByType(FlightCameraType.FLIGHT_CAMERA_TYPE_HYDROPHONE, null)
    else
      hydrophone__is_in_active_mode = false
      get_app().flightControlMode.cameraControl.setCameraByType(FlightCameraType.FLIGHT_CAMERA_TYPE_TURRET, null)

[es(tag=gameClient, REQUIRE = controlledHero, REQUIRE = (unit_tag__ship, hydrophone_props__enabled)), unused_argument(evt)]
def identify_target(evt : EventIdentifyHydrophoneTarget;
                    hydrophone__scan_target : EntityId;
                    var hydrophone__scan_progress : float&;
                    hydrophone_props__scan_time : float;
                    var hydrophone__identified_target : EntityId&;
                    var hydrophone__identified_target_remaining_time : float&;
                    hydrophone_props__identification_lifetime : float)
  if hydrophone__scan_target == INVALID_ENTITY_ID || hydrophone__scan_progress < hydrophone_props__scan_time
    return
  hydrophone__scan_progress = 0.0
  hydrophone__identified_target = hydrophone__scan_target
  hydrophone__identified_target_remaining_time = hydrophone_props__identification_lifetime
  var ctrl = get_app().flightControlMode
  (*ctrl).setNewTarget(get_unit_by_eid(hydrophone__identified_target), -1.0)
  ecs::query(hydrophone__identified_target) <| $ [es] (var hydrophone_sound_source__remaining_identification_time : float&)
    hydrophone_sound_source__remaining_identification_time = hydrophone_props__identification_lifetime

[es(tag=gameClient, REQUIRE = controlledHero, no_order)]
def hydrophone_target_identification_updater_es(act : UpdateStageInfoAct;
                                                var hydrophone__identified_target : EntityId&;
                                                var hydrophone__identified_target_remaining_time : float&)
  if hydrophone__identified_target != INVALID_ENTITY_ID
    hydrophone__identified_target_remaining_time -= act.dt
    if hydrophone__identified_target_remaining_time < 0.0
      hydrophone__identified_target = INVALID_ENTITY_ID

[es(tag=gameClient, REQUIRE_NOT = controlledHero, no_order)]
def hydrophone_identified_target_updater_es(act : UpdateStageInfoAct;
                                            var hydrophone_sound_source__remaining_identification_time : float&)
  hydrophone_sound_source__remaining_identification_time -= act.dt

[es(tag=gameClient, REQUIRE = controlledHero, REQUIRE = unit_tag__ship, no_order)]
def hydrophone_updater_es(act : UpdateStageInfoAct;
                          unit__ref : UnitRef;
                          eid : EntityId;
                          hydrophone_props__enabled : bool;
                          hydrophone_props__detection_range : float;
                          hydrophone_props__min_dot_passive : float;
                          hydrophone_props__min_dot_active : float;
                          var hydrophone__is_in_active_mode : bool&;
                          var hydrophone__scan_target : EntityId&;
                          var hydrophone__scan_progress : float&;
                          hydrophone_props__scan_time : float)
  if is_in_hangar() || unit__ref.unit.isDelayed || !hydrophone_props__enabled
    return

  let camera = get_app().flightControlMode.cameraControl.cur
  if camera == null || get_app().flightControlMode.cameraControl.cur.camtype != FlightCameraType.FLIGHT_CAMERA_TYPE_HYDROPHONE
    hydrophone__is_in_active_mode = false

  if !canUseHydrophone(eid)
    if hydrophone__is_in_active_mode
      setHydrophoneMode(eid, false)
    return

  let canDetectSurfacedTargets = unit__ref.unit.isFullyUnderWater

  let unitPos = unit__ref.unit.unitTm[3]
  var aimDir = get_camera_orig_dir()
  if !unit__ref.unit.isFullyUnderWater
    aimDir.y = min(aimDir.y, 0.0)
    aimDir = normalize(aimDir)

  // prototype UI
  let center = get_camera_pos() + aimDir
  draw_debug_circle_buffered(center, aimDir, tan(acos(hydrophone_props__min_dot_passive)), E3DCOLOR(0xFFFFFFFF), 40, 1)
  if hydrophone__is_in_active_mode
    draw_debug_circle_buffered(center, aimDir, tan(acos(hydrophone_props__min_dot_active)), E3DCOLOR(0xFF00FFFF), 40, 1)
  // ==

  let ownerArmy = unit__ref.unit.army
  var scannedActiveTarget = false
  ecs::query() <| $ [es(REQUIRE_NOT = controlledHero, REQUIRE = unit_tag__ship)] (unit__ref : UnitRef;
                                                                                  eid : EntityId)
    if unit__ref.unit.army == ownerArmy || !unit__ref.unit.isAlive
      return

    if !unit__ref.unit.isFullyUnderWater && !canDetectSurfacedTargets
      return

    let targetPos = unit__ref.unit.unitTm[3]
    let distSq = length_sq(unitPos - targetPos)
    if distSq > hydrophone_props__detection_range * hydrophone_props__detection_range
      return

    let dirToTarget = normalize(targetPos - get_camera_pos())
    let dotProduct = dot(dirToTarget, aimDir)
    if dotProduct < hydrophone_props__min_dot_passive
      return

    let speedCheck = isDetectedBySpeed(unit__ref, distSq)
    let throttleNoiceCheck = isDetectedByThrottle(unit__ref, distSq)
    if !throttleNoiceCheck && !speedCheck
      return

    let fromPos = unitPos
    let traceDir = normalize(targetPos - fromPos)
    let flags = ETF_LMESH | ETF_HEIGHTMAP
    let hitGround = rayhit_normalized(fromPos, traceDir, sqrt(distSq), flags, -1)
    if hitGround
      return

    if hydrophone__is_in_active_mode
      if hydrophone__scan_target != INVALID_ENTITY_ID
        if hydrophone__scan_target == eid && dotProduct > hydrophone_props__min_dot_active
          hydrophone__scan_progress += act.dt
          scannedActiveTarget = true
      else
        if dotProduct > hydrophone_props__min_dot_active
          hydrophone__scan_target = eid
          hydrophone__scan_progress = act.dt
          scannedActiveTarget = true

    // prototype UI
    let propgress = hydrophone__scan_target == eid ? min(hydrophone__scan_progress / hydrophone_props__scan_time, 1.0) : 0.0
    let c = lerp(float4(1.0, 0.0, 0.0, 1.0), float4(0.0, 1.0, 0.0, 1.0), propgress)
    let color = E3DCOLOR(Color4(c))
    let maxSize = 0.15
    let minSize = 0.03
    let size = lerp(maxSize, minSize, propgress)
    draw_debug_circle_buffered(get_camera_pos() + dirToTarget, dirToTarget, size, color, 40, 1)
    // ==

  if !scannedActiveTarget
    hydrophone__scan_progress = 0.0
    hydrophone__scan_target = INVALID_ENTITY_ID

[es]
def init_hydrophone(evt : CmdInitComponent;
                    var hydrophone_props__enabled : bool&;
                    var hydrophone_props__detection_range : float&;
                    var hydrophone_props__min_dot_passive : float&;
                    var hydrophone_props__min_dot_active : float&;
                    var hydrophone_props__scan_time : float&;
                    var hydrophone_props__identification_lifetime : float&;
                    var hydrophone_props__works_when_surfaced : bool&,
                    var hydrophone_props__has_active_mode : bool&)
  let propsBlk = *evt.modelBlk |> datablock_get_block_by_name("hydrophone")
  if propsBlk == null
    hydrophone_props__enabled = false
    return
  hydrophone_props__enabled = true

  let angularWidthPassive = propsBlk |> datablock_getReal("angularWidthPassiveDeg", -1.0)
  if angularWidthPassive > 0.0
    hydrophone_props__min_dot_passive = cos(angularWidthPassive / 180.0 * PI * 0.5)

  let angularWidthActive = propsBlk |> datablock_getReal("angularWidthActiveDeg", -1.0)
  if angularWidthActive > 0.0
    hydrophone_props__min_dot_active = cos(angularWidthActive / 180.0 * PI * 0.5)

  hydrophone_props__detection_range = propsBlk |> datablock_getReal("detectionRange", hydrophone_props__detection_range)
  hydrophone_props__scan_time = propsBlk |> datablock_getReal("scanTime", hydrophone_props__scan_time)
  hydrophone_props__identification_lifetime = propsBlk |> datablock_getReal("identificationTime", hydrophone_props__identification_lifetime)
  hydrophone_props__works_when_surfaced = propsBlk |> datablock_getBool("worksWhenSurfaced", hydrophone_props__works_when_surfaced)
  hydrophone_props__has_active_mode = propsBlk |> datablock_getBool("hasActiveMode", evt.modelBlk |> datablock_getBool("isSubmarine", false))
