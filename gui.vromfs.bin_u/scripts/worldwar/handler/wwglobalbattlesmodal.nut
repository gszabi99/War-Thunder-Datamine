let globalBattlesListData = require("%scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
let WwGlobalBattle = require("%scripts/worldWar/operations/model/wwGlobalBattle.nut")
let { openBattlesFilterMenu, isMatchFilterMask } = require("%scripts/worldWar/handler/wwBattlesFilterMenu.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

local MAX_VISIBLE_BATTLES_PER_GROUP = 5

::gui_handlers.WwGlobalBattlesModal <- class extends ::gui_handlers.WwBattleDescription
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
    let availableUnits = {}
    let operationUnits = {}
    if (operationBattle.isValid())
      foreach (side in ::g_world_war.getSidesOrder(curBattleInList))
      {
        let playerTeam = operationBattle.getTeamBySide(side)
        availableUnits.__update(operationBattle.getTeamRemainUnits(playerTeam))
        operationUnits.__update(::g_world_war.getAllOperationUnitsBySide(side))
      }

    let map = getMap()
    let unitsGroupsByCountry = map?.getUnitsGroupsByCountry()
    let prevSlotbarStatus = hasSlotbarByUnitsGroups
    hasSlotbarByUnitsGroups = unitsGroupsByCountry != null
    if (prevSlotbarStatus != hasSlotbarByUnitsGroups)
      destroySlotbar()
    if (hasSlotbarByUnitsGroups)
      slotbarPresets.setCurPreset(map.getId() ,unitsGroupsByCountry)

    let assignCountry = ::get_profile_country_sq()
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
    let cb = ::Callback(function() {
      local newOperationBattle = ::g_world_war.getBattleById(curBattleInList.id)
      if (!newOperationBattle.isValid() || newOperationBattle.isStale())
      {
        newOperationBattle = clone curBattleInList
        newOperationBattle.setStatus(::EBS_FINISHED)
      }
      let isBattleEqual = operationBattle.isEqual(newOperationBattle)
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
    return "#ui/images/worldwar_window_bg_image_all_battles.jpg?P1"
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

    let battleListMap = clone curBattleListMap
    foreach(idx, battle in battleListMap)
    {
      let newBattle = getBattleById(battle.id, false)
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
    let applyFilter = ::Callback(function()
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
    let assignCountry = ::get_profile_country_sq()
    battlesList = globalBattlesListData.getList().filter(@(battle)
      battle.hasSideCountry(assignCountry) && battle.isOperationMapAvaliable()
      && battle.hasAvailableUnits())

    if (currViewMode != WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      return

    battlesList = battlesList.filter(
      function(battle) {
        let side = getPlayerSide(battle)
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
    let operationInfoTextObj = scene.findObject("operation_info_text")
    if (!::check_obj(operationInfoTextObj))
      return

    let operation = getOperationById(curBattleInList.getOperationId())
    if (!operation)
      return

    operationInfoTextObj.setValue(operation.getNameText())
  }

  function getFilteredBattlesByMaxCountPerGroup()
  {
    if (battlesList.len() == 0)
      return []

    let maxVisibleBattlesPerGroup = ::g_world_war.getSetting("maxVisibleGlobalBattlesPerGroup",
      MAX_VISIBLE_BATTLES_PER_GROUP)

    let battlesByGroups = {}
    let res = []
    foreach (battleData in battlesList)
    {
      let groupId = battleData.getGroupId()
      if (!(groupId in battlesByGroups))
        battlesByGroups[groupId] <- [battleData]
      else
        battlesByGroups[groupId].append(battleData)
    }

    foreach (group in battlesByGroups)
    {
      group.sort(battlesSort)
      group.resize(min(group.len(), maxVisibleBattlesPerGroup))
      res.extend(group)
    }

    res.sort(battlesSort)
    return res
  }
}
