local { get_blk_value_by_path } = require("sqStdLibs/helpers/datablockUtils.nut")
local time = require("scripts/time.nut")
local operationPreloader = require("scripts/worldWar/externalServices/wwOperationPreloader.nut")
local seenWWMapsObjective = require("scripts/seen/seenList.nut").get(SEEN.WW_MAPS_OBJECTIVE)
local wwActionsWithUnitsList = require("scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
local wwArmyGroupManager = require("scripts/worldWar/inOperation/wwArmyGroupManager.nut")
local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")
local { isCrossPlayEnabled } = require("scripts/social/crossplay.nut")
local { getNearestMapToBattleShort,
  hasAvailableMapToBattle,
  hasAvailableMapToBattleShort,
  getOperationById,
  getOperationFromShortStatusById
} = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
local { actionWithGlobalStatusRequest } = require("scripts/worldWar/operations/model/wwGlobalStatus.nut")
local { subscribeOperationNotifyOnce } = require("scripts/worldWar/services/wwService.nut")
local {
  checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("scripts/user/xboxFeatures.nut")


const WW_CUR_OPERATION_SAVE_ID = "worldWar/curOperation"
const WW_CUR_OPERATION_COUNTRY_SAVE_ID = "worldWar/curOperationCountry"
const WW_LAST_OPERATION_LOG_SAVE_ID = "worldWar/lastReadLog/operation"
const WW_UNIT_WEAPON_PRESET_PATH = "worldWar/weaponPreset/"
const WW_OBJECTIVE_OUT_OF_DATE_DAYS = 1

local LAST_VISIBLE_AVAILABLE_MAP_IN_PROMO_PATH = "worldWar/lastVisibleAvailableMapInPromo"

::g_world_war <- {
  [PERSISTENT_DATA_PARAMS] = ["configurableValues", "curOperationCountry"]

  armyGroups = []
  isArmyGroupsValid = false
  battles = []
  isBattlesValid = false
  configurableValues = ::DataBlock()

  isLastFlightWasWwBattle = false

  infantryUnits = null
  artilleryUnits = null
  transportUnits = null

  rearZones = null
  curOperationCountry = null
  lastPlayedOperationId = null
  lastPlayedOperationCountry = null

  isDebugMode = false

  myClanParticipateIcon = "#ui/gameuiskin#lb_victories_battles.svg"
  lastPlayedIcon = "#ui/gameuiskin#last_played_operation_marker"

  defaultDiffCode = ::DIFFICULTY_ARCADE

  function clearUnitsLists()
  {
    infantryUnits = null
    artilleryUnits = null
    transportUnits = null
  }

  function getInfantryUnits()
  {
    if (infantryUnits == null)
      infantryUnits = getWWConfigurableValue("infantryUnits", infantryUnits)

    return infantryUnits
  }

  function getArtilleryUnits()
  {
    if (artilleryUnits == null)
      artilleryUnits = getWWConfigurableValue("artilleryUnits", artilleryUnits)

    return artilleryUnits
  }

  function getTransportUnits()
  {
    if (transportUnits == null)
      transportUnits = getWWConfigurableValue("transportUnits", transportUnits)

    return transportUnits
  }

  function getLastPlayedOperation() {
    if (lastPlayedOperationId)
      return getOperationFromShortStatusById(lastPlayedOperationId)
    return null
  }

  function getPlayedOperationText(needMapName = true)
  {
    local operation = getLastPlayedOperation()
    if (operation != null)
      return operation.getMapText()


    local nearestAvailableMapToBattle = getNearestMapToBattleShort()
    if(!nearestAvailableMapToBattle)
      return null

    local name = needMapName ? nearestAvailableMapToBattle.getNameText() : ::loc("mainmenu/btnWorldwar")
    if (nearestAvailableMapToBattle.isActive())
      return ::loc("worldwar/operation/isNow", { name = name })

    return ::loc("worldwar/operation/willBegin", { name = name
      time = nearestAvailableMapToBattle.getChangeStateTimeText()})
  }

  function hasNewNearestAvailableMapToBattle()
  {
    if (getLastPlayedOperation() != null)
      return false

    local nearestAvailableMapToBattle = getNearestMapToBattleShort()
    if (!nearestAvailableMapToBattle)
      return false

    local lastVisibleAvailableMap = ::load_local_account_settings(LAST_VISIBLE_AVAILABLE_MAP_IN_PROMO_PATH)
    if (lastVisibleAvailableMap?.id == nearestAvailableMapToBattle.getId()
      && lastVisibleAvailableMap?.changeStateTime == nearestAvailableMapToBattle.getChangeStateTime())
      return false

    ::save_local_account_settings(LAST_VISIBLE_AVAILABLE_MAP_IN_PROMO_PATH,
      {
        id = nearestAvailableMapToBattle.getId()
        changeStateTime = nearestAvailableMapToBattle.getChangeStateTime()
      })

    return true
  }

  isWWSeasonActive = @() hasAvailableMapToBattle()
  isWWSeasonActiveShort = @() hasAvailableMapToBattleShort()

  function updateCurOperationStatusInGlobalStatus() {
    local operationId = ::ww_get_operation_id()
    if (operationId == -1)
      return

    local operation = getOperationById(operationId)
    operation?.setFinishedStatus(isCurrentOperationFinished())
  }
}

::g_script_reloader.registerPersistentDataFromRoot("g_world_war")

g_world_war.getSetting <- function getSetting(settingName, defaultValue)
{
  return ::get_game_settings_blk()?.ww_settings?[settingName] ?? defaultValue
}

g_world_war.canPlayWorldwar <- function canPlayWorldwar()
{
  if (!isMultiplayerPrivilegeAvailable())
    return false

  if (!isCrossPlayEnabled())
    return false

  local minRankRequired = getSetting("minCraftRank", 0)
  local unit = ::u.search(::all_units, @(unit)
    unit.canUseByPlayer() && unit.rank >= minRankRequired
  )

  return !!unit
}

g_world_war.getLockedCountryData <- function getLockedCountryData()
{
  if (!curOperationCountry)
    return null

  return {
    availableCountries = [curOperationCountry]
    reasonText = ::loc("worldWar/cantChangeCountryInOperation")
  }
}

g_world_war.canJoinWorldwarBattle <- function canJoinWorldwarBattle()
{
  return ::is_worldwar_enabled() && ::g_world_war.canPlayWorldwar()
}

g_world_war.getPlayWorldwarConditionText <- function getPlayWorldwarConditionText(fullText = false)
{
  if (!isMultiplayerPrivilegeAvailable())
    return ::loc("xbox/noMultiplayer")

  if (!isCrossPlayEnabled())
    return fullText
      ? ::loc("xbox/actionNotAvailableCrossNetworkPlay")
      : ::loc("xbox/crossPlayRequired")

  local rankText = ::colorize("@unlockHeaderColor",
    ::get_roman_numeral(getSetting("minCraftRank", 0)))
  return ::loc("worldWar/playCondition", {rank = rankText})
}

g_world_war.getCantPlayWorldwarReasonText <- function getCantPlayWorldwarReasonText()
{
  return !canPlayWorldwar() ? getPlayWorldwarConditionText(true) : ""
}

g_world_war.openMainWnd <- function openMainWnd(forceOpenMainMenu = false)
{
  if (!checkPlayWorldwarAccess())
    return

  if (!forceOpenMainMenu && ::g_world_war.lastPlayedOperationId)
  {
    local operation = getOperationById(::g_world_war.lastPlayedOperationId)
    if (operation)
    {
      joinOperationById(lastPlayedOperationId, lastPlayedOperationCountry)
      return
    }
  }

  openOperationsOrQueues()
}

g_world_war.openWarMap <- function openWarMap()
{
  local operationId = ::ww_get_operation_id()
  subscribeOperationNotifyOnce(
    operationId,
    null,
    function(responce) {
      if (::ww_get_operation_id() != operationId)
        return
      ::g_world_war.stopWar()
      ::showInfoMsgBox(::loc("worldwar/cantUpdateOperation"))
    }
  )
  ::handlersManager.loadHandler(::gui_handlers.WwMap)
}

g_world_war.checkPlayWorldwarAccess <- function checkPlayWorldwarAccess()
{
  if (!::is_worldwar_enabled())
  {
    ::show_not_available_msg_box()
    return false
  }

  if (!canPlayWorldwar())
  {
    if (!checkAndShowMultiplayerPrivilegeWarning())
      return false

    if (!::xbox_try_show_crossnetwork_message())
      ::showInfoMsgBox(getPlayWorldwarConditionText(true))
    return false
  }
  return true
}

g_world_war.openOperationsOrQueues <- function openOperationsOrQueues(needToOpenBattles = false, map = null)
{
  stopWar()

  if (!checkPlayWorldwarAccess())
    return

  ::ww_get_configurable_values(configurableValues)

  if (!::handlersManager.findHandlerClassInScene(::gui_handlers.WwOperationsMapsHandler))
    ::handlersManager.loadHandler(::gui_handlers.WwOperationsMapsHandler,
      { needToOpenBattles = needToOpenBattles
        autoOpenMapOperation = map })
}

g_world_war.joinOperationById <- function joinOperationById(operationId, country = null, isSilence = false, onSuccess = null)
{
  local operation = getOperationById(operationId)
  if (!operation)
  {
    if (!isSilence)
      ::showInfoMsgBox(::loc("worldwar/operationNotFound"))
    return
  }

  stopWar()

  if (::u.isEmpty(country))
    country = operation.getMyAssignCountry() || ::get_profile_country_sq()

  operation.join(country, null, isSilence, onSuccess)
}

g_world_war.onJoinOperationSuccess <- function onJoinOperationSuccess(operationId, country, isSilence, onSuccess)
{
  local operation = getOperationById(operationId)
  local sideSelectSuccess = false
  if (operation)
  {
    if (getMyArmyGroup() != null)
      sideSelectSuccess = ::ww_select_player_side_for_army_group_member()
    else
      sideSelectSuccess = ::ww_select_player_side_for_regular_user(country)
  }
  curOperationCountry = country

  if (!sideSelectSuccess)
  {
    openOperationsOrQueues()
    return
  }

  saveLastPlayed(operationId, country)
  seenWWMapsObjective.setDaysToUnseen(WW_OBJECTIVE_OUT_OF_DATE_DAYS)

  if (!isSilence)
    openWarMap()

  // To force an extra ui update when operation is fully loaded, and lastPlayedOperationId changed.
  ::ww_event("LoadOperation")

  if (onSuccess)
    onSuccess()
}

g_world_war.openJoinOperationByIdWnd <- function openJoinOperationByIdWnd()
{
  ::gui_modal_editbox_wnd({
    charMask="1234567890"
    allowEmpty = false
    okFunc = function(value) {
      local operationId = ::to_integer_safe(value)
      joinOperationById(operationId)
    }
    owner = this
  })
}

g_world_war.onEventLoadingStateChange <- function onEventLoadingStateChange(p)
{
  if (!::is_in_flight())
    return

  ::g_squad_manager.cancelWwBattlePrepare()
  local missionRules = ::g_mis_custom_state.getCurMissionRules()
  isLastFlightWasWwBattle = missionRules.isWorldWar
  local operationId = missionRules.getCustomRulesBlk()?.operationId.tointeger()
  if (operationId == null)
    return

  subscribeOperationNotifyOnce(operationId)
  if (operationId != ::ww_get_operation_id())
    updateOperationPreviewAndDo(operationId, null)   //need set operation preview if in WW battle for load operation config
}

g_world_war.onEventResetSkipedNotifications <- function onEventResetSkipedNotifications(p)
{
  ::saveLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false)
}

g_world_war.stopWar <- function stopWar()
{
  rearZones = null
  curOperationCountry = null

  ::g_tooltip.removeAll()
  ::g_ww_logs.clear()
  if (!::ww_is_operation_loaded())
    return

  updateCurOperationStatusInGlobalStatus()
  ::ww_stop_war()
  ::ww_event("StopWorldWar")
}

g_world_war.saveLastPlayed <- function saveLastPlayed(operationId, country)
{
  lastPlayedOperationId = operationId
  lastPlayedOperationCountry = country
  ::saveLocalByAccount(WW_CUR_OPERATION_SAVE_ID, operationId)
  ::saveLocalByAccount(WW_CUR_OPERATION_COUNTRY_SAVE_ID, country)
}

g_world_war.loadLastPlayed <- function loadLastPlayed()
{
  lastPlayedOperationId = ::loadLocalByAccount(WW_CUR_OPERATION_SAVE_ID)
  if (lastPlayedOperationId)
    lastPlayedOperationCountry = ::loadLocalByAccount(WW_CUR_OPERATION_COUNTRY_SAVE_ID, ::get_profile_country_sq())
}

g_world_war.onEventBeforeProfileInvalidation <- function onEventBeforeProfileInvalidation(p)
{
  stopWar()
}

g_world_war.onEventLoginComplete <- function onEventLoginComplete(p)
{
  loadLastPlayed()
  updateUserlogsAccess()
}

g_world_war.onEventScriptsReloaded <- function onEventScriptsReloaded(p)
{
  loadLastPlayed()
}

g_world_war.leaveWWBattleQueues <- function leaveWWBattleQueues(battle = null)
{
  if (::g_squad_manager.isSquadMember())
    return

  ::g_squad_manager.cancelWwBattlePrepare()

  if (battle)
  {
    local queue = ::queues.findQueueByName(battle.getQueueId())
    ::queues.leaveQueue(queue)
  }
  else
    ::queues.leaveQueueByType(QUEUE_TYPE_BIT.WW_BATTLE)
}

g_world_war.onEventWWGlobalStatusChanged <- function onEventWWGlobalStatusChanged(p)
{
  if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS)
    ::g_squad_manager.updateMyMemberData()
}

