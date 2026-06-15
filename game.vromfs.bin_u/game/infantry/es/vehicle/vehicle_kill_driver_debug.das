options no_aot
require ecs
require DagorConsole
require PropsManager
require %game.dm.dm_events
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.net_console_macro

[net_console_cmd(name="vehicle.killHeroDriver", hint="Kills the driver soldier sitting in the hero vehicle")]
def vehicle_kill_hero_driver(@net_hero hero_eid : EntityId)
  var vehicleEid = INVALID_ENTITY_ID
  if has(hero_eid, "vehicle__controlledByDriver")
    vehicleEid = hero_eid
  else
    vehicleEid = get_Eid(hero_eid, "human_anim__vehicleSelected") ?? INVALID_ENTITY_ID

  if vehicleEid == INVALID_ENTITY_ID
    console_print("vehicle.killHeroDriver: hero is not in a vehicle")
    return

  let driverEid = get_Eid(vehicleEid, "vehicle__controlledByDriver") ?? INVALID_ENTITY_ID
  if driverEid == INVALID_ENTITY_ID
    console_print("vehicle.killHeroDriver: vehicle {vehicleEid} has no driver")
    return

  sendEvent(driverEid, CmdKill(offender = driverEid,
                               damageType = uint16(int(DamageType.DM_PROJECTILE)),
                               packedGunPropsId = props_pack_for_net(PropsId()),
                               shellId = -1))
  console_print("vehicle.killHeroDriver: killed driver {driverEid} in vehicle {vehicleEid}")
