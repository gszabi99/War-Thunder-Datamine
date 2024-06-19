require ecs
require Unit
require soundEvent
require Mission
require DagorRandom
require HeroManager
require %game.utils.utils_common
require %game.events
require %game.events
require DagorSystem
require DagorMath
require Mission
require %game.unit.ammo_stowage_events

[es(tag=server, on_event=EventFlightStart, REQUIRE_NOT=inFlight)]
def burav_start_flight_es(evt : Event;
                          eid : EntityId;
                          var burav__delayTimer : float&;
                          var burav__delayed : bool&;
                          burav__activateTime : float2;
                          burav__excludeAreas : StringList;
                          var burav__excludeAreasId : IntList&)
  if !has(eid, "inFlight")
    addSubTemplate(eid, "in_flight")
  burav__delayTimer = rnd_float(burav__activateTime.x, burav__activateTime.y)
  burav__delayed = true
  for area_name in burav__excludeAreas
    let aId = get_area_id(string(area_name))
    if aId >= 0
      burav__excludeAreasId |> push(aId)

[es(tag=server, REQUIRE=inFlight)]
def burav_update_es(act : UpdateStageInfoAct;
                    var burav__position : float2&;
                    var burav__delayTimer : float&;
                    var burav__delayed : bool&;
                    var burav__needSync : bool&;
                    burav__spawnArea : float4;
                    burav__velocity : float;
                    var burav__target : float2&;
                    burav__attackRadius : float;
                    var burav__curArmy : int&;
                    burav__controllerUid : int;
                    burav__respawnTimeout : float2;
                    burav__excludeAreasId : IntList&)
  burav__needSync = false
  if burav__delayed
    burav__delayTimer -= act.dt
    if burav__delayTimer <= 0.
      burav__delayed = false
      if length_sq(burav__position) <= 0.0
        var spawnPos = float2(0., 0.)
        spawnPos.x = rnd_float(burav__spawnArea.x, burav__spawnArea.z)
        spawnPos.y = rnd_float(burav__spawnArea.y, burav__spawnArea.w)
        burav__position = spawnPos
      burav__curArmy = 0
      burav__needSync = true
    return
  if burav__curArmy == 0
    return
  if length_sq(burav__target) > 0.
    if length_sq(burav__target - burav__position) < burav__velocity * act.dt
      if burav__position != burav__target
        burav__needSync = true
      burav__position = burav__target
    else
      let dir = normalize(burav__target - burav__position)
      burav__position += burav__velocity * act.dt * dir
      burav__needSync = true
    var victimEid = INVALID_ENTITY_ID
    var victinUid = -1
    query() <| $ [es] (uid : int; eid : EntityId)
      let unit = get_unit(uid)
      if unit != null && unit.army != burav__curArmy && !unit.isFlightModelWrap && unit.isAlive
        let unitPos3 = unit.pos
        let unitPos = unitPos3.xz
        if length_sq(unitPos - burav__position) <= burav__attackRadius * burav__attackRadius
          var inSafe = false
          for areaId in burav__excludeAreasId
            inSafe = is_in_area(areaId, unitPos)
            if inSafe
              break
          if !inSafe
            victinUid = uid
            victimEid = eid
    if victinUid != -1
      burav__delayed = true
      burav__delayTimer = rnd_float(burav__respawnTimeout.x, burav__respawnTimeout.y)
      sendEvent(victimEid, [[EventAmmoStowageSendExplosionFatal ammoLeft = 1.0, fullExpl = true]])
      sendEvent(victimEid, [[EventKilledByBurav killerUid = burav__controllerUid]])
      burav__target = float2(0., 0.)
      query() <| $ [es] (var sand_worm__victimUid : int&; var sand_worm__delayedTimer : float&; sand_worm__delayedTime : float)
        sand_worm__victimUid = victinUid
        sand_worm__delayedTimer = sand_worm__delayedTime


[es(tag=gameClient, track=burav__delayed)]
def burav_delayed_track(evt : Event;
                        burav__delayed : bool;
                        var burav__nearSoundEvent : SoundEvent&;
                        burav__appearSound : string)
  if !burav__delayed
    oneshot(burav__appearSound)
  if burav__delayed && is_playing(burav__nearSoundEvent)
    abandon(burav__nearSoundEvent)

[es(tag=gameClient)]
def burav_client_update_es(act : UpdateStageInfoAct;
                           burav__position : float2;
                           burav__delayed : bool;
                           burav__controlRadius : float)
  var nearestUnit = -1
  var nearestDistSq = -1.0
  query() <| $ [es(REQUIRE=can_control_burav)] (uid : int)
    get_unit_for_edit(uid) <| $(var unit)
      if !unit.isDelayed && unit.isAlive
        let unitPos3 = unit.pos
        let unitPos = unitPos3.xz
        let distSq = length_sq(unitPos - burav__position)
        if (nearestDistSq < 0.0 || distSq < nearestDistSq) && distSq <= burav__controlRadius * burav__controlRadius
          nearestDistSq = distSq
          nearestUnit = uid
        *unit |> setCanControlBurav(false)
  if nearestUnit >= 0 && !burav__delayed
    get_unit_for_edit(nearestUnit) <| $(var unit)
      *unit |> setCanControlBurav(true)

[es(tag=gameClient)]
def burav_near_effect_update_es(act : UpdateStageInfoAct;
                                burav__near_dist : float;
                                burav__delayed : bool;
                                burav__position : float2;
                                burav__nearSound : string;
                                var burav__nearSoundEvent : SoundEvent&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let unitPos3 = hero.pos
  let unitPos = unitPos3.xz
  let dist = length(unitPos - burav__position)
  if !burav__delayed && dist <= burav__near_dist
    if !is_playing(burav__nearSoundEvent)
      burav__nearSoundEvent |> play(burav__nearSound)
    set_var_optional(burav__nearSoundEvent, "dist", dist)
  else
    if is_playing(burav__nearSoundEvent)
      abandon(burav__nearSoundEvent)

[es(tag=server, REQUIRE=inFlight)]
def burav_control_command_es(evt : EventTryControlBurav;
                             burav__delayed : bool;
                             burav__controlRadius : float;
                             burav__position : float2;
                             var burav__target : float2&;
                             var burav__controllerUid : int&;
                             var burav__curArmy : int&)
  if evt.uid < 0 || length_sq(evt.target) == 0. || burav__delayed
    return
  if (!das_is_in_battle_area(evt.target, true))
    return
  let controlSender = get_unit(evt.uid)
  if controlSender != null
    if length_sq(evt.target - burav__position) <= burav__controlRadius * burav__controlRadius
      var nearestUnitId = -1
      var nearestDistSq = -1.0
      query() <| $ [es(REQUIRE=can_control_burav)] (uid : int)
        let unit = get_unit(uid)
        if !unit.isDelayed && unit.isAlive
          let unitPos3 = unit.pos
          let unitPos = unitPos3.xz
          let distSq = length_sq(unitPos - burav__position)
          if (nearestDistSq < 0.0 || distSq < nearestDistSq) && distSq <= burav__controlRadius * burav__controlRadius
            nearestDistSq = distSq
            nearestUnitId = uid
      if nearestUnitId == evt.uid
        burav__target = evt.target
        burav__curArmy = controlSender.army
        burav__controllerUid = nearestUnitId