g_world_war.checkOpenGlobalBattlesModal <- function checkOpenGlobalBattlesModal()
{
  if (!::g_squad_manager.getWwOperationBattle())
    return

  if (::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE))
    return

  if (!::g_squad_manager.isSquadMember() || !::g_squad_manager.isMeReady())
    return

  ::g_world_war.stopWar()
  ::gui_handlers.WwGlobalBattlesModal.open()
}

g_world_war.onEventSquadSetReady <- function onEventSquadSetReady(params)
{
  checkOpenGlobalBattlesModal()
}

g_world_war.isDebugModeEnabled <- function isDebugModeEnabled()
{
  return isDebugMode
}

g_world_war.setDebugMode <- function setDebugMode(value)
{
  if (!::has_feature("worldWarMaster"))
    value = false

  if (value == isDebugMode)
    return

  isDebugMode = value
  ::ww_event("ChangedDebugMode")
}

g_world_war.updateArmyGroups <- function updateArmyGroups()
{
  if (isArmyGroupsValid)
    return

  isArmyGroupsValid = true

  armyGroups.clear()

  local blk = ::DataBlock()
  ::ww_get_army_groups_info(blk)

  if (!("armyGroups" in blk))
    return

  local itemCount = blk.armyGroups.blockCount()

  for (local i = 0; i < itemCount; i++)
  {
    local itemBlk = blk.armyGroups.getBlock(i)
    local group   = ::WwArmyGroup(itemBlk)

    if (group.isValid())
      armyGroups.append(group)
  }
  wwArmyGroupManager.updateManagers()
}

