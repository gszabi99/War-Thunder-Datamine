require ecs
require DagorConsole
require DagorDebug3D
require DagorMath
require CollRes
require math.base

require %appGame.wt_events

[event(broadcast)]
struct SlotAttachUpdateEvent
  dt : float

[es(on_appear, REQUIRE=hangar_weapon_placer)]
def hangar_weapon_placing(evt : Event;
                          var transform : float3x4&;
                          var original_transform : float3x4&;
                          collres : CollisionResource const?;
                          var hangar_weapon__maxAngles : float4&;
                          hangar_weapon__raised : bool)
  if !hangar_weapon__raised
    let height = collres.boundingBox.boxMax.x - collres.boundingBox.boxMin.x
    transform = transform * original_transform
    if height > 0.
      transform[3] = transform[3] + float3(0., height * 0.5, 0.)
    original_transform = transform
  hangar_weapon__maxAngles *= PI / 180.0

[es]
def hangar_weapon_rotated_es(evt : EventHangarCameraRotated;
                             hangar_weapon__raiseProgress : float&;
                             var hangar_weapon__angles : float2&;
                             hangar_weapon__rotationSpeed : float2&;
                             hangar_weapon__maxAngles : float4&)
  if hangar_weapon__raiseProgress < 1.0
    return

  
  hangar_weapon__angles.x += evt.anglesDiff.x * hangar_weapon__rotationSpeed.x
  hangar_weapon__angles.y += evt.anglesDiff.y * hangar_weapon__rotationSpeed.y
  hangar_weapon__angles.x = clamp(hangar_weapon__angles.x, hangar_weapon__maxAngles.x, hangar_weapon__maxAngles.y)
  hangar_weapon__angles.y = clamp(hangar_weapon__angles.y, hangar_weapon__maxAngles.z, hangar_weapon__maxAngles.w)


[es]
def hangar_camera_weapon_zoom_es(evt : EventHangarCameraZoom;
                                 var hangar_cam_weapon__zoom : float&;
                                 hangar_cam_weapon__zoom_speed : float;
                                 hangar_cam_weapon__zoom_limits : float2)
  hangar_cam_weapon__zoom += evt.zoomDelta * hangar_cam_weapon__zoom_speed
  hangar_cam_weapon__zoom = clamp(hangar_cam_weapon__zoom, hangar_cam_weapon__zoom_limits.x, hangar_cam_weapon__zoom_limits.y)

[es]
def hangar_weapon_raise_es(evt : CmdHangarRaiseWeapon;
                           var hangar_weapon__angles : float2&;
                           var hangar_weapon__raised : bool&)
  if hangar_weapon__raised
    return
  hangar_weapon__raised = !hangar_weapon__raised
  hangar_weapon__angles = float2(0.0, 0.0)

def get_bbox_center(original_box : BBox3& const)
  var bbox = original_box
  bbox.boxMin.x = -original_box.boxMin.z;
  bbox.boxMax.x = -original_box.boxMax.z;
  bbox.boxMin.z = original_box.boxMin.x;
  bbox.boxMax.z = original_box.boxMax.x;
  return bbox.center

