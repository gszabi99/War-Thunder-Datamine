require ecs

require %appGame.wt_events
require Dacoll
require DagorMath
require %appGame.infantry.es.dm_common


[es(tag=sound)]
def player_expl_tinnitus_sound(evt : EventPlayerTinnitus;
                               eid : EntityId;
                               camera__look_at : DPoint3&)
  let exPos = evt.position
  let radius = evt.radius
  let power = evt.power
  let distExp = evt.distExponent

  var dirToHead = float3(camera__look_at) - exPos
  let distToHead = length(dirToHead)
  if distToHead > radius.y
    return
  dirToHead *= safeinv(distToHead)

  var tinnitusPow = power.x

  if rayhit_normalized(exPos, dirToHead, distToHead, ETF_DEFAULT, -1)
    if distToHead > radius.x
      return
  else
    let penetration = float2()
    tinnitusPow = calc_dist_damage(distToHead, 0f, distExp, penetration, radius, power)

  if tinnitusPow <= 0f
    return
  sendEvent(eid, CmdStartTinnitusSfx(pos = float3(camera__look_at), power = tinnitusPow))