g_world_war.getArtilleryUnitParamsByBlk <- function getArtilleryUnitParamsByBlk(blk)
{
  local artillery = getArtilleryUnits()
  for (local i = 0; i < blk.blockCount(); i++)
  {
    local wwUnitName = blk.getBlock(i).getBlockName()
    if (wwUnitName in artillery)
      return artillery[wwUnitName]
  }

  return null
}

g_world_war.updateRearZones <- function updateRearZones()
{
  local blk = ::DataBlock()
  ::ww_get_rear_zones(blk)

  rearZones = {}
  foreach (zoneName, zoneOwner in blk)
  {
    local sideName = ::ww_side_val_to_name(zoneOwner)
    if (!(sideName in rearZones))
      rearZones[sideName] <- []

    rearZones[sideName].append(zoneName)
  }
}

g_world_war.getRearZones <- function getRearZones()
{
  if (!rearZones)
    updateRearZones()

  return rearZones
}

g_world_war.getRearZonesBySide <- function getRearZonesBySide(side)
{
  return getRearZones()?[::ww_side_val_to_name(side)] ?? []
}

g_world_war.getRearZonesOwnedToSide <- function getRearZonesOwnedToSide(side)
{
  return getRearZonesBySide(side).filter(@(zone) ::ww_get_zone_side_by_name(zone) == side)
}

