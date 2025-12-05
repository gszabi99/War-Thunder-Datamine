from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { get_current_mission_name } = require("mission")
let { eventbus_subscribe } = require("eventbus")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getAvailableRespawnBases } = require("guiRespawn")
let RespawnBase = require("%scripts/respawn/respawnBase.nut")
let { isInFlight } = require("gameplayBinding")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { isShipBattle } = require("%scripts/missions/missionType.nut")

const SAVED_RESPAWN_BASE_ID = "respawns"

local savedRespawnBases = null

local respawnBases = {
  MAP_ID_NOTHING = RespawnBase.MAP_ID_NOTHING
  selectedBaseData = null 

  function getSelectedBase() {
    return this.selectedBaseData?.respBase
  }

  function getRespawnBasesData(unit, isBadWeather = false) {
    let res = {
      hasRespawnBases = false
      canChooseRespawnBase = false
      basesList = []
      selBase = null
    }

    let rbs = getAvailableRespawnBases(unit.tags)
    if (!rbs.len())
      return res

    res.hasRespawnBases = true
    res.canChooseRespawnBase = true
    let lastSelectedBase = this.getSelectedBase()
    let needToSelectAirfield = isBadWeather && ES_UNIT_TYPE_AIRCRAFT == unit.esUnitType && !isShipBattle()
    local defaultBase = null
    local airfiled = null
    foreach (_idx, id in rbs) {
      let rb = RespawnBase(id)
      res.basesList.append(rb)
      if (rb.isEqual(lastSelectedBase))
        res.selBase = rb
      if (!defaultBase || (rb.isDefault <=> defaultBase.isDefault) > 0)
        defaultBase = rb
      if (rb.isSpawnIsAirfiled())
        airfiled = rb
    }

    if (needToSelectAirfield && airfiled)
      defaultBase = airfiled
    let autoSelectedBase = RespawnBase(defaultBase.id, true)
    res.basesList.insert(0, autoSelectedBase)
    if (!res.selBase)
      res.selBase = autoSelectedBase
    return res
  }

  function selectBase(unit, respawnBase) {
    if (respawnBase)
      this.selectedBaseData = {
        unit = unit
        respBase = respawnBase
      }
    else
      this.selectedBaseData = null
  }

  function resetSelectedBase() {
    this.selectedBaseData = null
  }

  function onEventLoadingStateChange(_p) {
    if (!isInFlight())
      this.resetSelectedBase()
  }

  function loadSavedRespawnBases() {
    if (savedRespawnBases == null)
      savedRespawnBases = loadLocalAccountSettings(SAVED_RESPAWN_BASE_ID) ?? DataBlock()
  }

  function getSavedBaseType() {
    this.loadSavedRespawnBases()
    return savedRespawnBases?[get_current_mission_name()]
  }

  function hasSavedBase() {
    return this.getSavedBaseType() != null
  }

  function saveSelectedBase(spawn, save) {
    this.loadSavedRespawnBases()

    let missionName = get_current_mission_name()
    if (save)
      savedRespawnBases[missionName] = spawn.isAutoSelected ? "auto" : spawn.isGround ? "airfield" : "air"
    else
      if (savedRespawnBases.paramExists(missionName))
        savedRespawnBases.removeParam(missionName)

    saveLocalAccountSettings(SAVED_RESPAWN_BASE_ID, savedRespawnBases)
  }
}

subscribe_handler(respawnBases, g_listener_priority.DEFAULT_HANDLER)

eventbus_subscribe("on_sign_out", @(_) savedRespawnBases = null)

return respawnBases