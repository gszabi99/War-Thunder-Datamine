options no_aot
require ecs
require ecs.common
require strings
require DagorDebug3D
require DagorConsole
require DagorMath
require DagorMathUtils
require Dacoll
require MPlayer
require Mission
require %appGame.infantry.es.team_common
require %appGame.infantry.es.net_console_macro

require ecs.ecs_template
[ecs_template]
struct sector_capzone_debug_draw
  sectorCapzoneDebug : Tag

[console_cmd(name="capzone.draw_sectors", hint="Toggle sector capture zone debug draw")]
def sector_capzone_debug_cmd()
  let exist = find_query() <| $ [es(REQUIRE=sectorCapzoneDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !exist
    createEntity("sector_capzone_debug_draw")
  console_print("sector capzone debug {exist ? "disabled" : "enabled"}")

def private force_sector_owners(zone_id : int; sector_index : int; team : int) : int
  var proxyEid = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=sectoredCapzone)] (eid : EntityId; capture_zone__zoneId : int)
    if capture_zone__zoneId != zone_id
      return false
    proxyEid = eid
    return true
  var count = 0
  query() <| $ [es] (capzone_sector__parentEid : EntityId;
                     capzone_sector__index : int;
                     var capzone_sector__owningTeam : int&;
                     var capzone_sector__capTeam : int&;
                     var capzone_sector__progress : float&)
    if capzone_sector__parentEid != proxyEid || (sector_index >= 0 && capzone_sector__index != sector_index)
      return
    capzone_sector__owningTeam = team
    capzone_sector__capTeam = team
    capzone_sector__progress = team == 1 ? -1.0 : (team == 2 ? 1.0 : 0.0)
    count++
  return count

[net_console_cmd(name="capzone.sector_owner", hint="capzone.sector_owner <zoneId> <sectorIndex> <team>: force a sector owner (team -1, 1 or 2)")]
def sector_owner_cmd(zone_id : int; sector_index : int; team : int)
  let count = force_sector_owners(zone_id, sector_index, team)
  console_print("capzone.sector_owner: {count > 0 ? "done" : "sector not found"}")

[net_console_cmd(name="capzone.set_owner", hint="capzone.set_owner <zoneId> <team>: capture a zone and all its sectors for team 1 or 2, 0 = neutral")]
def set_owner_cmd(zone_id : int; team : int)
  force_sector_owners(zone_id, -1, team == 0 ? TEAM_UNASSIGNED : team)
  capture_zone_set_army(zone_id, team)

let
  EDGE_SPHERE_STEP = 2.5
  EDGE_SPHERE_RADIUS = 0.3
  DEBUG_TEXT_X = 300.0
  DEBUG_TEXT_Y = 130.0

def private owner_color(owner : int; local_team : int) : E3DCOLOR
  if owner == -1
    return E3DCOLOR(0xFFC0C0C0)
  if owner == local_team
    return E3DCOLOR(0xFF3060FF)
  return E3DCOLOR(0xFFFF6030)

def private ground_y(x, z : float; top_y : float; fallback : float) : float
  var t = 1000.
  var norm = float3(0., 1., 0.)
  if traceray_normalized(float3(x, top_y + 10., z), float3(0., -1., 0.), t, norm)
    return top_y + 10. - t
  return fallback

