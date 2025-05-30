require app
require dm
require ecs
require math/random
require net
require BitStream
require FlightModelWrap
require DagorConsole
require DagorDebug3D
require Sound
require Unit
require %game.unit.unit_events
require %game.unit.unit_proximity_damage_events

[es(tag=server)]
def on_entity_part_damaged_by_proximity_explosion(evt : EventOnPartDamagedByProximityExplosion;
                                                  unit__ref : UnitRef;
                                                  var proximity_damage__pos : Point3List&;
                                                  var proximity_damage__parts : PartIdList&)
  let unit = unit__ref.unit
  let fmw = unit |> as_fmw()
  if fmw != null && fmw.boundingSphereRad < get_game_params().holeRendering.boundingSphereRadiusExclusionForProximityDamage
    return

  let partId = PartId(evt.partId)
  if !is_part_inner(unit.dmData, int(partId.id))
    proximity_damage__pos |> push(evt.pos)
    proximity_damage__parts |> push(partId)

[es(tag=server)]
def create_proximity_visual_damage_es_event_handler(evt : CmdCreateProximityVisialDamage;
                                                    eid : EntityId;
                                                    unit__ref : UnitRef;
                                                    var proximity_damage__pos : Point3List&;
                                                    var proximity_damage__parts : PartIdList&;
                                                    var proximity_damage__partGlobalId : Int16List&;
                                                    var proximity_damage__visualNum : IntList&)
  if empty(proximity_damage__pos)
    return

  let unit = unit__ref.unit
  let distanceForDiscard = pow(get_game_params().holeRendering.distFromExplosionForDiscardingProximityDamageSq, 2.)
  let maxDamageInfoForAirUnit : int = min(get_game_params().holeRendering.maximumRayPerProximityDamageAircraft, length(proximity_damage__pos))
  let maxDamageInfoForGroundUnit : int = min(get_game_params().holeRendering.maximumRayPerProximityDamageGroundModel, length(proximity_damage__pos))
  let numProximityDamagePerPartOnAirUnit : int = get_game_params().holeRendering.numProximityDamageVisualPerPartOnAircraft
  let numProximityDamagePerPartOnGroundUnit : int = get_game_params().holeRendering.numProximityDamageVisualPerPartOnGroundModel
  let maximumProximityDamageInfo : int = unit.isFlightModelWrap ? maxDamageInfoForAirUnit : maxDamageInfoForGroundUnit
  let numProximityDamagePerPart : int = unit.isFlightModelWrap ? numProximityDamagePerPartOnAirUnit : numProximityDamagePerPartOnGroundUnit

  var validPartsIndexes : array<int>
  var currentProximityDamageInfoNum : int = 0
  for i, partPos in iter_range(proximity_damage__pos), proximity_damage__pos
    if length_sq(partPos - evt.explosionPos) < distanceForDiscard
      continue

    var isNoDamagePerPartFound = true
    for j, partGlobalId in iter_range(proximity_damage__partGlobalId), proximity_damage__partGlobalId
      if partGlobalId == proximity_damage__parts[i].globalId
        isNoDamagePerPartFound = false
        if proximity_damage__visualNum[j] < numProximityDamagePerPart
          proximity_damage__visualNum[j]++
          currentProximityDamageInfoNum++
          validPartsIndexes |> push(i)
        break
    if isNoDamagePerPartFound
      proximity_damage__partGlobalId |> push(proximity_damage__parts[i].globalId)
      proximity_damage__visualNum |> push(1)
      currentProximityDamageInfoNum++
      validPartsIndexes |> push(i)

  if empty(validPartsIndexes)
    return

  if length(validPartsIndexes) > maximumProximityDamageInfo
    validPartsIndexes |> shuffle()
    validPartsIndexes |> resize(maximumProximityDamageInfo)

  let itm = inverse(unit.unitTm)
  using() <| $(var bs : BitStream)
    bs |> Write(length(validPartsIndexes))
    for i in iter_range(validPartsIndexes)
      let p = itm * proximity_damage__pos[i]
      bs |> Write(proximity_damage__parts[i].id)
      bs |> Write(p)

    send_net_event(eid, EventProximityVisualDamageNetSync(explosionPos = itm * evt.explosionPos, projectilePropsId = evt.projectilePropsId, bs = ecs_addr(bs)))

  clear(proximity_damage__pos)
  clear(proximity_damage__parts)

[es(tag=render)]
def proximity_visual_damage_net_sync_es(evt : EventProximityVisualDamageNetSync;
                                        var unit__ref : UnitRef)
  let unit = unit__ref.unit
  assume bs = *evt.bs
  var isRead = true
  var directionsCount : int = 0
  var positions : array<float3>
  var parts : array<int16>
  isRead &&= Read(bs, directionsCount)
  if !isRead
    return
  for _i in range(directionsCount)
    var partId : int16
    var pos : float3
    isRead &&= Read(bs, partId)
    isRead &&= Read(bs, pos)
    if !isRead
      break

    if int(partId) >= get_damage_part_props_count(unit.dmData)
      continue

    positions |> push(unit.unitTm * pos)
    parts |> push(partId)

  if !isRead
    return

  let showDebug : bool = get_game_params().holeRendering.showProximityDamageDebug
  let explosionPos = unit.unitTm * evt.explosionPos
  for i in iter_range(positions)
    assume pos = positions[i]
    assume partId = parts[i]
    let normalizedDir = normalize(pos - explosionPos)
    *unit__ref.unit |> addProximityDamageVisualPatch(pos, normalizedDir, partId, evt.projectilePropsId)
    if showDebug
      draw_debug_line_buffered(explosionPos, pos, E3DCOLOR(0xFF00FF00), 100000)

[es(tag=sound, REQUIRE = controlledHero)]
def proximity_visual_damage_sound_effect_es(evt : EventProximityVisualDamageNetSync;
                                            unit__ref : UnitRef)
  let fmw = unit__ref.unit |> as_fmw()
  if fmw != null
    play_sound_effect_fast(MiscSfxEffectType.MODULE_DAMAGE)


[es(tag=server, on_event=(EventUnitRepair, EventUnitRespawn))]
def on_unit_repair_proximity_damage_handler(evt : Event;
                                            var proximity_damage__pos : Point3List&;
                                            var proximity_damage__parts : PartIdList&;
                                            var proximity_damage__partGlobalId : Int16List&;
                                            var proximity_damage__visualNum : IntList&)
  clear(proximity_damage__pos)
  clear(proximity_damage__parts)
  clear(proximity_damage__partGlobalId)
  clear(proximity_damage__visualNum)