options no_aot

require ecs
require ecs.ecs_template
require DagorConsole

[ecs_template]
struct projectile_hp_damage_debug
  projectileHpDamageDebug : Tag

[console_cmd(name="projectile.hp_damage_debug")]
def projectile_hp_damage_debug(v : int = -1)
  var isEnabled = false
  let wasEnabled = find_query() <| $ [es(REQUIRE=projectileHpDamageDebug)] (eid : EntityId)
    isEnabled = true
    if v != 1
      destroyEntity(eid)
      isEnabled = false
    return true
  if !wasEnabled && v != 0
    createEntity("projectile_hp_damage_debug")
    isEnabled = true
  if isEnabled
    console_print("on")
  else
    console_print("off")