def private draw_sector_rings()
  var centers : table<EntityId; float3>
  let localPlayer = player_get_local()
  let localTeam = localPlayer != null ? int(localPlayer.team) : -1
  query() <| $ [es] (eid : EntityId;
                     transform : float3x4;
                     capzone_sector__topY : float;
                     capzone_sector__bottomY : float)
    let fallbackY = (capzone_sector__topY + capzone_sector__bottomY) * 0.5
    let gy = ground_y(transform[3].x, transform[3].z, capzone_sector__topY, fallbackY)
    centers[eid] = float3(transform[3].x, gy + 2., transform[3].z)
  query() <| $ [es] (eid : EntityId;
                     capzone_sector__points : Point2List;
                     capzone_sector__topY : float;
                     capzone_sector__bottomY : float;
                     capzone_sector__owningTeam : int;
                     capzone_sector__neighborEids : EidList const?;
                     capzone_sector__strongpointEid : EntityId const?)
    let n = length(capzone_sector__points)
    if n == 0 || !key_exists(centers, eid)
      return
    let color = owner_color(capzone_sector__owningTeam, localTeam)
    let fallbackY = (capzone_sector__topY + capzone_sector__bottomY) * 0.5
    var firstPt = float3(0.)
    var prevPt = float3(0.)
    var haveFirst = false
    for i in range(n)
      let a = capzone_sector__points[i]
      let b = capzone_sector__points[(i + 1) % n]
      let edge = b - a
      let steps = max(1, int(length(edge) / EDGE_SPHERE_STEP))
      for s in range(steps)
        let k = float(s) / float(steps)
        let x = a.x + edge.x * k
        let z = a.y + edge.y * k
        let y = ground_y(x, z, capzone_sector__topY, fallbackY)
        let p = float3(x, y + EDGE_SPHERE_RADIUS, z)
        draw_debug_sphere_buffered(p, EDGE_SPHERE_RADIUS, color, 12, 1)
        if haveFirst
          draw_cached_debug_line(prevPt, p, color)
        else
          firstPt = p
          haveFirst = true
        prevPt = p
    if haveFirst
      draw_cached_debug_line(prevPt, firstPt, color)
    let center = centers[eid]
    if capzone_sector__neighborEids != null
      for neighborEid in *capzone_sector__neighborEids
        if uint(neighborEid) > uint(eid) && key_exists(centers, neighborEid)
          draw_cached_debug_line(center, centers[neighborEid], E3DCOLOR(0xFFFFFFFF))
    if capzone_sector__strongpointEid != null
      query(*capzone_sector__strongpointEid) <| $ [es] (transform aka sp_transform : float3x4)
        draw_cached_debug_line(center, sp_transform[3], E3DCOLOR(0xFFFF5050))

def private draw_sector_states(hero_sector : EntityId; hero_parent : EntityId)
  var lines : array<string>
  query() <| $ [es] (eid : EntityId;
                     capzone_sector__parentEid : EntityId;
                     capzone_sector__index : int;
                     capzone_sector__owningTeam : int;
                     capzone_sector__capTeam : int;
                     capzone_sector__progress : float;
                     capzone_sector__strongpointName : string;
                     teamPresence : Object)
    if capzone_sector__parentEid != hero_parent || capzone_sector__index < 0
      return
    if length(lines) <= capzone_sector__index
      resize(lines, capzone_sector__index + 1)
    let mark = eid == hero_sector ? ">" : " "
    let p1 = team_presence_count(teamPresence, 1)
    let p2 = team_presence_count(teamPresence, 2)
    lines[capzone_sector__index] = "{mark} S{capzone_sector__index + 1} owner {capzone_sector__owningTeam} cap {capzone_sector__capTeam} prog {fmt(":.2f", capzone_sector__progress)} [{p1}/{p2}] {capzone_sector__strongpointName}"
  var text = "sector capzone {uint(hero_parent)}"
  for line in lines
    if !empty(line)
      text += "\n{line}"
  add_debug_text_mark_screen(DEBUG_TEXT_X, DEBUG_TEXT_Y, text, -1, 0.0, E3DCOLOR(0xFF303030))

[es(tag=render, no_order, REQUIRE=sectorCapzoneDebug)]
def sector_capzone_debug_draw_es(act : UpdateStageInfoRenderDebug)
  begin_draw_cached_debug_lines(false, false, false)
  draw_sector_rings()
  end_draw_cached_debug_lines()

  var heroPos = float3(0.)
  let hasHero = find_query() <| $ [es(REQUIRE=hero)] (transform : float3x4)
    heroPos = transform[3]
    return true
  if !hasHero
    return
  var heroSector = INVALID_ENTITY_ID
  var heroParent = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid : EntityId;
                          capzone_sector__parentEid : EntityId;
                          capzone_sector__points : Point2List)
    if !is_point_in_poly(heroPos.xz, capzone_sector__points)
      return false
    heroSector = eid
    heroParent = capzone_sector__parentEid
    return true
  if heroSector != INVALID_ENTITY_ID
    draw_sector_states(heroSector, heroParent)
