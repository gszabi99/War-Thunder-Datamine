options no_aot = true
require ecs
require walkerai
require math
require math.base
require DagorMath
require DngWalkerai
require DagorRandom
require strings


require %appGame.es.ai_danger_common
require %appGame.es.walker_common


def print_values(limit = 100; step = 10; hr = true; blk)
  let origin : float2
  let shootDir = float2(1, 0)
  var x = -limit
  if hr
    to_log(LOG_DEBUG, " y\\x ")
    while x <= limit
      to_log(LOG_DEBUG, format("% 4d", x))
      to_log(LOG_DEBUG, x == 0 ? "  " : " ")
      x += step
      if x == 0
        to_log(LOG_DEBUG, " ")
    to_log(LOG_DEBUG, "\n\n")

  var y = -limit
  while y <= limit
    x = -limit
    if hr
      to_log(LOG_DEBUG, format("% 4d", y))
      to_log(LOG_DEBUG, " ")
    while x <= limit
      let pos = float2(x, y)
      invoke(blk, origin, pos, shootDir)
      if hr && x == 0
        to_log(LOG_DEBUG, " ")
      x += step
      if hr && x == 0
        to_log(LOG_DEBUG, " ")
    to_log(LOG_DEBUG, "\n")
    if hr && y == 0
      to_log(LOG_DEBUG, "\n")
    y += step
    if hr && y == 0
      to_log(LOG_DEBUG, "\n")


def print_alertness_with_params(stance : int)
  let agent_dangers__frustumAngle = 45f
  let frustumMinCos = cos(deg_to_rad(agent_dangers__frustumAngle))
  print_values(100, 10, true) <| $(origin, pos, shootDir : float2)
    let dist = length(pos - origin)
    let frustumCos = dot(normalize(pos - origin), shootDir)
    let inFrustum = frustumCos >= frustumMinCos
    let agent_dangers__maxDangerDist = 90.0
    let alertness = calc_target_alertness(dist, inFrustum, frustumCos, stance, false, agent_dangers__maxDangerDist)
    to_log(LOG_DEBUG, format("%1.2f", alertness))
    to_log(LOG_DEBUG, " ")


def print_alertness()
  to_log(LOG_DEBUG, "Stance stand\n")
  print_alertness_with_params(STANCE_STAND)
  to_log(LOG_DEBUG, "Stance crouch\n")
  print_alertness_with_params(STANCE_CROUCH)
  to_log(LOG_DEBUG, "Stance crawl\n")
  print_alertness_with_params(STANCE_CRAWL)
  to_log(LOG_DEBUG, " ")


def print_traceable_ratio()
  print_danger_or_traceable_ratio(false)


def print_danger()
  print_danger_or_traceable_ratio(true)

def print_danger_or_traceable_ratio(printDanger = true)
  let agent_dangers__frustumAngle = 45f
  let frustumMinCos = cos(deg_to_rad(agent_dangers__frustumAngle))
  let atTime = 1000f
  let agent_dangers__maxDangerDist = 90f

  print_values(100, 10, true) <| $(origin, pos, shootDir : float2)
    let dist = length(pos - origin)
    let frustumCos = dot(normalize(pos - origin), shootDir)
    let inFrustum = frustumCos >= frustumMinCos
    let alertness = calc_target_alertness(dist, inFrustum, frustumCos, STANCE_STAND, false, agent_dangers__maxDangerDist)
    using() <| $(var danger : Danger#)
      danger.distance = dist
      danger.alertness = alertness
      danger.inFrustumTime = inFrustum ? atTime - 1f : -1f
      danger.lastBulletNearbyTime = -1f 
      danger.lastTraceTime = atTime - 100f
      using() <| $(var target : Target#)
        target.lastShootTimer = atTime 
        let isAi = false
        var dangerMeter = calc_danger(atTime, agent_dangers__maxDangerDist, danger, target, 0.25, isAi)
        if (dangerMeter < 0.73)
          dangerMeter = 0.0
        to_log(LOG_DEBUG, format("%0.2f", printDanger ? dangerMeter : calc_traceable_ratio(atTime, dangerMeter, danger)))
        to_log(LOG_DEBUG, " ")
