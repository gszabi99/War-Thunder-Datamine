require ecs
require %appGame.infantry.es.hero_common
require Dacoll
require DagorMath

require %appGame.wt_events
require %appGame.infantry.es.dm_common


[es(tag=gameClient, REQUIRE=msg_sink)]
def player_disorientated_es(evt : EventFlashExploded)
  let exPos = evt.pos
  let tinnitusRad = evt.tinnitusRad
  let flashRad = evt.flashRad
  let tinnitusPower = evt.tinnitusPower
  let flashPower = evt.flashPower
  let ignoreEid = evt.ignoreEid
  let eid = get_controlled_hero_eid()

  if ignoreEid != INVALID_ENTITY_ID && ignoreEid == eid
    return
  query(eid) <| $ [es] (human__visible : bool = true; isInVehicleHidden : bool = false)
    if human__visible && !isInVehicleHidden
      if flashPower.x > 0.f
        sendEvent(eid, EventPlayerBlindness(position = exPos, radius = flashRad, power = flashPower, distExponent = evt.flashDistExp))
      sendEvent(eid, EventPlayerTinnitus(position = exPos, radius = tinnitusRad, power = tinnitusPower, distExponent = evt.tinnitusDistExp))

[es(tag=gameClient)]
def player_flash_blindness_es(evt : EventPlayerBlindness;
                              camera__look_at : DPoint3&;
                              camera__lookDir : float3&)
  let exPos = evt.position
  let radius = evt.radius
  let power = evt.power
  let distExp = evt.distExponent

  var dirToHead = float3(camera__look_at) - exPos
  let distToHead = length(dirToHead)
  if distToHead > radius.y
    return
  dirToHead *= safeinv(distToHead)
  let penetration = float2()
  let flashPow = -dot(camera__lookDir, dirToHead) * calc_dist_damage(distToHead, 0f, distExp, penetration, radius, power)
  if flashPow <= 0f
    return
  if rayhit_normalized(exPos, dirToHead, distToHead, ETF_DEFAULT, -1)
    var rayhitToCam = true
    find_query() <| $ [es(REQUIRE=camera__active)] (transform : float3x4&;
                                                    camera__active : bool)
      if !camera__active
        return false
      let camPos = transform[3]
      if length_sq(camPos - float3(camera__look_at)) < 0.01f
        return true
      var dirToCam = camPos - exPos
      let distToCam = length(dirToCam)
      dirToCam *= safeinv(distToCam)
      rayhitToCam = rayhit_normalized(exPos, dirToCam, distToCam, ETF_DEFAULT, -1)
      return true
    if rayhitToCam
      return
  let eid = get_controlled_hero_eid()
  sendEvent(eid, EventFlashBlindEffect(power = flashPow))
  sendEvent(eid, EventRetinalDamageEffect(position = exPos, distance = distToHead))
