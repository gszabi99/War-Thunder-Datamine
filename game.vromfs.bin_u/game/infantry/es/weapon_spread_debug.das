options no_aot
require ecs
require ecs.ecs_template
require DaWeapons
require DagorDebug3D
require DagorConsole
require %appGame.infantry.es.net_console_macro


[ecs_template]
struct gun_spread_debug_draw
  gunSpreadDebug : Tag


[console_cmd(name="gun.debug_spread", hint="Draw cone for hero's gun where bullets can go")]
def gun_spread_debug()
  var exists = false
  query() <| $ [es(REQUIRE=gunSpreadDebug)] (eid : EntityId)
    destroyEntity(eid)
    console_print("gun.debug_spread = false")
    exists = true
  if !exists
    createEntity("gun_spread_debug_draw")
    console_print("gun.debug_spread = true")


[es(tag=(render, dev), no_order, REQUIRE=gunSpreadDebug)]
def draw_gun_spread(evt : UpdateStageInfoAct)
  query() <| $ [es(REQUIRE=hero)] (human_weap__currentGunEid : EntityId)
    query(human_weap__currentGunEid) <| $ [es] (gun : Gun&)
      let spreadConusLength = 100.0
      let projectileSpread = gun_calcSpread(gun).x 
      draw_debug_cone_buffered(gun.curState.gunTm[3], gun.curState.gunTm[3] + gun.curState.gunTm[0] * spreadConusLength,
                               projectileSpread, E3DCOLOR(0xFFFFFFFF), 16, 1)


[net_console_cmd(name="gun.change_magnification", hint="Changes current gun's magnification value")]
def gun_change_magnification(magnification : float = 1.0, @net_hero eid : EntityId)
  query(eid) <| $ [es] (human_weap__currentGunEid : EntityId)
    query(human_weap__currentGunEid) <| $ [es] (var gun__magnification : float&)
      let clampedMagnification = clamp(magnification, 0.1, 20.0)
      gun__magnification = clampedMagnification
