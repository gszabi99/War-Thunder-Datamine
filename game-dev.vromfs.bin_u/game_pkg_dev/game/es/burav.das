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

[es(tag=server, REQUIRE=inFlight, no_order)]
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
                    burav__controllerEid : EntityId;
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
    query() <| $ [es] (unit__ref : UnitRef; eid : EntityId)
      let unit = unit__ref.unit
      if unit.army != burav__curArmy && !unit.isFlightModelWrap && unit.isAlive
        let unitPos3 = unit.pos
        let unitPos = unitPos3.xz
        if length_sq(unitPos - burav__position) <= burav__attackRadius * burav__attackRadius
          var inSafe = false
          for areaId in burav__excludeAreasId
            inSafe = is_in_area(areaId, unitPos)
            if inSafe
              break
          if !inSafe
            victimEid = eid
    if victimEid != INVALID_ENTITY_ID
      burav__delayed = true
      burav__delayTimer = rnd_float(burav__respawnTimeout.x, burav__respawnTimeout.y)
      sendEvent(victimEid, EventAmmoStowageSendExplosionFatal(ammoLeft = 1.0, fullExpl = true))
      sendEvent(victimEid, EventKilledByBurav(killerEid = burav__controllerEid))
      burav__target = float2(0., 0.)
      query() <| $ [es] (var sand_worm__victimEid : EntityId&; var sand_worm__delayedTimer : float&; sand_worm__delayedTime : float)
        sand_worm__victimEid = victimEid
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

[es(tag=gameClient, no_order)]
def burav_client_update_es(act : UpdateStageInfoAct;
                           burav__position : float2;
                           burav__delayed : bool;
                           burav__controlRadius : float)
  var nearestUnit = INVALID_ENTITY_ID
  var nearestDistSq = -1.0
  query() <| $ [es(REQUIRE=can_control_burav)] (var unit__ref : UnitRef; eid : EntityId)
    var unit = unit__ref.unit
    if !unit.isDelayed && unit.isAlive
      let unitPos3 = unit.pos
      let unitPos = unitPos3.xz
      let distSq = length_sq(unitPos - burav__position)
      if (nearestDistSq < 0.0 || distSq < nearestDistSq) && distSq <= burav__controlRadius * burav__controlRadius
        nearestDistSq = distSq
        nearestUnit = eid
      *unit |> setCanControlBurav(false)
  if nearestUnit != INVALID_ENTITY_ID && !burav__delayed
    var unit = get_unit_by_eid(nearestUnit)
    if unit != null
      *unit |> setCanControlBurav(true)

[es(tag=gameClient, no_order)]
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
                             var burav__controllerEid : EntityId&;
                             var burav__curArmy : int&)
  if evt.eid == INVALID_ENTITY_ID || length_sq(evt.target) == 0. || burav__delayed
    return
  if (!das_is_in_battle_area(evt.target, true))
    return
  let controlSender = get_unit_by_eid(evt.eid)
  if controlSender != null
    if length_sq(evt.target - burav__position) <= burav__controlRadius * burav__controlRadius
      var nearestUnitEid = INVALID_ENTITY_ID
      var nearestDistSq = -1.0
      query() <| $ [es(REQUIRE=can_control_burav)] (eid : EntityId; unit__ref : UnitRef)
        let unit = unit__ref.unit
        if !unit.isDelayed && unit.isAlive
          let unitPos3 = unit.pos
          let unitPos = unitPos3.xz
          let distSq = length_sq(unitPos - burav__position)
          if (nearestDistSq < 0.0 || distSq < nearestDistSq) && distSq <= burav__controlRadius * burav__controlRadius
            nearestDistSq = distSq
            nearestUnitEid = eid
      if nearestUnitEid == evt.eid
        burav__target = evt.target
        burav__curArmy = controlSender.army
        burav__controllerEid = nearestUnitEid



