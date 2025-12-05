import "%sqstd/ecs.nut" as ecs

let { localPlayerSquadMembers, localPlayerHumanContext, selectedBotForOrder } = require("%appGlobals/hudSquadMembers.nut")
let { controlledHeroEid } = require("%appGlobals/controlledHeroEid.nut")
let { Computed } = require("frp")
let { RqCancelContextCommand, RqCancelPersonalContextCommand, RqMenuContextCommandPointOrder } = require("dasevents")
let { eventbus_send } = require("eventbus")


let commandSmokeGrenade = @() ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqMenuContextCommandPointOrder({pointOrderStrID="smoke_grenade_ctx"}))
let commandFlashGrenade = @() ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqMenuContextCommandPointOrder({pointOrderStrID="flash_grenade_ctx"}))
let commandFragGrenade = @() ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqMenuContextCommandPointOrder({pointOrderStrID="frag_grenade_ctx"}))
let commandAttackVehicle = @() ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqMenuContextCommandPointOrder({pointOrderStrID="attack_vehicle"}))

let hasActiveSquadMembers = Computed(@()
  localPlayerSquadMembers.get().findvalue(@(m) m.eid != controlledHeroEid.get() && m.isAlive) != null)
let canGiveOrders = Computed(@() hasActiveSquadMembers.get())

let isFreeMateWithFragGrenade = @(m)
  m.eid != controlledHeroEid.get() && m.isAlive && m.hasFragGrenade && !m.isActionOrder
let canMateThrowFragGrenade = Computed(@() canGiveOrders.get()
  && localPlayerSquadMembers.get().findvalue(@(m) isFreeMateWithFragGrenade(m)) != null)
canMateThrowFragGrenade.subscribe(@(_v) eventbus_send("onCanMateThrowFragGrenadeStateChange"))

let isFreeMateWithSmokeGrenade = @(m)
  m.eid != controlledHeroEid.get() && m.isAlive && m.hasSmokeGrenade && !m.isActionOrder
let canMateThrowSmokeGrenade = Computed(@() canGiveOrders.get()
  && localPlayerSquadMembers.get().findvalue(@(m) isFreeMateWithSmokeGrenade(m)) != null)
canMateThrowSmokeGrenade.subscribe(@(_v) eventbus_send("onCanMateThrowSmokeGrenadeStateChange"))

let isFreeMateWithFlashGrenade = @(m)
  m.eid != controlledHeroEid.get() && m.isAlive && m.hasFlashGrenade && !m.isActionOrder
let canMateThrowFlashGrenade = Computed(@() canGiveOrders.get()
  && localPlayerSquadMembers.get().findvalue(@(m) isFreeMateWithFlashGrenade(m)) != null)
canMateThrowFlashGrenade.subscribe(@(_v) eventbus_send("onCanMateThrowFlashGrenadeStateChange"))

let canMateAttackVehicle = Computed(
  @() localPlayerHumanContext.get().hasGroundVehicleAttackerAndTarget || localPlayerHumanContext.get().hasAirVehicleAttackerAndTarget)
canMateAttackVehicle.subscribe(@(_v) eventbus_send("onCanMateAttackVehicleStateChange"))

let cancelAllCommandsForSquad = @() ecs.g_entity_mgr.sendEvent(
  controlledHeroEid.get(), RqCancelContextCommand({ include_personal_orders=true })
)
let cancelAllCommandsForSelectedBot = @() ecs.g_entity_mgr.sendEvent(
  selectedBotForOrder.get().eid, RqCancelPersonalContextCommand({})
)

let isAnyPersonalOrderSet = Computed(
  @() localPlayerSquadMembers.get().findvalue(@(m) m.isPersonalOrder) != null)
isAnyPersonalOrderSet.subscribe(@(_v) eventbus_send("onCanCancelSquadOrdersStateChange"))

let canCancelMateOrder = Computed(@() selectedBotForOrder.get() != null
  && selectedBotForOrder.get().isAlive && selectedBotForOrder.get().isPersonalOrder)
canCancelMateOrder.subscribe(@(_v) eventbus_send("onCanCancelMateOrderStateChange"))

return {
  commandSmokeGrenade
  commandFlashGrenade
  commandFragGrenade
  commandAttackVehicle

  canGiveOrders
  canMateThrowFragGrenade
  canMateThrowSmokeGrenade
  canMateThrowFlashGrenade
  canMateAttackVehicle

  cancelAllCommandsForSquad
  cancelAllCommandsForSelectedBot
  isAnyPersonalOrderSet
  canCancelMateOrder

}
