from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { get_current_mission_name, get_mp_local_team } = require("mission")
let { eventbus_subscribe } = require("eventbus")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getFullRespawnBasesList, is_respawnbase_selectable, getSavedRespawnBaseForSlot
} = require("guiRespawn")
let RespawnBase = require("%scripts/respawn/respawnBase.nut")
let { isInFlight } = require("gameplayBinding")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { isShipBattle } = require("%scripts/missions/missionType.nut")

const SAVED_RESPAWN_BASE_ID = "respawns"

local savedRespawnBases = null

local respawnBases = {
  MAP_ID_NOTHING = -1
  selectedBaseData = null 
  selectedSquadmateBasePlayerId = -1

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

    let rbs = getFullRespawnBasesList()
    if (!rbs.len())
      return res

    let lastSelectedBase = this.getSelectedBase()
    let localTeam = get_mp_local_team()
    let savedBaseForSlot = getSavedRespawnBaseForSlot(-1)
    let hasSavedBase = rbs.findvalue(@(rb) rb.id == savedBaseForSlot) != null
    local defaultBase = null
    local airfiled = null
    foreach (rbConfig in rbs) {
      let { id, team } = rbConfig
      if (team != localTeam || !is_respawnbase_selectable(id))
        continue
      let rb = RespawnBase(id)
      let isSavedForSlot = id == savedBaseForSlot
      let canSelect = !hasSavedBase || isSavedForSlot
      rb.fillRespawnBaseData({ isSavedForSlot, canSelect })
      res.basesList.append(rb)
      if (!canSelect)
        continue
      if (rb.isEqual(lastSelectedBase))
        res.selBase = rb
      if (!defaultBase || (rb.isDefault <=> defaultBase.isDefault) > 0)
        defaultBase = rb
      if (rb.isSpawnIsAirfiled())
        airfiled = rb
    }

    if (res.basesList.len() == 0)
      return res

    res.hasRespawnBases = true
    res.canChooseRespawnBase = true
    let needToSelectAirfield = isBadWeather && ES_UNIT_TYPE_AIRCRAFT == unit.esUnitType && !isShipBattle()
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