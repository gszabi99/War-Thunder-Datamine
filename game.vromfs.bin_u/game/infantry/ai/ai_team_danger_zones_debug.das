options no_aot

require ecs
require math.base
require DagorMath
require %game.utils.utils_common
require %appGame.infantry.es.vehicle_turrets_common
require %appGame.infantry.ai.walker_nodes_common
require %game.events
require DagorConsole
require DagorDebug3D
require DagorSystem
require DngWalkerai
require pathfinder

[console_cmd(name="ai.debug_vehicle_danger_zones")]
def ai_vehicle_danger_zones_toggle_debug()
  var debugEid = INVALID_ENTITY_ID
  query() <| $ [es] (eid : EntityId;
                     var turret_danger_zones__areasDebugData  : Point4List&;
                     var turret_danger_zones__areasDebugTimes : Point2List&)
    turret_danger_zones__areasDebugData |> clear()
    turret_danger_zones__areasDebugTimes |> clear()
    debugEid = eid

  if debugEid == INVALID_ENTITY_ID
    console_print("Vehicle danger zones debug: ON")
    createEntity("team_danger_zones_debug")
  else
    console_print("Vehicle danger zones debug: OFF")
    destroyEntity(debugEid)

[console_cmd(name="ai.check_point_safe")]
def ai_check_point_safe_cmd(x : float; y : float; z : float; team : int)
  let pos = float3(x, y, z)
  let safe = is_point_safe(pos, team)
  console_print("Point ({x}, {y}, {z}) for team {team} is {safe ? "SAFE" : "DANGEROUS"}")

[es(tag=(server, dev), no_order)]
def ai_vehicle_danger_zones_debug(info : ParallelUpdateFrameDelayed;
                                  var turret_danger_zones__areasDebugData  : Point4List&;
                                  var turret_danger_zones__areasDebugTimes : Point2List&)
  query() <| $ [es] (walker_custom_nav : CustomNav;
                     turret_danger_zones__vehicleMainAreaList : IntList;
                     turret_danger_zones__vehicleMainAreaRadius : float)
    for mainArea in turret_danger_zones__vehicleMainAreaList
      let areaBBox = walker_custom_nav_getAreaBBox(walker_custom_nav, mainArea)
      let areaCenter = areaBBox.center
      let areaBottom = float3(areaCenter.x, areaBBox.boxMin.y, areaCenter.z)
      let areaTop = float3(areaCenter.x, areaBBox.boxMax.y, areaCenter.z)
      let radius = turret_danger_zones__vehicleMainAreaRadius
      draw_debug_circle_buffered(areaBottom, float3(0, 1, 0), radius, E3DCOLOR(0xFF00FFFF), 24, 1)
      draw_debug_circle_buffered(areaTop, float3(0, 1, 0), radius, E3DCOLOR(0xFF00FFFF), 24, 1)

  var i = length(turret_danger_zones__areasDebugData)
  while --i >= 0
    let data = turret_danger_zones__areasDebugData[i]
    let pos = data.xyz
    let radius = data.w
    let times = turret_danger_zones__areasDebugTimes[i]
    let alpha = clamp(cvt(info.curTime, times.x, times.y, 1.0, 0.0), 0.0, 1.0)
    if alpha > 0.0
      draw_debug_circle_buffered(pos + float3(0.f, 0.1f, 0.f), float3(0, 1, 0), radius, E3DCOLOR(uint(int(float(0xFF) * alpha) << 24) | 0x00FF00), 16, 1)
      draw_debug_circle_buffered(pos + float3(0.f, 5.0f, 0.f), float3(0, 1, 0), radius, E3DCOLOR(uint(int(float(0xFF) * alpha) << 24) | 0x00FF00), 16, 1)
    else
      turret_danger_zones__areasDebugData |> erase(i)
      turret_danger_zones__areasDebugTimes |> erase(i)
