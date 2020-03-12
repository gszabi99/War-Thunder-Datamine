local globalBattlesListData = require("scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
local WwGlobalBattle = require("scripts/worldWar/operations/model/wwGlobalBattle.nut")
local wwBattlesFilterMenu = require("scripts/worldWar/handler/wwBattlesFilterMenu.nut")
local slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")

const WW_GLOBAL_BATTLES_FILTER_ID = "worldWar/ww_global_battles_filter"
local MAX_VISIBLE_BATTLES_PER_GROUP = 5

global enum UNAVAILABLE_BATTLES_CATEGORIES
{
  NO_AVAILABLE_UNITS  = 0x0001
  NO_FREE_SPACE       = 0x0002
  IS_UNBALANCED       = 0x0004
  LOCK_BY_TIMER       = 0x0008
  NOT_STARTED         = 0x0010
}

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
  filterMask = null

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
    updateBattlesFilter()
    globalBattlesListData.requestList()
    base.initScreen()

    ::checkNonApprovedResearches(true)
  }

  function updateBattlesFilter()
  {
    filterMask = wwBattlesFilterMenu.validateFilterMask(::loadLocalByAccount(WW_GLOBAL_BATTLES_FILTER_ID))
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
  }

  function getTitleText()
  {
    return ::loc("worldwar/global_battle/title", {country = ::loc(::get_profile_country_sq())})
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

    createSlotbar(
      {
        customCountry = ::get_profile_country_sq()
        availableUnits = availableUnits.len() ? availableUnits : null
        customUnitsList = hasSlotbarByUnitsGroups || operationUnits.len() == 0
          ? null
          : operationUnits
      }.__update(getSlotbarParams())
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

  function createActiveCountriesInfo()
  {
    local countryListObj = scene.findObject("active_country_info")
    if (!::check_obj(battlesListObj))
      return

    local countriesInfo = getActiveCountriesData()

    local view = { countries = [] }
    foreach (country, data in countriesInfo)
      view.countries.append({
        name = ::loc(country)
        countryIcon = ::get_country_icon(country)
        value = ::loc("worldWar/battles", {number = data})
      })

    local countriesInfoData = ::handyman.renderCached("gui/worldWar/wwActiveCountriesList", view)
    guiScene.replaceContentFromText(countryListObj, countriesInfoData, countriesInfoData.len(), this)

    if (!countriesInfo.len())
    {
      local titleText = countryListObj.findObject("active_countries_text")
      if (::check_obj(titleText))
        titleText.setValue(::loc("worldWar/noParticipatingCountries"))
    }
  }

  function getActiveCountriesData()
  {
    local countriesData = {}
    local globalBattlesList = globalBattlesListData.getList().filter(@(battle)
      battle.isOperationMapAvaliable())
    local isMatchFilters = ::Callback(isMatchFilterMask, this)
    ::shopCountriesList.each(function(country) {
      local battlesListByCountry = globalBattlesList.filter(
        @(battle) battle.hasSideCountry(country) && isMatchFilters(battle, country))

      local battlesNumber = battlesListByCountry.len()
      if (battlesNumber)
        countriesData[country] <- battlesNumber
    })

    return countriesData
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
    local applyFilter = ::Callback(function(selBitMask)
      {
        filterMask = selBitMask
        ::saveLocalByAccount(WW_GLOBAL_BATTLES_FILTER_ID, filterMask)
        reinitBattlesList(true)
        refreshList(true)
      }, this)

    wwBattlesFilterMenu.open({
      alignObj = scene.findObject("btn_battles_filters")
      filterBitMasks = clone filterMask
      onChangeValuesBitMaskCb = applyFilter
    })
  }

  function setFilteredBattles()
  {
    local country = ::get_profile_country_sq()

    battlesList = globalBattlesListData.getList().filter(@(battle)
      battle.hasSideCountry(country) && battle.isOperationMapAvaliable()
      && battle.hasAvailableUnits())

    if (currViewMode != WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      return

    battlesList = battlesList.filter(
      function(battle) {
        return isMatchFilterMask(battle, country)
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

    local operation = ::g_ww_global_status.getOperationById(curBattleInList.getOperationId())
    if (!operation)
      return

    operationInfoTextObj.setValue(operation.getNameText())
  }

  function updateNoAvailableBattleInfo()
  {
  }

  function isMatchFilterMask(battle, country)
  {
    local side = getPlayerSide(battle)
    local team = battle.getTeamBySide(side)
    local curFilterMask = filterMask?.by_available_battles ?? 0

    if (team && !(UNAVAILABLE_BATTLES_CATEGORIES.NO_AVAILABLE_UNITS & curFilterMask)
        && !battle.hasUnitsToFight(country, team, side))
      return false

    if (team && !(UNAVAILABLE_BATTLES_CATEGORIES.NO_FREE_SPACE & curFilterMask)
        && !battle.hasEnoughSpaceInTeam(team))
      return false

    if (team && !(UNAVAILABLE_BATTLES_CATEGORIES.IS_UNBALANCED & curFilterMask)
        && battle.isLockedByExcessPlayers(battle.getSide(country), team.name))
      return false

    if (!(UNAVAILABLE_BATTLES_CATEGORIES.LOCK_BY_TIMER & curFilterMask)
        && battle.getBattleActivateLeftTime() > 0)
      return false

    if (!(UNAVAILABLE_BATTLES_CATEGORIES.NOT_STARTED & curFilterMask)
        && battle.isStarting())
      return false

    curFilterMask = filterMask?.by_unit_type ?? {}
    if (!(curFilterMask?[battle.unitTypeMask.tostring()] ?? true))
      return false

    return true
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
