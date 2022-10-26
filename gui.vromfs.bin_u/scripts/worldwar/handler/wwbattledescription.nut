from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let wwQueuesData = require("%scripts/worldWar/operations/model/wwQueuesData.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let slotbarWidget = require("%scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let { setCurPreset } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let wwHelpSlotbarGroupsModal = require("%scripts/worldWar/handler/wwHelpSlotbarGroupsModal.nut")
let { getBestPresetData, generatePreset } = require("%scripts/slotbar/generatePreset.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById, getMapByName
} = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let getLockedCountryData = require("%scripts/worldWar/inOperation/wwGetSlotbarLockedCountryFunc.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")

// Temporary image. Has to be changed after receiving correct art
const WW_OPERATION_DEFAULT_BG_IMAGE = "#ui/bkg/login_layer_h1_0.jpg?P1"

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

::gui_handlers.WwBattleDescription <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/worldWar/battleDescriptionWindow.tpl"
  sceneTplBattleList = "%gui/missions/missionBoxItemsList.tpl"
  sceneTplDescriptionName = "%gui/worldWar/battleDescriptionWindowContent.tpl"
  sceneTplTeamRight = "%gui/worldWar/wwBattleDescriptionTeamUnitsInfo.tpl"
  sceneTplTeamHeaderInfo = "%gui/worldWar/wwBattleDescriptionTeamInfo.tpl"

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
        ::g_popups.add("", loc("worldwar/battle_finished"),
          null, null, null, "battle_finished")
      }
      else if (battle.isAutoBattle())
      {
        battle = ::WwBattle()
        ::g_popups.add("", loc("worldwar/battleIsInAutoMode"),
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
    return this.scene.findObject("root-box")
  }

  getSceneTplView = @() {}

  function initScreen()
  {
    this.battlesListObj = this.scene.findObject("items_list")
    let battleListData = ::handyman.renderCached(this.sceneTplBattleList,
      { items = array(this.minCountBattlesInList, DEFAULT_BATTLE_ITEM_CONGIG)})
    this.guiScene.appendWithBlk(this.battlesListObj, battleListData, this)
    this.curBattleListMap = []
    this.initQueueInfo()
    this.updateForceSelectedBattle()

    this.syncSquadCountry()
    this.updateViewMode()
    this.updateDescription()
    this.updateSlotbar()
    this.reinitBattlesList()
    this.initSquadList()

    let timerObj = this.scene.findObject("update_timer")
    if (checkObj(timerObj))
      timerObj.setUserData(this)

    this.requestQueuesData()
  }

  function initQueueInfo()
  {
    let queueInfoObj = this.scene.findObject("queue_info")
    if (!checkObj(queueInfoObj))
      return

    let handler = ::handlersManager.loadHandler(::gui_handlers.WwQueueInfo,
      { scene = queueInfoObj })
    this.registerSubHandler(handler)
    this.queueInfoHandlerWeak = handler.weakref()
  }

  function updateForceSelectedBattle()
  {
    let queue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
    if (queue)
    {
      let battleWithQueue = this.getQueueBattle(queue)
      if (battleWithQueue && battleWithQueue.isValid() && this.curBattleInList.id != battleWithQueue.id)
        this.curBattleInList = this.getBattleById(battleWithQueue.id)
    }
    else
    {
      let wwBattleName = ::g_squad_manager.getWwOperationBattle()
      if (wwBattleName && this.curBattleInList.id != wwBattleName)
        this.curBattleInList = this.getBattleById(wwBattleName)
    }

    if (!this.curBattleInList.isValid())
      this.curBattleInList = this.getFirstBattleInListMap()
  }

  function initSquadList()
  {
    let squadInfoObj = this.scene.findObject("squad_info")
    if (!checkObj(squadInfoObj))
      return

    let handler = ::handlersManager.loadHandler(::gui_handlers.WwSquadList,
      { scene = squadInfoObj })
    this.registerSubHandler(handler)
    this.squadListHandlerWeak = handler.weakref()
    this.updateBattleSquadListData()
  }

  function reinitBattlesList(isForceUpdate = false)
  {
    if (!wwQueuesData.isDataValid())
      this.requestQueuesData()

    let currentBattleListMap = this.createBattleListMap()
    let needRefillBattleList = isForceUpdate || this.hasChangedInBattleListMap(currentBattleListMap)

    this.curBattleListMap = currentBattleListMap

    if (needRefillBattleList)
    {
      let view = this.getBattleListView()
      this.fillBattleList(view)
      this.curBattleListItems = clone view.items
      this.selectItemInList()
    }

    this.updateSelectedItem(isForceUpdate)

    this.validateSquadInfo()
    this.validateCurQueue()

    if (this.getViewMode() == WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      this.showSceneBtn("items_list", this.curBattleListMap.len() > 0)
  }

  function validateCurQueue()
  {
    let queue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
    if (!queue)
      return

    let queueBattle = this.getQueueBattle(queue)
    if (!queueBattle || !queueBattle.isValid())
      ::g_world_war.leaveWWBattleQueues()
  }

  function validateSquadInfo()
  {
    let wwBattleName = ::g_squad_manager.getWwOperationBattle()
    if (wwBattleName && (wwBattleName != this.operationBattle.id || !this.operationBattle.isValid()))
      ::g_squad_manager.cancelWwBattlePrepare()
  }

  function getBattleById(battleId, _searchInCurList = true)
  {
    return ::g_world_war.getBattleById(battleId)
  }

  function isBattleValid(battleId)
  {
    return this.getBattleById(battleId).isValid()
  }

  function updateWindow()
  {
    this.updateViewMode()
    this.updateDescription()
    this.updateSlotbar()
    this.updateButtons()
    this.updateDurationTimer()
  }

  function updateTitle()
  {
    let titleTextObj = this.scene.findObject("battle_description_frame_text")
    if (!checkObj(titleTextObj))
      return

    titleTextObj.setValue(this.currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST ?
      this.getTitleText() : loc("worldwar/prepare_battle"))
  }

  function getTitleText()
  {
    return loc("userlog/page/battle")
  }

  function updateDurationTimer()
  {
    if (this.battleDurationTimer && this.battleDurationTimer.isValid())
      this.battleDurationTimer.destroy()

    this.battleDurationTimer = ::Timer(this.scene, 1,
      @() this.updateBattleStatus(this.operationBattle.getView(this.getPlayerSide())), this, true)
  }

  function isBattleAvailableToMatching(battle, country)
  {
    if (battle.getBattleActivateLeftTime() > 0)
      return false

    if(!battle.hasAvailableUnits())
      return false

    let side = this.getPlayerSide(battle)
    let team = battle.getTeamBySide(side)
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
    let wwBattlesView = ::u.map(this.curBattleListMap,
      function(battle) {
        return this.createBattleListItemView(battle)
      }.bindenv(this))

    return { items = wwBattlesView }
  }

  function selectItemInList()
  {
    if (!this.curBattleListItems.len())
    {
      this.curBattleInList = this.getEmptyBattle()
      return
    }

    if (!this.curBattleInList.isValid())
      this.updateForceSelectedBattle()

    let itemId = this.curBattleInList.isValid() ? this.curBattleInList.id
      : ""

    let idx = itemId.len() ? (this.curBattleListItems.findindex(@(item) item.id == itemId) ?? -1) : -1
    if (idx >= 0 && this.battlesListObj.getValue() != idx)
      this.battlesListObj.setValue(idx)
  }

  function fillBattleList(view)
  {
    this.guiScene.setUpdatesEnabled(false, false)
    let newList = view.items
    let total = max(newList.len(), this.curBattleListItems?.len?() ?? 0)
    for(local i = 0; i < total; i++)
      this.updateBattleInList(i, this.curBattleListItems?[i], newList?[i])

    this.showSceneBtn("no_active_battles_text", this.curBattleListMap.len() == 0)

    this.guiScene.setUpdatesEnabled(true, true)
    if (!this.needUpdatePrefixWidth || view.items.len() <= 0)
      return

    local maxSectorNameWidth = 0
    let sectorNameTextObjs = []
    foreach(item in view.items)
    {
      let sectorNameTxtObj = this.scene.findObject("mission_item_prefix_text_" + item.id)
      if (checkObj(sectorNameTxtObj))
      {
        sectorNameTextObjs.append(sectorNameTxtObj)
        maxSectorNameWidth = max(maxSectorNameWidth, sectorNameTxtObj.getSize()[0])
      }
    }

    let sectorWidth = maxSectorNameWidth
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
    let playerSide = this.getPlayerSide(battleData)
    let battleView = battleData.getView(playerSide)
    let view = {
      id = battleData.id.tostring()
      itemPrefixText = this.getSelectedBattlePrefixText(battleData)
      itemText = ""
      itemIcon = battleView.getIconImage()
      status = battleView.getStatus()
      additionalDescription = ""
    }

    if (battleData.isActive() || battleData.isFinished())
      view.itemText <- battleData.getLocName(playerSide)
    else
    {
      let battleSides = ::g_world_war.getSidesOrder()
      let teamsData = battleView.getTeamBlockByIconSize(
        battleSides, WW_ARMY_GROUP_ICON_SIZE.SMALL, false,
        {hasArmyInfo = false, hasVersusText = true, canAlignRight = false})
      local teamsMarkUp = ""
      foreach(_idx, army in teamsData)
        teamsMarkUp += army.armies.armyViews

      view.additionalDescription <- teamsMarkUp
    }

    return view
  }

  function getSelectedBattlePrefixText(battleData)
  {
    let battleView = battleData.getView()
    let battleName = colorize("newTextColor", battleView.getShortBattleName())
    let sectorName = battleData.getSectorName()
    return battleName + (!::u.isEmpty(sectorName) ? " " + sectorName : "")
  }

  function updateSlotbar()
  {
    let side = this.getPlayerSide()
    let availableCountries = getOperationById(::ww_get_operation_id())?.getCountriesByTeams()[side]
    let isSlotbarVisible = (availableCountries?.len() ?? 0) > 0
    this.showSceneBtn("nav-slotbar", isSlotbarVisible)
    if (!isSlotbarVisible)
      return

    let playerCountry = profileCountrySq.value
    let assignCountry = isInArray(playerCountry, availableCountries) ? playerCountry : availableCountries[0]
    let playerTeam = this.operationBattle.getTeamBySide(side)
    switchProfileCountry(assignCountry)
    let map = this.getMap()
    let unitsGroupsByCountry = map?.getUnitsGroupsByCountry()
    this.hasSlotbarByUnitsGroups = unitsGroupsByCountry != null
    let operationUnits = ::g_world_war.getAllOperationUnitsBySide(side)
    let availableUnits = playerTeam != null ? this.operationBattle.getTeamRemainUnits(playerTeam)
      : this.hasSlotbarByUnitsGroups ? ::all_units : operationUnits
    if (this.hasSlotbarByUnitsGroups)
      setCurPreset(map.getId() ,unitsGroupsByCountry)

    this.createSlotbar(
      {
        singleCountry = assignCountry
        customViewCountryData = {[assignCountry]  = getCustomViewCountryData(assignCountry, map.getId(), true)}
        availableUnits = availableUnits
        customUnitsList = this.hasSlotbarByUnitsGroups ? null : operationUnits
      }.__update(this.getSlotbarParams()),
      "nav-slotbar"
    )
  }

  function getSlotbarParams() {
    return {
      gameModeName = this.getGameModeNameText()
      showEmptySlot = true
      needPresetsPanel = !this.hasSlotbarByUnitsGroups
      shouldCheckCrewsReady = true
      hasExtraInfoBlock = true
      showNewSlot = true
      customUnitsListName = this.getCustomUnitsListNameText()
      shouldAppendToObject = false
      getLockedCountryData
    }
  }

  createSlotbarHandler = @(params) this.hasSlotbarByUnitsGroups
    ? slotbarWidget.create(params)
    : ::gui_handlers.SlotbarWidget.create(params)

  function getGameModeNameText()
  {
    return this.operationBattle.getView(this.getPlayerSide()).getFullBattleName()
  }

  function getMap()
  {
    let operation = getOperationById(::ww_get_operation_id())
    if (operation == null)
      return null

    let map = operation.getMap()
    if (map == null)
      return null

    return map
  }

  function getCustomUnitsListNameText()
  {
    let operation = getOperationById(::ww_get_operation_id())
    if (operation)
      return operation.getMapText()

    return ""
  }

  function updateDescription()
  {
    let descrObj = this.scene.findObject("item_desc")
    if (!checkObj(descrObj))
      return

    let isOperationBattleLoaded = this.curBattleInList.id == this.operationBattle.id
    let battle = isOperationBattleLoaded ? this.operationBattle : this.curBattleInList
    let battleView = battle.getView(this.getPlayerSide())
    let blk = ::handyman.renderCached(this.sceneTplDescriptionName, battleView)

    this.guiScene.replaceContentFromText(descrObj, blk, blk.len(), this)

    this.fillOperationBackground()
    this.fillOperationInfoText()

    this.showSceneBtn("operation_loading_wait_anim", battle.isValid() && !isOperationBattleLoaded && !battle.isFinished())

    if (!battle.isValid() || !isOperationBattleLoaded || battle.isFinished())
    {
      this.showSceneBtn("battle_info", battle.isFinished())
      this.showSceneBtn("teams_block", false)
      this.showSceneBtn("tactical_map_block", false)
      if (battle.isFinished())
        this.updateBattleStatus(battleView)
      return
    }

    let battleSides = ::g_world_war.getSidesOrder()
    let teamsData = battleView.getTeamsDataBySides(battleSides)
    foreach(idx, teamData in teamsData)
    {
      let teamObjHeaderInfo = this.scene.findObject($"team_header_info_{idx}")
      if (checkObj(teamObjHeaderInfo))
      {
        let teamHeaderInfoBlk = ::handyman.renderCached(this.sceneTplTeamHeaderInfo, teamData)
        this.guiScene.replaceContentFromText(teamObjHeaderInfo, teamHeaderInfoBlk, teamHeaderInfoBlk.len(), this)
      }

      let teamObjPlace = this.scene.findObject($"team_unit_info_{idx}")
      if (checkObj(teamObjPlace))
      {
        let teamBlk = ::handyman.renderCached(this.sceneTplTeamRight, teamData)
        this.guiScene.replaceContentFromText(teamObjPlace, teamBlk, teamBlk.len(), this)
      }
    }

    this.loadMap(battleSides[0])
    this.updateBattleStatus(battleView)
  }

  function fillOperationBackground()
  {
    let battleBgObj = this.scene.findObject("battle_background")
    if (!checkObj(battleBgObj))
      return

    battleBgObj["background-image"] = this.getOperationBackground()
  }

  function getOperationBackground()
  {
    let curOperation = getOperationById(::ww_get_operation_id())
    if (!curOperation)
      return WW_OPERATION_DEFAULT_BG_IMAGE

    let curMap = getMapByName(curOperation.getMapId())
    if (!curMap)
      return WW_OPERATION_DEFAULT_BG_IMAGE

    return curMap.getBackground()
  }

  function fillOperationInfoText()
  {
  }

  function loadMap(playerSide)
  {
    let tacticalMapObj = this.scene.findObject("tactical_map_single")
    if (!checkObj(tacticalMapObj))
      return

    local misFileBlk = null
    let misData = this.operationBattle.missionInfo
    if (misData != null)
    {
      let missionBlk = ::DataBlock()
      missionBlk.setFrom(misData)

      misFileBlk = ::DataBlock()
      misFileBlk.load(missionBlk.getStr("mis_file",""))
    }
    else
      log("Error: WWar: Battle with id=" + this.operationBattle.id + ": not found mission info for mission " + this.operationBattle.missionName)

    ::g_map_preview.setMapPreview(tacticalMapObj, misFileBlk)
    let playerTeam = this.operationBattle.getTeamBySide(playerSide)
    if (playerTeam && "name" in playerTeam)
      ::tactical_map_set_team_for_briefing(::get_mp_team_by_team_name(playerTeam.name))
  }

  function updateViewMode()
  {
    let newViewMode = this.getViewMode()
    if (newViewMode == this.currViewMode)
      return

    this.currViewMode = newViewMode

    let isViewBattleList = this.currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST
    let isViewSquadInfo = this.currViewMode == WW_BATTLE_VIEW_MODES.SQUAD_INFO
    this.showSceneBtn("queue_info", this.currViewMode == WW_BATTLE_VIEW_MODES.QUEUE_INFO)
    this.showSceneBtn("items_list", isViewBattleList)
    this.showSceneBtn("squad_info", isViewSquadInfo)
    if (this.squadListHandlerWeak)
      this.squadListHandlerWeak.updateButtons(isViewSquadInfo)
    if (isViewBattleList)
      ::move_mouse_on_child_by_value(this.battlesListObj)

    this.updateTitle()
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
    let isViewBattleList = this.currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST
    this.showSceneBtn("btn_battles_filters", this.hasBattleFilter && isViewBattleList)
    this.showSceneBtn("invite_squads_button",
      this.hasSquadsInviteButton && ::g_world_war.isSquadsInviteEnable())

    if (!this.curBattleInList.isValid())
    {
      this.showSceneBtn("cant_join_reason_txt", false)
      this.showSceneBtn("btn_join_battle", false)
      this.showSceneBtn("btn_leave_battle", false)
      this.showSceneBtn("btn_auto_preset", false)
      this.showSceneBtn("btn_slotbar_help", false)
      this.showSceneBtn("warning_icon", false)
      return
    }

    local isJoinBattleVisible = this.currViewMode != WW_BATTLE_VIEW_MODES.QUEUE_INFO
    local isLeaveBattleVisible = this.currViewMode == WW_BATTLE_VIEW_MODES.QUEUE_INFO
    local isJoinBattleActive = true
    local isLeaveBattleActive = true
    local battleText = isJoinBattleVisible
      ? loc("mainmenu/toBattle")
      : loc("mainmenu/btnCancel")

    let cantJoinReasonData = this.operationBattle.getCantJoinReasonData(this.getPlayerSide(),
      ::g_squad_manager.isInSquad() && ::g_squad_manager.isSquadLeader())
    let joinWarningData = this.operationBattle.getWarningReasonData(this.getPlayerSide())
    local warningText = ""
    local fullWarningText = ""

    if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
    {
      isJoinBattleActive = isJoinBattleVisible && cantJoinReasonData.canJoin
      warningText = this.currViewMode != WW_BATTLE_VIEW_MODES.QUEUE_INFO
        ? this.getWarningText(cantJoinReasonData, joinWarningData)
        : joinWarningData.warningText
      fullWarningText = this.currViewMode != WW_BATTLE_VIEW_MODES.QUEUE_INFO
        ? this.getFullWarningText(cantJoinReasonData, joinWarningData)
        : joinWarningData.fullWarningText
    }
    else
      switch (this.currViewMode)
      {
        case WW_BATTLE_VIEW_MODES.BATTLE_LIST:
          if (!this.canGatherAllSquadMembersForBattle(cantJoinReasonData))
          {
            isJoinBattleActive = false
            warningText = cantJoinReasonData.reasonText
          }
          else if (this.canPrerareSquadForBattle(cantJoinReasonData))
          {
            isJoinBattleActive = false
            warningText = cantJoinReasonData.reasonText
          }
          else if (!::g_squad_manager.readyCheck(false))
          {
            isJoinBattleActive = false
            warningText = loc("squad/not_all_in_operation")
          }

          break

        case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
          if (::g_squad_manager.isSquadMember())
          {
            isJoinBattleVisible = !::g_squad_manager.isMyCrewsReady
            isLeaveBattleVisible = ::g_squad_manager.isMyCrewsReady
            battleText = ::g_squad_manager.isMyCrewsReady
              ? loc("multiplayer/state/player_not_ready")
              : loc("multiplayer/state/crews_ready")
          }
          isJoinBattleActive = cantJoinReasonData.canJoin
          warningText = this.getWarningText(cantJoinReasonData, joinWarningData)
          fullWarningText = this.getFullWarningText(cantJoinReasonData, joinWarningData)
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
      this.scene.findObject("btn_join_battle_text").setValue(battleText)
    if (isLeaveBattleVisible)
      this.scene.findObject("btn_leave_event_text").setValue(battleText)

    let joinButtonObj = this.showSceneBtn("btn_join_battle", isJoinBattleVisible)
    joinButtonObj.inactiveColor = isJoinBattleActive ? "no" : "yes"
    let leaveButtonObj = this.showSceneBtn("btn_leave_battle", isLeaveBattleVisible)
    leaveButtonObj.enable(isLeaveBattleActive)

    let warningTextObj = this.showSceneBtn("cant_join_reason_txt", !::u.isEmpty(warningText))
    warningTextObj.setValue(warningText)

    let warningIconObj = this.showSceneBtn("warning_icon", !::u.isEmpty(fullWarningText))
    warningIconObj.tooltip = fullWarningText

    let unitAvailability = ::g_world_war.getSetting("checkUnitAvailability",
      WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)
    this.showSceneBtn("required_crafts_block",
      unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.OPERATION_UNITS ||
      unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)

    let isVisibleBtnAutoPreset = joinWarningData.needMsgBox || this.hasSlotbarByUnitsGroups
    let btnAutoPreset = this.showSceneBtn("btn_auto_preset", isVisibleBtnAutoPreset)
    if (isVisibleBtnAutoPreset) {
      let bestPresetData = getBestPresetData(joinWarningData.availableUnits,
        joinWarningData.country, this.hasSlotbarByUnitsGroups)
      let hasChangeInPreset = bestPresetData?.hasChangeInPreset ?? false
      btnAutoPreset.inactiveColor = hasChangeInPreset ? "no" : "yes"
      btnAutoPreset.hasUnseenIcon = hasChangeInPreset ? "yes" : "no"
      ::showBtn("auto_preset_warning_icon", hasChangeInPreset, btnAutoPreset)
    }

    let btnSlotbarHelpObj = this.showSceneBtn("btn_slotbar_help", this.hasSlotbarByUnitsGroups)
    if (this.hasSlotbarByUnitsGroups)
    {
      let isHelpUnseen = wwHelpSlotbarGroupsModal.isUnseen()
      this.showSceneBtn("btn_slotbar_help_unseen_icon", isHelpUnseen)
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
    let statusObj = this.scene.findObject("battle_status_text")
    if (checkObj(statusObj))
      statusObj.setValue(battleView.getBattleStatusWithCanJoinText())

    let needShowWinChance = battleView.needShowWinChance()
    let winCahnceObj = this.showSceneBtn("win_chance", needShowWinChance)
    if (needShowWinChance && winCahnceObj)
    {
      let winCahnceTextObj = winCahnceObj.findObject("win_chance_text")
      let percent = battleView.getAutoBattleWinChancePercentText()
      if (checkObj(winCahnceTextObj) && percent != "")
        winCahnceTextObj.setValue(percent)
      else
        winCahnceObj.show(false)
    }

    let battleTimeObj = this.scene.findObject("battle_time_text")
    if (checkObj(battleTimeObj) && battleView.needShowTimer())
    {
      local battleTimeText = ""
      let timeStartAutoBattle = battleView.getTimeStartAutoBattle()
      if (battleView.hasBattleDurationTime())
        battleTimeText = loc("debriefing/BattleTime") + loc("ui/colon") +
          battleView.getBattleDurationTime()
      else if (battleView.hasBattleActivateLeftTime())
      {
        this.isSelectedBattleActive = false
        battleTimeText = loc("worldWar/can_join_countdown") + loc("ui/colon") +
          battleView.getBattleActivateLeftTime()
      } else if (timeStartAutoBattle != "")
      {
        this.isSelectedBattleActive = false
        battleTimeText = loc("worldWar/will_start_auto_battle") + loc("ui/colon")
          + timeStartAutoBattle
      }
      battleTimeObj.setValue(battleTimeText)

      if (!this.isSelectedBattleActive && !battleView.hasBattleActivateLeftTime() && timeStartAutoBattle == "")
      {
        this.isSelectedBattleActive = true
        this.updateDescription()
        this.updateButtons()
      }
    }

    let playersInfoText = battleView.hasTeamsInfo()
      ? battleView.getTotalPlayersInfoText()
      : battleView.hasQueueInfo()
        ? battleView.getTotalQueuePlayersInfoText()
        : ""

    let hasInfo = !::u.isEmpty(playersInfoText)
    this.showSceneBtn("teams_info", hasInfo)
    if (hasInfo)
    {
      let playersTextObj = this.scene.findObject("number_of_players")
      if (checkObj(playersTextObj))
        playersTextObj.setValue(playersInfoText)
    }
  }

  function onOpenSquadsListModal(_obj)
  {
    ::gui_handlers.WwMyClanSquadInviteModal.open(
      ::ww_get_operation_id(), this.operationBattle.id, profileCountrySq.value)
  }

  function onEventWWUpdateWWQueues(_params)
  {
    this.reinitBattlesList()
    this.updateButtons()
  }

  function goBack()
  {
    if (::g_squad_manager.isInSquad() && ::g_squad_manager.getOnlineMembersCount() > 1)
      switch (this.currViewMode)
      {
        case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
          if (::g_squad_manager.isSquadLeader())
            this.msgBox("ask_leave_squad", loc("squad/ask/cancel_fight"),
              [
                ["yes", Callback(function() {
                    ::g_squad_manager.cancelWwBattlePrepare()
                  }, this)],
                ["no", @() null]
              ],
              "no", { cancel_fn = function() {} })
          else
            this.msgBox("ask_leave_squad", loc("squad/ask/leave"),
              [
                ["yes", Callback(function() {
                    ::g_squad_manager.leaveSquad()
                    this.goBack()
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
    if (!checkObj(obj))
      return

    let side = obj?.isPlayerSide == "yes" ?
      this.getPlayerSide() : ::g_world_war.getOppositeSide(this.getPlayerSide())

    ::handlersManager.loadHandler(::gui_handlers.WwJoinBattleCondition, {
      battle = this.operationBattle
      side = side
    })
  }

  function onJoinBattle()
  {
    let side = this.getPlayerSide()
    let cantJoinReasonData = this.operationBattle.getCantJoinReasonData(side, false)
    switch (this.currViewMode)
    {
      case WW_BATTLE_VIEW_MODES.BATTLE_LIST:
        if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
          this.tryToJoin(side)
        else if (::g_squad_manager.isSquadLeader())
        {
          if (::g_squad_manager.readyCheck(false))
          {
            if (!hasFeature("WorldWarSquadInfo"))
              this.tryToJoin(side)
            else
            {
              if (!this.canGatherAllSquadMembersForBattle(cantJoinReasonData))
                ::showInfoMsgBox(cantJoinReasonData.fullReasonText)
              else if (this.canPrerareSquadForBattle(cantJoinReasonData))
                ::showInfoMsgBox(cantJoinReasonData.reasonText)
              else
                ::g_squad_manager.startWWBattlePrepare(this.operationBattle.id)
            }
          }
          else
          {
            if (!this.canGatherAllSquadMembersForBattle(cantJoinReasonData))
              ::showInfoMsgBox(cantJoinReasonData.fullReasonText)
            else
              ::showInfoMsgBox(loc("squad/not_all_in_operation"))
          }
        }
        else
          ::g_squad_manager.setReadyFlag()
        break

      case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
        if (::g_squad_manager.isSquadLeader())
          this.tryToJoin(side)
        else
        {
          if (cantJoinReasonData.canJoin)
            this.tryToSetCrewsReadyFlag()
          else
            ::showInfoMsgBox(cantJoinReasonData.reasonText)
        }
        break
    }
  }

  function tryToJoin(side)
  {
    this.queueInfoHandlerWeak.hideQueueInfoObj()
    this.operationBattle.tryToJoin(side)
  }

  function tryToSetCrewsReadyFlag()
  {
    let warningData = this.operationBattle.getWarningReasonData(this.getPlayerSide())
    if (warningData.needMsgBox && !::loadLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false))
    {
      ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox,
        {
          parentHandler = this
          message = ::u.isEmpty(warningData.fullWarningText)
            ? warningData.warningText
            : warningData.fullWarningText
          ableToStartAndSkip = true
          onStartPressed = this.setCrewsReadyFlag
          skipFunc = @(value) ::saveLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, value)
        })
      return
    }
    this.setCrewsReadyFlag()
  }

  function setCrewsReadyFlag()
  {
    ::g_squad_manager.setCrewsReadyFlag()
  }

  function onLeaveBattle()
  {
    switch (this.currViewMode)
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
    this.updateSelectedItem(false)
  }

  function updateSelectedItem(_isForceUpdate = false)
  {
    this.refreshSelBattle()
    let newOperationBattle = this.getBattleById(this.curBattleInList.id)
    let isBattleEqual = this.operationBattle.isEqual(newOperationBattle)
    this.operationBattle = newOperationBattle

    if (isBattleEqual)
      return

    this.updateBattleSquadListData()
    this.updateWindow()
  }

  function updateBattleSquadListData()
  {
    local country = null
    local remainUnits = null
    if (this.operationBattle && this.operationBattle.isValid() && !this.operationBattle.isFinished())
    {
      let side = this.getPlayerSide()
      let team = this.operationBattle.getTeamBySide(side)
      country = team?.country
      remainUnits = this.operationBattle.getUnitsRequiredForJoin(team, side)
    }
    if (this.squadListHandlerWeak)
      this.squadListHandlerWeak.updateBattleData(country, remainUnits)
  }

  function refreshSelBattle()
  {
    let idx = this.battlesListObj.getValue()
    if (idx < 0 || idx >= this.battlesListObj.childrenCount())
      return

    let opObj = this.battlesListObj.getChild(idx)
    if (!checkObj(opObj))
      return

    this.curBattleInList = this.getBattleById(opObj.id)
  }

  function getEmptyBattle()
  {
    return ::WwBattle()
  }

  function syncSquadCountry()
  {
    if (!::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader())
      return
    if (this.getViewMode() != WW_BATTLE_VIEW_MODES.SQUAD_INFO)
      return

    let squadCountry = ::g_squad_manager.getWwOperationCountry()
    if (!::u.isEmpty(squadCountry) && profileCountrySq.value != squadCountry)
      switchProfileCountry(squadCountry)
  }

  function onEventSquadDataUpdated(_params)
  {
    let wwBattleName = ::g_squad_manager.getWwOperationBattle()
    let squadCountry = ::g_squad_manager.getWwOperationCountry()
    let selectedBattleName = this.curBattleInList.id
    let prevCurrViewMode = this.currViewMode
    this.updateViewMode()

    if (wwBattleName)
    {
      if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
      {
        ::g_squad_manager.cancelWwBattlePrepare()
        return
      }

      let isBattleDifferent = !this.curBattleInList || this.curBattleInList.id != wwBattleName
      if (isBattleDifferent)
        this.curBattleInList = this.getBattleById(wwBattleName)

      if (!::u.isEmpty(squadCountry) && profileCountrySq.value != squadCountry)
        this.guiScene.performDelayed(this, function() {
          if (this.isValid())
            this.syncSquadCountry()
        })
      else
        if (isBattleDifferent)
          this.reinitBattlesList(true)
    }

    if (this.getPlayerSide() == SIDE_NONE)
      return

    if (selectedBattleName != this.curBattleInList.id)
      this.updateDescription()

    this.updateButtons()

    if (prevCurrViewMode == WW_BATTLE_VIEW_MODES.SQUAD_INFO &&
        prevCurrViewMode != this.currViewMode &&
        ::g_squad_manager.isSquadMember())
    {
      ::g_squad_manager.setCrewsReadyFlag(false)
      ::showInfoMsgBox(loc("squad/message/cancel_fight"))
    }
  }

  function onEventCrewTakeUnit(_params)
  {
    this.updateButtons()
  }

  function onEventQueueChangeState(_params)
  {
    if (this.getPlayerSide() == SIDE_NONE)
      return

    this.updateViewMode()
    this.refreshSelBattle()
    this.updateButtons()
  }

  function onEventSlotbarPresetLoaded(_params)
  {
    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.updateButtons()
    })
  }

  function onEventWWLoadOperation(_params)
  {
    this.reinitBattlesList()
  }

  function onUpdate(_obj, _dt)
  {
    this.requestQueuesData()
  }

  function requestQueuesData()
  {
    wwQueuesData.requestData()
  }

  function getFirstBattleInListMap()
  {
    if (!this.curBattleListItems || !this.curBattleListItems.len())
      return this.getEmptyBattle()

    foreach(item in this.curBattleListItems)
    {
      let battle = this.getBattleById(item.id)
      if (battle.isValid())
        return battle
    }

    return this.getEmptyBattle()
  }

  function createBattleListMap()
  {
    let battles = ::g_world_war.getBattles(::g_world_war.isBattleAvailableToPlay)
    battles.sort(this.battlesSort)
    return battles
  }

  function getQueueBattle(queue)
  {
    let battleId = queue.getQueueWwBattleId()
    if (!battleId)
      return null

    return this.getBattleById(battleId)
  }

  static function getPlayerSide(_battle = null)
  {
    return ::ww_get_player_side()
  }

  function hasChangedInBattleListMap(newBattleListMap)
  {
    if (this.curBattleListMap == null)
      return true

    if (newBattleListMap.len() != this.curBattleListMap.len())
      return true

    foreach(idx, newbattle in newBattleListMap)
    {
      let curBattle = this.curBattleListMap[idx]
      if (newbattle.id != curBattle.id || newbattle.status != curBattle.status)
        return true
    }

    return false
  }

  function onShowSlotbarHelp(_obj)
  {
    wwHelpSlotbarGroupsModal.open()
  }

  function onRunAutoPreset(_obj)
  {
    if (this.slotbarWeak?.slotbarOninit ?? false)
      return

    let cb = Callback(this.generateAutoPreset, this)
    ::queues.checkAndStart(
      Callback(function() {
        ::g_squad_utils.checkSquadUnreadyAndDo(cb, @() null, true)
      }, this),
      @() null,
      "isCanModifyCrew"
    )
  }

  function generateAutoPreset()
  {
    let side = this.getPlayerSide()
    let team = this.operationBattle.getTeamBySide(side)
    if (!team)
      return

    let country = team?.country
    if (country == null)
      return

    if (!::isCountryAllCrewsUnlockedInHangar(country))
    {
      ::showInfoMsgBox(loc("charServer/updateError/52"), "slotbar_presets_forbidden")
      return
    }

    let teamUnits = this.operationBattle.getTeamRemainUnits(team, this.hasSlotbarByUnitsGroups)
    generatePreset(teamUnits, country, this.hasSlotbarByUnitsGroups)
  }

  function onOpenBattlesFilters(_obj)
  {
  }

  function getWndHelpConfig()
  {
    let res = {
      textsBlk = "%gui/worldWar/wwBattlesModalHelp.blk"
      objContainer = this.scene.findObject("root-box")
    }
    let links = [
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

    let obj = this.getBattleObj(idx)
    let show = !!newBattle
    obj.show(show)
    obj.enable(show)
    if (!show)
      return

    let oldId = obj.id
    obj.id = newBattle.id
    local childObj = obj.findObject("mission_item_prefix_text_" + oldId)
    childObj.id = "mission_item_prefix_text_" +  newBattle.id
    childObj.setValue(newBattle.itemPrefixText)
    childObj = obj.findObject("txt_" + oldId)
    childObj.id = "txt_" +  newBattle.id
    childObj.setValue(newBattle.itemText)

    let medalObj = obj.findObject("medal_icon")
    medalObj["background-image"] = newBattle.itemIcon
    medalObj["status"] = newBattle.status
    let descriptionObj = obj.findObject("additional_desc")
    this.guiScene.replaceContentFromText(descriptionObj, newBattle.additionalDescription,
      newBattle.additionalDescription.len(), this)
  }

  function getBattleObj(idx)
  {
    if (this.battlesListObj.childrenCount() > idx)
      return this.battlesListObj.getChild(idx)

    return this.battlesListObj.getChild(idx-1).getClone(this.battlesListObj, this)
  }

  onEventPresetsByGroupsChanged = @(_params) this.updateButtons()

  function getSlotbarActions()
  {
    if (this.hasSlotbarByUnitsGroups)
      return [ "autorefill", "aircraft", "changeUnitsGroup", "weapons", "crew", "info", "repair" ]
    else
      return [ "autorefill", "aircraft", "weapons", "crew", "info", "repair" ]
  }
}
