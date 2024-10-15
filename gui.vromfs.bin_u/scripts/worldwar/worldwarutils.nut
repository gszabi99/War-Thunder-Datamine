from "%scripts/dagui_natives.nut" import ww_is_player_on_war, get_char_error_msg, ww_stop_war, ww_get_selected_armies_names, ww_operation_request_log, ww_side_val_to_name, ww_select_player_side_for_regular_user, ww_get_operation_objectives, ww_send_operation_request, ww_select_player_side_for_army_group_member, clan_get_my_clan_id, ww_get_sides_info, ww_get_rear_zones
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let DataBlock  = require("DataBlock")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let time = require("%scripts/time.nut")
let operationPreloader = require("%scripts/worldWar/externalServices/wwOperationPreloader.nut")
let seenWWMapsObjective = require("%scripts/seen/seenList.nut").get(SEEN.WW_MAPS_OBJECTIVE)
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let wwArmyGroupManager = require("%scripts/worldWar/inOperation/wwArmyGroupManager.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let { getNearestMapToBattle, hasAvailableMapToBattle, getOperationById
} = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { subscribeOperationNotifyOnce } = require("%scripts/worldWar/services/wwService.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { hasMultiplayerRestritionByBalance } = require("%scripts/user/balance.nut")
let { openWwOperationRewardPopup
} = require("%scripts/worldWar/inOperation/handler/wwOperationRewardPopup.nut")
let { addMail } =  require("%scripts/matching/serviceNotifications/postbox.nut")
let { getGlobalStatusData } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { get_current_mission_desc } = require("guiMission")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_game_settings_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { WwArmyGroup } = require("%scripts/worldWar/inOperation/model/wwArmyGroup.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { wwGetOperationId, wwGetPlayerSide, wwIsOperationLoaded, wwGetOperationWinner,
  wwGetOperationTimeMillisec, wwGetZoneSideByName, wwGetAirfieldsCount, wwGetSelectedAirfield,
  wwFindAirfieldByCoordinates, wwGetArmyGroupsInfo, wwGetConfigurableValues,
  wwGetReinforcementsInfo, wwGetBattlesInfo, wwGetMapCellByCoords } = require("worldwar")
let { WwAirfield } = require("%scripts/worldWar/inOperation/model/wwAirfield.nut")
let { WwArmy } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")
let { addTask } = require("%scripts/tasker.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { WwBattle } = require("%scripts/worldWar/inOperation/model/wwBattle.nut")
let { WwReinforcementArmy } = require("%scripts/worldWar/inOperation/model/wwReinforcementArmy.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { removeAllGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")

const WW_CUR_OPERATION_SAVE_ID = "worldWar/curOperation"
const WW_CUR_OPERATION_COUNTRY_SAVE_ID = "worldWar/curOperationCountry"
const WW_LAST_OPERATION_LOG_SAVE_ID = "worldWar/lastReadLog/operation"
const WW_UNIT_WEAPON_PRESET_PATH = "worldWar/weaponPreset/"
const WW_OBJECTIVE_OUT_OF_DATE_DAYS = 1

const LAST_VISIBLE_AVAILABLE_MAP_IN_PROMO_PATH = "worldWar/lastVisibleAvailableMapInPromo"

function canPlayWorldwar() {
  if (!isMultiplayerPrivilegeAvailable.value
      || hasMultiplayerRestritionByBalance())
    return false

  if (!isCrossPlayEnabled())
    return false

  let minRankRequired = this.getSetting("minCraftRank", 0)
  let unit = u.search(getAllUnits(), @(unit)
    unit.canUseByPlayer() && unit.rank >= minRankRequired
  )

  return !!unit
}

local g_world_war
g_world_war = {
  armyGroups = []
  isArmyGroupsValid = false
  battles = []
  isBattlesValid = false
  configurableValues = DataBlock()

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

  defaultDiffCode = DIFFICULTY_REALISTIC

  function clearUnitsLists() {
    this.infantryUnits = null
    this.artilleryUnits = null
    this.transportUnits = null
  }

  function getInfantryUnits() {
    if (this.infantryUnits == null)
      this.infantryUnits = this.getWWConfigurableValue("infantryUnits", this.infantryUnits)

    return this.infantryUnits
  }

  function getArtilleryUnits() {
    if (this.artilleryUnits == null)
      this.artilleryUnits = this.getWWConfigurableValue("artilleryUnits", this.artilleryUnits)

    return this.artilleryUnits
  }

  function getTransportUnits() {
    if (this.transportUnits == null)
      this.transportUnits = this.getWWConfigurableValue("transportUnits", this.transportUnits)

    return this.transportUnits
  }

  function getLastPlayedOperation() {
    if (this.lastPlayedOperationId)
      return getOperationById(this.lastPlayedOperationId)
    return null
  }

  function getPlayedOperationText(needMapName = true) {
    let operation = this.getLastPlayedOperation()
    if (operation != null)
      return operation.getMapText()


    let nearestAvailableMapToBattle = getNearestMapToBattle()
    if (!nearestAvailableMapToBattle)
      return ""

    let name = needMapName ? nearestAvailableMapToBattle.getNameText() : loc("mainmenu/btnWorldwar")
    if (nearestAvailableMapToBattle.isActive())
      return loc("worldwar/operation/isNow", { name = name })

    return loc("worldwar/operation/willBegin", { name = name
      time = nearestAvailableMapToBattle.getChangeStateTimeText() })
  }

  function getNewNearestAvailableMapToBattle() {
    if (this.getLastPlayedOperation() != null)
      return null

    let nearestAvailableMapToBattle = getNearestMapToBattle()
    if (!nearestAvailableMapToBattle)
      return null

    let lastVisibleAvailableMap = loadLocalAccountSettings(LAST_VISIBLE_AVAILABLE_MAP_IN_PROMO_PATH)
    if (lastVisibleAvailableMap?.id == nearestAvailableMapToBattle.getId()
      && lastVisibleAvailableMap?.changeStateTime == nearestAvailableMapToBattle.getChangeStateTime())
      return null

    return nearestAvailableMapToBattle
  }

  function hasNewNearestAvailableMapToBattle() {
    let nearestAvailableMapToBattle = this.getNewNearestAvailableMapToBattle()
    if (!nearestAvailableMapToBattle)
      return false

    saveLocalAccountSettings(LAST_VISIBLE_AVAILABLE_MAP_IN_PROMO_PATH, {
        id = nearestAvailableMapToBattle.getId()
        changeStateTime = nearestAvailableMapToBattle.getChangeStateTime()
      })

    return true
  }

  isWWSeasonActive = @() hasAvailableMapToBattle()

  function updateCurOperationStatusInGlobalStatus() {
    let operationId = wwGetOperationId()
    if (operationId == -1)
      return

    let operation = getOperationById(operationId)
    operation?.setFinishedStatus(this.isCurrentOperationFinished())
  }

  function isWwOperationInviteEnable() {
    let wwOperationId = wwGetOperationId()
    return wwOperationId > -1 && ::g_clans.hasRightsToQueueWWar()
      && getOperationById(wwOperationId)?.isMyClanParticipate()
  }

  function inviteToWwOperation(uid) {
    let operationId = wwGetOperationId()
    if (operationId < 0 || !this.canJoinWorldwarBattle())
      return

    addMail({
      user_id = uid.tointeger()
      mail = {
        inviteClassName = "Operation"
        params = {
          operationId = operationId
          country = getOperationById(operationId)?.getMyAssignCountry()
        }
      }
      ttl = 3600
    })
  }

  function getSetting(settingName, defaultValue) {
    return get_game_settings_blk()?.ww_settings?[settingName] ?? defaultValue
  }

  canPlayWorldwar

  function canJoinWorldwarBattle() {
    return ::is_worldwar_enabled() && canPlayWorldwar()
  }

  function getPlayWorldwarConditionText(fullText = false) {
    if (!isMultiplayerPrivilegeAvailable.value)
      return loc("xbox/noMultiplayer")

    if (!isCrossPlayEnabled())
      return fullText
        ? loc("xbox/actionNotAvailableCrossNetworkPlay")
        : loc("xbox/crossPlayRequired")

    let rankText = colorize("@unlockHeaderColor",
      get_roman_numeral(this.getSetting("minCraftRank", 0)))
    return loc("worldWar/playCondition", { rank = rankText })
  }

  function getCantPlayWorldwarReasonText() {
    return !canPlayWorldwar() ? this.getPlayWorldwarConditionText(true) : ""
  }

  function openMainWnd(forceOpenMainMenu = false) {
    if (!this.checkPlayWorldwarAccess())
      return

    if (!forceOpenMainMenu && this.lastPlayedOperationId) {
      let operation = getOperationById(this.lastPlayedOperationId)
      if (operation) {
        this.joinOperationById(this.lastPlayedOperationId, this.lastPlayedOperationCountry)
        return
      }
    }

    this.openOperationsOrQueues()
  }

  function stopWar() {
    this.rearZones = null
    this.curOperationCountry = null

    removeAllGenericTooltip()
    ::g_ww_logs.clear()
    if (!wwIsOperationLoaded())
      return

    this.updateCurOperationStatusInGlobalStatus()
    ww_stop_war()
    wwEvent("StopWorldWar")
  }

  function openWarMap() {
    let operationId = wwGetOperationId()
    subscribeOperationNotifyOnce(
      operationId,
      null,
      function(_responce) {
        if (wwGetOperationId() != operationId)
          return
        this.stopWar()
        showInfoMsgBox(loc("worldwar/cantUpdateOperation"))
      }
    )
    handlersManager.loadHandler(gui_handlers.WwMap)
  }

  function checkPlayWorldwarAccess() {
    if (!::is_worldwar_enabled()) {
      ::show_not_available_msg_box()
      return false
    }

    if (!canPlayWorldwar()) {
      if (!isMultiplayerPrivilegeAvailable.value)
        checkAndShowMultiplayerPrivilegeWarning()
      else if (!isShowGoldBalanceWarning())
        checkAndShowCrossplayWarning(@()
          showInfoMsgBox(this.getPlayWorldwarConditionText(true)))
      return false
    }
    return true
  }

  function openOperationsOrQueues(needToOpenBattles = false, map = null) {
    this.stopWar()

    if (!this.checkPlayWorldwarAccess())
      return

    wwGetConfigurableValues(this.configurableValues)

    if (!handlersManager.findHandlerClassInScene(gui_handlers.WwOperationsMapsHandler))
      handlersManager.loadHandler(gui_handlers.WwOperationsMapsHandler,
        { needToOpenBattles = needToOpenBattles
          autoOpenMapOperation = map })
  }

  function joinOperationById(operationId,
    country = null, isSilence = false, onSuccess = null, forced = false) {
    let operation = getOperationById(operationId)
    if (!operation) {
      if (!isSilence)
        showInfoMsgBox(loc("worldwar/operationNotFound"))
      return
    }

    this.stopWar()

    if (u.isEmpty(country))
      country = operation.getMyAssignCountry() || profileCountrySq.value

    operation.join(country, null, isSilence, onSuccess, forced)
  }

  function onJoinOperationSuccess(operationId, country, isSilence, onSuccess) {
    let operation = getOperationById(operationId)
    local sideSelectSuccess = false
    if (operation) {
      if (this.getMyArmyGroup() != null)
        sideSelectSuccess = ww_select_player_side_for_army_group_member()
      else
        sideSelectSuccess = ww_select_player_side_for_regular_user(country)
    }
    this.curOperationCountry = country

    if (!sideSelectSuccess) {
      this.openOperationsOrQueues()
      return
    }

    this.saveLastPlayed(operationId, country)
    seenWWMapsObjective.setDaysToUnseen(WW_OBJECTIVE_OUT_OF_DATE_DAYS)

    if (!isSilence)
      this.openWarMap()

    // To force an extra ui update when operation is fully loaded, and lastPlayedOperationId changed.
    wwEvent("LoadOperation")

    if (onSuccess)
      onSuccess()
  }

  function openJoinOperationByIdWnd() {
    openEditBoxDialog({
      title = loc("mainmenu/operationsMap")
      charMask = "1234567890"
      allowEmpty = false
      okFunc = function(value) {
        let operationId = to_integer_safe(value)
        this.joinOperationById(operationId)
      }
      owner = this
    })
  }

  function onEventLoadingStateChange(_p) {
    if (!isInFlight())
      return

    g_squad_manager.cancelWwBattlePrepare()
    let missionRules = getCurMissionRules()
    this.isLastFlightWasWwBattle = missionRules.isWorldWar
    let operationId = missionRules.getCustomRulesBlk()?.operationId.tointeger()
    if (operationId == null)
      return

    subscribeOperationNotifyOnce(operationId)
    if (operationId != wwGetOperationId())
      this.updateOperationPreviewAndDo(operationId, null)   //need set operation preview if in WW battle for load operation config
  }

  function onEventResetSkipedNotifications(_p) {
    saveLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false)
  }

  function saveLastPlayed(operationId, country) {
    this.lastPlayedOperationId = operationId
    this.lastPlayedOperationCountry = country
    saveLocalByAccount(WW_CUR_OPERATION_SAVE_ID, operationId)
    saveLocalByAccount(WW_CUR_OPERATION_COUNTRY_SAVE_ID, country)
  }

  function loadLastPlayed() {
    this.lastPlayedOperationId = loadLocalByAccount(WW_CUR_OPERATION_SAVE_ID)
    if (this.lastPlayedOperationId)
      this.lastPlayedOperationCountry = loadLocalByAccount(WW_CUR_OPERATION_COUNTRY_SAVE_ID, profileCountrySq.value)
  }

  function onEventBeforeProfileInvalidation(_p) {
    this.stopWar()
  }

  function onEventLoginComplete(_p) {
    this.loadLastPlayed()
    this.updateUserlogsAccess()
  }

  function onEventScriptsReloaded(_p) {
    this.loadLastPlayed()
  }

  function leaveWWBattleQueues(battle = null) {
    if (g_squad_manager.isSquadMember())
      return

    g_squad_manager.cancelWwBattlePrepare()

    if (battle) {
      let queue = ::queues.findQueueByName(battle.getQueueId())
      ::queues.leaveQueue(queue)
    }
    else
      ::queues.leaveQueueByType(QUEUE_TYPE_BIT.WW_BATTLE)
  }

  function onEventWWGlobalStatusChanged(p) {
    if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS)
      g_squad_manager.updateMyMemberData()
  }

  function isDebugModeEnabled() {
    return this.isDebugMode
  }

  function setDebugMode(value) {
    if (!hasFeature("worldWarMaster"))
      value = false

    if (value == this.isDebugMode)
      return

    this.isDebugMode = value
    wwEvent("ChangedDebugMode")
  }

  function updateArmyGroups() {
    if (this.isArmyGroupsValid)
      return

    this.isArmyGroupsValid = true

    this.armyGroups.clear()

    let blk = DataBlock()
    wwGetArmyGroupsInfo(blk)

    if (!("armyGroups" in blk))
      return

    let itemCount = blk.armyGroups.blockCount()

    for (local i = 0; i < itemCount; i++) {
      let itemBlk = blk.armyGroups.getBlock(i)
      let group   = WwArmyGroup(itemBlk)

      if (group.isValid())
        this.armyGroups.append(group)
    }
    wwArmyGroupManager.updateManagers()
  }

  function getArtilleryUnitParamsByBlk(blk) {
    let artillery = this.getArtilleryUnits()
    for (local i = 0; i < blk.blockCount(); i++) {
      let wwUnitName = blk.getBlock(i).getBlockName()
      if (wwUnitName in artillery)
        return artillery[wwUnitName]
    }

    return null
  }

  function updateRearZones() {
    let blk = DataBlock()
    ww_get_rear_zones(blk)

    this.rearZones = {}
    foreach (zoneName, zoneOwner in blk) {
      let sideName = ww_side_val_to_name(zoneOwner)
      if (!(sideName in this.rearZones))
        this.rearZones[sideName] <- []

      this.rearZones[sideName].append(zoneName)
    }
  }

  function getRearZones() {
    if (!this.rearZones)
      this.updateRearZones()

    return this.rearZones
  }

  function getRearZonesBySide(side) {
    return this.getRearZones()?[ww_side_val_to_name(side)] ?? []
  }

  function getRearZonesOwnedToSide(side) {
    return this.getRearZonesBySide(side).filter(@(zone) wwGetZoneSideByName(zone) == side)
  }

  function getRearZonesLostBySide(side) {
    return this.getRearZonesBySide(side).filter(@(zone) wwGetZoneSideByName(zone) != side)
  }

  function getSelectedArmies() {
    return ww_get_selected_armies_names().map(@(name) g_world_war.getArmyByName(name))
  }

  function getSidesStrenghtInfo() {
    let blk = DataBlock()
    ww_get_sides_info(blk)

    let unitsStrenghtBySide = {}
    foreach (side in this.getCommonSidesOrder())
      unitsStrenghtBySide[side] <- []

    let sidesBlk = blk?["sides"]
    if (sidesBlk == null)
      return unitsStrenghtBySide

    for (local i = 0; i < sidesBlk.blockCount(); ++i) {
      let wwUnitsList = []
      let sideBlk = sidesBlk.getBlock(i)
      let unitsBlk = sideBlk["units"]

      for (local j = 0; j < unitsBlk.blockCount(); ++j) {
        let unitsTypeBlk = unitsBlk.getBlock(j)
        let unitTypeBlk = unitsTypeBlk?["units"]
        wwUnitsList.extend(wwActionsWithUnitsList.loadUnitsFromBlk(unitTypeBlk))
      }

      let collectedWwUnits = u.values(this.collectUnitsData(wwUnitsList))
      collectedWwUnits.sort(this.sortUnitsBySortCodeAndCount)
      unitsStrenghtBySide[sideBlk.getBlockName().tointeger()] = collectedWwUnits
    }

    return unitsStrenghtBySide
  }

  function getAllOperationUnitsBySide(side) {
    let allOperationUnits = {}
    let blk = DataBlock()
    ww_get_sides_info(blk)

    let sidesBlk = blk?["sides"]
    if (sidesBlk == null)
      return allOperationUnits

    let sideBlk = sidesBlk?[side.tostring()]
    if (sideBlk == null)
      return allOperationUnits

    foreach (unitName in sideBlk.unitsEverSeen % "item")
      if (getAircraftByName(unitName))
        allOperationUnits[unitName] <- true

    return allOperationUnits
  }

  function filterArmiesByManagementAccess(armiesArray) {
    return armiesArray.filter(@(army) army.hasManageAccess())
  }

  function haveManagementAccessForSelectedArmies() {
    let armiesArray = this.getSelectedArmies()
    return this.filterArmiesByManagementAccess(armiesArray).len() > 0
  }

  function getMyAccessLevelListForCurrentBattle() {
    let list = {}
    if (!ww_is_player_on_war())
      return list

    foreach (group in this.getArmyGroups()) {
      list[group.owner.armyGroupIdx] <- group.getAccessLevel()
    }

    return list
  }

  function haveManagementAccessForAnyGroup() {
    local result = u.search(this.getMyAccessLevelListForCurrentBattle(),
      function(access) {
        return access & WW_BATTLE_ACCESS.MANAGER
      }
    ) || WW_BATTLE_ACCESS.NONE
    return result >= WW_BATTLE_ACCESS.MANAGER
  }

  function isSquadsInviteEnable() {
    return hasFeature("WorldWarSquadInvite") &&
           this.haveManagementAccessForAnyGroup() &&
           clan_get_my_clan_id().tointeger() >= 0
  }

  function isGroupAvailable(group, accessList = null) {
    if (!group || !group.isValid() || !group.owner.isValid())
      return false

    if (!accessList)
      accessList = this.getMyAccessLevelListForCurrentBattle()

    let access = getTblValue(group.owner.armyGroupIdx, accessList, WW_BATTLE_ACCESS.NONE)
    return !!(access & WW_BATTLE_ACCESS.MANAGER)
  }

  // return array of WwArmyGroup
  function getArmyGroups(filterFunc = null) {
    this.updateArmyGroups()

    return filterFunc ? this.armyGroups.filter(filterFunc) : this.armyGroups
  }


  // return array of WwArmyGroup
  function getArmyGroupsBySide(side, filterFunc = null) {
    return this.getArmyGroups(
       function (group) {
        if (group.owner.side != side)
          return false

        return filterFunc ? filterFunc(group) : true
      }
    )
  }


  // return WwArmyGroup or null
  function getArmyGroupByArmy(army) {
    return u.search(this.getArmyGroups(),
       function (group) {
        return group.isMyArmy(army)
      }
    )
  }

  function getMyArmyGroup() {
    return u.search(this.getArmyGroups(),
        function(group) {
          return isInArray(userIdInt64.value, group.observerUids)
        }
      )
  }

  function getArmyByName(armyName) {
    if (!armyName)
      return null
    return WwArmy(armyName)
  }

  function getBattleById(battleId) {
    let battles = this.getBattles(
         function(checkedBattle) {
          return checkedBattle.id == battleId
        }
      )

    return battles.len() > 0 ? battles[0] : WwBattle()
  }


  function getAirfieldByIndex(index) {
    return WwAirfield(index)
  }


  function getAirfieldsCount() {
    return wwGetAirfieldsCount();
  }

  function getAirfieldsArrayBySide(side, filterType = "ANY") {
    let res = []
    for (local index = 0; index < this.getAirfieldsCount(); index++) {
      let field = this.getAirfieldByIndex(index)
      let airfieldType = field.airfieldType.name
      if (field.isMySide(side) && (filterType == "ANY" || filterType == airfieldType))
        res.append(field)
    }

    return res
  }

  function getBattles(filterFunc = null, forced = false) {
    this.updateBattles(forced)
    return filterFunc ? this.battles.filter(filterFunc) : this.battles
  }

  function getBattleForArmy(army, _playerSide = SIDE_NONE) {
    if (!army)
      return null

    return u.search(this.getBattles(),
       function (battle) {
        return !battle.isFinished() && battle.isArmyJoined(army.name)
      }
    )
  }

  function isBattleAvailableToPlay(wwBattle) {
    return wwBattle && wwBattle.isValid() && !wwBattle.isAutoBattle() && !wwBattle.isFinished()
  }


  function updateBattles(forced = false) {
    if (this.isBattlesValid && !forced)
      return

    this.isBattlesValid = true

    this.battles.clear()

    let blk = DataBlock()
    wwGetBattlesInfo(blk)

    if (!("battles" in blk))
      return

    let itemCount = blk.battles.blockCount()

    for (local i = 0; i < itemCount; i++) {
      let itemBlk = blk.battles.getBlock(i)
      let battle   = WwBattle(itemBlk)

      if (battle.isValid())
        this.battles.append(battle)
    }
  }


  function updateConfigurableValues() {
    this.clearUnitsLists()
    let blk = DataBlock()
    wwGetConfigurableValues(blk)
    this.configurableValues = blk
    // ----- FIX ME: Weapon masks data should be received from char -----
    if (!("fighterCountAsAssault" in this.configurableValues)) {
      this.configurableValues.fighterCountAsAssault = DataBlock()
      this.configurableValues.fighterCountAsAssault.mgun    = false
      this.configurableValues.fighterCountAsAssault.cannon  = false
      this.configurableValues.fighterCountAsAssault.gunner  = false
      this.configurableValues.fighterCountAsAssault.bomb    = true
      this.configurableValues.fighterCountAsAssault.torpedo = false
      this.configurableValues.fighterCountAsAssault.rockets = true
      this.configurableValues.fighterCountAsAssault.gunpod  = false
    }
    // ------------------------------------------------------------------

    local fighterToAssaultWeaponMask = 0
    let fighterCountAsAssault = this.configurableValues.fighterCountAsAssault
    for (local i = 0; i < fighterCountAsAssault.paramCount(); i++)
      if (fighterCountAsAssault.getParamValue(i))
        fighterToAssaultWeaponMask = fighterToAssaultWeaponMask | (1 << i)

    this.configurableValues.fighterToAssaultWeaponMask = fighterToAssaultWeaponMask
  }


  function onEventWWLoadOperationFirstTime(_params = {}) {
    this.updateConfigurableValues()
  }

  function onEventWWLoadOperation(_params = {}) {
    this.isArmyGroupsValid = false
    this.isBattlesValid = false
  }

  function getWWConfigurableValue(paramPath, defaultValue) {
    return getBlkValueByPath(this.configurableValues, paramPath, defaultValue)
  }

  function getOperationObjectives() {
    let blk = DataBlock()
    ww_get_operation_objectives(blk)
    return blk
  }

  function isCurrentOperationFinished() {
    if (!wwIsOperationLoaded())
      return false

    return wwGetOperationWinner() != SIDE_NONE
  }

  function getReinforcementsInfo() {
    let blk = DataBlock()
    wwGetReinforcementsInfo(blk)
    return blk
  }

  function getReinforcementsArrayBySide(side) {
    let reinforcementsInfo = this.getReinforcementsInfo()
    if (reinforcementsInfo?.reinforcements == null)
      return []

    let res = []
    for (local i = 0; i < reinforcementsInfo.reinforcements.blockCount(); i++) {
      let reinforcement = reinforcementsInfo.reinforcements.getBlock(i)
      let wwReinforcementArmy = WwReinforcementArmy(reinforcement)
      if (hasFeature("worldWarMaster") ||
           (wwReinforcementArmy.isMySide(side)
           && wwReinforcementArmy.hasManageAccess())
         )
          res.append(wwReinforcementArmy)
    }

    return res
  }

  function getMyReinforcementsArray() {
    return this.getReinforcementsArrayBySide(wwGetPlayerSide()).filter(@(reinf) reinf.hasManageAccess())
  }

  function getMyReadyReinforcementsArray() {
    return this.getMyReinforcementsArray().filter(@(reinf) reinf.isReady())
  }

  function hasSuspendedReinforcements() {
    return u.search(
        this.getMyReinforcementsArray(),
        function(reinf) {
          return !reinf.isReady()
        }
      ) != null
  }

  function getReinforcementByName(name, blk = null) {
    if (!name || !name.len())
      return null
    if (!blk)
      blk = this.getReinforcementsInfo()
    if (!blk?.reinforcements)
      return null

    for (local i = 0; i < blk.reinforcements.blockCount(); i++) {
      let reinforcement = blk.reinforcements.getBlock(i)
      if (!reinforcement)
        continue

      if (reinforcement.getBlockName() == name)
        return WwReinforcementArmy(reinforcement)
    }

    return null
  }

  function sendReinforcementRequest(cellIdx, name) {
    let params = DataBlock()
    params.setInt("cellIdx", cellIdx)
    params.setStr("name", name)
    return ww_send_operation_request("cln_ww_emplace_reinforcement", params)
  }

  function isArmySelected(armyName) {
    return isInArray(armyName, ww_get_selected_armies_names())
  }

  function moveSelectedArmyToCell(cellIdx, params = {}) {
    let army = getTblValue("army", params)
    if (!army)
      return

    local moveType = "EMT_ATTACK" //default move type
    let targetAirfieldIdx = getTblValue("targetAirfieldIdx", params, -1)
    let target = getTblValue("target", params)

    let blk = DataBlock()
    if (targetAirfieldIdx >= 0) {
      let airfield = this.getAirfieldByIndex(targetAirfieldIdx)
      if (g_ww_unit_type.isAir(army.unitType) && army.isMySide(airfield.side)) {
        moveType = "EMT_BACK_TO_AIRFIELD"
        blk.setInt("targetAirfieldIdx", targetAirfieldIdx)
      }
    }

    blk.setStr("moveType", moveType)
    blk.setStr("army", army.name)
    blk.setInt("targetCellIdx", cellIdx)

    let appendToPath = getTblValue("appendToPath", params, false)
    if (appendToPath)
      blk.setBool("appendToPath", appendToPath)
    if (target)
      blk.addStr("targetName", target)

    this.playArmyActionSound("moveSound", army)

    let taskId = ww_send_operation_request("cln_ww_move_army_to", blk)
    addTask(taskId, null, @() null,
      function (_errorCode) {
        this.popupCharErrorMsg("move_army_error")
      })
  }


  // TODO: make this function to work like moveSelectedArmyToCell
  // to avoid duplication code for ground and air arimies.
  function moveSelectedArmiesToCell(cellIdx, armies = [], target = null, appendPath = false) {
    //MOVE TYPE - EMT_ATTACK always
    if (cellIdx < 0  || armies.len() == 0)
      return

    let params = DataBlock()
    for (local i = 0; i < armies.len(); i++) {
      params.addStr($"army{i}", armies[i].name)
      params.addInt($"targetCellIdx{i}", cellIdx)
    }

    if (appendPath)
      params.addBool("appendToPath", true)
    if (target)
      params.addStr("targetName", target)

    this.playArmyActionSound("moveSound", armies[0])
    ww_send_operation_request("cln_ww_move_armies_to", params)
  }


  function playArmyActionSound(soundId, wwArmy) {
    if (!wwArmy || !wwArmy.isValid())
      return

    let unitTypeCode = wwArmy.getOverrideUnitType() ||
                         wwArmy.getUnitType()
    let armyType = g_ww_unit_type.getUnitTypeByCode(unitTypeCode)
    get_cur_gui_scene()?.playSound(armyType[soundId])
  }


  function moveSelectedArmes(toX, toY, target = null, append = false) {
    if (!this.haveManagementAccessForSelectedArmies())
      return

    if (!this.hasEntrenchedInList(ww_get_selected_armies_names())) {
      this.requestMoveSelectedArmies(toX, toY, target, append)
      return
    }

    gui_handlers.FramedMessageBox.open({
      title = loc("worldwar/armyAskDigout")
      message = loc("worldwar/armyAskDigoutText")
      onOpenSound = "ww_unit_entrench_move_notify"
      buttons = [
        {
          id = "no",
          text = loc("msgbox/btn_no"),
          shortcut = "B"
        }
        {
          id = "yes",
          text = loc("msgbox/btn_yes"),
          cb = Callback(@() this.requestMoveSelectedArmies(toX, toY, target, append), this)
          shortcut = "A"
        }
      ]
    })
  }


  function requestMoveSelectedArmies(toX, toY, target, append) {
    let groundArmies = []
    let selectedArmies = ww_get_selected_armies_names()
    for (local i = selectedArmies.len() - 1; i >= 0 ; i--) {
      let army = this.getArmyByName(selectedArmies.remove(i))
      if (!army.isValid())
        continue

      if (g_ww_unit_type.isAir(army.unitType)) {
        let cellIdx = wwGetMapCellByCoords(toX, toY)
        let targetAirfieldIdx = wwFindAirfieldByCoordinates(toX, toY)
        this.moveSelectedArmyToCell(cellIdx, {
          army = army
          target = target
          targetAirfieldIdx = targetAirfieldIdx
          appendToPath = append
        })
        continue
      }

      groundArmies.append(army)
    }

    if (groundArmies.len()) {
      let cellIdx = wwGetMapCellByCoords(toX, toY)
      this.moveSelectedArmiesToCell(cellIdx, groundArmies, target, append)
    }
  }


  function hasEntrenchedInList(armyNamesList) {
    for (local i = 0; i < armyNamesList.len(); i++) {
      let army = this.getArmyByName(armyNamesList[i])
      if (army && army.isEntrenched())
        return true
    }
    return false
  }


  function stopSelectedArmy() {
    let filteredArray = this.filterArmiesByManagementAccess(this.getSelectedArmies())
    if (!filteredArray.len())
      return

    let params = DataBlock()
    foreach (idx, army in filteredArray)
      params.addStr($"army{idx}", army.name)
    ww_send_operation_request("cln_ww_stop_armies", params)
  }

  function entrenchSelectedArmy() {
    let filteredArray = this.filterArmiesByManagementAccess(this.getSelectedArmies())
    if (!filteredArray.len())
      return

    let entrenchedArmies = filteredArray.filter(@(army) !army.isEntrenched())
    if (!entrenchedArmies.len())
      return

    let params = DataBlock()
    foreach (idx, army in entrenchedArmies)
      params.addStr($"army{idx}", army.name)
    get_cur_gui_scene()?.playSound("ww_unit_entrench")
    ww_send_operation_request("cln_ww_entrench_armies", params)
  }

  function moveSelectedAircraftsToCell(cellIdx, unitsList, owner, target = null) {
    if (cellIdx < 0)
      return -1

    if (unitsList.len() == 0)
      return -1

    let params = DataBlock()
    let airfieldIdx = wwGetSelectedAirfield()
    params.addInt("targetCellIdx", cellIdx)
    params.addInt("airfield", airfieldIdx)
    params.addStr("side", ww_side_val_to_name(owner.side))
    params.addStr("country", owner.country)
    params.addInt("armyGroupIdx", owner.armyGroupIdx)

    local i = 0
    foreach (unitName, unitTable in unitsList) {
      if (unitTable.count == 0)
        continue

      params.addStr($"unitName{i}", unitName)
      params.addInt($"unitCount{i}", unitTable?.count ?? 0)
      params.addStr($"unitWeapon{i}", unitTable?.weapon ?? "")
      i++
    }

    if (target)
      params.addStr("targetName", target)

    let airfield = this.getAirfieldByIndex(airfieldIdx)
    get_cur_gui_scene()?.playSound(airfield.airfieldType.flyoutSound)

    return ww_send_operation_request("cln_ww_move_army_to", params)
  }

  function sortUnitsByTypeAndCount(a, b) {
    let aType = a.wwUnitType.code
    let bType = b.wwUnitType.code
    if (aType != bType)
      return aType - bType
    return a.count - b.count
  }

  function sortUnitsBySortCodeAndCount(a, b) {
    let aSortCode = a.wwUnitType.sortCode
    let bSortCode = b.wwUnitType.sortCode
    if (aSortCode != bSortCode)
      return aSortCode - bSortCode

    let aCount = a.count
    let bCount = b.count
    return aCount.tointeger() - bCount.tointeger()
  }

  function getOperationTimeSec() {
    return time.millisecondsToSecondsInt(wwGetOperationTimeMillisec())
  }

  function requestLogs(loadAmount, useLogMark, cb, errorCb) {
    let logMark = useLogMark ? ::g_ww_logs.lastMark : ""
    let reqBlk = DataBlock()
    reqBlk.setInt("count", loadAmount)
    reqBlk.setStr("last", logMark)
    let taskId = ww_operation_request_log(reqBlk)

    if (taskId < 0) // taskId == -1 means request result is ready
      cb()
    else
      addTask(taskId, null, cb, errorCb)
  }

  function getSidesOrder() {
    local playerSide = wwGetPlayerSide()
    if (playerSide == SIDE_NONE)
      playerSide = SIDE_1

    let enemySide  = this.getOppositeSide(playerSide)
    return [ playerSide, enemySide ]
  }

  function getCommonSidesOrder() {
    return [SIDE_1, SIDE_2]
  }

  function getOppositeSide(side) {
    return side == SIDE_2 ? SIDE_1 : SIDE_2
  }

  function get_last_weapon_preset(unitName) {
    let unit = getAircraftByName(unitName)
    if (!unit)
      return ""

    let weaponName = loadLocalByAccount($"{WW_UNIT_WEAPON_PRESET_PATH}{unitName}", "")
    let weapons = unit.getWeapons()
    foreach (weapon in weapons)
      if (weapon.name == weaponName)
        return weaponName

    return weapons?[0].name ?? ""
  }

  function set_last_weapon_preset(unitName, weaponName) {
    saveLocalByAccount($"{WW_UNIT_WEAPON_PRESET_PATH}{unitName}", weaponName)
  }

  function collectUnitsData(unitsArray, isViewStrengthList = true) {
    let collectedUnits = {}
    foreach (wwUnit in unitsArray) {
      let id = isViewStrengthList ? wwUnit.stengthGroupExpClass : wwUnit.expClass
      if (!(id in collectedUnits))
        collectedUnits[id] <- wwUnit
      else
        collectedUnits[id].count += wwUnit.count
    }

    return collectedUnits
  }

  function getSaveOperationLogId() {
    return $"{WW_LAST_OPERATION_LOG_SAVE_ID}{wwGetOperationId()}"
  }

  function updateUserlogsAccess() {
    if (!::is_worldwar_enabled())
      return

    let wwUserLogTypes = [EULT_WW_START_OPERATION,
                            EULT_WW_CREATE_OPERATION,
                            EULT_WW_END_OPERATION]
    for (local i = ::hidden_userlogs.len() - 1; i >= 0; i--)
      if (isInArray(::hidden_userlogs[i], wwUserLogTypes))
        ::hidden_userlogs.remove(i)
  }

  function updateOperationPreviewAndDo(operationId, cb, hasProgressBox = false) {
    operationPreloader.loadPreview(operationId, cb, hasProgressBox)
  }

  function onEventWWOperationPreviewLoaded(_params = {}) {
    this.isArmyGroupsValid = false
    this.isBattlesValid = false
    this.updateConfigurableValues()
  }

  function popupCharErrorMsg(groupName = null, titleText = "", errorMsgId = null) {
    errorMsgId = errorMsgId ?? get_char_error_msg()
    if (!errorMsgId)
      return

    if (errorMsgId == "WRONG_REINFORCEMENT_NAME")
      return

    let popupText = loc($"worldwar/charError/{errorMsgId}",
      loc("worldwar/charError/defaultError", ""))
    if (popupText.len() || titleText.len())
      addPopup(titleText, popupText, null, null, null, groupName)
  }

  function getCurMissionWWBattleName() {
    let misBlk = DataBlock()
    get_current_mission_desc(misBlk)

    let battleId = misBlk?.customRules?.battleId
    if (!battleId)
      return ""

    let battle = this.getBattleById(battleId)
    return battle ? battle.getView().getBattleName() : ""
  }

  function getCurMissionWWOperationName() {
    let misBlk = DataBlock()
    get_current_mission_desc(misBlk)

    let operationId = misBlk?.customRules?.operationId
    if (!operationId)
      return ""

    let operation = getOperationById(operationId.tointeger())
    return operation ? operation.getNameText() : ""
  }

  function openOperationRewardPopup(logObj) {
    if (getGlobalStatusData())
      openWwOperationRewardPopup(logObj)
  }

}
registerPersistentData("g_world_war", g_world_war, ["configurableValues", "curOperationCountry"])

::g_world_war <- g_world_war

subscribe_handler(g_world_war, g_listener_priority.DEFAULT_HANDLER)
