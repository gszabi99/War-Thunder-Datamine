import "%sqstd/ecs.nut" as ecs
import "DataBlock" as DataBlock
from "%appGlobals/controlledHeroEid.nut" import controlledHeroEid
from "%appGlobals/hud/hudState.nut" import isWheelMenuActive
from "dasevents" import sendNetEvent, RequestSpawnVehicle
from "eventbus" import eventbus_send
from "mission" import get_local_mplayer
from "guiMission" import get_current_mission_desc
from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%scripts/wheelmenu/multifuncMenuTools.nut" import getMfmHandler
from "%scripts/dagui_library.nut" import *
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")

const SUPPLY_TRANSPORT_STATE_IDLE = 0
const SUPPLY_TRANSPORT_STATE_LOADING = 1

let defSupplyTransportInfo = {
  isActive = false
  isLoading = false
  progress = 0.0
}

let supplyTransportInfo = Watched(defSupplyTransportInfo)
supplyTransportInfo.subscribe(@(v) g_hud_event_manager.onHudEvent("supplyTransportInProgress", v))


ecs.register_es("supply_transport_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      supplyTransportInfo.set({
        isActive = comp.supply_transport__state != SUPPLY_TRANSPORT_STATE_IDLE
        isLoading = comp.supply_transport__state == SUPPLY_TRANSPORT_STATE_LOADING
        progress = comp.supply_transport__pointsCapacity > 0 ? comp.supply_transport__points / comp.supply_transport__pointsCapacity : 0.0
      })
    }
    onDestroy = function() {
      supplyTransportInfo.set(defSupplyTransportInfo)
    }
  },
  {
    comps_rq=["heroVehicle"]
    comps_no=["isReplayObserved"]
    comps_track=[["supply_transport__state", ecs.TYPE_INT], ["supply_transport__points", ecs.TYPE_FLOAT]]
    comps_ro=[["supply_transport__pointsCapacity", ecs.TYPE_FLOAT]]
  }
)

let supplyTerminalTransportsQuery = ecs.SqQuery("supplyTerminalTransportsQuery", {
  comps_ro = [["supply_terminal__transports", ecs.TYPE_SHARED_ARRAY]]
})

const SUPPLY_TRANSPORT_BUY_SECTION = "supply_transport_buy"

let supplyTransportOffers = Watched({ laptopEid = ecs.INVALID_ENTITY_ID, offers = [] })

function onSupplyTransportBuyMenu(data) {
  if (isWheelMenuActive.get())
    return
  let offers = supplyTerminalTransportsQuery(data.nodeEid, @(_, comp) comp.supply_terminal__transports.getAll()) ?? []
  if (offers.len() == 0)
    return
  supplyTransportOffers.set({ laptopEid = data.laptopEid, offers })
  eventbus_send("on_multifunc_menu_request", { show = true, curSection = SUPPLY_TRANSPORT_BUY_SECTION })
}

function onSupplyTransportBuyHintHide(_data) {
  let handler = getMfmHandler()
  if ((handler?.isActive ?? false) && handler.curSectionId == SUPPLY_TRANSPORT_BUY_SECTION)
    handler.quit()
}

function subscribeBuyMenu() {
  g_hud_event_manager.subscribe("supply_transport_buy_menu", onSupplyTransportBuyMenu)
  g_hud_event_manager.subscribe("hint:supply_buy_transport:hide", onSupplyTransportBuyHintHide)
}
subscribeBuyMenu()
add_event_listener("HudEventManagerReset", @(_) subscribeBuyMenu())

function canAffordSupplyTransport(cost) {
  let missionDesc = DataBlock()
  get_current_mission_desc(missionDesc)
  return !(missionDesc?.useSpawnScore ?? false) || (get_local_mplayer()?.spawnScore ?? 0) >= cost
}

function buySupplyTransport(idx) {
  let { laptopEid, offers } = supplyTransportOffers.get()
  if (idx < 0 || idx >= offers.len())
    return
  sendNetEvent(controlledHeroEid.get(), RequestSpawnVehicle({ supplyLaptopEid = laptopEid, transportIdx = idx }))
}

return freeze({ SUPPLY_TRANSPORT_BUY_SECTION, supplyTransportOffers, buySupplyTransport, canAffordSupplyTransport })