[es(no_order)]
def hangar_weapon_update_es(act : UpdateStageInfoAct;
                            original_transform : float3x4&;
                            var transform aka weapon_transform : float3x4&;
                            collres : CollisionResource const?;
                            var hangar_weapon__raiseProgress : float&;
                            var hangar_weapon__raiseProgressExtra : float&;
                            var hangar_weapon__focusPos : float3&;
                            hangar_weapon__pivotOffset : float3 const = float3(0., 0., 0.);
                            hangar_weapon__angles : float2&;
                            hangar_weapon__raised : bool;
                            hangar_weapon__raiseTime : float;
                            hangar_weapon__raiseHeight : float)
  if hangar_weapon__raised && hangar_weapon__raiseProgress < 1.
    hangar_weapon__raiseProgress = min(1., hangar_weapon__raiseProgress + act.dt / hangar_weapon__raiseTime)
    hangar_weapon__raiseProgressExtra = 0.
  if !hangar_weapon__raised && hangar_weapon__raiseProgress > 0.
    hangar_weapon__raiseProgress = max(0., hangar_weapon__raiseProgress - act.dt / hangar_weapon__raiseTime)
    hangar_weapon__raiseProgressExtra = 0.
  if hangar_weapon__raised && hangar_weapon__raiseProgress + hangar_weapon__raiseProgressExtra < 2.
    hangar_weapon__raiseProgressExtra = min(1., hangar_weapon__raiseProgressExtra + act.dt / hangar_weapon__raiseTime)

  
  let raiseAngle = -PI * 0.25
  let quatRaised = quat(sin(raiseAngle), 0.0, 0.0, cos(raiseAngle))

  var quatRotation = quat(0.0, 0.0, 0.0, 1.0)
  if (hangar_weapon__raiseProgress < 1.)
    let quatRaise = slerp(quat(0.0, 0.0, 0.0, 1.0), quatRaised, hangar_weapon__raiseProgress)
    quatRotation = DagorMath::quat(original_transform) * quatRaise
  else
    var camTransform = identity3x4()
    query() <| $ [es(REQUIRE=camera_view)] (transform aka camera_transform : float3x4&)
      camTransform = transform
    let quatCameraFace = dir_to_quat(camTransform[2])

    
    let phi = hangar_weapon__angles.y
    let theta = hangar_weapon__angles.x
    let dir = normalize(float3(cos(phi) * cos(theta), sin(phi), cos(phi) * sin(theta)))
    let quatDir = inverse(dir_to_quat(dir))

    let quatBase = DagorMath::quat(original_transform) * quatRaised
    let rotateToCameraFace = quatCameraFace * inverse(quatBase)
    quatRotation = quatBase * rotateToCameraFace * quatDir * inverse(rotateToCameraFace)

  let bboxCenterLocal = get_bbox_center(collres.boundingBox)
  let raiseOffset = float3(0., hangar_weapon__raiseHeight * hangar_weapon__raiseProgress, 0.)
  var pivotOffset = float3(hangar_weapon__pivotOffset.x, hangar_weapon__pivotOffset.z, 0.0)
  var basePosition = original_transform[3] + raiseOffset
  basePosition.y += hangar_weapon__pivotOffset.y

  make_tm(quatRotation, float3(0., 0., 0.), transform)
  transform[3] = basePosition - transform[0] * bboxCenterLocal.x - transform[1] * bboxCenterLocal.y - transform[2] * bboxCenterLocal.z
  transform[3] = transform[3] - transform[0] * pivotOffset.x - transform[1] * pivotOffset.y - transform[2] * pivotOffset.z

  hangar_weapon__focusPos = basePosition

  if ((hangar_weapon__raised && hangar_weapon__raiseProgress + hangar_weapon__raiseProgressExtra < 2.) ||
      (!hangar_weapon__raised && hangar_weapon__raiseProgress + hangar_weapon__raiseProgressExtra > 0.))
    broadcastEventImmediate(SlotAttachUpdateEvent(dt = act.dt))

[es(on_appear, tag=hangar, REQUIRE=camera_view)]
def hangar_camera_weapon_init_es(evt : Event; eid : EntityId)
  addSubTemplate(eid, "hangar_cam_weapon")

