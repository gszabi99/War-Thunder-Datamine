require ecs
require Unit
require DagorSystem
require %game.events
require DagorRandom
require Mission
require %game.utils_common
require soundEvent
require HeroManager
require Weapon

[es (tag=server, no_order)]
def unit_noise_update_es(act : UpdateStageInfoAct;
                         uid : int;
                         var sand_unit__noise : float&;
                         sand_unit__moveNoiseK, sand_unit__noiseDecSpd : float)
  let unit = get_unit(uid)
  if sand_unit__noise > 0.0
    sand_unit__noise -= sand_unit__noiseDecSpd * act.dt
  if unit != null
    let noiseBySpd = unit.speed * sand_unit__moveNoiseK
    if sand_unit__noise < noiseBySpd
      sand_unit__noise = noiseBySpd

[es (tag=server)]
def unit_noise_after_shot(evt: EventGunShot;
                          var sand_unit__noise : float&)
  if sand_unit__noise < evt.noise
    sand_unit__noise = evt.noise

[es (tag=gameClient, no_order)]
def unit_death_anim_update_es(act : UpdateStageInfoAct;
                              sand_unit__deathAnimVarId, uid : int;
                              var sand_unit__deathAnimTimer : float&;
                              sand_unit__deathAnimTime : float)
  if sand_unit__deathAnimVarId < 0 || sand_unit__deathAnimTime < 0. || sand_unit__deathAnimTimer < 0.
    return
  get_unit_for_edit(uid) <| $(var unit)
    *unit |> setAnimPhysVarVal(sand_unit__deathAnimVarId, sand_unit__deathAnimTimer / sand_unit__deathAnimTime)
  if sand_unit__deathAnimTimer <= sand_unit__deathAnimTime
    sand_unit__deathAnimTimer += act.dt


[es (tag=gameClient, on_event=EventSandUnitDead)]
def sand_worm_kill_unit_es(evt:Event;
                           var sand_unit__deathAnimTimer : float&)
  sand_unit__deathAnimTimer = 0.

[es (tag=server, on_event=EventFlightStart, REQUIRE_NOT=inFlight)]
def sand_worm_start_flight_es(evt:Event;
                              eid : EntityId;
                              var sand_worm__delayTimer : float&;
                              var sand_worm__delayed : bool&;
                              sand_worm__activateTime : float2;
                              sand_worm__noiseExcludeAreas : StringList;
                              var sand_worm__excludeAreasId : IntList&)
  if !has(eid, "inFlight")
    addSubTemplate(eid, "in_flight")
  sand_worm__delayTimer = rnd_float(sand_worm__activateTime.x, sand_worm__activateTime.y)
  sand_worm__delayed = true
  for area_name in sand_worm__noiseExcludeAreas
    let aId = get_area_id(string(area_name))
    if aId >= 0
      sand_worm__excludeAreasId |> push(aId)

