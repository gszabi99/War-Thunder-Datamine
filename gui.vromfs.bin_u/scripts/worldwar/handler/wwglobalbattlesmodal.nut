//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let globalBattlesListData = require("%scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
let WwGlobalBattle = require("%scripts/worldWar/operations/model/wwGlobalBattle.nut")
let { openBattlesFilterMenu, isMatchFilterMask } = require("%scripts/worldWar/handler/wwBattlesFilterMenu.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

local MAX_VISIBLE_BATTLES_PER_GROUP = 5

::gui_handlers.WwGlobalBattlesModal <- class extends ::gui_handlers.WwBattleDescription {
  hasSquadsInviteButton = false
  hasBattleFilter = true
  battlesList = null
  operationBattle = null
  isBattleInited = false
  needUpdatePrefixWidth = false
  minCountBattlesInList = 100
  needFullUpdateList = true

  static function open(battle = null) {
    if (!battle || !battle.isValid())
      battle = WwGlobalBattle()

    ::handlersManager.loadHandler(::gui_handlers.WwGlobalBattlesModal, {
        curBattleInList = battle
        operationBattle = ::WwBattle()
      })
  }

  function initScreen() {
    this.battlesList = []
    globalBattlesListData.requestList()
    base.initScreen()

    ::checkNonApprovedResearches(true)
  }

  function getSceneTplView() {
    return {
      hasRefreshButton = true
    }
  }

  function onUpdate(_obj, _dt) {
    this.refreshList()
  }

  function onRefresh() {
    this.refreshList(true)
  }

  function goBack() {
    ::ww_stop_preview()
    base.goBack()
  }

  function refreshList(isForce = false) {
    this.requestQueuesData()
    globalBattlesListData.requestList()

    if (!isForce)
      return

    this.needFullUpdateList = true
  }

  function onEventWWUpdateGlobalBattles(_p) {
    this.updateForceSelectedBattle()
    this.reinitBattlesList()
  }

  function onEventWWUpdateWWQueues(_params) {
    this.reinitBattlesList()
  }

  function updateWindow() {
    this.updateViewMode()
    this.updateDescription()
    this.updateSlotbar()
    this.updateButtons()
    this.updateDurationTimer()
    this.isBattleInited = true
    this.updateTitle()
  }

  function getTitleText() {
    return loc("worldwar/global_battle/title", {
      country = loc(getCustomViewCountryData(profileCountrySq.value).locId) })
  }

  function updateSlotbar() {
    let availableUnits = {}
    let operationUnits = {}
    if (this.operationBattle.isValid())
      foreach (side in ::g_world_war.getSidesOrder(this.curBattleInList)) {
        let playerTeam = this.operationBattle.getTeamBySide(side)
        availableUnits.__update(this.operationBattle.getTeamRemainUnits(playerTeam))
        operationUnits.__update(::g_world_war.getAllOperationUnitsBySide(side))
      }

    let map = this.getMap()
    let unitsGroupsByCountry = map?.getUnitsGroupsByCountry()
    let prevSlotbarStatus = this.hasSlotbarByUnitsGroups
    this.hasSlotbarByUnitsGroups = unitsGroupsByCountry != null
    if (prevSlotbarStatus != this.hasSlotbarByUnitsGroups)
      this.destroySlotbar()
    if (this.hasSlotbarByUnitsGroups)
      slotbarPresets.setCurPreset(map.getId(), unitsGroupsByCountry)

    let assignCountry = profileCountrySq.value
    this.createSlotbar(
      {
        singleCountry = assignCountry
        customViewCountryData = { [assignCountry]  = getCustomViewCountryData(assignCountry, map?.getId(), true) }
        availableUnits = availableUnits.len() ? availableUnits : null
        customUnitsList = this.hasSlotbarByUnitsGroups || operationUnits.len() == 0
          ? null
          : operationUnits
      }.__update(this.getSlotbarParams()),
      "nav-slotbar"
    )
  }

  function updateSelectedItem(isForceUpdate = false) {
    this.refreshSelBattle()
    let cb = Callback(function() {
      local newOperationBattle = ::g_world_war.getBattleById(this.curBattleInList.id)
      if (!newOperationBattle.isValid() || newOperationBattle.isStale()) {
        newOperationBattle = clone this.curBattleInList
        newOperationBattle.setStatus(EBS_FINISHED)
      }
      let isBattleEqual = this.operationBattle.isEqual(newOperationBattle)
      this.operationBattle = newOperationBattle

      this.updateBattleSquadListData()
      if (!this.isBattleInited || !isBattleEqual)
        this.updateWindow()
    }, this)

    if (this.curBattleInList.isValid()) {
      if (isForceUpdate) {
        this.updateDescription()
        this.updateButtons()
      }
      if (this.curBattleInList.operationId != ::ww_get_operation_id())
        ::g_world_war.updateOperationPreviewAndDo(this.curBattleInList.operationId, cb)
      else
        cb()
    }
    else
      cb()
  }

  function getOperationBackground() {
    return "#ui/images/worldwar_window_bg_image_all_battles?P1"
  }

  function getSelectedBattlePrefixText(_battleData) {
    return ""
  }

  function createBattleListMap() {
    this.setFilteredBattles()
    if (this.needFullUpdateList || this.curBattleListMap.len() <= 0) {
      this.needFullUpdateList = false
      return this.getFilteredBattlesByMaxCountPerGroup()
    }

    let battleListMap = clone this.curBattleListMap
    foreach (idx, battle in battleListMap) {
      let newBattle = this.getBattleById(battle.id, false)
      if (newBattle.isValid()) {
        battleListMap[idx] = newBattle
        continue
      }

      if (battle.isFinished())
        continue

      newBattle.setFromBattle(battle)
      newBattle.setStatus(EBS_FINISHED)
      battleListMap[idx] = newBattle
    }

    return battleListMap
  }

  function onEventCountryChanged(_p) {
    this.guiScene.performDelayed(this, function() {
      this.needFullUpdateList = true
      this.reinitBattlesList(true)
      this.updateTitle()
    })
  }

  function onOpenBattlesFilters(_obj) {
    let applyFilter = Callback(function() {
        this.reinitBattlesList(true)
        this.refreshList(true)
      }, this)

    openBattlesFilterMenu({
      alignObj = this.scene.findObject("btn_battles_filters")
      onChangeValuesBitMaskCb = applyFilter
    })
  }

  function setFilteredBattles() {
    let assignCountry = profileCountrySq.value
    this.battlesList = globalBattlesListData.getList().filter(@(battle)
      battle.hasSideCountry(assignCountry) && battle.isOperationMapAvaliable()
      && battle.hasAvailableUnits())

    if (this.currViewMode != WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      return

    this.battlesList = this.battlesList.filter(
      function(battle) {
        let side = this.getPlayerSide(battle)
        local team = battle.getTeamBySide(side)
        return isMatchFilterMask(battle, assignCountry, team, side)
      }.bindenv(this))
  }

  function battlesSort(battleA, battleB) {
    return battleB.isConfirmed() <=> battleA.isConfirmed()
      || battleA.sortTimeFactor <=> battleB.sortTimeFactor
      || battleB.sortFullnessFactor <=> battleA.sortFullnessFactor
  }

  function getBattleById(battleId, searchInCurList = true) {
    return ::u.search(this.battlesList, @(battle) battle.id == battleId)
      ?? (searchInCurList
        ? (::u.search(this.curBattleListMap, @(battle) battle.id == battleId) ?? WwGlobalBattle())
        : WwGlobalBattle())
  }

  function getPlayerSide(battle = null) {
    if (!battle)
      battle = this.curBattleInList

    return battle.getSideByCountry(profileCountrySq.value)
  }

  function getEmptyBattle() {
    return WwGlobalBattle()
  }

  function fillOperationInfoText() {
    let operationInfoTextObj = this.scene.findObject("operation_info_text")
    if (!checkObj(operationInfoTextObj))
      return

    let operation = getOperationById(this.curBattleInList.getOperationId())
    if (!operation)
      return

    operationInfoTextObj.setValue(operation.getNameText())
  }

  function getFilteredBattlesByMaxCountPerGroup() {
    if (this.battlesList.len() == 0)
      return []

    let maxVisibleBattlesPerGroup = ::g_world_war.getSetting("maxVisibleGlobalBattlesPerGroup",
      MAX_VISIBLE_BATTLES_PER_GROUP)

    let battlesByGroups = {}
    let res = []
    foreach (battleData in this.battlesList) {
      let groupId = battleData.getGroupId()
      if (!(groupId in battlesByGroups))
        battlesByGroups[groupId] <- [battleData]
      else
        battlesByGroups[groupId].append(battleData)
    }

    foreach (group in battlesByGroups) {
      group.sort(this.battlesSort)
      group.resize(min(group.len(), maxVisibleBattlesPerGroup))
      res.extend(group)
    }

    res.sort(this.battlesSort)
    return res
  }
}