[es(no_order)]
def hangar_camera_weapon_update_es(act : UpdateStageInfoAct;
                                   var transform aka camera_transform : float3x4&;
                                   hangar_cam_weapon__fov : float;
                                   hangar_cam_weapon__weapon_offset : float3&;
                                   hangar_cam_weapon__zoom : float;
                                   hangar_cam_weapon__margin : float;
                                   hangar_cam_weapon__viscosity : float;
                                   hangar_cam_weapon__start_animation_offset : float3&;
                                   hangar_cam_weapon__start_animation_rotation : float3&;
                                   hangar_cam_weapon__selected : bool;
                                   var hangar_cam_weapon__origin_pos : float3&;
                                   var hangar_cam_weapon__distance : float&;
                                   var hangar_cam_weapon__animation_offset : float3&;
                                   var hangar_cam_weapon__animation_rotation : float3&)
  if hangar_cam_weapon__fov <= 0.0f
    return

  query() <| $ [es] (hangar_weapon__focusPos : float3&;
                     var hangar_weapon__animationFinished : bool&;
                     original_transform : float3x4&;
                     collres : CollisionResource const?)
    let radius = (collres.boundingBox.boxMax.z - collres.boundingBox.boxMin.z) * 0.5 + hangar_cam_weapon__margin
    if radius < FLT_EPSILON
      return

    let fovRad = deg_to_rad(hangar_cam_weapon__fov)
    let fitDist = safediv(radius, tan(0.5f * fovRad))
    let zoom = clamp(hangar_cam_weapon__zoom, 0.25f, 4.0f)
    var distance = fitDist / zoom

    let cameraOriginPos = original_transform[3] + hangar_cam_weapon__weapon_offset
    var camDirection = normalize(hangar_weapon__focusPos - cameraOriginPos)
    if length_sq(camDirection) < FLT_EPSILON
      camDirection = float3(0.0f, 0.0f, 1.0f)

    if length_sq(hangar_cam_weapon__origin_pos) < FLT_EPSILON
      hangar_cam_weapon__origin_pos = cameraOriginPos + hangar_cam_weapon__start_animation_offset

    let wishDistance = distance - length(hangar_weapon__focusPos - cameraOriginPos)
    hangar_cam_weapon__distance = approach(hangar_cam_weapon__distance, wishDistance, act.dt, hangar_cam_weapon__viscosity)
    hangar_cam_weapon__origin_pos = approach(hangar_cam_weapon__origin_pos, cameraOriginPos, act.dt, hangar_cam_weapon__viscosity)
    if !hangar_weapon__animationFinished
      hangar_cam_weapon__animation_offset = approach(hangar_cam_weapon__animation_offset, float3(0.0, 0.0, 0.0), act.dt, hangar_cam_weapon__viscosity)
      hangar_cam_weapon__animation_rotation = approach(hangar_cam_weapon__animation_rotation, float3(0.0, 0.0, 0.0), act.dt, hangar_cam_weapon__viscosity)
      if length_sq(hangar_cam_weapon__animation_offset) < FLT_EPSILON && length_sq(hangar_cam_weapon__animation_rotation) < FLT_EPSILON
        hangar_cam_weapon__animation_offset = float3(0.0, 0.0, 0.0)
        hangar_cam_weapon__animation_rotation = float3(0.0, 0.0, 0.0)
        hangar_weapon__animationFinished = true

    var up = float3(0.0f, 1.0f, 0.0f)
    if 1.0 - abs(dot(up, camDirection)) < FLT_EPSILON
      up = float3(0.0f, 0.0f, 1.0f)

    var camRight = normalize(cross(up, camDirection))
    var camUp = normalize(cross(camDirection, camRight))

    if !hangar_weapon__animationFinished && length_sq(hangar_cam_weapon__animation_rotation) > FLT_EPSILON
      let rotRad = hangar_cam_weapon__animation_rotation * (PI / 180.0)
      if abs(rotRad.y) > 0.0
        var tmYaw : float3x4
        make_tm(camUp, rotRad.y, tmYaw)
        camRight = normalize(tmYaw * camRight)
        camDirection = normalize(tmYaw * camDirection)

      if abs(rotRad.x) > 0.0
        var tmPitch : float3x4
        make_tm(camRight, rotRad.x, tmPitch)
        camUp = normalize(tmPitch * camUp)
        camDirection = normalize(tmPitch * camDirection)

      if abs(rotRad.z) > 0.0
        var tmRoll : float3x4
        make_tm(camDirection, rotRad.z, tmRoll)
        camRight = normalize(tmRoll * camRight)
        camUp = normalize(tmRoll * camUp)

    camera_transform[0] = camRight
    camera_transform[1] = camUp
    camera_transform[2] = camDirection
    camera_transform[3] = hangar_cam_weapon__origin_pos - camDirection * hangar_cam_weapon__distance
    if !hangar_weapon__animationFinished
      camera_transform[3] += hangar_cam_weapon__animation_offset

  if !hangar_cam_weapon__selected
    hangar_cam_weapon__animation_offset = hangar_cam_weapon__start_animation_offset
    hangar_cam_weapon__animation_rotation = hangar_cam_weapon__start_animation_rotation

[es(no_order)]
def hangar_camera_dof_es(act : UpdateStageInfoAct;
                         camera__dof_enabled : bool;
                         camera__dof_near_settings : float3;
                         camera__dof_far_unzoom : float3;
                         camera__dof_far_zoom : float3;
                         hangar_cam_weapon__zoom : float;
                         hangar_cam_weapon__zoom_limits : float2;
                         var camera__dof_near : float3&;
                         var camera__dof_far : float3&)
  if !camera__dof_enabled
    return

  let zoomNormalized = cvt(hangar_cam_weapon__zoom, hangar_cam_weapon__zoom_limits.x, hangar_cam_weapon__zoom_limits.y, 0.0f, 1.0f)
  camera__dof_far.x = cvt(zoomNormalized, 0.0f, 1.0f, camera__dof_far_unzoom.x, camera__dof_far_zoom.x)
  camera__dof_far.y = cvt(zoomNormalized, 0.0f, 1.0f, camera__dof_far_unzoom.y, camera__dof_far_zoom.y)
  camera__dof_far.z = cvt(zoomNormalized, 0.0f, 1.0f, camera__dof_far_unzoom.z, camera__dof_far_zoom.z)
  camera__dof_near.x = camera__dof_near_settings.x
  camera__dof_near.y = camera__dof_near_settings.y
  camera__dof_near.z = camera__dof_near_settings.z
