require ecs
require app
require net
require math.base

require %appGame.wt_events
require %appGame.infantry.es.riextra_common
require %game.events
require RendInst
require RendInstPhys
require DagorMath
require DagorSystem
require Dacoll


[es(on_appear)]
def rotating_rendinst_simple_phys_appear(evt : Event;
                                         rotating_rendinst_simple_phys__momentOfInertiaFromMassDiv : float;
                                         rendinst__mass : float = 0.0;
                                         var rotating_rendinst_simple_phys__invMomentOfInertia : float&)
  if rendinst__mass > 0.0
    rotating_rendinst_simple_phys__invMomentOfInertia = saturate(rotating_rendinst_simple_phys__momentOfInertiaFromMassDiv / rendinst__mass)


[es(on_appear)]
def rotating_rendinst_simple_phys_processing_appear(evt : Event;
                                                    rendinst_axis_rotation__curAngle : float;
                                                    var rotating_rendinst_simple_phys__physAnglePrevUpdate : float&;
                                                    var rotating_rendinst_simple_phys__physAngle : float&)
  rotating_rendinst_simple_phys__physAnglePrevUpdate = rendinst_axis_rotation__curAngle
  rotating_rendinst_simple_phys__physAngle = rendinst_axis_rotation__curAngle



[es(REQUIRE_NOT=rendinst_axis_rotation__enabled, no_order, REQUIRE_NOT=rotating_rendinst_simple_phys_disabled)]
def rotating_rendinst_simple_phys_update(act : UpdateStageInfoAct;
                                         eid : EntityId;
                                         ri_extra : RiExtraComponent;
                                         transform : float3x4;
                                         rotating_rendinst_simple_phys__fixedDt : float = 1.0 / 30.0;
                                         rotating_rendinst_simple_phys__maxStepsCount = 10;
                                         rotating_rendinst_simple_phys__processingTemplate : string;
                                         rotating_rendinst_simple_phys__angularVelocity : float;
                                         rotating_rendinst_simple_phys__minAngularVelocityToStopServer : float = 0.1;
                                         rotating_rendinst_simple_phys__minAngularVelocityToStopClient : float = 0.1;
                                         rotating_rendinst_simple_phys__torque : float;
                                         var rotating_rendinst_simple_phys__timeAcc : float&;
                                         var rotating_rendinst_simple_phys__idleUpdate : bool&)
  assume fixedDt = rotating_rendinst_simple_phys__fixedDt
  let minAngularVelocityToStop = is_dedicated() ? rotating_rendinst_simple_phys__minAngularVelocityToStopServer : rotating_rendinst_simple_phys__minAngularVelocityToStopClient
  rotating_rendinst_simple_phys__timeAcc += act.dt
  let steps = min(rotating_rendinst_simple_phys__maxStepsCount, int(rotating_rendinst_simple_phys__timeAcc / fixedDt))

  if steps > 0
    if (abs(rotating_rendinst_simple_phys__angularVelocity) < minAngularVelocityToStop &&
      abs(rotating_rendinst_simple_phys__torque) <= 0.0)

      
      if rotating_rendinst_simple_phys__idleUpdate
        if riex_isRiGenExtraValid(ri_extra.handle)
          move_ri_extra_tm(ri_extra.handle, transform)
        removeSubTemplate(eid, rotating_rendinst_simple_phys__processingTemplate)
        return

      rotating_rendinst_simple_phys__idleUpdate = true
    else
      rotating_rendinst_simple_phys__idleUpdate = false

  rotating_rendinst_simple_phys__timeAcc -= fixedDt * float(steps)
  let accRatio = rotating_rendinst_simple_phys__timeAcc / fixedDt

  for _ in range(steps)
    sendEventImmediate(eid, RotatingRendinstSimplePhysFixedUpdate(dt = fixedDt))
  sendEventImmediate(eid, RotatingRendinstSimplePhysUpdateFinished(accRatio = accRatio))


[es(REQUIRE_NOT=rotating_rendinst_simple_phys_disabled)]
def rotating_rendinst_simple_phys_update_finished(evt : RotatingRendinstSimplePhysUpdateFinished;
                                                  rendinst_axis_rotation__axis : float3;
                                                  initialTransform : float3x4;
                                                  rotating_rendinst_simple_phys__physAnglePrevUpdate : float;
                                                  rotating_rendinst_simple_phys__physAngle : float;
                                                  var transform : float3x4;
                                                  var rendinst_axis_rotation__curAngle : float&;
                                                  var rendinst_axis_rotation__targetAngle : float&)
  
  rendinst_axis_rotation__curAngle = lerp(rotating_rendinst_simple_phys__physAnglePrevUpdate, rotating_rendinst_simple_phys__physAngle, evt.accRatio)
  rendinst_axis_rotation__targetAngle = rendinst_axis_rotation__curAngle

  var rotTm : float3x4
  make_tm(rendinst_axis_rotation__axis, deg_to_rad(rendinst_axis_rotation__curAngle), rotTm)
  transform = initialTransform * rotTm


