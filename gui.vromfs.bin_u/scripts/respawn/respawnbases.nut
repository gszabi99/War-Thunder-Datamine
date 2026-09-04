import "DataBlock" as DataBlock
import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%scripts/respawn/respawnBase.nut" as RespawnBase

from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler
from "mission" import get_current_mission_name, get_mp_local_team
from "eventbus" import eventbus_subscribe
from "guiRespawn" import getFullRespawnBasesList, is_respawnbase_selectable, getSavedRespawnBaseForSlot
from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/respawn/respawnConsts.nut" import RespawnBaseType, CATAPULT_CARRIER_SPAWN_NAME, TRAMPOLINE_CARRIER_SPAWN_NAME
from "%scripts/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/missions/missionType.nut" import isShipBattle
from "%scripts/dagui_natives.nut" import get_slot_delay
from "blkGetters" import get_current_mission_info_cached

const SAVED_RESPAWN_BASE_ID = "respawns"

local savedRespawnBases = null

let isPerBaseDelayRow = @(spawn) !spawn.isSquadRespawnBase && !spawn.isZoneRespawnBase
  && spawn.isAvailable && spawn.canSelect

local respawnBases = {
  MAP_ID_NOTHING = -1
  selectedBaseData = null 
  selectedSquadmateBasePlayerId = -1
  hasCarrierInList = false

  function getSelectedBase() {
    return this.selectedBaseData?.respBase
  }

  function updateHasCarrierInList(basesList) {
    this.hasCarrierInList = basesList.findindex(
      @(b) b.name == CATAPULT_CARRIER_SPAWN_NAME || b.name == TRAMPOLINE_CARRIER_SPAWN_NAME) != null
  }

  function getPerBaseRespawnDelays(respawnBasesList, unitName) {
    local baseDelays = {}
    if ((get_current_mission_info_cached()?.afterRespawnDelaySec ?? 0) <= 0)
      return baseDelays
    foreach (spawn in respawnBasesList)
      if (isPerBaseDelayRow(spawn))
        baseDelays[spawn.id] <- get_slot_delay(unitName, spawn.id)
    return baseDelays
  }

  function getRespawnBasesData(unit, isBadWeather = false) {
    let res = {
      hasRespawnBases = false
      canChooseRespawnBase = false
      basesList = []
      selBase = null
    }
    this.hasCarrierInList = false

    let rbs = getFullRespawnBasesList()
    if (!rbs.len())
      return res

    let lastSelectedBase = this.getSelectedBase()
    let localTeam = get_mp_local_team()
    let savedBaseForSlot = getSavedRespawnBaseForSlot(-1)
    let availableBases = []
    local hasSavedBase = false
    foreach (rbConfig in rbs) {
      let { id, team } = rbConfig
      if (team != localTeam || !is_respawnbase_selectable(id))
        continue
      availableBases.append(rbConfig)
      hasSavedBase = hasSavedBase || id == savedBaseForSlot
    }

    local defaultBase = null
    local airfiled = null
    foreach (rbConfig in availableBases) {
      let { id } = rbConfig
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
    this.updateHasCarrierInList(res.basesList)
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

  function getAircraftRespawnBaseType(spawn) {
    if (spawn.isAutoSelected)
      return RespawnBaseType.AUTO
    if (spawn.name == CATAPULT_CARRIER_SPAWN_NAME)
      return RespawnBaseType.CARRIER_CATAPULT
    if (spawn.name == TRAMPOLINE_CARRIER_SPAWN_NAME)
      return RespawnBaseType.CARRIER_TRAMPOLINE
    return spawn.isGround ? RespawnBaseType.AIRFIELD : RespawnBaseType.AIR
  }

  function saveSelectedBase(spawn, save) {
    this.loadSavedRespawnBases()

    let missionName = get_current_mission_name()
    if (save) {
      let newType = this.getAircraftRespawnBaseType(spawn)
      let prevType = savedRespawnBases?[missionName]
      let isPrevCarrierType = prevType == RespawnBaseType.CARRIER_CATAPULT || prevType == RespawnBaseType.CARRIER_TRAMPOLINE
      
      
      let skipSave = !this.hasCarrierInList && isPrevCarrierType && newType == RespawnBaseType.AUTO
      if (!skipSave)
        savedRespawnBases[missionName] = newType
    }
    else
      if (savedRespawnBases.paramExists(missionName))
        savedRespawnBases.removeParam(missionName)

    saveLocalAccountSettings(SAVED_RESPAWN_BASE_ID, savedRespawnBases)
  }
}

subscribe_handler(respawnBases, g_listener_priority.DEFAULT_HANDLER)

eventbus_subscribe("on_sign_out", @(_) savedRespawnBases = null)

respawnBases.isPerBaseDelayRow <- isPerBaseDelayRow

return respawnBases