[es (tag=server, REQUIRE=inFlight)]
def sand_worm_update_es(act : UpdateStageInfoAct;
                        var sand_worm__position : float2&;
                        var sand_worm__delayTimer : float&;
                        var sand_worm__radius : float&;
                        var sand_worm__curInactive : float&;
                        var sand_worm__delayed : bool&;
                        var sand_worm__needSync : bool&;
                        sand_worm__respawnTimeout : float2;
                        sand_worm__speedK : Point2List;
                        sand_worm__excludeAreasId : IntList;
                        sand_worm__radiusDecK, sand_worm__inactiveTime, sand_worm__attackRadius : float)
  sand_worm__needSync = false
  if sand_worm__delayed
    sand_worm__delayTimer -= act.dt
    if sand_worm__delayTimer <= 0.
      sand_worm__delayed = false
      sand_worm__position = get_battle_area_center(true).xz
      sand_worm__radius = get_battle_area_radius(true) * 1.5
      sand_worm__needSync = true
    return
  var bestNoise = 0.
  var dir = float2(0., 0.)
  var bestUid = -1
  var bestEid = INVALID_ENTITY_ID
  query() <| $ [es](uid : int; sand_unit__noise : float; eid : EntityId)
    if sand_unit__noise > bestNoise
      let unit = get_unit(uid)
      if unit != null
        let unitPos3 = unit.pos
        let unitPos = unitPos3.xz
        let unitVector = unitPos - sand_worm__position
        if length_sq(unitVector) <= sand_worm__radius * sand_worm__radius
          var inSafe = false
          for areaId in sand_worm__excludeAreasId
            inSafe = is_in_area(areaId, unitPos)
            if inSafe
              break
          if !inSafe
            dir = normalize(unitVector)
            bestNoise = sand_unit__noise
            bestUid = uid
            bestEid = eid
  if bestNoise > 0.
    var speed = 0.
    for i in range(0, length(sand_worm__speedK))
      if sand_worm__radius < sand_worm__speedK[i].x
        speed = sand_worm__speedK[i].y
        break
    sand_worm__position += speed * bestNoise * act.dt * dir
    sand_worm__radius -= bestNoise * sand_worm__radiusDecK * act.dt
    sand_worm__curInactive = 0.
    sand_worm__needSync = true
    if sand_worm__radius < sand_worm__attackRadius
      sand_worm__delayed = true
      sand_worm__delayTimer = rnd_float(sand_worm__respawnTimeout.x, sand_worm__respawnTimeout.y)
      get_unit_for_edit(bestUid) <| $(var unit)
        *unit |> setUnitState(UnitState US_DEAD)
      sendEvent(bestEid, [[EventSandUnitDead]])
      query() <| $ [es](var sand_worm__victimUid : int&; var sand_worm__delayedTimer : float&; sand_worm__delayedTime : float)
        sand_worm__victimUid = bestUid
        sand_worm__delayedTimer = sand_worm__delayedTime
  else
    if sand_worm__curInactive <= 0.
      sand_worm__needSync = true
    sand_worm__curInactive += act.dt
    if sand_worm__curInactive >= sand_worm__inactiveTime
      sand_worm__curInactive = 0.
      sand_worm__delayed = true
      sand_worm__delayTimer = rnd_float(sand_worm__respawnTimeout.x, sand_worm__respawnTimeout.y)
      sand_worm__needSync = true

[es (tag=gameClient, track=sand_worm__delayed)]
def sand_worm_delayed_track(evt : Event;
                            sand_worm__delayed : bool;
                            sand_worm__cameraShake : float3;
                            var sand_worm__cameraShakeTimer : float&;
                            var sand_worm__nearSoundEvent : SoundEvent&;
                            sand_worm__appearSound : string)
  if !sand_worm__delayed
    oneshot(sand_worm__appearSound)
    query() <| $[es(REQUIRE=controlledHero)](uid: int)
      let unit = get_unit(uid)
      if unit != null && !unit.isHelicopter
        let unitPos = unit.pos
        set_camera_shake(sand_worm__cameraShake.x, unitPos, sand_worm__cameraShake.y)
        sand_worm__cameraShakeTimer = sand_worm__cameraShake.z
  if sand_worm__delayed && is_playing(sand_worm__nearSoundEvent.handle)
    abandon(sand_worm__nearSoundEvent.handle)

[es (tag=gameClient)]
def sand_worm_client_update_es(act : UpdateStageInfoAct;
                               sand_worm__cameraShake : float3;
                               sand_worm__curInactive : float;
                               var sand_worm__nearSoundEvent : SoundEvent&;
                               var sand_worm__cameraShakeTimer : float&)
  if sand_worm__cameraShakeTimer >= 0.
    sand_worm__cameraShakeTimer -= act.dt
    query() <| $[es(REQUIRE=controlledHero)](uid: int)
      let unit = get_unit(uid)
      if unit != null
        let unitPos = unit.pos
        set_camera_shake(sand_worm__cameraShake.x, unitPos, sand_worm__cameraShake.y)
  if sand_worm__curInactive > 0. && is_playing(sand_worm__nearSoundEvent.handle)
    abandon(sand_worm__nearSoundEvent.handle)