g_world_war.getRearZonesLostBySide <- function getRearZonesLostBySide(side)
{
  return getRearZonesBySide(side).filter(@(zone) ::ww_get_zone_side_by_name(zone) != side)
}

g_world_war.getSelectedArmies <- function getSelectedArmies()
{
  return ::u.map(::ww_get_selected_armies_names(), function(name)
  {
    return ::g_world_war.getArmyByName(name)
  })
}

g_world_war.getSidesStrenghtInfo <- function getSidesStrenghtInfo()
{
  local blk = ::DataBlock()
  ::ww_get_sides_info(blk)

  local unitsStrenghtBySide = {}
  foreach(side in getCommonSidesOrder())
    unitsStrenghtBySide[side] <- []

  local sidesBlk = blk?["sides"]
  if (sidesBlk == null)
    return unitsStrenghtBySide

  for (local i = 0; i < sidesBlk.blockCount(); ++i)
  {
    local wwUnitsList = []
    local sideBlk = sidesBlk.getBlock(i)
    local unitsBlk = sideBlk["units"]

    for (local j = 0; j < unitsBlk.blockCount(); ++j)
    {
      local unitsTypeBlk = unitsBlk.getBlock(j)
      local unitTypeBlk = unitsTypeBlk?["units"]
      wwUnitsList.extend(wwActionsWithUnitsList.loadUnitsFromBlk(unitTypeBlk))
    }

    local collectedWwUnits = ::u.values(::g_world_war.collectUnitsData(wwUnitsList))
    collectedWwUnits.sort(::g_world_war.sortUnitsBySortCodeAndCount)
    unitsStrenghtBySide[sideBlk.getBlockName().tointeger()] = collectedWwUnits
  }

  return unitsStrenghtBySide
}

g_world_war.getAllOperationUnitsBySide <- function getAllOperationUnitsBySide(side)
{
  local allOperationUnits = {}
  local blk = ::DataBlock()
  ::ww_get_sides_info(blk)

  local sidesBlk = blk?["sides"]
  if (sidesBlk == null)
    return allOperationUnits

  local sideBlk = sidesBlk?[side.tostring()]
  if (sideBlk == null)
    return allOperationUnits

  foreach (unitName in sideBlk.unitsEverSeen % "item")
    if (::getAircraftByName(unitName))
      allOperationUnits[unitName] <- true

  return allOperationUnits
}

g_world_war.filterArmiesByManagementAccess <- function filterArmiesByManagementAccess(armiesArray)
{
  return ::u.filter(armiesArray, function(army) { return army.hasManageAccess() })
}

g_world_war.haveManagementAccessForSelectedArmies <- function haveManagementAccessForSelectedArmies()
{
  local armiesArray = getSelectedArmies()
  return filterArmiesByManagementAccess(armiesArray).len() > 0
}

g_world_war.getMyAccessLevelListForCurrentBattle <- function getMyAccessLevelListForCurrentBattle()
{
  local list = {}
  if (!::ww_is_player_on_war())
    return list

  foreach(group in getArmyGroups())
  {
    list[group.owner.armyGroupIdx] <- group.getAccessLevel()
  }

  return list
}

g_world_war.haveManagementAccessForAnyGroup <- function haveManagementAccessForAnyGroup()
{
  local result = ::u.search(getMyAccessLevelListForCurrentBattle(),
    function(access) {
      return access & WW_BATTLE_ACCESS.MANAGER
    }
  ) || WW_BATTLE_ACCESS.NONE
  return result >= WW_BATTLE_ACCESS.MANAGER
}

g_world_war.isSquadsInviteEnable <- function isSquadsInviteEnable()
{
  return ::has_feature("WorldWarSquadInvite") &&
         ::g_world_war.haveManagementAccessForAnyGroup() &&
         ::clan_get_my_clan_id().tointeger() >= 0
}

g_world_war.isGroupAvailable <- function isGroupAvailable(group, accessList = null)
{
  if (!group || !group.isValid() || !group.owner.isValid())
    return false

  if (!accessList)
    accessList = getMyAccessLevelListForCurrentBattle()

  local access = ::getTblValue(group.owner.armyGroupIdx, accessList, WW_BATTLE_ACCESS.NONE)
  return !!(access & WW_BATTLE_ACCESS.MANAGER)
}

// return array of WwArmyGroup
g_world_war.getArmyGroups <- function getArmyGroups(filterFunc = null)
{
  updateArmyGroups()

  return filterFunc ? ::u.filter(armyGroups, filterFunc) : armyGroups
}


// return array of WwArmyGroup
g_world_war.getArmyGroupsBySide <- function getArmyGroupsBySide(side, filterFunc = null)
{
  return getArmyGroups(
    (@(side, filterFunc) function (group) {
      if (group.owner.side != side)
        return false

      return filterFunc ? filterFunc(group) : true
    })(side, filterFunc)
  )
}


// return WwArmyGroup or null
g_world_war.getArmyGroupByArmy <- function getArmyGroupByArmy(army)
{
  return ::u.search(getArmyGroups(),
    (@(army) function (group) {
      return group.isMyArmy(army)
    })(army)
  )
}

g_world_war.getMyArmyGroup <- function getMyArmyGroup()
{
  return ::u.search(getArmyGroups(),
      function(group)
      {
        return ::isInArray(::my_user_id_int64, group.observerUids)
      }
    )
}

