require math
require DagorMath
require DagorMathUtils

module ai_aiming_common shared

def calc_compensated_aim_angles(curDir : float3) : float2
  return dir_to_angles(curDir)

def calc_compensated_aim_angles(curDir : float3;
                                gunAimOffset : float2;
                                breathOffset : float2;
                                gunAimOffsetCompensation : float;
                                breathOffsetCompensation : float) : float2
  return dir_to_angles(curDir) - gunAimOffset * gunAimOffsetCompensation - breathOffset * breathOffsetCompensation

def clamp_angle_by_speed(dt : float;
                         angle : float;
                         pivot : float;
                         speed : float) : float
  return clamp(renorm_ang(angle, pivot), pivot - speed * dt, pivot + speed * dt)

def calc_wish_approach_vel(dt : float;
                           aimSpeed : float;
                           curDir : float3;
                           wishDir : float3;
                           gunAimOffsetCompensation : float;
                           breathOffsetCompensation : float;
                           aimViscosity : float;
                           velViscosity : float;
                           velFactor : float;
                           gunAimOffset : float2;
                           breathOffset : float2;
                           var aimVelocity : float2&) : float3
  let curAngles  = calc_compensated_aim_angles(curDir)
  var wishAngles = calc_compensated_aim_angles(wishDir, gunAimOffset, breathOffset,
    gunAimOffsetCompensation, breathOffsetCompensation)

  wishAngles.x = approach_vel(curAngles.x, renorm_ang(wishAngles.x, curAngles.x), dt, aimViscosity,
                              aimVelocity.x, velViscosity, velFactor)
  wishAngles.y = approach_vel(curAngles.y, wishAngles.y, dt, aimViscosity,
                              aimVelocity.y, velViscosity, velFactor)

  wishAngles.x = clamp_angle_by_speed(dt, wishAngles.x, curAngles.x, aimSpeed)
  wishAngles.y = clamp_angle_by_speed(dt, wishAngles.y, curAngles.y, aimSpeed)

  return angles_to_dir(wishAngles)