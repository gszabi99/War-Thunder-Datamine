require ecs
require app
require math.base
require AnimV20
require DagorMath
require DagorMathUtils
require MotionMatching
require %game.events


[es(tag=gameClient, on_appear)]
def motion_matching_init_align_velocity(evt : Event;
                                        animchar : AnimcharBaseComponent;
                                        motion_matching__alignVelocityParamName : string;
                                        var motion_matching__alignVelocityParamId : int&)
  motion_matching__alignVelocityParamId = *animchar.animGraph |> anim_graph_getParamId(motion_matching__alignVelocityParamName, int(PT_ScalarParam))


[es(tag=gameClient, after=wait_motion_matching_job_es, before=animchar_es)]
def motion_matching_update_align_velocity(act : ParallelUpdateFrameDelayed;
                                          motion_matching__controller : MotionMatchingController;
                                          motion_matching__alignVelocityMaxAngle : float;
                                          motion_matching__alignVelocityViscosity : float;
                                          motion_matching__alignVelocityParamId : int;
                                          mm_trajectory__linearVelocity : float3;
                                          var animchar : AnimcharBaseComponent;
                                          var motion_matching__alignVelocityAngle : float&;
                                          var motion_matching__alignVelocitySpeed : float&)
  if motion_matching__alignVelocityParamId < 0
    return
  var wishAlignAngle = 0.0f
  if motion_matching__controller.hasActiveAnimation()
    let clipIdx = motion_matching__controller.getCurrentClip()
    var frameIdx = motion_matching__controller.getCurrentFrame()
    assume curClip = motion_matching__controller.dataBase.clips[clipIdx]
    frameIdx = min(frameIdx, curClip.tickDuration - 1)
    let velocity = (curClip.rootMotion[frameIdx + 1].translation - curClip.rootMotion[frameIdx].translation) * TICKS_PER_SECOND
    if length(velocity) > 0.5
      let worldVel = quat_mul_vec(quat_mul(motion_matching__controller.rootRotation,
                                          quat_conjugate(curClip.rootMotion[frameIdx].rotation)), velocity)
      wishAlignAngle = rad_to_deg(dir_to_angles(worldVel).x - dir_to_angles(mm_trajectory__linearVelocity).x)
      if abs(wishAlignAngle) > 180f
        wishAlignAngle -= sign(wishAlignAngle) * 360f
      wishAlignAngle = clamp(wishAlignAngle, -motion_matching__alignVelocityMaxAngle, motion_matching__alignVelocityMaxAngle)

  simple_spring_damper_exact(motion_matching__alignVelocityAngle, motion_matching__alignVelocitySpeed,
    wishAlignAngle, motion_matching__alignVelocityViscosity, act.dt)
  *animchar.animState |> anim_state_holder_setParam(motion_matching__alignVelocityParamId, motion_matching__alignVelocityAngle)
