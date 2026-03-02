from "%rGui/globals/ui_library.nut" import *

from "hudState" import hud_request_hud_tank_debuffs_state
import "%sqstd/ecs.nut" as ecs
let { eventbus_subscribe } = require("eventbus")

let tracksData = Watched({})
let turretDriveData = Watched({})
let gunData = Watched({})
let engineData = Watched({})
let engineOverheatState = Watched(false)
let fireState = Watched({})

eventbus_subscribe("TankDebuffs:Tracks", @(data) tracksData.set(data))
eventbus_subscribe("TankDebuffs:TurretDrive", @(data) turretDriveData.set(data))
eventbus_subscribe("TankDebuffs:Gun", @(data) gunData.set(data))
eventbus_subscribe("TankDebuffs:Engine", @(data) engineData.set(data))
eventbus_subscribe("TankDebuffs:Fire", @(data) fireState.set(data))

ecs.register_es("engine_overheat_damage_es_darg", {
  [["onInit", "onChange"]] = @(_, comp) engineOverheatState.set(comp.tank_engine__overheat),
}, {
  comps_track = [["tank_engine__overheat", ecs.TYPE_BOOL]],
  comps_rq = ["controlledHero"]
})

return {
  tracksData
  turretDriveData
  gunData
  engineData
  engineOverheatState
  fireState
  reInitTankDebuffsStates = hud_request_hud_tank_debuffs_state
}