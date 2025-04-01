options no_aot
require ecs
require ecs.common
require DagorConsole
require Dacoll

def spawn_soldiers_at_pos(pos : float3; count, team : int; spawn_template : string; cell_size : float)
  query() <| $ [es(REQUIRE=devSoldier)] (eid : EntityId) { destroyEntity(eid); }
  var offset = float3(0.f, 0.f, 0.f)
  for j in range(0, count)
    for i in range(0, count)
      createEntity(spawn_template) <| $(var init : ComponentsInitializer)
        var tm : float3x4
        tm[0] = float3(1., 0., 0.)
        tm[1] = float3(0., 1., 0.)
        tm[2] = float3(0., 0., 1.)
        tm[3] = pos + offset - float3(float(count) * 0.5f, 0.f, float(count) * 0.5f)
        set(init, "transform", tm)
        
        let usedTeam = team == 0 ? (i ^ j) % 2 + 1 : team
        set(init, "unit_params__armyId", usedTeam)
        set(init, "spawn_immunity__timer", 0.f)

        offset += float3(0.f, 0.f, cell_size)
    offset += float3(cell_size, 0.f, 0.f)
    offset.z = 0.f

[console_cmd(name="squad.spawnMoreSoldiers")]
def squad_spawnMoreSoldiers(count = 7; isAlive = true; team = 0; cellSize = 1.f)
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    var tm : float3x4
    if !camera__active
      return false
    var len = 100.0
    var norm = float3()
    tm = transform
    let dir = tm[2]
    let pos = tm[3]
    traceray_normalized(pos, dir, len, norm)
    let center = pos + dir * len
    spawn_soldiers_at_pos(center, count, team, isAlive ? "base_soldier+dev_soldier_tag" : "dead_base_soldier+dev_soldier_tag", cellSize)
    return true