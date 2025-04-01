options no_aot

require ecs
require ecs.common
require ecs.ecs_template
require DagorSystem
require DagorConsole
require WTCamera
require DaWeapons
require walkerai
require DngWalkerai
require %appGame.es.ai_trench_bot_common
require DagorDebug3D


[ecs_template]
struct trench_debug
  trench_debug__showMask : uint


enum TrenchDebugOptions
  SHOW_COVERS
  SHOW_SPAWNERS
  SHOW_LOOK_TARGETS
  SHOW_LOOK_COVERS
  SHOW_WAYPOINTS
  SHOW_NUM


let SHOW_ALL_MASK = (1u << uint(TrenchDebugOptions.SHOW_NUM)) - 1u


def make_show_mask(option : TrenchDebugOptions)
  return 1u << uint(option)


def make_show_mask(optionS : array<TrenchDebugOptions>)
  var res = 0u
  for option in optionS
    res |= make_show_mask(option)
  return res


[console_cmd(name="trench_storm")]
def trench_storm_cmd(offender_trench_bot_spawner_id : int)
  trench_storm(offender_trench_bot_spawner_id)


[console_cmd(name="trench_destroy_bots")]
def trench_destroy_bots(spawner_id : int = 0)
  query() <| $ [es(REQUIRE=trench_bot)] (eid : EntityId; trench_bot__spawnerEid : EntityId)
    if spawner_id == 0
      destroyEntity(eid)
    else
      query(trench_bot__spawnerEid) <| $ [es] (trench_bot_spawner__id : int)
        if trench_bot_spawner__id == spawner_id
          destroyEntity(eid)


[console_cmd(name="trench_spawner_enable")]
def trench_spawner_enable(id : int = 0)
  if id == 0
    query() <| $ [es] (var trench_bot_spawner__active : bool&)
      trench_bot_spawner__active = true
  else
    let eid = EntityId(uint(id))
    query(eid) <| $ [es] (var trench_bot_spawner__active : bool&)
      trench_bot_spawner__active = true


[console_cmd(name="trench_spawner_disable")]
def trench_spawner_disable(id : int = 0)
  if id == 0
    query() <| $ [es] (var trench_bot_spawner__active : bool&)
      trench_bot_spawner__active = false
  else
    let eid = EntityId(uint(id))
    query(eid) <| $ [es] (var trench_bot_spawner__active : bool&)
      trench_bot_spawner__active = false


def change_trench_debug_show_mask(option : string; var trench_debug__showMask : uint&)
  if option == "toggle"
    if trench_debug__showMask != SHOW_ALL_MASK
      trench_debug__showMask = SHOW_ALL_MASK
    else
      trench_debug__showMask = 0u
  elif option == "all"
    trench_debug__showMask = SHOW_ALL_MASK
  elif option == "none"
    trench_debug__showMask = 0u
  elif option == "cover"
    trench_debug__showMask ^= make_show_mask(TrenchDebugOptions.SHOW_COVERS)
  elif option == "spawner"
    trench_debug__showMask ^= make_show_mask(TrenchDebugOptions.SHOW_SPAWNERS)
  elif option == "look"
    let lookMask = make_show_mask([TrenchDebugOptions.SHOW_LOOK_TARGETS, TrenchDebugOptions.SHOW_LOOK_COVERS])
    if (trench_debug__showMask & lookMask) == lookMask
      trench_debug__showMask &= ~lookMask
    else
      trench_debug__showMask |= lookMask
  elif option == "look_target"
    trench_debug__showMask ^= make_show_mask(TrenchDebugOptions.SHOW_LOOK_TARGETS)
  elif option == "look_cover"
    trench_debug__showMask ^= make_show_mask(TrenchDebugOptions.SHOW_LOOK_COVERS)
  elif option == "waypoint"
    trench_debug__showMask ^= make_show_mask(TrenchDebugOptions.SHOW_WAYPOINTS)
  else
    logerr("unknown option")


[console_cmd(name="trench_debug", hint="toggle, all, none, cover, spawner, waypoint, look, look_target, look_cover")]
def trench_debug_cmd(option : string = "toggle")
  let isFound = find_query() <| $ [es] (eid : EntityId; var trench_debug__showMask : uint&)
    change_trench_debug_show_mask(option, trench_debug__showMask)
    if trench_debug__showMask == 0u
      destroyEntity(eid)
    return true
  if !isFound
    var mask = 0u
    change_trench_debug_show_mask(option, mask)
    if mask != 0u
      createEntity("trench_debug") <| $(init)
        set(init, "trench_debug__showMask", mask)