[es (tag=gameClient, track=sand_worm__radius)]
def sand_worm_near_effect_es(evt : Event;
                             sand_worm__radius, sand_worm__near_dist : float;
                             sand_worm__position : float2;
                             sand_worm__nearSound : string;
                             sand_worm__near_shake : Point3List;
                             var sand_worm__nearSoundEvent : SoundEvent&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let unitPos3 = hero.pos
  let distSq = length_sq(unitPos3.xz - sand_worm__position)
  if distSq <= sand_worm__radius * sand_worm__radius && sand_worm__radius <= sand_worm__near_dist
    var shake = float2(0., 0.)
    for i in range(0, length(sand_worm__near_shake))
      if sand_worm__radius >= sand_worm__near_shake[i].x
        shake = sand_worm__near_shake[i].yz
        break
    set_camera_shake(shake.x, unitPos3, shake.y)
    if !is_playing(sand_worm__nearSoundEvent.handle)
      sand_worm__nearSoundEvent |> play(sand_worm__nearSound)
    set_var_optional(sand_worm__nearSoundEvent.handle, "radius", sand_worm__radius)
  else
    if is_playing(sand_worm__nearSoundEvent.handle)
      abandon(sand_worm__nearSoundEvent.handle)


[es (tag=gameClient, no_order)]
def sky_laser_render_es(act : UpdateStageInfoAct;
                        sky_laser__weaponIdx, sky_laser__uid : int;
                        sky_laser__timings : FloatList;
                        sky_laser__direction : float3;
                        sky_laser__positions : Point3List)
  let unit = get_unit(sky_laser__uid)
  if unit != null
    var weapon = unit.weap.Weapons |> get_weapon(sky_laser__weaponIdx)
    if weapon != null
      var tm = identity3x4()
      let time = float(get_total_time())
      for i in range(0, length(sky_laser__timings) - 1)
        if time >= sky_laser__timings[i] && time < sky_laser__timings[i+1]
          let k = (time - sky_laser__timings[i]) / (sky_laser__timings[i+1] - sky_laser__timings[i])
          tm[3] = lerp(sky_laser__positions[i], sky_laser__positions[i+1], float3(k))
          tm[0] = sky_laser__direction
          *weapon |> renderBeam(tm)

def sky_laser_update(weaponIdx, uid : int;
                    var lastShootAt : float&;
                    timer : float;
                    timings : FloatList;
                    direction : float3;
                    positions : Point3List )
  if lastShootAt > 0. && float(get_total_time()) - lastShootAt < timer
    return true
  let unit = get_unit(uid)
  if unit != null
    var weapon = unit.weap.Weapons |> get_weapon(weaponIdx)
    var gun = Gun_cast(weapon)
    if gun != null
      var tm = identity3x4()
      let time = float(get_total_time())
      for i in range(0, length(timings) - 1)
        if time >= timings[i] && time < timings[i+1]
          let k = (time - timings[i]) / (timings[i+1] - timings[i])
          tm[3] = lerp(positions[i], positions[i+1], float3(k))
          tm[0] = direction
          *gun |> beamShots(tm, time)
          lastShootAt = time
          return true
  return false

[es (tag=server, no_order)]
def sky_laser_update_es(act : UpdateStageInfoAct;
                        eid : EntityId;
                        sky_laser__weaponIdx, sky_laser__uid : int;
                        var sky_laser__lastShootAt : float&;
                        sky_laser__timer : float;
                        sky_laser__timings : FloatList;
                        sky_laser__direction : float3;
                        sky_laser__positions : Point3List)
  if !sky_laser_update(sky_laser__weaponIdx, sky_laser__uid, sky_laser__lastShootAt, sky_laser__timer, sky_laser__timings, sky_laser__direction, sky_laser__positions)
    destroyEntity(eid)

[es (tag=netClient, no_order)]
def sky_laser_update_client_es(act : UpdateStageInfoAct;
                        sky_laser__weaponIdx, sky_laser__uid : int;
                        var sky_laser__lastShootAt : float&;
                        sky_laser__timer : float;
                        sky_laser__timings : FloatList;
                        sky_laser__direction : float3;
                        sky_laser__positions : Point3List)
  sky_laser_update(sky_laser__weaponIdx, sky_laser__uid, sky_laser__lastShootAt, sky_laser__timer, sky_laser__timings, sky_laser__direction, sky_laser__positions)

[es (on_event=EventEntityDestroyed)]
def sky_laser_destroy_es(evt:Event;
                         sky_laser__weaponIdx, sky_laser__uid : int)
  let unit = get_unit(sky_laser__uid)
  if unit != null
    var weapon = unit.weap.Weapons |> get_weapon(sky_laser__weaponIdx)
    var gun = Gun_cast(weapon)
    if gun != null
      *gun |> stopBeam()

[es (tag=sound, track=sand_worm__victimUid)]
def sand_worm_attack_track(evt : Event;
                           sand_worm__victimUid : int;
                           sand_worm__attackSfx : string)
  if sand_worm__victimUid < 0
    return
  let unit = get_unit(sand_worm__victimUid)
  if unit != null && !unit.isDelayed && !unit.isLoading && !unit.isFarAway
    let pos = unit.pos
    oneshot(sand_worm__attackSfx, pos)