g_world_war.getArmyByName <- function getArmyByName(armyName)
{
  if (!armyName)
    return null
  return ::WwArmy(armyName)
}

g_world_war.getArmyByArmyGroup <- function getArmyByArmyGroup(armyGroup)
{
  local armyName = ::u.search(::ww_get_armies_names(), (@(armyGroup) function(armyName) {
      local army = ::g_world_war.getArmyByName(armyName)
      return armyGroup.isMyArmy(army)
    })(armyGroup))

  if (!armyName)
    return null
  return ::g_world_war.getArmyByName(armyName)
}

g_world_war.getBattleById <- function getBattleById(battleId)
{
  local battles = getBattles(
      (@(battleId) function(checkedBattle) {
        return checkedBattle.id == battleId
      })(battleId)
    )

  return battles.len() > 0 ? battles[0] : ::WwBattle()
}


g_world_war.getAirfieldByIndex <- function getAirfieldByIndex(index)
{
  return ::WwAirfield(index)
}


g_world_war.getAirfieldsCount <- function getAirfieldsCount()
{
  return ::ww_get_airfields_count();
}

g_world_war.getAirfieldsArrayBySide <- function getAirfieldsArrayBySide(side, filterType = "ANY")
{
  local res = []
  for (local index = 0; index < getAirfieldsCount(); index++)
  {
    local field = getAirfieldByIndex(index)
    local airfieldType = field.airfieldType
    if (field.isMySide(side) && (filterType == "ANY" || filterType == airfieldType))
      res.append(field)
  }

  return res
}

g_world_war.getBattles <- function getBattles(filterFunc = null, forced = false)
{
  updateBattles(forced)
  return filterFunc ? ::u.filter(battles, filterFunc) : battles
}

g_world_war.getBattleForArmy <- function getBattleForArmy(army, playerSide = ::SIDE_NONE)
{
  if (!army)
    return null

  return ::u.search(getBattles(),
    (@(army) function (battle) {
      return !battle.isFinished() && battle.isArmyJoined(army.name)
    })(army)
  )
}

g_world_war.isBattleAvailableToPlay <- function isBattleAvailableToPlay(wwBattle)
{
  return wwBattle && wwBattle.isValid() && !wwBattle.isAutoBattle() && !wwBattle.isFinished()
}


g_world_war.updateBattles <- function updateBattles(forced = false)
{
  if (isBattlesValid && !forced)
    return

  isBattlesValid = true

  battles.clear()

  local blk = ::DataBlock()
  ::ww_get_battles_info(blk)

  if (!("battles" in blk))
    return

  local itemCount = blk.battles.blockCount()

  for (local i = 0; i < itemCount; i++)
  {
    local itemBlk = blk.battles.getBlock(i)
    local battle   = ::WwBattle(itemBlk)

    if (battle.isValid())
      battles.append(battle)
  }
}


g_world_war.updateConfigurableValues <- function updateConfigurableValues()
{
  clearUnitsLists()
  local blk = ::DataBlock()
  ::ww_get_configurable_values(blk)
  configurableValues = blk
  // ----- FIX ME: Weapon masks data should be received from char -----
  if (!("fighterCountAsAssault" in configurableValues))
  {
    configurableValues.fighterCountAsAssault = ::DataBlock()
    configurableValues.fighterCountAsAssault.mgun    = false
    configurableValues.fighterCountAsAssault.cannon  = false
    configurableValues.fighterCountAsAssault.gunner  = false
    configurableValues.fighterCountAsAssault.bomb    = true
    configurableValues.fighterCountAsAssault.torpedo = false
    configurableValues.fighterCountAsAssault.rockets = true
    configurableValues.fighterCountAsAssault.gunpod  = false
  }
  // ------------------------------------------------------------------

  local fighterToAssaultWeaponMask = 0
  local fighterCountAsAssault = configurableValues.fighterCountAsAssault
  for (local i = 0; i < fighterCountAsAssault.paramCount(); i++)
    if (fighterCountAsAssault.getParamValue(i))
      fighterToAssaultWeaponMask = fighterToAssaultWeaponMask | (1 << i)

  configurableValues.fighterToAssaultWeaponMask = fighterToAssaultWeaponMask
}


g_world_war.onEventWWLoadOperationFirstTime <- function onEventWWLoadOperationFirstTime(params = {})
{
  updateConfigurableValues()
}

g_world_war.onEventWWLoadOperation <- function onEventWWLoadOperation(params = {})
{
  isArmyGroupsValid = false
  isBattlesValid = false
}

g_world_war.getWWConfigurableValue <- function getWWConfigurableValue(paramPath, defaultValue)
{
  return get_blk_value_by_path(configurableValues, paramPath, defaultValue)
}

g_world_war.getOperationObjectives <- function getOperationObjectives()
{
  local blk = ::DataBlock()
  ::ww_get_operation_objectives(blk)
  return blk
}

g_world_war.isCurrentOperationFinished <- function isCurrentOperationFinished()
{
  if (!::ww_is_operation_loaded())
    return false

  return ::ww_get_operation_winner() != ::SIDE_NONE
}

g_world_war.getReinforcementsInfo <- function getReinforcementsInfo()
{
  local blk = ::DataBlock()
  ::ww_get_reinforcements_info(blk)
  return blk
}