[es(REQUIRE_NOT=rotating_rendinst_simple_phys_disabled)]
def rotating_rendinst_simple_phys_fixed_update(act : RotatingRendinstSimplePhysFixedUpdate;
                                               eid : EntityId;
                                               rotating_rendinst_simple_phys__angularDamping : float;
                                               rotating_rendinst_simple_phys__collisionDampingMult : float = 0.66;
                                               rotating_rendinst_simple_phys__clampAngles : float2 const?;
                                               rotating_rendinst_simple_phys__torqueLimits : float2 = float2(-1e4, 1e4);
                                               rotating_rendinst_simple_phys__kinematicForwardCheckOffset : float = 0.1;
                                               ri_extra : RiExtraComponent;
                                               transform : float3x4;
                                               initialTransform : float3x4;
                                               rendinst_axis_rotation__axis : float3;
                                               rendinst_axis_rotation__rightAxis : float3 = float3(1.0, 0.0, 0.0);
                                               rotating_rendinst_simple_phys__kinematicCollisionsEnabled : bool;
                                               var rotating_rendinst_simple_phys__torque : float&;
                                               var rotating_rendinst_simple_phys__angularVelocity : float&;
                                               var rotating_rendinst_simple_phys__physAnglePrevUpdate : float&;
                                               var rotating_rendinst_simple_phys__physAngle : float&)
  rotating_rendinst_simple_phys__physAnglePrevUpdate = rotating_rendinst_simple_phys__physAngle

  if rotating_rendinst_simple_phys__torque > rotating_rendinst_simple_phys__torqueLimits.y
    rotating_rendinst_simple_phys__torque = rotating_rendinst_simple_phys__torqueLimits.y
  elif rotating_rendinst_simple_phys__torque < rotating_rendinst_simple_phys__torqueLimits.x
    rotating_rendinst_simple_phys__torque = rotating_rendinst_simple_phys__torqueLimits.x

  rotating_rendinst_simple_phys__angularVelocity += act.dt * rotating_rendinst_simple_phys__torque
  rotating_rendinst_simple_phys__torque = 0.0
  rotating_rendinst_simple_phys__angularVelocity *= 1.0 / (1.0 + rotating_rendinst_simple_phys__angularDamping * act.dt)

  let rotationValue = rotating_rendinst_simple_phys__angularVelocity * act.dt

  let newAngle = normalize_rendinst_rotation_angle(rotating_rendinst_simple_phys__physAngle + rotationValue)

  if rotating_rendinst_simple_phys__clampAngles != null
    
    if newAngle <= (*rotating_rendinst_simple_phys__clampAngles).x
      rotating_rendinst_simple_phys__physAngle = (*rotating_rendinst_simple_phys__clampAngles).x
      rotating_rendinst_simple_phys__angularVelocity = -rotating_rendinst_simple_phys__angularVelocity * rotating_rendinst_simple_phys__collisionDampingMult
      sendEventImmediate(eid, RotatingRendinstSimplePhysClampAngleReached(angle = rotating_rendinst_simple_phys__physAngle))
      return
    elif newAngle >= (*rotating_rendinst_simple_phys__clampAngles).y
      rotating_rendinst_simple_phys__physAngle = (*rotating_rendinst_simple_phys__clampAngles).y
      rotating_rendinst_simple_phys__angularVelocity = -rotating_rendinst_simple_phys__angularVelocity * rotating_rendinst_simple_phys__collisionDampingMult
      sendEventImmediate(eid, RotatingRendinstSimplePhysClampAngleReached(angle = rotating_rendinst_simple_phys__physAngle))
      return

  var rotTm : float3x4
  make_tm(rendinst_axis_rotation__axis, deg_to_rad(newAngle), rotTm)
  var newTrans = initialTransform * rotTm

  let forwardAxis = cross(rendinst_axis_rotation__axis, rendinst_axis_rotation__rightAxis)
  let rotationDir = rotate(transform, forwardAxis) * sign(rotationValue)
  newTrans[3] += rotationDir * rotating_rendinst_simple_phys__kinematicForwardCheckOffset

  using(ri_extra.handle) <| $(var desc : RendInstDesc#)
    if check_ri_collision_filtered(desc, transform, newTrans, int(PhysLayer.EPL_KINEMATIC)) && rotating_rendinst_simple_phys__kinematicCollisionsEnabled
      rotating_rendinst_simple_phys__angularVelocity = -rotating_rendinst_simple_phys__angularVelocity * rotating_rendinst_simple_phys__collisionDampingMult
      return

    rotating_rendinst_simple_phys__physAngle = newAngle


[es(REQUIRE=rendinst_axis_rotation__enabled, on_appear)]
def disable_rotating_rendinst_simple_phys_on_rotation_enabled(evt : Event;
                                                              eid : EntityId;
                                                              rotating_rendinst_simple_phys__processingTemplate : string)
  removeSubTemplate(eid, rotating_rendinst_simple_phys__processingTemplate)


def calc_rotating_rendinst_simple_phys_impulse_torque(impulse_pos : float3;
                                                      impulse : float3;
                                                      transform : float3x4;
                                                      rendinst_axis_rotation__axis : float3;
                                                      rotating_rendinst_simple_phys__invMomentOfInertia : float)
  let hingePos = transform[3]
  let hitPosToHingePos = impulse_pos - hingePos
  let torque3d = cross(hitPosToHingePos, impulse)
  let axisWS = rotate(transform, rendinst_axis_rotation__axis)
  let torque = dot(torque3d, axisWS)

  return torque * rotating_rendinst_simple_phys__invMomentOfInertia


[es(REQUIRE_NOT=rendinst_axis_rotation__enabled, REQUIRE_NOT=rotating_rendinst_simple_phys_disabled)]
def rotating_rendinst_simple_phys_on_projectile_hit(evt : EventRendinstOnProjectileHit;
                                                    eid : EntityId;
                                                    transform : float3x4;
                                                    rendinst_axis_rotation__axis : float3;
                                                    rotating_rendinst_simple_phys__startEnabled : bool = true;
                                                    rotating_rendinst_simple_phys__processingTemplate : string;
                                                    rotating_rendinst_simple_phys__invMomentOfInertia : float;
                                                    var rotating_rendinst_simple_phys__angularVelocity : float?)
  if !rotating_rendinst_simple_phys__startEnabled
    return

  let IMPULSE_MULT = 50.0
  let torque = calc_rotating_rendinst_simple_phys_impulse_torque(evt.pos, evt.impulse * IMPULSE_MULT, transform,
                                                                 rendinst_axis_rotation__axis,
                                                                 rotating_rendinst_simple_phys__invMomentOfInertia)
  
  if rotating_rendinst_simple_phys__angularVelocity != null
    *rotating_rendinst_simple_phys__angularVelocity += torque
  else
    addSubTemplate(eid, rotating_rendinst_simple_phys__processingTemplate) <| $(var init : ComponentsInitializer)
      init |> set("rotating_rendinst_simple_phys__angularVelocity", torque)


[es(REQUIRE_NOT=rendinst_axis_rotation__enabled, REQUIRE_NOT=rotating_rendinst_simple_phys_disabled)]
def rotating_rendinst_simple_phys_on_impulse(evt : EventRendinstImpulse;
                                             eid : EntityId;
                                             transform : float3x4;
                                             rendinst_axis_rotation__axis : float3;
                                             rotating_rendinst_simple_phys__startEnabled : bool = true;
                                             rotating_rendinst_simple_phys__processingTemplate : string;
                                             rotating_rendinst_simple_phys__rendinstImpulseMult : float = 430.0;
                                             rotating_rendinst_simple_phys__rendinstImpulseMinValue : float = 20.0;
                                             rotating_rendinst_simple_phys__invMomentOfInertia : float;
                                             var rotating_rendinst_simple_phys__torque : float?;
                                             var rotating_rendinst_simple_phys__rendinstImpulseActors : IPoint2List)
  if !rotating_rendinst_simple_phys__startEnabled
    return
  if dot(evt.impulseDir, -evt.collisionNormal) < 0.0
    return

  let impulse = evt.impulse * -evt.collisionNormal * rotating_rendinst_simple_phys__rendinstImpulseMult
  let torque = calc_rotating_rendinst_simple_phys_impulse_torque(evt.impulsePos, impulse, transform, rendinst_axis_rotation__axis,
                                                                        rotating_rendinst_simple_phys__invMomentOfInertia)
  let torqueValue = abs(torque)
  if torqueValue <= rotating_rendinst_simple_phys__rendinstImpulseMinValue
    return

  let frameNo = int(get_dagor_frame_no())

  
  let collisionActorId = evt.userData
  if collisionActorId > 0
    var colliderRendinstImpulseUserDataIdx = -1
    let rendinstImpulseActorsCount = length(rotating_rendinst_simple_phys__rendinstImpulseActors)
    for i in range(rendinstImpulseActorsCount)
      let rendinstImpulseActorIdx = rendinstImpulseActorsCount - i - 1
      assume rendinstImpulseActorRecord = rotating_rendinst_simple_phys__rendinstImpulseActors[rendinstImpulseActorIdx]

      if rendinstImpulseActorRecord.x == collisionActorId
        colliderRendinstImpulseUserDataIdx = rendinstImpulseActorIdx
        break

      if rendinstImpulseActorRecord.y != frameNo
        rotating_rendinst_simple_phys__rendinstImpulseActors |> erase(rendinstImpulseActorIdx)

    if colliderRendinstImpulseUserDataIdx == -1
      rotating_rendinst_simple_phys__rendinstImpulseActors |> push(int2(collisionActorId, frameNo))
    else
      assume rendinstImpulseActorRecord = rotating_rendinst_simple_phys__rendinstImpulseActors[colliderRendinstImpulseUserDataIdx]
      if rendinstImpulseActorRecord.y == frameNo
        return
      rendinstImpulseActorRecord.y = frameNo



  
  if rotating_rendinst_simple_phys__torque != null
    *rotating_rendinst_simple_phys__torque += torque
  else
    addSubTemplate(eid, rotating_rendinst_simple_phys__processingTemplate) <| $(var init : ComponentsInitializer)
      init |> set("rotating_rendinst_simple_phys__torque", torque)