def draw_waypoint_line(cur_waypoint_pos : float3; prev_waypoint_eid : EntityId; spawner_eid : EntityId)
  let prevEid = prev_waypoint_eid == INVALID_ENTITY_ID ? spawner_eid : prev_waypoint_eid
  query(prevEid) <| $ [es] (transform aka prev_transform : float3x4)
    draw_debug_line_buffered(cur_waypoint_pos, prev_transform[3], E3DCOLOR(0xFF0000FF), 1)


[es(tag=render, no_order)]
def draw_trench_cover_ids(info : UpdateStageInfoAct)
  find_query() <| $ [es] (trench_debug__showMask : uint)
    begin_draw_cached_debug_lines(false, false, false)
    if (trench_debug__showMask & make_show_mask(TrenchDebugOptions.SHOW_COVERS)) != 0u
      query() <| $ [es] (trench_cover__id : int; trench_cover__occupied : bool; trench_cover__active : bool; trench_cover__blocked : bool; transform : float3x4)
        let color = trench_cover__occupied ? E3DCOLOR(0xFFCCFFCC) : !trench_cover__active || trench_cover__blocked ? E3DCOLOR(0xFF005500) : E3DCOLOR(0xFF00FF00)
        add_debug_text_mark(transform[3], "{trench_cover__id}",  -1, 0.0, color)
    if (trench_debug__showMask & make_show_mask(TrenchDebugOptions.SHOW_SPAWNERS)) != 0u
      query() <| $ [es] (trench_bot_spawner__id : int; trench_bot_spawner__blocked : bool; trench_bot_spawner__stormedSpawnerId : int; transform : float3x4)
        let text = trench_bot_spawner__stormedSpawnerId < 0 ? "{trench_bot_spawner__id}" : "{trench_bot_spawner__id} -> {trench_bot_spawner__stormedSpawnerId}"
        add_debug_text_mark(transform[3], text,  -1, 0.0, trench_bot_spawner__blocked ? E3DCOLOR(0xFF550000) : E3DCOLOR(0xFFFF0000))
    let lookMask = make_show_mask([TrenchDebugOptions.SHOW_LOOK_TARGETS, TrenchDebugOptions.SHOW_LOOK_COVERS])
    if (trench_debug__showMask & lookMask) != 0u
      query() <| $ [es] (trench_bot_spawner__id : int; trench_bot_spawner__stormedSpawnerId : int)
        var stormedTrenchCoverIdEidMap = make_trench_cover_id_eid_map(trench_bot_spawner__stormedSpawnerId)
        query() <| $ [es] (transform : float3x4; trench_cover__id : int; trench_cover__spawnerId : int; trench_cover__lookAtTargetEid : EntityId)
          if trench_cover__spawnerId != trench_bot_spawner__id
            return
          let stormedCoverEid = get_value(stormedTrenchCoverIdEidMap, trench_cover__id)
          let lookAtPos = get_trench_bot_look_at_position(transform[3], stormedCoverEid, trench_cover__lookAtTargetEid)
          var shouldDrawLine = false
          if trench_cover__lookAtTargetEid == INVALID_ENTITY_ID
            shouldDrawLine = (trench_debug__showMask & make_show_mask(TrenchDebugOptions.SHOW_LOOK_COVERS)) != 0u
          else
            shouldDrawLine = (trench_debug__showMask & make_show_mask(TrenchDebugOptions.SHOW_LOOK_TARGETS)) != 0u
          if shouldDrawLine
            draw_debug_line_buffered(transform[3], lookAtPos, E3DCOLOR(0xFFFF00FF), 1)
      query() <| $ [es] (transform : float3x4; trench_target__id : int)
        add_debug_text_mark(transform[3], "{trench_target__id}",  -1, 0.0, E3DCOLOR(0xFFFF00FF))
    if (trench_debug__showMask & make_show_mask(TrenchDebugOptions.SHOW_WAYPOINTS)) != 0u
      query() <| $ [es] (trench_cover__waypointEid : EntityId; trench_cover__spawnerEid : EntityId; transform aka cover_transform : float3x4)
        draw_waypoint_line(cover_transform[3], trench_cover__waypointEid, trench_cover__spawnerEid)
      query() <| $ [es] (trench_waypoint__id : int; trench_waypoint__blocked : bool; trench_waypoint__prevEid : EntityId; trench_waypoint__spawnerEid : EntityId; transform aka cur_transform : float3x4)
        add_debug_text_mark(cur_transform[3], "{trench_waypoint__id}",  -1, 0.0, trench_waypoint__blocked ? E3DCOLOR(0xFF000055) : E3DCOLOR(0xFF0000FF))
        draw_waypoint_line(cur_transform[3], trench_waypoint__prevEid, trench_waypoint__spawnerEid)
    end_draw_cached_debug_lines()
    return true