g_world_war.getReinforcementsArrayBySide <- function getReinforcementsArrayBySide(side)
{
  local reinforcementsInfo = getReinforcementsInfo()
  if (reinforcementsInfo?.reinforcements == null)
    return []

  local res = []
  for (local i = 0; i < reinforcementsInfo.reinforcements.blockCount(); i++)
  {
    local reinforcement = reinforcementsInfo.reinforcements.getBlock(i)
    local wwReinforcementArmy = ::WwReinforcementArmy(reinforcement)
    if (::has_feature("worldWarMaster") ||
         (wwReinforcementArmy.isMySide(side)
         && wwReinforcementArmy.hasManageAccess())
       )
        res.append(wwReinforcementArmy)
  }

  return res
}

g_world_war.getMyReinforcementsArray <- function getMyReinforcementsArray()
{
  return ::u.filter(getReinforcementsArrayBySide(::ww_get_player_side()),
    function(reinf) { return reinf.hasManageAccess()}
  )
}

g_world_war.getMyReadyReinforcementsArray <- function getMyReadyReinforcementsArray()
{
  return ::u.filter(getMyReinforcementsArray(), function(reinf) { return reinf.isReady() })
}

g_world_war.hasSuspendedReinforcements <- function hasSuspendedReinforcements()
{
  return ::u.search(
      getMyReinforcementsArray(),
      function(reinf) {
        return !reinf.isReady()
      }
    ) != null
}

g_world_war.getReinforcementByName <- function getReinforcementByName(name, blk = null)
{
  if (!name || !name.len())
    return null
  if (!blk)
    blk = getReinforcementsInfo()
  if (!blk?.reinforcements)
    return null

  for (local i = 0; i < blk.reinforcements.blockCount(); i++)
  {
    local reinforcement = blk.reinforcements.getBlock(i)
    if (!reinforcement)
      continue

    if (reinforcement.getBlockName() == name)
      return ::WwReinforcementArmy(reinforcement)
  }

  return null
}

g_world_war.sendReinforcementRequest <- function sendReinforcementRequest(cellIdx, name)
{
  local params = ::DataBlock()
  params.setInt("cellIdx", cellIdx)
  params.setStr("name", name)
  return ::ww_send_operation_request("cln_ww_emplace_reinforcement", params)
}

g_world_war.isArmySelected <- function isArmySelected(armyName)
{
  return ::isInArray(armyName, ::ww_get_selected_armies_names())
}

g_world_war.moveSelectedArmyToCell <- function moveSelectedArmyToCell(cellIdx, params = {})
{
  local army = ::getTblValue("army", params)
  if (!army)
    return

  local moveType = "EMT_ATTACK" //default move type
  local targetAirfieldIdx = ::getTblValue("targetAirfieldIdx", params, -1)
  local target = ::getTblValue("target", params)

  local blk = ::DataBlock()
  if (targetAirfieldIdx >= 0)
  {
    local airfield = ::g_world_war.getAirfieldByIndex(targetAirfieldIdx)
    if (::g_ww_unit_type.isAir(army.unitType) && army.isMySide(airfield.side))
    {
      moveType = "EMT_BACK_TO_AIRFIELD"
      blk.setInt("targetAirfieldIdx", targetAirfieldIdx)
    }
  }

  blk.setStr("moveType", moveType)
  blk.setStr("army", army.name)
  blk.setInt("targetCellIdx", cellIdx)

  local appendToPath = ::getTblValue("appendToPath", params, false)
  if (appendToPath)
    blk.setBool("appendToPath", appendToPath)
  if (target)
    blk.addStr("targetName", target)

  playArmyActionSound("moveSound", army)

  local taskId = ::ww_send_operation_request("cln_ww_move_army_to", blk)
  ::g_tasker.addTask(taskId, null, @() null,
    function (errorCode) {
      ::g_world_war.popupCharErrorMsg("move_army_error")
    })
}


// TODO: make this function to work like moveSelectedArmyToCell
// to avoid duplication code for ground and air arimies.
g_world_war.moveSelectedArmiesToCell <- function moveSelectedArmiesToCell(cellIdx, armies = [], target = null, appendPath = false)
{
  //MOVE TYPE - EMT_ATTACK always
  if (cellIdx < 0  || armies.len() == 0)
    return

  local params = ::DataBlock()
  for (local i = 0; i < armies.len(); i++)
  {
    params.addStr("army" + i, armies[i].name)
    params.addInt("targetCellIdx" + i, cellIdx)
  }

  if (appendPath)
    params.addBool("appendToPath", true)
  if (target)
    params.addStr("targetName", target)

  playArmyActionSound("moveSound", armies[0])
  ::ww_send_operation_request("cln_ww_move_armies_to", params)
}


g_world_war.playArmyActionSound <- function playArmyActionSound(soundId, wwArmy)
{
  if (!wwArmy || !wwArmy.isValid())
    return

  local unitTypeCode = wwArmy.getOverrideUnitType() ||
                       wwArmy.getUnitType()
  local armyType = ::g_ww_unit_type.getUnitTypeByCode(unitTypeCode)
  ::get_cur_gui_scene()?.playSound(armyType[soundId])
}


g_world_war.moveSelectedArmes <- function moveSelectedArmes(toX, toY, target = null, append = false)
{
  if (!::g_world_war.haveManagementAccessForSelectedArmies())
    return

  if (!hasEntrenchedInList(::ww_get_selected_armies_names()))
  {
    requestMoveSelectedArmies(toX, toY, target, append)
    return
  }

  ::gui_handlers.FramedMessageBox.open({
    title = ::loc("worldwar/armyAskDigout")
    message = ::loc("worldwar/armyAskDigoutText")
    onOpenSound = "ww_unit_entrench_move_notify"
    buttons = [
      {
        id = "no",
        text = ::loc("msgbox/btn_no"),
        shortcut = "B"
      }
      {
        id = "yes",
        text = ::loc("msgbox/btn_yes"),
        cb = ::Callback(@() requestMoveSelectedArmies(toX, toY, target, append), this)
        shortcut = "A"
      }
    ]
  })
}


