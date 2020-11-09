local wwQueuesData = require("scripts/worldWar/operations/model/wwQueuesData.nut")
local clustersModule = require("scripts/clusterSelect.nut")
local slotbarWidget = require("scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
local { setCurPreset } = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
local WwHelpSlotbarGroupsModal = require("scripts/worldWar/handler/WwHelpSlotbarGroupsModal.nut")
local { getBestPresetData, generatePreset } = require("scripts/slotbar/generatePreset.nut")
local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")
local { getCustomViewCountryData } = require("scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
local { getOperationById, getMapByName
} = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

// Temporary image. Has to be changed after receiving correct art
const WW_OPERATION_DEFAULT_BG_IMAGE = "#ui/bkg/login_layer_h1_0"

global enum WW_BATTLE_VIEW_MODES
{
  BATTLE_LIST,
  SQUAD_INFO,
  QUEUE_INFO
}

local DEFAULT_BATTLE_ITEM_CONGIG = {
  id = ""
  itemPrefixText = ""
  imgTag = "wwBattleIcon"
  itemIcon = ""
  isHidden = true
}

class ::gui_handlers.WwBattleDescription extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/worldWar/battleDescriptionWindow"
  sceneTplBattleList = "gui/missions/missionBoxItemsList"
  sceneTplDescriptionName = "gui/worldWar/battleDescriptionWindowContent"
  sceneTplTeamRight = "gui/worldWar/wwBattleDescriptionTeamUnitsInfo"
  sceneTplTeamHeaderInfo = "gui/worldWar/wwBattleDescriptionTeamInfo"

  slotbarActions = [ "autorefill", "aircraft", "sec_weapons", "weapons", "crew", "info", "repair" ]
  shouldCheckCrewsReady = true
  hasSquadsInviteButton = true
  hasBattleFilter = false

  curBattleInList = null      // selected battle in list
  operationBattle = null      // battle to dasplay, check join enable, join, etc
  needEventHeader = true
  currViewMode = null
  isSelectedBattleActive = false

  battlesListObj = null
  curBattleListMap = null
  curBattleListItems = null

  battleDurationTimer = null
  squadListHandlerWeak = null
  queueInfoHandlerWeak = null

  idPrefix = "btn_"
  needUpdatePrefixWidth = true
  minCountBattlesInList = 10

  hasSlotbarByUnitsGroups = false

  static function open(battle)
  {
    if (battle.isValid())
    {
      if (!battle.isStillInOperation())
      {
        battle = ::WwBattle()
        ::g_popups.add("", ::loc("worldwar/battle_finished"),
          null, null, null, "battle_finished")
      }
      else if (battle.isAutoBattle())
      {
        battle = ::WwBattle()
        ::g_popups.add("", ::loc("worldwar/battleIsInAutoMode"),
          null, null, null, "battle_in_auto_mode")
      }
    }

    ::handlersManager.loadHandler(::gui_handlers.WwBattleDescription, {
        curBattleInList = battle
        operationBattle = ::WwBattle()
      })
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function getSceneTplView()
  {
    return {
      hasGotoGlobalBattlesBtn = true
    }
  }

  function initScreen()
  {
    battlesListObj = scene.findObject("items_list")
    local battleListData = ::handyman.renderCached(sceneTplBattleList,
      { items = array(minCountBattlesInList, DEFAULT_BATTLE_ITEM_CONGIG)})
    guiScene.appendWithBlk(battlesListObj, battleListData, this)
    curBattleListMap = []
    initQueueInfo()
    updateForceSelectedBattle()

    syncSquadCountry()
    updateViewMode()
    updateDescription()
    updateSlotbar()
    reinitBattlesList()
    initSquadList()
    initFocusArray()

    local timerObj = scene.findObject("update_timer")
    if (::check_obj(timerObj))
      timerObj.setUserData(this)

    requestQueuesData()
  }

  function getMainFocusObj()
  {
    return "header_buttons"
  }

  function getMainFocusObj2()
  {
    return battlesListObj
  }

  function getMainFocusObj3()
  {
    return "squad_list"
  }

  function initQueueInfo()
  {
    local queueInfoObj = scene.findObject("queue_info")
    if (!::check_obj(queueInfoObj))
      return

    local handler = ::handlersManager.loadHandler(::gui_handlers.WwQueueInfo,
      { scene = queueInfoObj })
    registerSubHandler(handler)
    queueInfoHandlerWeak = handler.weakref()
  }

  function updateForceSelectedBattle()
  {
    local queue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
    if (queue)
    {
      local battleWithQueue = getQueueBattle(queue)
      if (battleWithQueue && battleWithQueue.isValid() && curBattleInList.id != battleWithQueue.id)
        curBattleInList = getBattleById(battleWithQueue.id)
    }
    else
    {
      local wwBattleName = ::g_squad_manager.getWwOperationBattle()
      if (wwBattleName && curBattleInList.id != wwBattleName)
        curBattleInList = getBattleById(wwBattleName)
    }

    if (!curBattleInList.isValid())
      curBattleInList = getFirstBattleInListMap()
  }

  function initSquadList()
  {
    local squadInfoObj = scene.findObject("squad_info")
    if (!::check_obj(squadInfoObj))
      return

    local handler = ::handlersManager.loadHandler(::gui_handlers.WwSquadList,
      { scene = squadInfoObj
        onWrapUpCb = ::Callback(onWrapUp, this)
        onWrapDownCb = ::Callback(onWrapDown, this) })
    registerSubHandler(handler)
    squadListHandlerWeak = handler.weakref()
    updateBattleSquadListData()
  }

  function reinitBattlesList(isForceUpdate = false)
  {
    if (!wwQueuesData.isDataValid())
      requestQueuesData()

    local currentBattleListMap = createBattleListMap()
    local needRefillBattleList = isForceUpdate || hasChangedInBattleListMap(currentBattleListMap)

    curBattleListMap = currentBattleListMap

    if (needRefillBattleList)
    {
      local view = getBattleListView()
      fillBattleList(view)
      curBattleListItems = clone view.items
      selectItemInList()
    }

    updateSelectedItem(isForceUpdate)

    validateSquadInfo()
    validateCurQueue()

    if (getViewMode() == WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      showSceneBtn("items_list", curBattleListMap.len() > 0)
  }

  function validateCurQueue()
  {
    local queue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
    if (!queue)
      return

    local queueBattle = getQueueBattle(queue)
    if (!queueBattle || !queueBattle.isValid())
      ::g_world_war.leaveWWBattleQueues()
  }

  function validateSquadInfo()
  {
    local wwBattleName = ::g_squad_manager.getWwOperationBattle()
    if (wwBattleName && (wwBattleName != operationBattle.id || !operationBattle.isValid()))
      ::g_squad_manager.cancelWwBattlePrepare()
  }

  function getBattleById(battleId, searchInCurList = true)
  {
    return ::g_world_war.getBattleById(battleId)
  }

  function isBattleValid(battleId)
  {
    return getBattleById(battleId).isValid()
  }

  function updateWindow()
  {
    updateViewMode()
    updateDescription()
    updateSlotbar()
    updateButtons()
    updateDurationTimer()
    updateNoAvailableBattleInfo()
  }

  function updateTitle()
  {
    local titleTextObj = scene.findObject("battle_description_frame_text")
    if (!::check_obj(titleTextObj))
      return

    titleTextObj.setValue(currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST ?
      getTitleText() : ::loc("worldwar/prepare_battle"))
  }

  function getTitleText()
  {
    return ::loc("userlog/page/battle")
  }

  function updateDurationTimer()
  {
    if (battleDurationTimer && battleDurationTimer.isValid())
      battleDurationTimer.destroy()

    battleDurationTimer = ::Timer(scene, 1,
      @() updateBattleStatus(operationBattle.getView(getPlayerSide())), this, true)
  }

  function updateNoAvailableBattleInfo()
  {
    if (currViewMode != WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      showSceneBtn("no_available_battles_alert_text", false)
    else
    {
      local country = ::g_world_war.curOperationCountry
      local availableBattlesList = ::g_world_war.getBattles().filter(
        function(battle) {
          return ::g_world_war.isBattleAvailableToPlay(battle)
            && isBattleAvailableToMatching(battle, country)
        }.bindenv(this))

      showSceneBtn("no_available_battles_alert_text", !availableBattlesList.len())
    }
  }

  function isBattleAvailableToMatching(battle, country)
  {
    if (battle.getBattleActivateLeftTime() > 0)
      return false

    if(!battle.hasAvailableUnits())
      return false

    local side = getPlayerSide(battle)
    local team = battle.getTeamBySide(side)
    if (team && !battle.hasUnitsToFight(country, team, side))
      return false

    if (team && !battle.hasEnoughSpaceInTeam(team))
      return false

    if (team && battle.isLockedByExcessPlayers(battle.getSide(country), team.name))
      return false

    return true
  }

  function getBattleListView()
  {
    local wwBattlesView = ::u.map(curBattleListMap,
      function(battle) {
        return createBattleListItemView(battle)
      }.bindenv(this))

    return { items = wwBattlesView }
  }

  function selectItemInList()
  {
    if (!curBattleListItems.len())
    {
      curBattleInList = getEmptyBattle()
      return
    }

    if (!curBattleInList.isValid())
      updateForceSelectedBattle()

    local itemId = curBattleInList.isValid() ? curBattleInList.id
      : ""

    local idx = itemId.len() ? (curBattleListItems.findindex(@(item) item.id == itemId) ?? -1) : -1
    if (idx >= 0 && battlesListObj.getValue() != idx)
      battlesListObj.setValue(idx)
  }

  function fillBattleList(view)
  {
    guiScene.setUpdatesEnabled(false, false)
    local newList = view.items
    local total = ::max(newList.len(), curBattleListItems?.len?() ?? 0)
    for(local i = 0; i < total; i++)
      updateBattleInList(i, curBattleListItems?[i], newList?[i])

    showSceneBtn("no_active_battles_text", curBattleListMap.len() == 0)

    guiScene.setUpdatesEnabled(true, true)
    if (!needUpdatePrefixWidth || view.items.len() <= 0)
      return

    local maxSectorNameWidth = 0
    local sectorNameTextObjs = []
    foreach(item in view.items)
    {
      local sectorNameTxtObj = scene.findObject("mission_item_prefix_text_" + item.id)
      if (::checkObj(sectorNameTxtObj))
      {
        sectorNameTextObjs.append(sectorNameTxtObj)
        maxSectorNameWidth = ::max(maxSectorNameWidth, sectorNameTxtObj.getSize()[0])
      }
    }

    local sectorWidth = maxSectorNameWidth
    foreach(sectorNameTextObj in sectorNameTextObjs)
      sectorNameTextObj["min-width"] = sectorWidth
  }

  function battlesSort(battleA, battleB)
  {
    return battleB.isActive() <=> battleA.isActive()
      || battleA.getOrdinalNumber() <=> battleB.getOrdinalNumber()
  }

  function createBattleListItemView(battleData)
  {
    local playerSide = getPlayerSide(battleData)
    local battleView = battleData.getView(playerSide)
    local view = {
      id = battleData.id.tostring()
      itemPrefixText = getSelectedBattlePrefixText(battleData)
      itemText = ""
      itemIcon = battleView.getIconImage()
      status = battleView.getStatus()
      additionalDescription = ""
    }

    if (battleData.isActive() || battleData.isFinished())
      view.itemText <- battleData.getLocName(playerSide)
    else
    {
      local battleSides = ::g_world_war.getSidesOrder(curBattleInList)
      local teamsData = battleView.getTeamBlockByIconSize(
        battleSides, WW_ARMY_GROUP_ICON_SIZE.SMALL, false,
        {hasArmyInfo = false, hasVersusText = true, canAlignRight = false})
      local teamsMarkUp = ""
      foreach(idx, army in teamsData)
        teamsMarkUp += army.armies.armyViews

      view.additionalDescription <- teamsMarkUp
    }

    return view
  }

  function getSelectedBattlePrefixText(battleData)
  {
    local battleView = battleData.getView()
    local battleName = ::colorize("newTextColor", battleView.getShortBattleName())
    local sectorName = battleData.getSectorName()
    return battleName + (!::u.isEmpty(sectorName) ? " " + sectorName : "")
  }

  function updateSlotbar()
  {
    local side = getPlayerSide()
    local availableCountries = getOperationById(::ww_get_operation_id())?.getCountriesByTeams()[side]
    local isSlotbarVisible = (availableCountries?.len() ?? 0) > 0
    showSceneBtn("nav-slotbar", isSlotbarVisible)
    if (!isSlotbarVisible)
      return

    local playerCountry = ::get_profile_country_sq()
    local assignCountry = ::isInArray(playerCountry, availableCountries) ? playerCountry : availableCountries[0]
    local playerTeam = operationBattle.getTeamBySide(side)
    ::switch_profile_country(assignCountry)
    local map = getMap()
    local unitsGroupsByCountry = map?.getUnitsGroupsByCountry()
    hasSlotbarByUnitsGroups = unitsGroupsByCountry != null
    local operationUnits = ::g_world_war.getAllOperationUnitsBySide(side)
    local availableUnits = playerTeam != null ? operationBattle.getTeamRemainUnits(playerTeam)
      : hasSlotbarByUnitsGroups ? ::all_units : operationUnits
    if (hasSlotbarByUnitsGroups)
      setCurPreset(map.getId() ,unitsGroupsByCountry)

    createSlotbar(
      {
        singleCountry = assignCountry
        customViewCountryData = {[assignCountry]  = getCustomViewCountryData(assignCountry, map.getId(), true)}
        availableUnits = availableUnits
        customUnitsList = hasSlotbarByUnitsGroups ? null : operationUnits
      }.__update(getSlotbarParams()),
      "nav-slotbar"
    )
  }

  function getSlotbarParams() {
    return {
      gameModeName = getGameModeNameText()
      showEmptySlot = true
      needPresetsPanel = !hasSlotbarByUnitsGroups
      shouldCheckCrewsReady = true
      hasExtraInfoBlock = true
      showNewSlot = true
      customUnitsListName = getCustomUnitsListNameText()
      shouldAppendToObject = false
    }
  }

  createSlotbarHandler = @(params) hasSlotbarByUnitsGroups
    ? slotbarWidget.create(params)
    : ::gui_handlers.SlotbarWidget.create(params)

  function getGameModeNameText()
  {
    return operationBattle.getView(getPlayerSide()).getFullBattleName()
  }

  function getMap()
  {
    local operation = getOperationById(::ww_get_operation_id())
    if (operation == null)
      return null

    local map = operation.getMap()
    if (map == null)
      return null

    return map
  }

  function getCustomUnitsListNameText()
  {
    local operation = getOperationById(::ww_get_operation_id())
    if (operation)
      return operation.getMapText()

    return ""
  }

  function updateDescription()
  {
    local descrObj = scene.findObject("item_desc")
    if (!::check_obj(descrObj))
      return

    local isOperationBattleLoaded = curBattleInList.id == operationBattle.id
    local battle = isOperationBattleLoaded ? operationBattle : curBattleInList
    local battleView = battle.getView(getPlayerSide())
    local blk = ::handyman.renderCached(sceneTplDescriptionName, battleView)

    guiScene.replaceContentFromText(descrObj, blk, blk.len(), this)

    fillOperationBackground()
    fillOperationInfoText()

    showSceneBtn("operation_loading_wait_anim", battle.isValid() && !isOperationBattleLoaded && !battle.isFinished())

    updateClusters()
    if (!battle.isValid() || !isOperationBattleLoaded || battle.isFinished())
    {
      showSceneBtn("battle_info", battle.isFinished())
      showSceneBtn("teams_block", false)
      showSceneBtn("tactical_map_block", false)
      if (battle.isFinished())
        updateBattleStatus(battleView)
      return
    }

    local battleSides = ::g_world_war.getSidesOrder(curBattleInList)
    local teamsData = battleView.getTeamsDataBySides(battleSides)
    foreach(idx, teamData in teamsData)
    {
      local teamObjHeaderInfo = scene.findObject($"team_header_info_{idx}")
      if (::check_obj(teamObjHeaderInfo))
      {
        local teamHeaderInfoBlk = ::handyman.renderCached(sceneTplTeamHeaderInfo, teamData)
        guiScene.replaceContentFromText(teamObjHeaderInfo, teamHeaderInfoBlk, teamHeaderInfoBlk.len(), this)
      }

      local teamObjPlace = scene.findObject($"team_unit_info_{idx}")
      if (::check_obj(teamObjPlace))
      {
        local teamBlk = ::handyman.renderCached(sceneTplTeamRight, teamData)
        guiScene.replaceContentFromText(teamObjPlace, teamBlk, teamBlk.len(), this)
      }
    }

    loadMap(battleSides[0])
    updateBattleStatus(battleView)
  }

  function fillOperationBackground()
  {
    local battleBgObj = scene.findObject("battle_background")
    if (!::check_obj(battleBgObj))
      return

    battleBgObj["background-image"] = getOperationBackground()
  }

  function getOperationBackground()
  {
    local curOperation = getOperationById(::ww_get_operation_id())
    if (!curOperation)
      return WW_OPERATION_DEFAULT_BG_IMAGE

    local curMap = getMapByName(curOperation.getMapId())
    if (!curMap)
      return WW_OPERATION_DEFAULT_BG_IMAGE

    return curMap.getBackground()
  }

  function fillOperationInfoText()
  {
  }

  function loadMap(playerSide)
  {
    local tacticalMapObj = scene.findObject("tactical_map_single")
    if (!::checkObj(tacticalMapObj))
      return

    local misFileBlk = null
    local misData = operationBattle.missionInfo
    if (misData != null)
    {
      local missionBlk = ::DataBlock()
      missionBlk.setFrom(misData)

      misFileBlk = ::DataBlock()
      misFileBlk.load(missionBlk.getStr("mis_file",""))
    }
    else
      dagor.debug("Error: WWar: Battle with id=" + operationBattle.id + ": not found mission info for mission " + operationBattle.missionName)

    ::g_map_preview.setMapPreview(tacticalMapObj, misFileBlk)
    local playerTeam = operationBattle.getTeamBySide(playerSide)
    if (playerTeam && "name" in playerTeam)
      ::tactical_map_set_team_for_briefing(::get_mp_team_by_team_name(playerTeam.name))
  }

  function updateViewMode()
  {
    local newViewMode = getViewMode()
    if (newViewMode == currViewMode)
      return

    currViewMode = newViewMode

    local isViewBattleList = currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST
    local isViewSquadInfo = currViewMode == WW_BATTLE_VIEW_MODES.SQUAD_INFO
    showSceneBtn("queue_info", currViewMode == WW_BATTLE_VIEW_MODES.QUEUE_INFO)
    showSceneBtn("items_list", isViewBattleList)
    showSceneBtn("squad_info", isViewSquadInfo)
    if (squadListHandlerWeak)
      squadListHandlerWeak.updateButtons(isViewSquadInfo)
    if (isViewBattleList && battlesListObj.childrenCount() > 0)
      battlesListObj.select()
    else if (!isViewSquadInfo)
      restoreFocus()

    updateTitle()
  }

  function getViewMode()
  {
    if (::queues.hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE))
      return WW_BATTLE_VIEW_MODES.QUEUE_INFO

    if (::g_squad_manager.isInSquad() &&
        ::g_squad_manager.getWwOperationBattle() &&
        ::g_squad_manager.isMeReady())
      return WW_BATTLE_VIEW_MODES.SQUAD_INFO

    return WW_BATTLE_VIEW_MODES.BATTLE_LIST
  }

  function updateButtons()
  {
    local isViewBattleList = currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST
    showSceneBtn("btn_battles_filters", hasBattleFilter && isViewBattleList)
    showSceneBtn("cluster_select_button", isViewBattleList)
    showSceneBtn("goto_global_battles_btn", isViewBattleList)
    showSceneBtn("invite_squads_button",
      hasSquadsInviteButton && ::g_world_war.isSquadsInviteEnable())

    if (!curBattleInList.isValid())
    {
      showSceneBtn("cant_join_reason_txt", false)
      showSceneBtn("btn_join_battle", false)
      showSceneBtn("btn_leave_battle", false)
      showSceneBtn("btn_auto_preset", false)
      showSceneBtn("btn_slotbar_help", false)
      showSceneBtn("warning_icon", false)
      return
    }

    local isJoinBattleVisible = currViewMode != WW_BATTLE_VIEW_MODES.QUEUE_INFO
    local isLeaveBattleVisible = currViewMode == WW_BATTLE_VIEW_MODES.QUEUE_INFO
    local isJoinBattleActive = true
    local isLeaveBattleActive = true
    local battleText = isJoinBattleVisible
      ? ::loc("mainmenu/toBattle")
      : ::loc("mainmenu/btnCancel")

    local cantJoinReasonData = operationBattle.getCantJoinReasonData(getPlayerSide(),
      ::g_squad_manager.isInSquad() && ::g_squad_manager.isSquadLeader())
    local joinWarningData = operationBattle.getWarningReasonData(getPlayerSide())
    local warningText = ""
    local fullWarningText = ""

    if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
    {
      isJoinBattleActive = isJoinBattleVisible && cantJoinReasonData.canJoin
      warningText = currViewMode != WW_BATTLE_VIEW_MODES.QUEUE_INFO
        ? getWarningText(cantJoinReasonData, joinWarningData)
        : joinWarningData.warningText
      fullWarningText = currViewMode != WW_BATTLE_VIEW_MODES.QUEUE_INFO
        ? getFullWarningText(cantJoinReasonData, joinWarningData)
        : joinWarningData.fullWarningText
    }
    else
      switch (currViewMode)
      {
        case WW_BATTLE_VIEW_MODES.BATTLE_LIST:
          if (::g_squad_manager.isSquadMember())
          {
            isJoinBattleVisible = !::g_squad_manager.isMeReady()
            isLeaveBattleVisible = ::g_squad_manager.isMeReady()
            battleText = ::g_squad_manager.isMeReady()
              ? ::loc("multiplayer/state/player_not_ready")
              : ::loc("multiplayer/state/player_ready")
          }
          else
          {
            if (!canGatherAllSquadMembersForBattle(cantJoinReasonData))
            {
              isJoinBattleActive = false
              warningText = cantJoinReasonData.reasonText
            }
            else if (canPrerareSquadForBattle(cantJoinReasonData))
            {
              isJoinBattleActive = false
              warningText = cantJoinReasonData.reasonText
            }
            else if (!::g_squad_manager.readyCheck(false))
            {
              isJoinBattleActive = false
              warningText = ::loc("squad/not_all_ready")
            }
          }
          break

        case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
          if (::g_squad_manager.isSquadMember())
          {
            isJoinBattleVisible = !::g_squad_manager.isMyCrewsReady
            isLeaveBattleVisible = ::g_squad_manager.isMyCrewsReady
            battleText = ::g_squad_manager.isMyCrewsReady
              ? ::loc("multiplayer/state/player_not_ready")
              : ::loc("multiplayer/state/crews_ready")
          }
          isJoinBattleActive = cantJoinReasonData.canJoin
          warningText = getWarningText(cantJoinReasonData, joinWarningData)
          fullWarningText = getFullWarningText(cantJoinReasonData, joinWarningData)
          break

        case WW_BATTLE_VIEW_MODES.QUEUE_INFO:
          if (::g_squad_manager.isSquadMember())
          {
            isJoinBattleVisible = false
            isLeaveBattleVisible = true
            isLeaveBattleActive = false
          }
          warningText = joinWarningData.warningText
          fullWarningText = joinWarningData.fullWarningText
          break
      }

    if (isJoinBattleVisible)
      scene.findObject("btn_join_battle_text").setValue(battleText)
    if (isLeaveBattleVisible)
      scene.findObject("btn_leave_event_text").setValue(battleText)

    local joinButtonObj = showSceneBtn("btn_join_battle", isJoinBattleVisible)
    joinButtonObj.inactiveColor = isJoinBattleActive ? "no" : "yes"
    local leaveButtonObj = showSceneBtn("btn_leave_battle", isLeaveBattleVisible)
    leaveButtonObj.enable(isLeaveBattleActive)

    local warningTextObj = showSceneBtn("cant_join_reason_txt", !::u.isEmpty(warningText))
    warningTextObj.setValue(warningText)

    local warningIconObj = showSceneBtn("warning_icon", !::u.isEmpty(fullWarningText))
    warningIconObj.tooltip = fullWarningText

    local unitAvailability = ::g_world_war.getSetting("checkUnitAvailability",
      WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)
    showSceneBtn("required_crafts_block",
      unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.OPERATION_UNITS ||
      unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)

    local isVisibleBtnAutoPreset = joinWarningData.needMsgBox || hasSlotbarByUnitsGroups
    local btnAutoPreset = showSceneBtn("btn_auto_preset", isVisibleBtnAutoPreset)
    if (isVisibleBtnAutoPreset) {
      local bestPresetData = getBestPresetData(joinWarningData.availableUnits,
        joinWarningData.country, hasSlotbarByUnitsGroups)
      local hasChangeInPreset = bestPresetData?.hasChangeInPreset ?? false
      btnAutoPreset.inactiveColor = hasChangeInPreset ? "no" : "yes"
      btnAutoPreset.hasUnseenIcon = hasChangeInPreset ? "yes" : "no"
      ::showBtn("auto_preset_warning_icon", hasChangeInPreset, btnAutoPreset)
    }

    local btnSlotbarHelpObj = showSceneBtn("btn_slotbar_help", hasSlotbarByUnitsGroups)
    if (hasSlotbarByUnitsGroups)
    {
      local isHelpUnseen = WwHelpSlotbarGroupsModal.isUnseen()
      showSceneBtn("btn_slotbar_help_unseen_icon", isHelpUnseen)
      btnSlotbarHelpObj.hasUnseenIcon = isHelpUnseen ? "yes" : "no"
    }
  }

  function getWarningText(cantJoinReasonData, joinWarningData)
  {
    return !cantJoinReasonData.canJoin ? cantJoinReasonData.reasonText
      : joinWarningData.needShow ? joinWarningData.warningText
      : ""
  }

  function getFullWarningText(cantJoinReasonData, joinWarningData)
  {
    return !cantJoinReasonData.canJoin ? cantJoinReasonData.fullReasonText
      : joinWarningData.needShow ? joinWarningData.fullWarningText
      : ""
  }

  function canPrerareSquadForBattle(cantJoinReasonData)
  {
    return !cantJoinReasonData.canJoin &&
           (cantJoinReasonData.code == WW_BATTLE_CANT_JOIN_REASON.WRONG_SIDE
            || cantJoinReasonData.code == WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
            || cantJoinReasonData.code == WW_BATTLE_CANT_JOIN_REASON.EXCESS_PLAYERS
            || cantJoinReasonData.code == WW_BATTLE_CANT_JOIN_REASON.QUEUE_FULL
            || cantJoinReasonData.code == WW_BATTLE_CANT_JOIN_REASON.TEAM_FULL
            || cantJoinReasonData.code == WW_BATTLE_CANT_JOIN_REASON.NO_AVAILABLE_UNITS)
  }

  function canGatherAllSquadMembersForBattle(cantJoinReasonData)
  {
    return cantJoinReasonData.canJoin
        || cantJoinReasonData.code != WW_BATTLE_CANT_JOIN_REASON.SQUAD_MEMBERS_NO_WW_ACCESS
  }

  function updateBattleStatus(battleView)
  {
    local statusObj = scene.findObject("battle_status_text")
    if (::check_obj(statusObj))
      statusObj.setValue(battleView.getBattleStatusWithCanJoinText())

    local needShowWinChance = battleView.needShowWinChance()
    local winCahnceObj = showSceneBtn("win_chance", needShowWinChance)
    if (needShowWinChance && winCahnceObj)
    {
      local winCahnceTextObj = winCahnceObj.findObject("win_chance_text")
      local percent = battleView.getAutoBattleWinChancePercentText()
      if (::check_obj(winCahnceTextObj) && percent != "")
        winCahnceTextObj.setValue(percent)
      else
        winCahnceObj.show(false)
    }

    local battleTimeObj = scene.findObject("battle_time_text")
    if (::check_obj(battleTimeObj) && battleView.needShowTimer())
    {
      local battleTimeText = ""
      local timeStartAutoBattle = battleView.getTimeStartAutoBattle()
      if (battleView.hasBattleDurationTime())
        battleTimeText = ::loc("debriefing/BattleTime") + ::loc("ui/colon") +
          battleView.getBattleDurationTime()
      else if (battleView.hasBattleActivateLeftTime())
      {
        isSelectedBattleActive = false
        battleTimeText = ::loc("worldWar/can_join_countdown") + ::loc("ui/colon") +
          battleView.getBattleActivateLeftTime()
      } else if (timeStartAutoBattle != "")
      {
        isSelectedBattleActive = false
        battleTimeText = ::loc("worldWar/will_start_auto_battle") + ::loc("ui/colon")
          + timeStartAutoBattle
      }
      battleTimeObj.setValue(battleTimeText)

      if (!isSelectedBattleActive && !battleView.hasBattleActivateLeftTime() && timeStartAutoBattle == "")
      {
        isSelectedBattleActive = true
        updateDescription()
        updateButtons()
        updateNoAvailableBattleInfo()
      }
    }

    local playersInfoText = battleView.hasTeamsInfo()
      ? battleView.getTotalPlayersInfoText()
      : battleView.hasQueueInfo()
        ? battleView.getTotalQueuePlayersInfoText()
        : ""

    local hasInfo = !::u.isEmpty(playersInfoText)
    showSceneBtn("teams_info", hasInfo)
    if (hasInfo)
    {
      local playersTextObj = scene.findObject("number_of_players")
      if (::check_obj(playersTextObj))
        playersTextObj.setValue(playersInfoText)
    }
  }

  function onOpenClusterSelect(obj)
  {
    ::queues.checkAndStart(
      ::Callback(@() clustersModule.createClusterSelectMenu(obj, "bottom"), this),
      null,
      "isCanChangeCluster")
  }

  function onOpenSquadsListModal(obj)
  {
    ::gui_handlers.WwMyClanSquadInviteModal.open(
      ::ww_get_operation_id(), operationBattle.id, ::get_profile_country_sq())
  }

  function onOpenGlobalBattlesModal(obj)
  {
    msgBox("ask_leave_operation", ::loc("worldwar/gotoGlobalBattlesMsgboxText"),
      [
        ["yes", function() { ::g_world_war.openOperationsOrQueues(true) }],
        ["no", @() null]
      ],
      "yes", { cancel_fn = @() null })
  }

  function onEventWWUpdateWWQueues(params)
  {
    reinitBattlesList()
    updateButtons()
  }

  function onEventClusterChange(params)
  {
    updateClusters()
  }

  function updateClusters()
  {
    clustersModule.updateClusters(scene.findObject("cluster_select_button_text"))
  }

  function goBack()
  {
    if (::g_squad_manager.isInSquad() && ::g_squad_manager.getOnlineMembersCount() > 1)
      switch (currViewMode)
      {
        case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
          if (::g_squad_manager.isSquadLeader())
            msgBox("ask_leave_squad", ::loc("squad/ask/cancel_fight"),
              [
                ["yes", ::Callback(function() {
                    ::g_squad_manager.cancelWwBattlePrepare()
                  }, this)],
                ["no", @() null]
              ],
              "no", { cancel_fn = function() {} })
          else
            msgBox("ask_leave_squad", ::loc("squad/ask/leave"),
              [
                ["yes", ::Callback(function() {
                    ::g_squad_manager.leaveSquad()
                    goBack()
                  }, this)
                ],
                ["no", @() null]
              ],
              "no", { cancel_fn = function() {} })
          return
      }

    base.goBack()
  }

  function onShowHelp(obj)
  {
    if (!::check_obj(obj))
      return

    local side = obj?.isPlayerSide == "yes" ?
      getPlayerSide() : ::g_world_war.getOppositeSide(getPlayerSide())

    ::handlersManager.loadHandler(::gui_handlers.WwJoinBattleCondition, {
      battle = operationBattle
      side = side
    })
  }

  function onJoinBattle()
  {
    local side = getPlayerSide()
    local cantJoinReasonData = operationBattle.getCantJoinReasonData(side, false)
    switch (currViewMode)
    {
      case WW_BATTLE_VIEW_MODES.BATTLE_LIST:
        if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
          tryToJoin(side)
        else if (::g_squad_manager.isSquadLeader())
        {
          if (::g_squad_manager.readyCheck(false))
          {
            if (!::has_feature("WorldWarSquadInfo"))
              tryToJoin(side)
            else
            {
              if (!canGatherAllSquadMembersForBattle(cantJoinReasonData))
                ::showInfoMsgBox(cantJoinReasonData.fullReasonText)
              else if (canPrerareSquadForBattle(cantJoinReasonData))
                ::showInfoMsgBox(cantJoinReasonData.reasonText)
              else
                ::g_squad_manager.startWWBattlePrepare(operationBattle.id)
            }
          }
          else
          {
            if (!canGatherAllSquadMembersForBattle(cantJoinReasonData))
              ::showInfoMsgBox(cantJoinReasonData.fullReasonText)
            else
              ::showInfoMsgBox(::loc("squad/not_all_ready"))
          }
        }
        else
          ::g_squad_manager.setReadyFlag()
        break

      case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
        if (::g_squad_manager.isSquadLeader())
          tryToJoin(side)
        else
        {
          if (cantJoinReasonData.canJoin)
            tryToSetCrewsReadyFlag()
          else
            ::showInfoMsgBox(cantJoinReasonData.reasonText)
        }
        break
    }
  }

  function tryToJoin(side)
  {
    queueInfoHandlerWeak.hideQueueInfoObj()
    operationBattle.tryToJoin(side)
  }

  function tryToSetCrewsReadyFlag()
  {
    local warningData = operationBattle.getWarningReasonData(getPlayerSide())
    if (warningData.needMsgBox && !::loadLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false))
    {
      ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox,
        {
          parentHandler = this
          message = ::u.isEmpty(warningData.fullWarningText)
            ? warningData.warningText
            : warningData.fullWarningText
          ableToStartAndSkip = true
          onStartPressed = setCrewsReadyFlag
          skipFunc = @(value) ::saveLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, value)
        })
      return
    }
    setCrewsReadyFlag()
  }

  function setCrewsReadyFlag()
  {
    ::g_squad_manager.setCrewsReadyFlag()
  }

  function onLeaveBattle()
  {
    switch (currViewMode)
    {
      case WW_BATTLE_VIEW_MODES.BATTLE_LIST:
        if (::g_squad_manager.isInSquad() && ::g_squad_manager.isSquadMember())
          ::g_squad_manager.setReadyFlag()
        break

      case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
        if (::g_squad_manager.isInSquad() && ::g_squad_manager.isSquadMember())
          ::g_squad_manager.setCrewsReadyFlag()
        break

      case WW_BATTLE_VIEW_MODES.QUEUE_INFO:
        ::g_world_war.leaveWWBattleQueues()
        ::ww_event("LeaveBattle")
        break
    }
  }

  function onItemSelect()
  {
    updateSelectedItem(false)
  }

  function updateSelectedItem(isForceUpdate = false)
  {
    refreshSelBattle()
    local newOperationBattle = getBattleById(curBattleInList.id)
    local isBattleEqual = operationBattle.isEqual(newOperationBattle)
    operationBattle = newOperationBattle

    if (isBattleEqual)
      return

    updateBattleSquadListData()
    updateWindow()
  }

  function updateBattleSquadListData()
  {
    local country = null
    local remainUnits = null
    if (operationBattle && operationBattle.isValid() && !operationBattle.isFinished())
    {
      local side = getPlayerSide()
      local team = operationBattle.getTeamBySide(side)
      country = team?.country
      remainUnits = operationBattle.getUnitsRequiredForJoin(team, side)
    }
    if (squadListHandlerWeak)
      squadListHandlerWeak.updateBattleData(country, remainUnits)
  }

  function refreshSelBattle()
  {
    local idx = battlesListObj.getValue()
    if (idx < 0 || idx >= battlesListObj.childrenCount())
      return

    local opObj = battlesListObj.getChild(idx)
    if (!::check_obj(opObj))
      return

    curBattleInList = getBattleById(opObj.id)
  }

  function getEmptyBattle()
  {
    return ::WwBattle()
  }

  function syncSquadCountry()
  {
    if (!::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader())
      return
    if (getViewMode() != WW_BATTLE_VIEW_MODES.SQUAD_INFO)
      return

    local squadCountry = ::g_squad_manager.getWwOperationCountry()
    if (!::u.isEmpty(squadCountry) && ::get_profile_country_sq() != squadCountry)
      ::switch_profile_country(squadCountry)
  }

  function onEventSquadDataUpdated(params)
  {
    local wwBattleName = ::g_squad_manager.getWwOperationBattle()
    local squadCountry = ::g_squad_manager.getWwOperationCountry()
    local selectedBattleName = curBattleInList.id
    local prevCurrViewMode = currViewMode
    updateViewMode()

    if (wwBattleName)
    {
      if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
      {
        ::g_squad_manager.cancelWwBattlePrepare()
        return
      }

      local isBattleDifferent = !curBattleInList || curBattleInList.id != wwBattleName
      if (isBattleDifferent)
        curBattleInList = getBattleById(wwBattleName)

      if (!::u.isEmpty(squadCountry) && ::get_profile_country_sq() != squadCountry)
        guiScene.performDelayed(this, function() {
          if (isValid())
            syncSquadCountry()
        })
      else
        if (isBattleDifferent)
          reinitBattlesList(true)
    }

    if (getPlayerSide() == ::SIDE_NONE)
      return

    if (selectedBattleName != curBattleInList.id)
      updateDescription()

    updateButtons()
    updateNoAvailableBattleInfo()

    if (prevCurrViewMode == WW_BATTLE_VIEW_MODES.SQUAD_INFO &&
        prevCurrViewMode != currViewMode &&
        ::g_squad_manager.isSquadMember())
    {
      ::g_squad_manager.setCrewsReadyFlag(false)
      ::showInfoMsgBox(::loc("squad/message/cancel_fight"))
    }
  }

  function onEventCrewTakeUnit(params)
  {
    updateButtons()
  }

  function onEventQueueChangeState(params)
  {
    if (getPlayerSide() == ::SIDE_NONE)
      return

    updateViewMode()
    refreshSelBattle()
    updateButtons()
    updateNoAvailableBattleInfo()
  }

  function onEventSlotbarPresetLoaded(params)
  {
    guiScene.performDelayed(this, function() {
      if (isValid())
        updateButtons()
    })
  }

  function onEventWWLoadOperation(params)
  {
    reinitBattlesList()
  }

  function onUpdate(obj, dt)
  {
    requestQueuesData()
  }

  function requestQueuesData()
  {
    wwQueuesData.requestData()
  }

  function getFirstBattleInListMap()
  {
    if (!curBattleListItems || !curBattleListItems.len())
      return getEmptyBattle()

    foreach(item in curBattleListItems)
    {
      local battle = getBattleById(item.id)
      if (battle.isValid())
        return battle
    }

    return getEmptyBattle()
  }

  function createBattleListMap()
  {
    local battles = ::g_world_war.getBattles(::g_world_war.isBattleAvailableToPlay)
    battles.sort(battlesSort)
    return battles
  }

  function getQueueBattle(queue)
  {
    local battleId = queue.getQueueWwBattleId()
    if (!battleId)
      return null

    return getBattleById(battleId)
  }

  static function getPlayerSide(battle = null)
  {
    return ::ww_get_player_side()
  }

  function hasChangedInBattleListMap(newBattleListMap)
  {
    if (curBattleListMap == null)
      return true

    if (newBattleListMap.len() != curBattleListMap.len())
      return true

    foreach(idx, newbattle in newBattleListMap)
    {
      local curBattle = curBattleListMap[idx]
      if (newbattle.id != curBattle.id || newbattle.status != curBattle.status)
        return true
    }

    return false
  }

  function onShowSlotbarHelp(obj)
  {
    WwHelpSlotbarGroupsModal.open()
  }

  function onRunAutoPreset(obj)
  {
    if (::slotbar_oninit)
      return

    local cb = ::Callback(generateAutoPreset, this)
    ::queues.checkAndStart(
      ::Callback(function() {
        ::g_squad_utils.checkSquadUnreadyAndDo(cb, @() null, true)
      }, this),
      @() null,
      "isCanModifyCrew"
    )
  }

  function generateAutoPreset()
  {
    local side = getPlayerSide()
    local team = operationBattle.getTeamBySide(side)
    if (!team)
      return

    local country = team?.country
    if (country == null)
      return

    if (!::isCountryAllCrewsUnlockedInHangar(country))
    {
      ::showInfoMsgBox(::loc("charServer/updateError/52"), "slotbar_presets_forbidden")
      return
    }

    local teamUnits = operationBattle.getTeamRemainUnits(team, hasSlotbarByUnitsGroups)
    generatePreset(teamUnits, country, hasSlotbarByUnitsGroups)
  }

  function onOpenBattlesFilters(obj)
  {
  }

  function getWndHelpConfig()
  {
    local res = {
      textsBlk = "gui/worldWar/wwBattlesModalHelp.blk"
      objContainer = scene.findObject("root-box")
    }
    local links = [
      { obj = ["items_list"]
        msgId = "hint_items_list"
      },
      { obj = ["queue_info"]
        msgId = "hint_queue_info"
      },
      { obj = ["squad_info"]
        msgId = "hint_squad_info"
      },
      { obj = ["team_header_info_0"]
        msgId = "hint_team_header_info_0"
      },
      { obj = ["battle_info"]
        msgId = "hint_battle_info"
      },
      { obj = ["team_header_info_1"]
        msgId = "hint_team_header_info_1"
      },
      { obj = ["team_unit_info_0"] },
      { obj = ["team_unit_info_1"] },
      { obj = ["cluster_select_button"]
        msgId = "hint_cluster_select_button"
      },
      { obj = ["invite_squads_button"]
        msgId = "hint_invite_squads_button"
      },
      { obj = ["btn_battles_filters"]
        msgId = "hint_btn_battles_filters"
      },
      { obj = ["btn_join_battle"]
        msgId = "hint_btn_join_battle"
      },
      { obj = ["btn_leave_battle"]
        msgId = "hint_btn_leave_battle"
      },
      { obj = ["goto_global_battles_btn"]
        msgId = "hint_goto_global_battles_btn"
      },
      { obj = ["tactical_map_block"]
        msgId = "hint_tactical_map_block"
      }
    ]

    res.links <- links
    return res
  }

  function getCurrentEdiff()
  {
    return ::g_world_war.defaultDiffCode
  }

  function updateBattleInList(idx, curBattle, newBattle)
  {
    if (curBattle == newBattle || (::u.isEqual(curBattle, newBattle)))
      return

    local obj = getBattleObj(idx)
    local show = !!newBattle
    obj.show(show)
    obj.enable(show)
    if (!show)
      return

    local oldId = obj.id
    obj.id = newBattle.id
    local childObj = obj.findObject("mission_item_prefix_text_" + oldId)
    childObj.id = "mission_item_prefix_text_" +  newBattle.id
    childObj.setValue(newBattle.itemPrefixText)
    childObj = obj.findObject("txt_" + oldId)
    childObj.id = "txt_" +  newBattle.id
    childObj.setValue(newBattle.itemText)

    local medalObj = obj.findObject("medal_icon")
    medalObj["background-image"] = newBattle.itemIcon
    medalObj["status"] = newBattle.status
    local descriptionObj = obj.findObject("additional_desc")
    guiScene.replaceContentFromText(descriptionObj, newBattle.additionalDescription,
      newBattle.additionalDescription.len(), this)
  }

  function getBattleObj(idx)
  {
    if (battlesListObj.childrenCount() > idx)
      return battlesListObj.getChild(idx)

    return battlesListObj.getChild(idx-1).getClone(battlesListObj, this)
  }

  onEventPresetsByGroupsChanged = @(params) updateButtons()

  function getSlotbarActions()
  {
    if (hasSlotbarByUnitsGroups)
      return [ "autorefill", "aircraft", "changeUnitsGroup", "weapons", "crew", "info", "repair" ]
    else
      return [ "autorefill", "aircraft", "weapons", "crew", "info", "repair" ]
  }
}
