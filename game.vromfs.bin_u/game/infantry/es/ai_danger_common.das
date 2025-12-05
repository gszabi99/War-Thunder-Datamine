module ai_danger_common shared

require math
require DagorMath
require %appGame.infantry.es.walker_common

def private logistic(x : float; k = 1.; max = 1.)
  return max / (1. + exp(-k * x))

def private logistic(x : float; coef : float3 )
  return logistic(x + coef.z, coef.x, coef.y)

def private inv(x : float; coef : float2)
  return coef.y * min(coef.x, safeinv(x))

def calc_target_alertness(dist : float; in_frustum : bool; frustum_cos : float;
                          target_stance : int; is_downed : bool;
                          agent_dangers__maxDangerDist : float;
                          dist_coef : float2 = float2(-0.03, 0.8);
                          in_frustum_coef : float2 = float2(1.8f, 0.25f);
                          frustum_coef : float3 = float3(5., 1f, 0.);
                          frustum_offset : float2 = float2(-0.1, 0.23);
                          crouch_coef : float = 0.85f;
                          crawl_coef : float = 0.5f;
                          downed_coef : float = 0.75f;
                          in_vehicle_coef : float = 1.f) : float
  var stanceK = 1.0f
  if is_downed
    stanceK = downed_coef
  elif target_stance == STANCE_CROUCH
    stanceK = crouch_coef
  elif target_stance == STANCE_CRAWL
    stanceK = crawl_coef
  let distK = logistic(dist, float3(dist_coef.x, dist_coef.y, -agent_dangers__maxDangerDist * stanceK * in_vehicle_coef))
  let frustumK = frustum_offset.y * (logistic(frustum_cos, frustum_coef) + frustum_offset.x) * (in_frustum ? in_frustum_coef.x : in_frustum_coef.y)
  return saturate(distK + frustumK)


def private time_to_dt(cur_time : float; time : float; defVal : float)
  return time < 0f ? defVal : cur_time - time


def calc_danger(cur_time, agent_dangers__maxDangerDist : float; danger : Danger | #; ai_target : Target | #; ai_target__noiseLevel : float; is_ai : bool;
                ai_coef : float2 = float2(1., 1.);
                avoid_bullets_near_time : float = 10f;
                on_shoot_line_coef : float = 0.0;
                on_shoot_line_score : float = 1.0;
                last_shoot_coef : float2 = float2(1., 1.);
                noise_coef : float2 = float2(0.2, 1f);
                last_bullet_nearby_coef : float2 = float2(10f, 10f)) : float
  let aiK = is_ai ? ai_coef.x : ai_coef.y
  let distCutOffMult = danger.distance <= agent_dangers__maxDangerDist ? 1f : 0f
  let noiseK = noise_coef.x * ai_target__noiseLevel + noise_coef.y + inv(ai_target.lastShootTimer, last_shoot_coef)
  let baseScore = danger.alertness + on_shoot_line_coef * on_shoot_line_score
  return baseScore * distCutOffMult * noiseK * aiK + inv(time_to_dt(cur_time, danger.lastBulletNearbyTime, 1e8), last_bullet_nearby_coef)


def calc_traceable_ratio(cur_time : float; dangerMeter : float; danger : Danger | #) : float
  let timeMult = min(5f, cur_time - danger.lastTraceTime)
  return dangerMeter * timeMult
