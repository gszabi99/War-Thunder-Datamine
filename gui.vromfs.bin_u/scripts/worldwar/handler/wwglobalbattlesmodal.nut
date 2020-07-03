local globalBattlesListData = require("scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
local WwGlobalBattle = require("scripts/worldWar/operations/model/wwGlobalBattle.nut")
local { openBattlesFilterMenu, isMatchFilterMask } = require("scripts/worldWar/handler/wwBattlesFilterMenu.nut")
local slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
local { getCustomViewCountryData } = require("scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
local { getOperationById } = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

local MAX_VISIBLE_BATTLES_PER_GROUP = 5

class ::gui_handlers.WwGlobalBattlesModal extends ::gui_handlers.WwBattleDescription
{
  hasSquadsInviteButton = false
  hasBattleFilter = true
  battlesList = null
  operationBattle = null
  isBattleInited = false
  needUpdatePrefixWidth = false
  minCountBattlesInList = 100
  needFullUpdateList = true

  static function open(battle = null)
  {
    if (!battle || !battle.isValid())
      battle = WwGlobalBattle()

    ::handlersManager.loadHandler(::gui_handlers.WwGlobalBattlesModal, {
        curBattleInList = battle
        operationBattle = ::WwBattle()
      })
  }

  function initScreen()
  {
    battlesList = []
    globalBattlesListData.requestList()
    base.initScreen()

    ::checkNonApprovedResearches(true)
  }

  function getSceneTplView()
  {
    return {
      hasRefreshButton = true
    }
  }

  function onUpdate(obj, dt)
  {
    refreshList()
  }

  function onRefresh()
  {
    refreshList(true)
  }

  function goBack()
  {
    ::ww_stop_preview()
    base.goBack()
  }

  function refreshList(isForce = false)
  {
    requestQueuesData()
    globalBattlesListData.requestList()

    if (!isForce)
      return

    needFullUpdateList = true
  }

  function onEventWWUpdateGlobalBattles(p)
  {
    updateForceSelectedBattle()
    reinitBattlesList()
  }

  function onEventWWUpdateWWQueues(params)
  {
    reinitBattlesList()
  }

  function updateWindow()
  {
    updateViewMode()
    updateDescription()
    updateSlotbar()
    updateButtons()
    updateDurationTimer()
    isBattleInited = true
    updateTitle()
  }

  function getTitleText()
  {
    return ::loc("worldwar/global_battle/title", {
      country = ::loc(getCustomViewCountryData(::get_profile_country_sq()).locId)})
  }

  function updateSlotbar()
  {
    local availableUnits = {}
    local operationUnits = {}
    if (operationBattle.isValid())
      foreach (side in ::g_world_war.getSidesOrder(curBattleInList))
      {
        local playerTeam = operationBattle.getTeamBySide(side)
        availableUnits.__update(operationBattle.getTeamRemainUnits(playerTeam))
        operationUnits.__update(::g_world_war.getAllOperationUnitsBySide(side))
      }

    local map = getMap()
    local unitsGroupsByCountry = map?.getUnitsGroupsByCountry()
    local prevSlotbarStatus = hasSlotbarByUnitsGroups
    hasSlotbarByUnitsGroups = unitsGroupsByCountry != null
    if (prevSlotbarStatus != hasSlotbarByUnitsGroups)
      destroySlotbar()
    if (hasSlotbarByUnitsGroups)
      slotbarPresets.setCurPreset(map.getId() ,unitsGroupsByCountry)

    local assignCountry = ::get_profile_country_sq()
    createSlotbar(
      {
        singleCountry = assignCountry
        customViewCountryData = {[assignCountry]  = getCustomViewCountryData(assignCountry, map?.getId(), true)}
        availableUnits = availableUnits.len() ? availableUnits : null
        customUnitsList = hasSlotbarByUnitsGroups || operationUnits.len() == 0
          ? null
          : operationUnits
      }.__update(getSlotbarParams()),
      "nav-slotbar"
    )
  }

  function updateSelectedItem(isForceUpdate = false)
  {
    refreshSelBattle()
    local cb = ::Callback(function() {
      local newOperationBattle = ::g_world_war.getBattleById(curBattleInList.id)
      if (!newOperationBattle.isValid() || newOperationBattle.isStale())
      {
        newOperationBattle = clone curBattleInList
        newOperationBattle.setStatus(::EBS_FINISHED)
      }
      local isBattleEqual = operationBattle.isEqual(newOperationBattle)
      operationBattle = newOperationBattle

      updateBattleSquadListData()
      if (!isBattleInited || !isBattleEqual)
        updateWindow()
    }, this)

    if (curBattleInList.isValid())
    {
      if (isForceUpdate)
      {
        updateDescription()
        updateButtons()
      }
      if (curBattleInList.operationId != ::ww_get_operation_id())
        ::g_world_war.updateOperationPreviewAndDo(curBattleInList.operationId, cb)
      else
        cb()
    }
    else
      cb()
  }

  function getOperationBackground()
  {
    return "#ui/images/worldwar_window_bg_image_all_battles"
  }

  function getSelectedBattlePrefixText(battleData)
  {
    return ""
  }

  function createBattleListMap()
  {
    setFilteredBattles()
    if (needFullUpdateList || curBattleListMap.len() <= 0)
    {
      needFullUpdateList = false
      return getFilteredBattlesByMaxCountPerGroup()
    }

    local battleListMap = clone curBattleListMap
    foreach(idx, battle in battleListMap)
    {
      local newBattle = getBattleById(battle.id, false)
      if (newBattle.isValid())
      {
        battleListMap[idx] = newBattle
        continue
      }

      if (battle.isFinished())
        continue

      newBattle.setFromBattle(battle)
      newBattle.setStatus(::EBS_FINISHED)
      battleListMap[idx] = newBattle
    }

    return battleListMap
  }

  function onEventCountryChanged(p)
  {
    guiScene.performDelayed(this, function() {
      needFullUpdateList = true
      reinitBattlesList(true)
      updateTitle()
    })
  }

  function onOpenBattlesFilters(obj)
  {
    local applyFilter = ::Callback(function()
      {
        reinitBattlesList(true)
        refreshList(true)
      }, this)

    openBattlesFilterMenu({
      alignObj = scene.findObject("btn_battles_filters")
      onChangeValuesBitMaskCb = applyFilter
    })
  }

  function setFilteredBattles()
  {
    local assignCountry = ::get_profile_country_sq()
    battlesList = globalBattlesListData.getList().filter(@(battle)
      battle.hasSideCountry(assignCountry) && battle.isOperationMapAvaliable()
      && battle.hasAvailableUnits())

    if (currViewMode != WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      return

    battlesList = battlesList.filter(
      function(battle) {
        local side = getPlayerSide(battle)
        local team = battle.getTeamBySide(side)
        return isMatchFilterMask(battle, assignCountry, team, side)
      }.bindenv(this))
  }

  function battlesSort(battleA, battleB)
  {
    return battleB.isConfirmed() <=> battleA.isConfirmed()
      || battleA.sortTimeFactor <=> battleB.sortTimeFactor
      || battleB.sortFullnessFactor <=> battleA.sortFullnessFactor
  }

  function getBattleById(battleId, searchInCurList = true)
  {
    return ::u.search(battlesList, @(battle) battle.id == battleId)
      ?? (searchInCurList
        ? (::u.search(curBattleListMap, @(battle) battle.id == battleId) ?? WwGlobalBattle())
        : WwGlobalBattle())
  }

  function getPlayerSide(battle = null)
  {
    if (!battle)
      battle = curBattleInList

    return battle.getSideByCountry(::get_profile_country_sq())
  }

  function getEmptyBattle()
  {
    return WwGlobalBattle()
  }

  function fillOperationInfoText()
  {
    local operationInfoTextObj = scene.findObject("operation_info_text")
    if (!::check_obj(operationInfoTextObj))
      return

    local operation = getOperationById(curBattleInList.getOperationId())
    if (!operation)
      return

    operationInfoTextObj.setValue(operation.getNameText())
  }

  function updateNoAvailableBattleInfo()
  {
  }

  function getFilteredBattlesByMaxCountPerGroup()
  {
    if (battlesList.len() == 0)
      return []

    local maxVisibleBattlesPerGroup = ::g_world_war.getSetting("maxVisibleGlobalBattlesPerGroup",
      MAX_VISIBLE_BATTLES_PER_GROUP)

    local battlesByGroups = {}
    local res = []
    foreach (battleData in battlesList)
    {
      local groupId = battleData.getGroupId()
      if (!(groupId in battlesByGroups))
        battlesByGroups[groupId] <- [battleData]
      else
        battlesByGroups[groupId].append(battleData)
    }

    foreach (group in battlesByGroups)
    {
      group.sort(battlesSort)
      res.extend(group.resize(min(group.len(), maxVisibleBattlesPerGroup)))
    }

    res.sort(battlesSort)
    return res
  }
}
