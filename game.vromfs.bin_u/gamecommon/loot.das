require ecs
require DagorRandom
require DagorSystem
require Unit
require net
require DagorMath
require soundEvent
require %game.events
require %game.utils.net_utils
require %game.utils.utils_common
require ecs.common
require math.random
require app
require Mission
require MPlayer
require Economic
require %game.unit.unit_events

let lootType = [[string[4] "scrap_metal_loot"; "vehicle_parts_loot"; "armor_loot"; "electronics_loot"]]

[es(tag=server, on_appear)]
def loot_init(evt : Event;
              loot__countRange : int2;
              var loot__count : int&;
              var loot__type : int&;
              loot__typeName : string)
  if loot__count < 0
    loot__count = rnd_int(loot__countRange.x, loot__countRange.y)
  loot__type = lootType |> find_index(loot__typeName)

[es(tag=server)]
def loot_carrier_update_es(act : UpdateStageInfoAct;
                           unit__ref : UnitRef;
                           eid aka unit_eid : EntityId;
                           loot_carrier__capacity : int;
                           var loot_carrier__loot_count : IntList&;
                           var loot_carrier__loot_type : IntList&;
                           var loot_carrier__loot_itemId : IntList&)
  let unit = unit__ref.unit
  if unit.isDelayed || !unit.isAlive || !unit.isTank
    return

  let bbox = unit.unitTm * unit.boundingBox
  var curLoad = 0
  for cnt in loot_carrier__loot_count
    curLoad += cnt
  if loot_carrier__capacity <= curLoad
    return
  query() <| $ [es] (var loot__count : int&; eid aka loot_eid : EntityId; loot__radius : float; transform : float3x4; loot__type : int; loot__itemId : int)
    if loot_carrier__capacity <= curLoad
      return
    let bSph = BSphere3(transform[3], loot__radius)
    if bbox & bSph
      var typeFound = false
      let canTake = min(loot_carrier__capacity - curLoad, loot__count)
      for lootType, i in loot_carrier__loot_type, range(0, length(loot_carrier__loot_count))
        if lootType == loot__type
          typeFound = true
          loot_carrier__loot_count[i] += canTake
          loot__count -= canTake
          send_net_event(unit_eid, [[EventPickUpLoot loot_type = loot__type, count = canTake]], target_entity_conn(unit_eid))
          break
      if !typeFound
        loot_carrier__loot_type |> push(loot__type)
        loot_carrier__loot_count |> push(canTake)
        loot_carrier__loot_itemId |> push(loot__itemId)
        loot__count -= canTake
        send_net_event(unit_eid, [[EventPickUpLoot loot_type = loot__type, count = canTake]], target_entity_conn(unit_eid))
      curLoad += canTake
      if loot__count <= 0
        destroyEntity(loot_eid)

[es(tag=server)]
def loot_carrier_rage_update_es(act : UpdateStageInfoAct;
                                unit__ref aka hero_unit__ref : UnitRef;
                                var loot_carrier__rage aka hero_loot_carrier__rage : int&)
  if hero_loot_carrier__rage >= 5
    return
  let hero = hero_unit__ref.unit
  if hero.isDelayed || !hero.isAlive || hero.myPlayer == null
    return
  let playerIdx = int(hero.myPlayer.id)
  var heroBbox = hero.boundingBox
  bbox3_inflate(heroBbox, 2.)
  heroBbox = hero.unitTm * heroBbox
  find_query() <| $ [es] (var unit__ref aka victim_unit__ref : UnitRef; var loot_carrier__rage aka victim_loot_carrier__rage : int&; dead_unit__player_id : int)
    let unit = victim_unit__ref.unit
    if victim_loot_carrier__rage >= 0 && hero.eid != unit.eid
      if !unit.isDelayed && !unit.isAlive && !is_allies(unit.army, hero.army) && !unit.bailoutAtExitZone && (dead_unit__player_id < 0 || dead_unit__player_id != playerIdx)
        let bbox = unit.unitTm * unit.boundingBox
        if heroBbox & bbox
          if victim_loot_carrier__rage > hero_loot_carrier__rage
            hero_loot_carrier__rage = victim_loot_carrier__rage
          else
            hero_loot_carrier__rage += 1
          victim_loot_carrier__rage = -1
          return true
    return false

