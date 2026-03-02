options no_aot

require ecs
require math.base
require DagorMath
require %game.utils.utils_common
require %appGame.infantry.es.vehicle_turrets_common
require %appGame.infantry.ai.walker_nodes_common
require %appGame.infantry.ai.ai_team_danger_zones_common
require %game.events
require DagorConsole
require DagorDebug3D
require DagorSystem
require DngWalkerai
require pathfinder


enum NavZonesDebugFlags
  None     = 0
  Turret   = 1 << 0
  Death    = 1 << 1

[console_cmd(name="ai.debug_nav_zones", hint="all, none, turret, death")]
def ai_nav_zones_toggle_debug(option : string)
  var flags : int = 0
  if option == "none"
    flags = 0
  elif option == "all"
    flags = int(NavZonesDebugFlags.Turret) | int(NavZonesDebugFlags.Death)
  elif option == "turret"
    flags = int(NavZonesDebugFlags.Turret)
  elif option == "death"
    flags = int(NavZonesDebugFlags.Death)
  else
    console_print("Unknown option '{option}'. Valid options are: all, none, turret, death.")
    return

  var debugEid = INVALID_ENTITY_ID
  query() <| $ [es] (eid : EntityId;
                     var nav_zones_debug__modeFlags : int&)
    debugEid = eid
    if option != "none" && option != "all"
      nav_zones_debug__modeFlags ^= flags
    else
      nav_zones_debug__modeFlags = flags
    flags = nav_zones_debug__modeFlags

  if debugEid == INVALID_ENTITY_ID && flags != 0
    createEntity("nav_zones_debug") <| $(init)
      init |> set("nav_zones_debug__modeFlags", flags)
  if debugEid != INVALID_ENTITY_ID && flags == 0
    destroyEntity(debugEid)


[console_cmd(name="ai.remove_nav_zones", hint="all, turret, death, allies")]
def ai_nav_zones_debug_remove(option : string)
  let removeTurret = option == "all" || option == "turret"
  let removeDeath  = option == "all" || option == "death"
  let removeAllies = option == "all" || option == "allies"

  if !removeTurret && !removeDeath && !removeAllies
    console_print("Unknown option '{option}'. Valid options are: all, turret, death, allies.")
    return

  query() <| $ [es] (var walker_custom_nav : CustomNav&;
                     var turret_danger_zones__list : int3&;
                     var turret_danger_zones__prevNext : IPoint2List&;
                     turret_danger_zones__areasData : IntList;
                     var death_danger_zones__list : int3&;
                     var death_danger_zones__prevNext : IPoint2List&;
                     death_danger_zones__areasData : IntList)
    if removeTurret
      var cur = turret_danger_zones__list.x
      while cur != -1
        walker_custom_nav_areaRemove(walker_custom_nav, turret_danger_zones__areasData[cur])
        cur = danger_zones_list_remove(cur, turret_danger_zones__list, turret_danger_zones__prevNext)

    if removeDeath
      var cur = death_danger_zones__list.x
      while cur != -1
        walker_custom_nav_areaRemove(walker_custom_nav, death_danger_zones__areasData[cur])
        cur = danger_zones_list_remove(cur, death_danger_zones__list, death_danger_zones__prevNext)


[console_cmd(name="ai.check_point_safe")]
def ai_check_point_safe_cmd(x : float; y : float; z : float; team : int)
  let pos = float3(x, y, z)
  let safe = is_point_safe(pos, team)
  console_print("Point ({x}, {y}, {z}) for team {team} is {safe ? "SAFE" : "DANGEROUS"}")