g_world_war.requestMoveSelectedArmies <- function requestMoveSelectedArmies(toX, toY, target, append)
{
  local groundArmies = []
  local selectedArmies = ::ww_get_selected_armies_names()
  for (local i = selectedArmies.len() - 1; i >=0 ; i--)
  {
    local army = ::g_world_war.getArmyByName(selectedArmies.remove(i))
    if (!army.isValid())
      continue

    if (::g_ww_unit_type.isAir(army.unitType))
    {
      local cellIdx = ::ww_get_map_cell_by_coords(toX, toY)
      local targetAirfieldIdx = ::ww_find_airfield_by_coordinates(toX, toY)
      ::g_world_war.moveSelectedArmyToCell(cellIdx, {
        army = army
        target = target
        targetAirfieldIdx = targetAirfieldIdx
        appendToPath = append
      })
      continue
    }

    groundArmies.append(army)
  }

  if (groundArmies.len())
  {
    local cellIdx = ::ww_get_map_cell_by_coords(toX, toY)
    moveSelectedArmiesToCell(cellIdx, groundArmies, target, append)
  }
}


g_world_war.hasEntrenchedInList <- function hasEntrenchedInList(armyNamesList)
{
  for (local i = 0; i < armyNamesList.len(); i++)
  {
    local army = getArmyByName(armyNamesList[i])
    if (army && army.isEntrenched())
      return true
  }
  return false
}


g_world_war.stopSelectedArmy <- function stopSelectedArmy()
{
  local filteredArray = filterArmiesByManagementAccess(getSelectedArmies())
  if (!filteredArray.len())
    return

  local params = ::DataBlock()
  foreach(idx, army in filteredArray)
    params.addStr("army" + idx, army.name)
  ::ww_send_operation_request("cln_ww_stop_armies", params)
}

g_world_war.entrenchSelectedArmy <- function entrenchSelectedArmy()
{
  local filteredArray = filterArmiesByManagementAccess(getSelectedArmies())
  if (!filteredArray.len())
    return

  local entrenchedArmies = ::u.filter(filteredArray, function(army) { return !army.isEntrenched() })
  if (!entrenchedArmies.len())
    return

  local params = ::DataBlock()
  foreach(idx, army in entrenchedArmies)
    params.addStr("army" + idx, army.name)
  ::get_cur_gui_scene()?.playSound("ww_unit_entrench")
  ::ww_send_operation_request("cln_ww_entrench_armies", params)
}

g_world_war.moveSelectedAircraftsToCell <- function moveSelectedAircraftsToCell(cellIdx, unitsList, owner, target = null)
{
  if (cellIdx < 0)
    return -1

  if (unitsList.len() == 0)
    return -1

  local params = ::DataBlock()
  local airfieldIdx = ::ww_get_selected_airfield()
  params.addInt("targetCellIdx", cellIdx)
  params.addInt("airfield", airfieldIdx)
  params.addStr("side", ::ww_side_val_to_name(owner.side))
  params.addStr("country", owner.country)
  params.addInt("armyGroupIdx", owner.armyGroupIdx)

  local i = 0
  foreach (unitName, unitTable in unitsList)
  {
    if (unitTable.count == 0)
      continue

    params.addStr("unitName" + i, unitName)
    params.addInt("unitCount" + i, ::getTblValue("count", unitTable, 0))
    params.addStr("unitWeapon" + i, ::getTblValue("weapon", unitTable, ""))
    i++
  }

  if (target)
    params.addStr("targetName", target)

  local airfield = ::g_world_war.getAirfieldByIndex(airfieldIdx)
  ::get_cur_gui_scene()?.playSound(airfield.airfieldType.flyoutSound)

  return ::ww_send_operation_request("cln_ww_move_army_to", params)
}

g_world_war.sortUnitsByTypeAndCount <- function sortUnitsByTypeAndCount(a, b)
{
  local aType = a.wwUnitType.code
  local bType = b.wwUnitType.code
  if (aType != bType)
    return aType - bType
  return a.count - b.count
}

g_world_war.sortUnitsBySortCodeAndCount <- function sortUnitsBySortCodeAndCount(a, b)
{
  local aSortCode = a.wwUnitType.sortCode
  local bSortCode = b.wwUnitType.sortCode
  if (aSortCode != bSortCode)
    return aSortCode - bSortCode

  local aCount = a.count
  local bCount = b.count
  return aCount.tointeger() - bCount.tointeger()
}

g_world_war.getOperationTimeSec <- function getOperationTimeSec()
{
  return time.millisecondsToSecondsInt(::ww_get_operation_time_millisec())
}

g_world_war.requestLogs <- function requestLogs(loadAmount, useLogMark, cb, errorCb)
{
  local logMark = useLogMark ? ::g_ww_logs.lastMark : ""
  local reqBlk = DataBlock()
  reqBlk.setInt("count", loadAmount)
  reqBlk.setStr("last", logMark)
  local taskId = ::ww_operation_request_log(reqBlk)

  if (taskId < 0) // taskId == -1 means request result is ready
    cb()
  else
    ::g_tasker.addTask(taskId, null, cb, errorCb)
}