[es(tag=server, track=loot_carrier__rage)]
def loot_carrier_rage_track(evt : Event;
                            var unit__ref : UnitRef;
                            loot_carrier__rage : int)
  let flag = uint(LowRateUnitFlag LRUF_FORCE_VISIBLE_ON_MAP)
  if loot_carrier__rage >= 5
    *unit__ref.unit |> setLowRateUnitFlags(flag)
  else
    *unit__ref.unit |> clrLowRateUnitFlags(flag)

[es(tag=render, track=loot_carrier__rage, on_event=CmdInitComponent)]
def loot_carrier_rage_render_track(evt : Event;
                                   var unit__ref : UnitRef;
                                   loot_carrier__rage : int)
  var unit = unit__ref.unit
  if !unit.isDelayed
    let name = loot_carrier__rage >= 0 ? "rage_0{loot_carrier__rage}" : "rage_00"
    *unit |> changeFlagTex(name)

[es(tag=sound, track=loot_carrier__rage, REQUIRE=controlledHero)]
def loot_carrier_rage_sound_track(evt : Event;
                                  loot_carrier__rage : int;
                                  loot_carrier__pickUpRageSfx : string;
                                  loot_carrier__pickUpRageMaxSfx : string)
  if loot_carrier__rage > 0
    if loot_carrier__rage == 5
      oneshot(loot_carrier__pickUpRageMaxSfx)
    else
      oneshot(loot_carrier__pickUpRageSfx)

[es(tag=sound, on_event=EventPickUpLoot)]
def loot_pickuped_client_es(evt : Event;
                            loot_carrier__pickUpSfx : string)
  oneshot(loot_carrier__pickUpSfx)

[es(tag=server, REQUIRE=loot_carrier__rage)]
def on_loot_carrier_death_es(evt : EventOnUnitDead)
  if evt.killer_eid != INVALID_ENTITY_ID
    query(evt.killer_eid) <| $ [es] (var loot_carrier__rage : int&)
      loot_carrier__rage = min(loot_carrier__rage + 1, 5)

[es(tag=server)]
def on_unit_death_es(evt : EventOnUnitDead;
                     var unit__ref : UnitRef;
                     loot_carrier__rage : int;
                     var killerEid : EntityId&)
  killerEid = evt.killer_eid
  var unit = unit__ref.unit
  if unit.myPlayer == null
    return
  let addCnt = unit.bailoutAtExitZone ? 1 : 0
  if loot_carrier__rage + addCnt > 0
    *unit.myPlayer |> setRageTokens(unit.myPlayer.rageTokens + max(loot_carrier__rage + addCnt, 0))

[es(tag=server)]
def lost_loot_after_death_es(evt : EventOnUnitDead;
                             unit__ref : UnitRef;
                             var loot_carrier__loot_count : IntList&;
                             var loot_carrier__loot_type : IntList&;
                             var loot_carrier__loot_itemId : IntList&)
  let unit = unit__ref.unit
  let player = unit.myPlayer
  for lType, cnt, itemId in loot_carrier__loot_type, loot_carrier__loot_count, loot_carrier__loot_itemId
    if lType < 0 || lType >= length(lootType) || cnt <= 0
      continue
    if !unit.bailoutAtExitZone
      if player != null && !is_session_finalizing() && evt.killer_eid != INVALID_ENTITY_ID
        let deadCnt = int(ceil(float(cnt) * 0.2))
        inventory_add_item(player.userId, itemId, deadCnt)
      createEntity(lootType[lType]) <| $(init)
        init |> set("loot__count", cnt)
        var tm = unit.unitTm
        tm[3] = tm[3] + normalize(float3(rnd_float(-1., 1.), 0., rnd_float(-1., 1.))) * rnd_float(5., 10.)
        init |> set("transform", tm)
    elif player != null && !is_session_finalizing()
      inventory_add_item(player.userId, itemId, cnt)
  loot_carrier__loot_count |> clear()
  loot_carrier__loot_type |> clear()
  loot_carrier__loot_itemId |> clear()

def is_point_in_box_zone(pos : float3; transform : float3x4)
  var zonePos : float3 = inverse(transform) * float3(pos.x, 0.0, pos.z)
  zonePos.y = 0.5
  return BBox3(float3(-0.5, 0.0, -0.5), float3(0.5, 1.0, 0.5)) & zonePos

