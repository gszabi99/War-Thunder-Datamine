options no_aot
require ecs
require ecs.ecs_template
require DngHuman
require DagorConsole
require DagorDebug3D
require Weapon
require %game.utils.net_utils
require %appGame.infantry.es.net_console_macro


[ecs_template]
struct trajectory_debug
  trajectory_debug_tag : Tag


[console_cmd(name="trajectory.debug_draw")]
def trajectory_debug_draw_cmd()
  let found = find_query() <| $ [es(REQUIRE=trajectory_debug_tag)] (eid : EntityId)
    destroyEntity(eid)
    console_print("trajectory.debug_draw = false")
    return true
  if !found
    createEntity("trajectory_debug")
    console_print("trajectory.debug_draw = true")


[es(tag=server, no_order)]
def transform_trajectory_update_server_es(info : UpdateStageInfoAct;
                                          transform : float3x4;
                                          var trajectory_debug__serverPos : float3&)
  trajectory_debug__serverPos = transform[3]

[es(tag=netClient, no_order)]
def transform_trajectory_update_client_es(info : UpdateStageInfoAct;
                                          transform : float3x4;
                                          var trajectory_debug__clientPos : float3&)
  trajectory_debug__clientPos = transform[3]

[es(tag=gameClient, no_order)]
def draw_shell_server_pos_es(info : UpdateStageInfoAct;
                             trajectory_debug__clientPos : float3;
                             trajectory_debug__serverPos : float3;
                             var trajectory_debug__clientPosOld : float3&;
                             var trajectory_debug__serverPosOld : float3&)
  let found = find_query() <| $ [es(REQUIRE=trajectory_debug_tag)] () => true
  if found
    draw_debug_sphere_buffered(trajectory_debug__clientPos, 0.01, E3DCOLOR(0xff00ff00), 3000)
    draw_debug_sphere_buffered(trajectory_debug__serverPos, 0.01, E3DCOLOR(0xffff0000), 3000)
    if trajectory_debug__clientPosOld != float3(0.0)
      draw_debug_line_buffered(trajectory_debug__clientPosOld, trajectory_debug__clientPos, E3DCOLOR(0xff00ff00), 3000)
    if trajectory_debug__serverPosOld != float3(0.0)
      draw_debug_line_buffered(trajectory_debug__serverPosOld, trajectory_debug__serverPos, E3DCOLOR(0xffff0000), 3000)
    trajectory_debug__clientPosOld = trajectory_debug__clientPos
    trajectory_debug__serverPosOld = trajectory_debug__serverPos