def private draw_nav_zones(walker_custom_nav : CustomNav;
                           cur_time : float;
                           head_node : int;
                           prev_next : IPoint2List;
                           areas_data : IntList;
                           areas_time : FloatList;
                           area_fade_time : float;
                           color : E3DCOLOR)
  var cur = head_node
  while cur != -1
    let areaId = areas_data[cur]
    let areaTime = areas_time[cur]
    let areaPosRadius = walker_custom_nav_getCylAreaBBoxPosRadius(walker_custom_nav, areaId)
    let areaPos = areaPosRadius.xyz
    let areaRadius = areaPosRadius.w

    let fadeStartTime = areaTime - area_fade_time
    let fadeEndTime = areaTime
    let alpha = clamp(cvt(cur_time, fadeStartTime, fadeEndTime, 1.0, 0.0), 0.0, 1.0)

    if alpha > 0.0
      let col = E3DCOLOR(uint(int(float(0xFF) * alpha) << 24) | uint(color))
      draw_debug_circle_buffered(areaPos + float3(0.f, 0.2f, 0.f), float3(0, 1, 0), areaRadius, col, 16, 1)
      draw_debug_sphere_buffered(areaPos, 0.2f, col, 1)
      
      
      

    cur = prev_next[cur].y

[es(tag=(server, dev), no_order)]
def ai_nav_zones_draw_debug(info : ParallelUpdateFrameDelayed;
                            nav_zones_debug__modeFlags : int)
  if (nav_zones_debug__modeFlags & int(NavZonesDebugFlags.Turret)) != 0
    query() <| $ [es] (walker_custom_nav : CustomNav;
                       turret_danger_zones__vehicleMainAreaList : IntList;
                       turret_danger_zones__vehicleMainAreaRadius : float;
                       turret_danger_zones__list : int3;
                       turret_danger_zones__prevNext : IPoint2List;
                       turret_danger_zones__areasData : IntList;
                       turret_danger_zones__areasTime : FloatList;
                       turret_danger_zones__areaDuration : float;
                       turret_danger_zones__areaFadeTimeStart : float)
      for mainArea in turret_danger_zones__vehicleMainAreaList
        let areaBBox = walker_custom_nav_getAreaBBox(walker_custom_nav, mainArea)
        let areaCenter = areaBBox.center
        let areaBottom = float3(areaCenter.x, areaBBox.boxMin.y, areaCenter.z)
        let areaTop = float3(areaCenter.x, areaBBox.boxMax.y, areaCenter.z)
        let radius = turret_danger_zones__vehicleMainAreaRadius
        draw_debug_circle_buffered(areaBottom, float3(0, 1, 0), radius, E3DCOLOR(0xFF00FFFF), 24, 1)
        draw_debug_circle_buffered(areaTop, float3(0, 1, 0), radius, E3DCOLOR(0xFF00FFFF), 24, 1)

      assume head_node = turret_danger_zones__list.x
      let fadeTime = turret_danger_zones__areaDuration - turret_danger_zones__areaFadeTimeStart
      draw_nav_zones(walker_custom_nav, info.curTime, head_node,
                    turret_danger_zones__prevNext,
                    turret_danger_zones__areasData,
                    turret_danger_zones__areasTime,
                    fadeTime,
                    E3DCOLOR(0x00FF00))

  if (nav_zones_debug__modeFlags & int(NavZonesDebugFlags.Death)) != 0
    query() <| $ [es] (walker_custom_nav : CustomNav;
                       team__id : int;
                       death_danger_zones__list : int3;
                       death_danger_zones__prevNext : IPoint2List;
                       death_danger_zones__areasData : IntList;
                       death_danger_zones__areasTime : FloatList;
                       death_danger_zones__areaFadeTime : float = 15.0)
      assume head_node = death_danger_zones__list.x
      let color = team__id == 1 ? E3DCOLOR(0xFFFF0000) : E3DCOLOR(0xFF9400D3)
      draw_nav_zones(walker_custom_nav, info.curTime, head_node,
                     death_danger_zones__prevNext,
                     death_danger_zones__areasData,
                     death_danger_zones__areasTime,
                     death_danger_zones__areaFadeTime,
                     color)