[es(tag=server)]
def loot_create_after_ri_destr_es(evt : EventRendInstDestroyed;
                                  loot_creater__scrapProb : float;
                                  loot_creater__partsProb : float;
                                  loot_creater__armorProb : float;
                                  loot_creater__electronicsProb : float;
                                  loot_carrier__riHandlers : UInt32List)
  if loot_carrier__riHandlers |> length() <= 0
    return
  if find_index(loot_carrier__riHandlers, evt.riType) < 0
    return
  var scrapProb = loot_creater__scrapProb
  var partsProb = loot_creater__partsProb
  var armorProb = loot_creater__armorProb
  var electrProb = loot_creater__electronicsProb
  find_query() <| $ [es] (transform : float3x4;
                          loot_chance_mult__scrap : float;
                          loot_chance_mult__parts : float;
                          loot_chance_mult__armor : float;
                          loot_chance_mult__electronics : float)
    if is_point_in_box_zone(evt.pos, transform)
      scrapProb *= loot_chance_mult__scrap
      partsProb *= loot_chance_mult__parts
      armorProb *= loot_chance_mult__armor
      electrProb *= loot_chance_mult__electronics
      return true
    return false
  var rand = rnd_float(0., 1.)
  var loot_template = ""
  if rand < scrapProb
    loot_template = "scrap_metal_loot"
  else
    rand -= scrapProb
    if rand < partsProb
      loot_template = "vehicle_parts_loot"
    else
      rand -= partsProb
      if rand < armorProb
        loot_template = "armor_loot"
      else
        rand -= armorProb
        if rand < electrProb
          loot_template = "electronics_loot"
  if !empty(loot_template)
    createEntity(loot_template) <| $(init)
      var tm = identity3x4()
      tm[3] = evt.pos
      init |> set("transform", tm)

[es(tag=server, on_event=EventFlightStart, REQUIRE=loot_creater__scrapProb)]
def loot_chance_mult_zone_init(evt : Event)
  var a = [[int[7] 1; 2; 3; 4; 0; 0; 0; ]]
  a |> shuffle()
  using() <| $(var zones : EidList)
    query() <| $ [es(REQUIRE=loot_chance_mult__scrap)] (eid : EntityId)
      zones |> push(eid)
    for i in range(0, length(zones))
      let loot_type = a[i % length(a)]
      query(zones[i]) <| $ [es] (var loot_chance_mult__scrap : float&;
                                 var loot_chance_mult__parts : float&;
                                 var loot_chance_mult__armor : float&;
                                 var loot_chance_mult__electronics : float&)
        if loot_type == 1
          loot_chance_mult__scrap = get_game_params().lootZoneChanceMult
        elif loot_type == 2
          loot_chance_mult__parts = get_game_params().lootZoneChanceMult
        elif loot_type == 3
          loot_chance_mult__armor = get_game_params().lootZoneChanceMult
        elif loot_type == 4
          loot_chance_mult__electronics = get_game_params().lootZoneChanceMult

[es(tag=server)]
def set_rage_item_award(evt : EventOnSessionEnd;
                        m_player : MPlayer)
  if m_player.rageTokens > 0
    inventory_add_item(m_player.userId, 2907200, m_player.rageTokens)

[es(tag=server)]
def set_rage_item_from_alive_unit_award(evt : EventOnSessionEnd;
                                        unit__ref : UnitRef;
                                        loot_carrier__rage : int;
                                        var loot_carrier__loot_count : IntList&;
                                        var loot_carrier__loot_type : IntList&;
                                        var loot_carrier__loot_itemId : IntList&)
  let unit = unit__ref.unit
  if unit.isDelayed || !unit.isAlive || unit.myPlayer == null
    return
  let player = unit.myPlayer
  if loot_carrier__rage > 0
    inventory_add_item(player.userId, 2907200, loot_carrier__rage)
  for lType, cnt, itemId in loot_carrier__loot_type, loot_carrier__loot_count, loot_carrier__loot_itemId
    if lType < 0 || lType >= length(lootType) || cnt <= 0
      continue
    let endCnt = int(ceil(float(cnt) * 0.2))
    inventory_add_item(player.userId, itemId, endCnt)
  loot_carrier__loot_count |> clear()
  loot_carrier__loot_type |> clear()
  loot_carrier__loot_itemId |> clear()