g_world_war.getSidesOrder <- function getSidesOrder(battle = null)
{
  local playerSide = (battle && ::u.isWwGlobalBattle(battle))
    ? battle.getSideByCountry(::get_profile_country_sq())
    : ::ww_get_player_side()

  if (playerSide == ::SIDE_NONE)
    playerSide = ::SIDE_1

  local enemySide  = ::g_world_war.getOppositeSide(playerSide)
  return [ playerSide, enemySide ]
}

g_world_war.getCommonSidesOrder <- function getCommonSidesOrder()
{
  return [::SIDE_1, ::SIDE_2]
}

g_world_war.getOppositeSide <- function getOppositeSide(side)
{
  return side == ::SIDE_2 ? ::SIDE_1 : ::SIDE_2
}

g_world_war.get_last_weapon_preset <- function get_last_weapon_preset(unitName)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return ""

  local weaponName = ::loadLocalByAccount(WW_UNIT_WEAPON_PRESET_PATH + unitName, "")
  foreach(weapon in unit.weapons)
    if (weapon.name == weaponName)
      return weaponName

  return unit.weapons.len() ? unit.weapons[0].name : ""
}

g_world_war.set_last_weapon_preset <- function set_last_weapon_preset(unitName, weaponName)
{
  ::saveLocalByAccount(WW_UNIT_WEAPON_PRESET_PATH + unitName, weaponName)
}

g_world_war.collectUnitsData <- function collectUnitsData(unitsArray, isViewStrengthList = true)
{
  local collectedUnits = {}
  foreach(wwUnit in unitsArray)
  {
    local id = isViewStrengthList ? wwUnit.stengthGroupExpClass : wwUnit.expClass
    if (!(id in collectedUnits))
      collectedUnits[id] <- wwUnit
    else
      collectedUnits[id].count += wwUnit.count
  }

  return collectedUnits
}

g_world_war.addOperationInvite <- function addOperationInvite(operationId, clanId, isStarted, inviteTime)
{
  if (!canJoinWorldwarBattle())
    return

  if (clanId.tostring() != ::clan_get_my_clan_id())
    return

  if (operationId >= 0 && operationId != ::ww_get_operation_id())
    actionWithGlobalStatusRequest("cln_ww_global_status", null, null, function() {
      local operation = getOperationById(operationId)
      if (operation && operation.isAvailableToJoin())
        ::g_invites.addInvite( ::g_invites_classes.WwOperation,
          { operationId = operationId,
            clanName = ::clan_get_my_clan_tag(),
            isStarted = isStarted,
            inviteTime = inviteTime
          })
    })
}

g_world_war.addSquadInviteToWWBattle <- function addSquadInviteToWWBattle(params)
{
  local squadronId = params?.squadronId
  local operationId = params?.battle?.operationId
  local battleId = params?.battle?.battleId
  if (!squadronId || !operationId || !battleId)
    return

  if (squadronId != ::clan_get_my_clan_id() || !::g_squad_manager.isSquadLeader())
    return

  ::g_invites.addInvite(::g_invites_classes.WwOperationBattle, {
    operationId = operationId,
    battleId = battleId
  })
  ::g_invites.rescheduleInvitesTask()
}

g_world_war.getSaveOperationLogId <- function getSaveOperationLogId()
{
  return WW_LAST_OPERATION_LOG_SAVE_ID + ::ww_get_operation_id()
}

g_world_war.updateUserlogsAccess <- function updateUserlogsAccess()
{
  if (!::is_worldwar_enabled())
    return

  local wwUserLogTypes = [::EULT_WW_START_OPERATION,
                          ::EULT_WW_CREATE_OPERATION,
                          ::EULT_WW_END_OPERATION]
  for (local i = ::hidden_userlogs.len() - 1; i >= 0; i--)
    if (::isInArray(::hidden_userlogs[i], wwUserLogTypes))
      ::hidden_userlogs.remove(i)
}

g_world_war.updateOperationPreviewAndDo <- function updateOperationPreviewAndDo(operationId, cb, hasProgressBox = false)
{
  operationPreloader.loadPreview(operationId, cb, hasProgressBox)
}

g_world_war.onEventWWOperationPreviewLoaded <- function onEventWWOperationPreviewLoaded(params = {})
{
  isArmyGroupsValid = false
  isBattlesValid = false
  updateConfigurableValues()
}

g_world_war.popupCharErrorMsg <- function popupCharErrorMsg(groupName = null, titleText = "", errorMsgId = null)
{
  errorMsgId = errorMsgId ?? get_char_error_msg()
  if (!errorMsgId)
    return

  if (errorMsgId == "WRONG_REINFORCEMENT_NAME")
    return

  local popupText = ::loc("worldwar/charError/" + errorMsgId,
    ::loc("worldwar/charError/defaultError", ""))
  if (popupText.len() || titleText.len())
    ::g_popups.add(titleText, popupText, null, null, null, groupName)
}

g_world_war.getCurMissionWWBattleName <- function getCurMissionWWBattleName()
{
  local misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)

  local battleId = misBlk?.customRules?.battleId
  if (!battleId)
    return ""

  local battle = getBattleById(battleId)
  return battle ? battle.getView().getBattleName() : ""
}

g_world_war.getCurMissionWWOperationName <- function getCurMissionWWOperationName()
{
  local misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)

  local operationId = misBlk?.customRules?.operationId
  if (!operationId)
    return ""

  local operation = getOperationById(operationId.tointeger())
  return operation ? operation.getNameText() : ""
}

::subscribe_handler(::g_world_war, ::g_listener_priority.DEFAULT_HANDLER)
