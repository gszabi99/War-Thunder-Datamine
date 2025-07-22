from "%scripts/dagui_natives.nut" import get_charserver_time_millisec, ww_get_selected_armies_names, ww_highlight_zones_by_name, ww_update_popuped_armies_name, ww_get_sides_info, ww_side_val_to_name, ww_turn_on_sector_sprites, ww_get_operation_activation_time, ww_find_army_name_by_coordinates, ww_get_zone_idx_world, ww_mark_zones_as_outlined_by_name, ww_turn_off_sector_sprites, ww_side_name_to_val
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { is_low_width_screen } = require("%scripts/options/safeAreaMenu.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { Point2 } = require("dagor.math")
let DataBlock  = require("DataBlock")
let time = require("%scripts/time.nut")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let mapAirfields = require("%scripts/worldWar/inOperation/model/wwMapAirfields.nut")
let actionModesManager = require("%scripts/worldWar/inOperation/wwActionModesManager.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { subscribeOperationNotifyOnce } = require("%scripts/worldWar/services/wwService.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { LEADER_OPERATION_STATES,
  getLeaderOperationState } = require("%scripts/squads/leaderWwOperationStates.nut")
let { isPlatformShieldTv } = require("%scripts/clientState/platform.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { create_ObjMoveToOBj } = require("%sqDagui/guiBhv/bhvAnim.nut")
let { wwGetOperationId, wwGetPlayerSide, wwGetOperationWinner,
  wwGetZoneName, wwGetSelectedAirfield, wwClearOutlinedZones, wwGetSpeedupFactor } = require("worldwar")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { worldWarMapControls } = require("%scripts/worldWar/bhvWorldWarMap.nut")
let { WwBattle } = require("%scripts/worldWar/inOperation/model/wwBattle.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")
let g_world_war_render = require("%scripts/worldWar/worldWarRender.nut")
let { setWWMapParams, dargMapVisible } = require("%scripts/worldWar/wwMapDataBridge.nut")
let { mapCellUnderCursor } = require("%appGlobals/wwObjectsUnderCursor.nut")
let { register_command } = require("console")
let { getWwSetting } = require("%scripts/worldWar/worldWarStates.nut")
let wwTopMenuLeftSideSections = require("%scripts/worldWar/externalServices/worldWarTopMenuSectionsConfigs.nut")
let { isOperationPaused, isOperationFinished } = require("%appGlobals/worldWar/wwOperationState.nut")
let { getWWLogsData, requestNewWWLogs } = require("%scripts/worldWar/inOperation/model/wwOperationLog.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { RenderCategory } = require("worldwarConst")
let g_world_war = require("%scripts/worldWar/worldWarUtils.nut")
let { getRearZones, getRearZonesOwnedToSide, getRearZonesLostBySide
} = require("%scripts/worldWar/inOperation/wwOperationStates.nut")
let { checkNonApprovedResearches } = require("%scripts/researches/researchActions.nut")
let { isMapHovered } = require("%appGlobals/worldWar/wwMapHoverState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")
let { getArmyByName } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")
let { g_ww_map_info_type } = require("%scripts/worldWar/inOperation/model/wwMapInfoTypes.nut")
let { g_ww_map_controls_buttons } = require("%scripts/worldWar/inOperation/model/wwMapControlsButtons.nut")
let { g_ww_map_reinforcement_tab_type } = require("%scripts/worldWar/inOperation/model/wwMapReinforcementTabType.nut")

let { fullUpdateCurrentOperation, forcedFullUpdateCurrentOperation
} = require("%scripts/worldWar/inOperation/wwOperations.nut")

const WW_LOG_REQUEST_DELAY = 1
const WW_LOG_EVENT_LOAD_AMOUNT = 10


gui_handlers.WwMap <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/worldWar/worldWarMap.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  operationStringTpl = "%gui/worldWar/operationString.tpl"
  handlerLocId = "mainmenu/operationsMap"

  UPDATE_ARMY_STRENGHT_DELAY = 60000

  isRightPanelVisible = true
  needUpdateSidesStrenghtView = false

  currentOperationInfoTabType = null
  currentReinforcementInfoTabType = null
  mainBlockHandler = null
  reinforcementBlockHandler = null
  needReindforcementsUpdate = false
  currentSelectedObject = null
  objectiveHandler = null
  timerDescriptionHandler = null
  highlightZonesTimer = null
  operationPauseTimer = null
  updateLogsTimer = null
  afkLostTimer = null
  afkCountdownTimer = null
  animationTimer = null

  armyStrengthUpdateTimeRemain = 0
  isArmiesPathSwitchedOn = false
  leftSectionHandlerWeak = null
  savedReinforcements = null

  static renderFlagPID = dagui_propid_add_name_id("_renderFlag")

  afkData = null

  canQuitByGoBack = false

  function initScreen() {
    if (g_squad_manager.isSquadMember() && !g_squad_manager.isMeReady())
      g_squad_manager.setReadyFlag(true)

    this.backSceneParams = { eventbusName = "gui_start_mainmenu" }
    g_world_war_render.init()
    this.registerSubHandler(handlersManager.loadHandler(gui_handlers.wwMapTooltip,
      { scene = this.scene.findObject("hovered_map_object_info"),
        controllerScene = this.scene.findObject("hovered_map_object_controller") }))

    this.leftSectionHandlerWeak = gui_handlers.TopMenuButtonsHandler.create(
      this.scene.findObject("topmenu_menu_panel"),
      this,
      wwTopMenuLeftSideSections,
      this.scene.findObject("left_gc_panel_free_width")
    )
    this.registerSubHandler(this.leftSectionHandlerWeak)
    this.afkData = {
      loseSide = 0,
      afkLoseTimeMsec = 0,
      isMeLost = false,
      haveAccess = false,
      isNeedAFKTimer = false
    }

    this.clearSavedData()
    this.initMapName()
    this.initOperationStatus(false)
    this.updateAFKTimer()
    this.initGCBottomBar()
    this.initToBattleButton()
    this.initArmyControlButtons()
    this.initControlBlockVisibiltiySwitch()
    this.initPageSwitch()
    this.initReinforcementPageSwitch()
    this.setCurrentSelectedObject(mapObjectSelect.NONE)
    this.markMainObjectiveZones()

    forcedFullUpdateCurrentOperation()
    let wwLogsData = getWWLogsData()
    wwLogsData.lastReadLogMark = loadLocalByAccount(g_world_war.getSaveOperationLogId(), "")
    requestNewWWLogs(WW_LOG_MAX_LOAD_AMOUNT, !wwLogsData.loaded.len())

    this.scene.findObject("update_timer").setUserData(this)
    this.scene.findObject("update_map_hovered_status_timer").setUserData(this)
    if (g_world_war_render.isCategoryEnabled(RenderCategory.ERC_ARMY_RADIUSES))
      g_world_war_render.setCategory(RenderCategory.ERC_ARMY_RADIUSES, false)

    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        checkNonApprovedResearches(true)
    })

    this.scene.findObject("worldwar_map").show(false)
    dargMapVisible.set(true)
  }

  function clearSavedData() {
    this.savedReinforcements = {}
    mapAirfields.reset()
  }

  function initMapName() {
    let headerObj = this.scene.findObject("operation_name")
    if (!checkObj(headerObj))
      return

    let curOperation = getOperationById(wwGetOperationId())
    headerObj.setValue(curOperation
      ? "".concat(curOperation.getNameText(), "\n",
        loc("worldwar/cluster"), loc("ui/colon"), loc($"cluster/{curOperation.getCluster()}"))
      : "")
  }

  function initControlBlockVisibiltiySwitch() {
    showObjById("control_block_visibility_switch", this.isSwitchPanelBtnVisible(), this.scene)
    this.updateGamercardType()
  }

  function isSwitchPanelBtnVisible() {
    return is_low_width_screen()
  }

  function updateGamercardType() {
    let gamercardObj = this.scene.findObject("gamercard_div")
    if (!checkObj(gamercardObj))
      return

    gamercardObj.switchBtnStat = !this.isSwitchPanelBtnVisible() ? "hidden"
      : this.isRightPanelVisible ? "switchOff"
      : "switchOn"
  }

  function initPageSwitch(forceTabSwitch = null) {
    let pagesObj = this.scene.findObject("pages_list")
    if (!checkObj(pagesObj))
      return

    let tabIndex = forceTabSwitch != null ? forceTabSwitch
      : this.currentOperationInfoTabType ? this.currentOperationInfoTabType.index : 0

    pagesObj.setValue(tabIndex)
    this.onPageChange(pagesObj)
  }

  function onPageChange(obj) {
    this.currentOperationInfoTabType = g_ww_map_info_type.getTypeByIndex(obj.getValue())
    showObjById("content_block_2", this.currentOperationInfoTabType == g_ww_map_info_type.OBJECTIVE, this.scene)
    this.updatePage()
    this.onTabChange()
  }


  function onReinforcementTabChange(obj) {
    this.currentReinforcementInfoTabType = g_ww_map_reinforcement_tab_type.getTypeByCode(obj.getValue())

    if (this.currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      this.setCurrentSelectedObject(mapObjectSelect.NONE)

    this.updateSecondaryBlock()
    this.updateSecondaryBlockTabs()
    this.onTabChange()
  }


  function initReinforcementPageSwitch() {
    let tabsObj = this.scene.findObject("reinforcement_pages_list")
    if (!checkObj(tabsObj))
      return

    let show = g_world_war.haveManagementAccessForAnyGroup()
    showObjById("reinforcements_block", show, this.scene)
    showObjById("armies_block", show, this.scene)

    local defaultTabId = 0
    if (show) {
      let reinforcement = g_ww_map_reinforcement_tab_type.REINFORCEMENT
      this.updateSecondaryBlockTab(reinforcement)
      if (reinforcement.needAutoSwitch())
        defaultTabId = reinforcement.code
    }

    tabsObj.setValue(defaultTabId)
  }

  function updatePage() {
    this.updateMainBlock()
    this.updateSecondaryBlock()
  }

  function updateMainBlock() {
    let operationBlockObj = this.scene.findObject("selected_page_block")
    if (!checkObj(operationBlockObj))
      return

    this.mainBlockHandler = this.currentOperationInfoTabType.getMainBlockHandler(operationBlockObj,
      wwGetPlayerSide(), {})
    if (this.mainBlockHandler)
      this.registerSubHandler(this.mainBlockHandler)
  }

  function onTabChange() {
    if (!this.mainBlockHandler.isValid())
      return

    if ("onTabChange" in this.mainBlockHandler)
      this.mainBlockHandler.onTabChange()
  }

  function updateSecondaryBlockTabs() {
    let blockObj = this.scene.findObject("reinforcement_pages_list")
    if (!checkObj(blockObj))
      return

    foreach (tab in g_ww_map_reinforcement_tab_type.types)
      this.updateSecondaryBlockTab(tab, blockObj)
  }

  function updateSecondaryBlockTab(tab, blockObj = null, hasUnseenIcon = false) {
    blockObj = blockObj || this.scene.findObject("reinforcement_pages_list")
    if (!checkObj(blockObj))
      return

    let { tabId = "", tabIcon = "", tabText = "" } = tab
    let tabObj = blockObj.findObject($"{tabId}_text")
    if (!checkObj(tabObj))
      return

    local tabName = loc(tabIcon)
    if (this.currentReinforcementInfoTabType == tab)
      tabName = $"{tabName} {loc(tabText)}"

    tabObj.setValue($"{tabName}{tab.getTabTextPostfix()}")

    let tabAlertObj = blockObj.findObject($"{tabId}_alert")
    if (!checkObj(tabAlertObj))
      return

    if (this.currentReinforcementInfoTabType == tab)
      tabAlertObj.show(false)
    else if (hasUnseenIcon)
      tabAlertObj.show(true)
  }

  function updateSecondaryBlock() {
    if (!this.currentReinforcementInfoTabType || !this.isSecondaryBlockVisible())
      return

    let commandersObj = this.scene.findObject("reinforcement_block")
    if (!checkObj(commandersObj))
      return

    this.reinforcementBlockHandler = this.currentReinforcementInfoTabType.getHandler(commandersObj)
    if (this.reinforcementBlockHandler)
      this.registerSubHandler(this.reinforcementBlockHandler)
  }

  function isSecondaryBlockVisible() {
    let secondaryBlockObj = this.scene.findObject("content_block_2")
    return checkObj(secondaryBlockObj) && secondaryBlockObj.isVisible()
  }

  function initGCBottomBar() {
    let obj = this.scene.findObject("gamercard_bottom_navbar_place")
    if (!checkObj(obj))
      return
    this.guiScene.replaceContent(obj, "%gui/worldWar/worldWarMapGCBottom.blk", this)
  }

  function initArmyControlButtons() {
    let obj = this.scene.findObject("ww_army_controls_place")
    if (!checkObj(obj))
      return

    local markUp = ""
    foreach (buttonView in g_ww_map_controls_buttons.types)
      markUp = "".concat(markUp, handyman.renderCached("%gui/commonParts/button.tpl", buttonView))

    this.guiScene.replaceContentFromText(obj, markUp, markUp.len(), this)
  }

  function updateArmyActionButtons() {
    let nestObj = this.scene.findObject("ww_army_controls_nest")
    if (!checkObj(nestObj))
      return

    if (!g_world_war.haveManagementAccessForAnyGroup()) {
      nestObj.show(false)
      return
    }

    local hasAccess = false
    if (this.currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      hasAccess = true
    else if (this.currentSelectedObject == mapObjectSelect.AIRFIELD) {
      let airfield = g_world_war.getAirfieldByIndex(wwGetSelectedAirfield())
      if (airfield.getAvailableFormations().len())
        hasAccess = true
    }
    else if (this.currentSelectedObject == mapObjectSelect.ARMY ||
             this.currentSelectedObject == mapObjectSelect.LOG_ARMY)
      hasAccess = g_world_war.haveManagementAccessForSelectedArmies()

    let btnBlockObj = this.scene.findObject("ww_army_controls_place")
    if (!checkObj(btnBlockObj))
      return

    local showAny = false
    foreach (buttonView in g_ww_map_controls_buttons.types) {
      let showButton = hasAccess && !buttonView.isHidden()
      let buttonObj = showObjById(buttonView.id, showButton, btnBlockObj)
      if (showButton && checkObj(buttonObj)) {
        buttonObj.enable(buttonView.isEnabled())
        buttonObj.setValue(buttonView.text())
      }

      showAny = showAny || showButton
    }
    nestObj.show(showAny)
    btnBlockObj.show(showAny)

    let warningTextObj = this.scene.findObject("ww_no_army_to_controls")
    if (checkObj(warningTextObj))
      warningTextObj.show(!showAny)
  }

  function showSelectHint(show = true) {
    if (!showConsoleButtons.value || !g_world_war.haveManagementAccessForAnyGroup())
      return

    showObjById("ww_army_select", show)
  }

  function initToBattleButton() {
    let toBattleNest = showObjById("gamercard_tobattle", true, this.scene)
    if (toBattleNest) {
      this.scene.findObject("top_gamercard_bg").needRedShadow = "no"
      let toBattleBlk = handyman.renderCached("%gui/mainmenu/toBattleButton.tpl", {
        enableEnterKey = !isPlatformShieldTv()
      })
      this.guiScene.replaceContentFromText(toBattleNest, toBattleBlk, toBattleBlk.len(), this)
    }
    showObjById("gamercard_logo", false, this.scene)

    this.updateToBattleButton()
  }

  function updateToBattleButton() {
    let toBattleButtonObj = this.scene.findObject("to_battle_button")
    if (!checkObj(this.scene) || !checkObj(toBattleButtonObj))
      return

    local txt = loc("worldWar/btn_battles")
    local isCancel = false

    if (g_squad_manager.isSquadMember()) {
      let state = getLeaderOperationState()
      let isReady = state == LEADER_OPERATION_STATES.LEADER_OPERATION
      if (g_squad_manager.isMeReady() != isReady)
        g_squad_manager.setReadyFlag(isReady)
      if (state == LEADER_OPERATION_STATES.OUT) {
        txt = loc("worldWar/menu/quitToHangar")
        isCancel = true
      }
      else if (state == LEADER_OPERATION_STATES.ANOTHER_OPERATION) {
        txt = "".concat(loc("ui/number_sign"), g_squad_manager.getWwOperationId())
        isCancel = true
      }
    }
    else if (this.isInQueue()) {
      txt = loc("mainmenu/btnCancel")
      isCancel = true
    }

    let enable = this.isOperationActive() && this.hasBattlesToPlay()
    toBattleButtonObj.inactiveColor = enable ? "no" : "yes"
    toBattleButtonObj.setValue(txt)
    toBattleButtonObj.findObject("to_battle_button_text").setValue(txt)
    toBattleButtonObj.isCancel = isCancel ? "yes" : "no"
    toBattleButtonObj.fontOverride = daguiFonts.getMaxFontTextByWidth(txt,
      to_pixels("1@maxToBattleButtonTextWidth"), "bold")
  }

  function hasBattlesToPlay() {
    return u.search(g_world_war.getBattles(),
      g_world_war.isBattleAvailableToPlay)
  }

  function onStart() {
    if (isOperationFinished())
      return showInfoMsgBox(loc("worldwar/operation_complete"))

    if (g_squad_manager.isSquadMember()) {
      let leaderState = getLeaderOperationState()
      if (leaderState == LEADER_OPERATION_STATES.OUT) {
        this.guiScene.performDelayed(this, this.goBackToHangar)
        return
      }

      if (leaderState == LEADER_OPERATION_STATES.ANOTHER_OPERATION) {
        this.guiScene.performDelayed(this, @()
          g_world_war.joinOperationById(g_squad_manager.getWwOperationId()))
        return
      }
    }

    let isInOperationQueue = isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE)
    if (isInOperationQueue)
      return g_world_war.leaveWWBattleQueues()

    let playerSide = wwGetPlayerSide()
    if (playerSide == SIDE_NONE)
      return showInfoMsgBox(loc("msgbox/internal_error_header"))

    this.openBattleDescriptionModal(WwBattle())
  }

  function goBackToHangar() {
    g_world_war.stopWar()
    this.goBack()
  }

  function onEventWWStopWorldWar(_p) {
    if (!isProfileReceived.get())
      return 

    this.goBack()
    if (g_squad_manager.isSquadMember() && g_squad_manager.isMeReady())
      g_squad_manager.setReadyFlag(false)
  }

  _isGoBackInProgress = false
  function goBack() {
    if (this._isGoBackInProgress)
      return
    this._isGoBackInProgress = true
    base.goBack()
  }

  function onEventMatchingConnect(_params) {
    subscribeOperationNotifyOnce(wwGetOperationId())
  }

  function onArmyMove(_obj) {
    let cursorPos = get_dagui_mouse_cursor_pos()

    if (this.currentSelectedObject == mapObjectSelect.ARMY ||
        this.currentSelectedObject == mapObjectSelect.LOG_ARMY)
      g_world_war.moveSelectedArmes(cursorPos[0], cursorPos[1],
        ww_find_army_name_by_coordinates(cursorPos[0], cursorPos[1]))
    else if (this.currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      wwEvent("MapRequestReinforcement", {
        cellIdx = mapCellUnderCursor.get()
      })
    else if (this.currentSelectedObject == mapObjectSelect.AIRFIELD) {
      let mapObj = this.scene.findObject("worldwar_map")
      if (!checkObj(mapObj))
        return

      worldWarMapControls.onMoveCommand.call(
        worldWarMapControls, mapObj, Point2(cursorPos[0], cursorPos[1]), false
      )
    }
  }

  function onArmyStop(_obj) {
    g_world_war.stopSelectedArmy()
  }

  function onArmyEntrench(_obj) {
    g_world_war.entrenchSelectedArmy()
  }

  function onArtilleryArmyPrepareToFire(_obj) {
    this.setActionMode(AUT_ArtilleryFire)
  }

  function onForceShowArmiesPath(_obj) {
    this.isArmiesPathSwitchedOn = g_world_war_render.isCategoryEnabled(RenderCategory.ERC_ARROWS_FOR_SELECTED_ARMIES)
    if (this.isArmiesPathSwitchedOn)
      g_world_war_render.setCategory(RenderCategory.ERC_ARROWS_FOR_SELECTED_ARMIES, false)
  }

  function onRemoveForceShowArmiesPath(_obj) {
    if (this.isArmiesPathSwitchedOn != g_world_war_render.isCategoryEnabled(RenderCategory.ERC_ARROWS_FOR_SELECTED_ARMIES))
      g_world_war_render.setCategory(RenderCategory.ERC_ARROWS_FOR_SELECTED_ARMIES, true)
  }

  function collectArmyStrengthData() {
    let result = {}

    let currentStrenghtInfo = g_world_war.getSidesStrenghtInfo()
    for (local side = SIDE_NONE; side < SIDE_TOTAL; side++) {
      if (!(side in currentStrenghtInfo))
        continue

      let sideName = ww_side_val_to_name(side)
      let armyGroups = g_world_war.getArmyGroupsBySide(side)
      if (!armyGroups.len())
        continue

      if (!(sideName in result))
        result[sideName] <- {}

      if (!("country" in result[sideName]))
        result[sideName].country <- []

      foreach (group in armyGroups) {
        let country = group.getArmyCountry()
        if (!isInArray(country, result[sideName].country))
          result[sideName].country.append(country)
      }

      result[sideName].units <- currentStrenghtInfo[side]
    }

    return result
  }

  function collectUnitsData(formationsArray) {
    let unitsList = []
    foreach (formation in formationsArray)
      unitsList.extend(formation.getUnits())

    return g_world_war.collectUnitsData(unitsList, false)
  }

  function markMainObjectiveZones() {
    let objectivesBlk = g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    let staticBlk = u.copy(objectivesBlk?.data) || DataBlock()
    let dynamicBlk = u.copy(objectivesBlk?.status) || DataBlock()

    for (local i = 0; i < staticBlk.blockCount(); i++) {
      let statBlk = staticBlk.getBlock(i)
      if (!statBlk?.mainObjective)
        continue

      let oType = ::g_ww_objective_type.getTypeByTypeName(statBlk?.type)
      if (oType != ::g_ww_objective_type.OT_CAPTURE_ZONE)
        continue

      let dynBlock = dynamicBlk?[statBlk.getBlockName()]
      if (!dynBlock)
        continue

      let zones = oType.getUpdatableZonesParams(
        dynBlock, statBlk, ww_side_val_to_name(wwGetPlayerSide())
      )
      if (!zones.len())
        continue

      for (local j = WW_MAP_HIGHLIGHT.LAYER_0; j <= WW_MAP_HIGHLIGHT.LAYER_2; j++) {
        let filteredZones = zones.filter(@(zone) zone.mapLayer == j)
        let zonesArray = filteredZones.map(@(zone) zone.id)
        ww_highlight_zones_by_name(zonesArray, j)
      }
    }
  }

  function showSidesStrenght() {
    let blockObj = this.scene.findObject("content_block_3")
    let armyStrengthData = this.collectArmyStrengthData()

    let orderArray = g_world_war.getSidesOrder()

    let side1Name = ww_side_val_to_name(orderArray.len() ? orderArray[0] : SIDE_NONE)
    let side1Data = getTblValue(side1Name, armyStrengthData, {})

    let side2Name = ww_side_val_to_name(orderArray.len() > 1 ? orderArray[1] : SIDE_NONE)
    let side2Data = getTblValue(side2Name, armyStrengthData, {})

    let mapName = getOperationById(wwGetOperationId())?.getMapId() ?? ""
    let view = {
      armyCountryImg1 = (side1Data?.country ?? []).map(@(c) { image = getCustomViewCountryData(c, mapName).icon })
      armyCountryImg2 = (side2Data?.country ?? []).map(@(c) { image = getCustomViewCountryData(c, mapName).icon })
      side1TotalVehicle = 0
      side2TotalVehicle = 0
      unitString = []
    }

    let armyStrengthsTable = {}
    let armyStrengths = []
    let totalVehicle = {
      [side1Name] = 0,
      [side2Name] = 0
    }
    foreach (sideName, army in armyStrengthData)
      foreach (wwUnit in army.units)
        if (wwUnit.isValid()) {
          local strenght = getTblValue(wwUnit.stengthGroupExpClass, armyStrengthsTable)
          if (!strenght) {
            strenght = {
              unitIcon = wwUnit.getUnitTypeOrClassIcon()
              unitName = wwUnit.getUnitStrengthGroupTypeText()
              shopItemType = wwUnit.getUnitRole()
              count = 0
            }
            strenght[side1Name] <- 0
            strenght[side2Name] <- 0

            armyStrengthsTable[wwUnit.stengthGroupExpClass] <- strenght
            armyStrengths.append(strenght)
          }

          strenght[sideName] += wwUnit.count
          strenght.count += wwUnit.count
          totalVehicle[sideName] += wwUnit.count
        }

    foreach (_idx, strength in armyStrengths) {
      view.unitString.append({
        unitIcon = strength.unitIcon
        unitName = strength.unitName
        shopItemType = strength.shopItemType
        side1UnitCount = strength[side1Name]
        side2UnitCount = strength[side2Name]
      })
    }
    view.side1TotalVehicle = totalVehicle[side1Name]
    view.side2TotalVehicle = totalVehicle[side2Name]

    let data = handyman.renderCached("%gui/worldWar/worldWarMapSidesStrenght.tpl", view)
    this.guiScene.replaceContentFromText(blockObj, data, data.len(), this)

    this.needUpdateSidesStrenghtView = false
  }

  function showSelectedArmy() {
    let blockObj = this.scene.findObject("content_block_3")
    let selectedArmyNames = ww_get_selected_armies_names()
    if (!selectedArmyNames.len())
      return

    let selectedArmy = getArmyByName(selectedArmyNames[0])
    if (!selectedArmy.isValid()) {
      wwEvent("MapClearSelection")
      return
    }

    let data = handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo.tpl", selectedArmy.getView())
    this.guiScene.replaceContentFromText(blockObj, data, data.len(), this)

    if (this.timerDescriptionHandler) {
      this.timerDescriptionHandler.destroy()
      this.timerDescriptionHandler = null
    }

    if (!selectedArmy.needUpdateDescription())
      return

    this.timerDescriptionHandler = Timer(blockObj, 1,
      @() this.updateSelectedArmy(blockObj, selectedArmy), this, true)
  }

  function showSelectedLogArmy(params) {
    let blockObj = this.scene.findObject("content_block_3")
    if (!checkObj(blockObj) || !("wwArmy" in params))
      return

    local data = handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo.tpl", params.wwArmy.getView())
    this.guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function updateSelectedArmy(blockObj, selectedArmy) {
    blockObj = blockObj || this.scene.findObject("content_block_3")
    if (!checkObj(blockObj) || !selectedArmy)
      return

    let armyView = selectedArmy.getView()
    foreach (fieldId, func in armyView.getRedrawArmyStatusData()) {
      let redrawFieldObj = blockObj.findObject(fieldId)
      if (checkObj(redrawFieldObj))
        redrawFieldObj.setValue(func.call(armyView) ?? "")
    }

    this.updateArmyActionButtons()
  }

  function showSelectedReinforcement(params) {
    let blockObj = this.scene.findObject("content_block_3")
    let reinforcement = g_world_war.getReinforcementByName(getTblValue("name", params))
    if (!reinforcement)
      return

    let reinfView = reinforcement.getView()
    let data = handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo.tpl", reinfView)
    this.guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function showSelectedAirfield(params) {
    if (this.currentReinforcementInfoTabType != g_ww_map_reinforcement_tab_type.AIRFIELDS)
      return

    if (!getTblValue("formationType", params) ||
        getTblValue("formationId", params, -1) < 0)
      return

    let airfield = g_world_war.getAirfieldByIndex(wwGetSelectedAirfield())
    local formation = null

    if (params.formationType == "formation") {
      formation = params.formationId == WW_ARMY_RELATION_ID.CLAN ?
        airfield.clanFormation : airfield.allyFormation
    }
    else if (params.formationType == "cooldown") {
      if (airfield.cooldownFormations.len() > params.formationId)
        formation = airfield.cooldownFormations[params.formationId]
    }

    if (!formation) {
      this.reinforcementBlockHandler.selectDefaultFormation()
      return
    }

    let blockObj = this.scene.findObject("content_block_3")
    let data = handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo.tpl", formation.getView())
    this.guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function setCurrentSelectedObject(value, params = {}) {
    let lastSelectedOject = this.currentSelectedObject
    this.currentSelectedObject = value
    g_ww_map_controls_buttons.setSelectedObjectCode(this.currentSelectedObject)

    if (this.currentSelectedObject == mapObjectSelect.ARMY)
      this.showSelectedArmy()
    else if (this.currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      this.showSelectedReinforcement(params)
    else if (this.currentSelectedObject == mapObjectSelect.AIRFIELD)
      this.showSelectedAirfield(params)
    else if (this.currentSelectedObject == mapObjectSelect.NONE) {
      this.needUpdateSidesStrenghtView = true
      if (lastSelectedOject != mapObjectSelect.NONE)
        this.showSidesStrenght()
    }

    this.updateArmyActionButtons()
    showObjById("ww_army_select", false)
  }

  function onSecondsUpdate(_obj, dt) {
    if (this.needReindforcementsUpdate)
      this.needReindforcementsUpdate = this.updateReinforcements()

    this.armyStrengthUpdateTimeRemain -= dt
    if (this.armyStrengthUpdateTimeRemain >= 0) {
      this.updateArmyStrenght()
      this.armyStrengthUpdateTimeRemain = this.UPDATE_ARMY_STRENGHT_DELAY
    }

    fullUpdateCurrentOperation()
  }

  function updateReinforcements() {
    let hasUnseenIcon = this.updateRearZonesHighlight()
    this.updateSecondaryBlockTab(g_ww_map_reinforcement_tab_type.REINFORCEMENT, null, hasUnseenIcon)
    return g_world_war.hasSuspendedReinforcements()
  }

  function updateRearZonesHighlight() {
    let emptySidesReinforcementList = {}
    let rearZones = getRearZones()
    foreach (sideName, _zones in rearZones)
      emptySidesReinforcementList[ww_side_name_to_val(sideName)] <- true

    local hasUnseenIcon = false
    let arrivingReinforcementSides = {}
    let reinforcements = g_world_war.getMyReadyReinforcementsArray()
    foreach (reinforcement in reinforcements) {
      let name = reinforcement?.name
      let side = reinforcement?.armyGroup.owner.side
      if (!side)
        continue

      emptySidesReinforcementList[side] = false

      if (name && !(name in this.savedReinforcements)) {
        hasUnseenIcon = true
        this.savedReinforcements[name] <- side
        if (!(side in arrivingReinforcementSides))
          arrivingReinforcementSides[side] <- null
      }
    }

    foreach (side, isEmpty in emptySidesReinforcementList)
      if (isEmpty)
        ww_turn_off_sector_sprites("Reinforcement", rearZones[ww_side_val_to_name(side)])
      else {
        ww_turn_off_sector_sprites("Reinforcement", getRearZonesLostBySide(side))
        if (!(side in arrivingReinforcementSides))
          ww_turn_on_sector_sprites("Reinforcement", getRearZonesOwnedToSide(side), 0)
      }

    foreach (side, _value in arrivingReinforcementSides)
      ww_turn_on_sector_sprites("Reinforcement", getRearZonesOwnedToSide(side), 5000)

    return hasUnseenIcon
  }

  function updateArmyStrenght() {
    if (!this.needUpdateSidesStrenghtView)
      return

    this.showSidesStrenght()
  }

  function updateAFKData() {
    let blk = DataBlock()
    ww_get_sides_info(blk)
    let sidesBlk = blk?.sides
    if (sidesBlk == null)
      return
    let loseSide = sidesBlk[SIDE_2.tostring()].afkLoseTimeMsec
      < sidesBlk[SIDE_1.tostring()].afkLoseTimeMsec
        ? SIDE_2 : SIDE_1
    let newLoseTime = sidesBlk[loseSide.tostring()].afkLoseTimeMsec
    this.afkData.isNeedAFKTimer = this.afkData.loseSide != loseSide || this.afkData.afkLoseTimeMsec != newLoseTime
    this.afkData.loseSide = loseSide
    this.afkData.afkLoseTimeMsec = newLoseTime
    this.afkData.isMeLost = wwGetPlayerSide() == loseSide
    this.afkData.haveAccess = g_world_war.haveManagementAccessForAnyGroup()
  }

  function destroyAllAFKTimers() {
    if (this.afkLostTimer?.isValid() ?? false)
      this.afkLostTimer.destroy()
    if (this.afkCountdownTimer?.isValid() ?? false)
      this.afkCountdownTimer.destroy()
    if (this.animationTimer?.isValid() ?? false)
      this.animationTimer.destroy()
    wwEvent("AFKTimerStop")
  }

  function updateAFKTimer() {
    if (this.animationTimer && this.animationTimer.isValid())
      Timer(this.scene, 2, this.updateAFKTimer, this)
    else if (!isOperationFinished() && !isOperationPaused()) {
      this.updateAFKData()
      if (!this.afkData.isNeedAFKTimer && (this.afkLostTimer || this.afkCountdownTimer))
        return

      this.fillAFKTimer()
    }
    else if (isOperationFinished())
      this.destroyAllAFKTimers()
  }

  function fillAFKTimer() {
    this.destroyAllAFKTimers()
    let afkLostObj = this.scene.findObject("afk_lost")
    if (checkObj(afkLostObj))
      afkLostObj.show(false)
    let operStatObj = this.scene.findObject("wwmap_operation_status")
    if (checkObj(operStatObj))
      operStatObj.animation = "hide"
    let afkLoseTimeShowSec = (getWwSetting("afkLoseTimeShowSec", 0)
      / wwGetSpeedupFactor()).tointeger()
    let delayTime = max(time.millisecondsToSecondsInt(this.afkData.afkLoseTimeMsec)
      - g_world_war.getOperationTimeSec() - afkLoseTimeShowSec, 0)

    this.afkLostTimer = Timer(this.scene, delayTime,
      function() {
        let needMsgWnd = this.afkData.haveAccess && this.afkData.isMeLost
        let textColor = needMsgWnd ? "white" : this.afkData.isMeLost
          ? "wwTeamEnemyColor" : "wwTeamAllyColor"
        let msgLoc = "".concat(
          loc(this.afkData.isMeLost
            ? "worldwar/operation/myTechnicalDefeatWarning"
            : "worldwar/operation/enemyTechnicalDefeatWarning"),
          loc("ui/colon"))

        this.afkCountdownTimer = Timer(this.scene, 1,
          function() {
            let afkObj = this.scene.findObject("afk_lost")
            let statObj = this.scene.findObject("wwmap_operation_status")
            let textObj = statObj.findObject("wwmap_operation_status_text")
            let afkLoseTime = time.millisecondsToSecondsInt(this.afkData.afkLoseTimeMsec)
              - g_world_war.getOperationTimeSec()
            if (afkLoseTime <= 0)
              this.afkCountdownTimer?.destroy()
            let txt = afkLoseTime > 0
              ? "".concat(colorize(textColor, msgLoc), time.secondsToString(afkLoseTime))
              : colorize(textColor, loc(this.afkData.isMeLost
                ? "worldwar/operation/myTechnicalDefeat"
                : "worldwar/operation/enemyTechnicalDefeat"))
            if (needMsgWnd && checkObj(textObj)) {
              textObj.setValue(txt)
              statObj.show(!isOperationPaused())
              statObj.animation = "show"
            }
            if (!needMsgWnd && checkObj(afkObj)) {
              afkObj.setValue(txt)
              afkObj.show(!isOperationPaused())
            }
          }, this, true)
        wwEvent("AFKTimerStart", { needResize = !needMsgWnd })
      }, this)
  }

  function initOperationStatus(sendEvent = true) {
    let objStartBox = this.scene.findObject("wwmap_operation_status")
    if (!checkObj(objStartBox))
      return

    let objTarget = this.scene.findObject("operation_status")
    if (!checkObj(objTarget))
      return

    let isFinished = isOperationFinished()
    local statusText = ""

    if (isFinished) {
      let isVictory = wwGetOperationWinner() == wwGetPlayerSide()
      statusText = loc(isVictory ? "debriefing/victory" : "debriefing/defeat")
      this.guiScene.playSound(isVictory ? "ww_oper_end_win" : "ww_oper_end_fail")
      objStartBox.show(true)
    }
    else if (isOperationPaused()) {
      let activationTime = ww_get_operation_activation_time()
      objStartBox.show(true)
      if (activationTime) {
        if (this.operationPauseTimer && this.operationPauseTimer.isValid())
          this.operationPauseTimer.destroy()

        statusText = this.getTimeToStartOperationText(activationTime)
        this.operationPauseTimer = Timer(this.scene, 1,
          @() this.fullTimeToStartOperation(), this, true)

        this.clearSavedData()
      }
      else
        statusText = loc("debriefing/pause")
    }
    else {
      objTarget.show(false)
      return
    }
    objTarget.setValue(statusText)
    objTarget.show(false)

    let copyObjTarget = this.scene.findObject("operation_status_hidden_copy")
    if (checkObj(copyObjTarget))
      copyObjTarget.setValue(statusText)

    let objStart = objStartBox.findObject("wwmap_operation_status_text")
    if (!checkObj(objStart)) {
      objTarget.setValue(statusText)
      objStartBox.show(false)
      return
    }
    objStart.setValue(statusText)

    objStartBox.animation = "show"

    this.animationTimer = Timer(this.scene, 2,
      function() {
        objTarget.needAnim = "yes"
        objTarget.show(true)

        objStartBox.animation = "hide"

        create_ObjMoveToOBj(this.scene, objStart, objTarget, { time = 0.6, bhvFunc = "square" })
      },
    this)

    if (sendEvent && isFinished)
      wwEvent("OperationFinished")
  }

  function fullTimeToStartOperation() {
    let activationTime = ww_get_operation_activation_time()
    if (activationTime)
      foreach (objName in ["operation_status", "wwmap_operation_status_text"]) {
        let obj = this.scene.findObject(objName)
        if (checkObj(obj))
          obj.setValue(this.getTimeToStartOperationText(activationTime))
      }
    else {
      this.operationPauseTimer.destroy()
      this.playFirstObjectiveAnimation()
    }
  }

  function getTimeToStartOperationText(activationTime) {
    let activationMillis = activationTime - get_charserver_time_millisec()
    if (activationMillis <= 0)
      return ""

    let activationSec = time.millisecondsToSecondsInt(activationMillis)
    if (activationSec == 0)
      return loc("debriefing/pause")

    let timeToActivation = loc("worldwar/activationTime",
      { text = time.hoursToString(time.secondsToHours(activationSec), false, true) })
    return "".concat(loc("debriefing/pause"),
      loc("ui/parentheses/space", { text = timeToActivation }))
  }

  function onEventWWChangedDebugMode(_params) {
    this.updatePage()
  }

  function onEventWWMapArmySelected(params) {
    this.setCurrentSelectedObject(params.armyType, params)
  }

  function onEventWWMapSelectedReinforcement(params) {
    this.setCurrentSelectedObject(mapObjectSelect.REINFORCEMENT, params)
  }

  function onEventWWMapAirfieldSelected(params) {
    let tabsObj = this.scene.findObject("reinforcement_pages_list")
    if (tabsObj.getValue() != 2) {
      tabsObj.setValue(2)
      this.onReinforcementTabChange(tabsObj)
    }
    this.setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapAirfieldFormationSelected(params) {
    this.setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapAirfieldCooldownSelected(params) {
    this.setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapClearSelection(_params) {
    this.setCurrentSelectedObject(mapObjectSelect.NONE)
  }

  function onEventWWLoadOperation(_params = {}) {
    this.updateSecondaryBlockTab(g_ww_map_reinforcement_tab_type.REINFORCEMENT)
    this.needReindforcementsUpdate = true

    this.setCurrentSelectedObject(this.currentSelectedObject)
    this.markMainObjectiveZones()
    this.initOperationStatus()
    this.updateAFKTimer()

    mapAirfields.updateMapIcons()

    this.onSecondsUpdate(null, 0)
    this.startRequestNewLogsTimer()
  }

  function startRequestNewLogsTimer() {
    if (this.updateLogsTimer)
      return

    this.updateLogsTimer = Timer(this.scene, WW_LOG_REQUEST_DELAY,
      function() {
        this.updateLogsTimer = null
        local logHandler = null
        if (this.currentOperationInfoTabType &&
            this.currentOperationInfoTabType == g_ww_map_info_type.LOG)
          logHandler = this.mainBlockHandler

        requestNewWWLogs(WW_LOG_EVENT_LOAD_AMOUNT, false, logHandler)
      }, this, false)
  }

  function onEventWWMapSelectedBattle(params) {
    let wwBattle = getTblValue("battle", params, WwBattle())
    this.openBattleDescriptionModal(wwBattle)
  }

  function openBattleDescriptionModal(wwBattle) {
    gui_handlers.WwBattleDescription.open(wwBattle)
  }

  function onEventWWSelectedReinforcement(params) {
    let mapObj = this.scene.findObject("worldwar_map")
    if (!checkObj(mapObj))
      return

    let name = getTblValue("name", params, "")
    if (u.isEmpty(name))
      return

    worldWarMapControls.selectedReinforcement.call(worldWarMapControls, mapObj, name)
  }

  function onEventSquadDataUpdated(_params) {
    if (g_squad_manager.isSquadMember())
      if (g_squad_manager.getWwOperationBattle() != null)
        this.onStart()
      else
        this.doWhenActiveOnce("updateToBattleButton")
  }

  function onEventMyStatsUpdated(_params) {
    this.updateToBattleButton()
  }

  function onEventSquadStatusChanged(_params) {
    this.updateToBattleButton()
  }

  function onEventQueueChangeState(_params) {
    this.updateToBattleButton()
  }

  function onChangeInfoBlockVisibility(obj) {
    let blockObj = this.getObj("ww-right-panel")
    if (!checkObj(blockObj))
      return

    this.isRightPanelVisible = !this.isRightPanelVisible
    blockObj.show(this.isRightPanelVisible)

    let rootObj = obj.getParent()
    rootObj.collapsed = this.isRightPanelVisible ? "no" : "yes"
    this.updateGamercardType()

    this.guiScene.applyPendingChanges(false)
    let placeholderObj = this.scene.findObject("worldwar_map")
    let pos = placeholderObj.getPosRC()
    let size = placeholderObj.getSize()
    setWWMapParams({ pos, size })
  }

  function onEventWWShowLogArmy(params) {
    let mapObj = this.guiScene["worldwar_map"]
    if (checkObj(mapObj))
      worldWarMapControls.selectArmy.call(
        worldWarMapControls, mapObj, params.wwArmy.getName(), true, mapObjectSelect.LOG_ARMY
      )
    this.showSelectedLogArmy({ wwArmy = params.wwArmy })
  }

  function onEventWWNewLogsDisplayed(params) {
    let tabObj = this.getObj("operation_log_block_text")
    if (!checkObj(tabObj))
      return

    local text = loc("mainmenu/log/short")
    if (params.amount > 0)
      text = "".concat(text, loc("ui/parentheses/space", { text = params.amount }))
    tabObj.setValue(text)
  }

  function onEventWWMapArmiesByStatusUpdated(params) {
    let armies = getTblValue("armies", params, [])
    if (armies.len() == 0)
      return

    this.updateSecondaryBlockTab(g_ww_map_reinforcement_tab_type.ARMIES)

    let selectedArmyNames = ww_get_selected_armies_names()
    if (!selectedArmyNames.len())
      return

    let army = armies[0]
    if (army.name != selectedArmyNames[0])
      return

    this.updateSelectedArmy(null, army)
  }

  function onEventWWShowRearZones(params) {
    let reinforcement = g_world_war.getReinforcementByName(params?.name)
    if (!reinforcement)
      return

    let reinforcementSide = reinforcement.getArmySide()
    let reinforcementType = reinforcement.getOverrideUnitType() || reinforcement.getUnitType()
    local highlightedZones = []
    if (g_ww_unit_type.isAir(reinforcementType)) {
      let filterType = g_ww_unit_type.isHelicopter(reinforcementType) ? "AT_HELIPAD" : "AT_RUNWAY"
      highlightedZones = g_world_war.getAirfieldsArrayBySide(reinforcementSide, filterType)
        .map(@(airfield) wwGetZoneName(ww_get_zone_idx_world(airfield.getPos())))
    }
    else
      highlightedZones = getRearZonesOwnedToSide(reinforcementSide)

    ww_mark_zones_as_outlined_by_name(highlightedZones)

    if (this.highlightZonesTimer)
      this.highlightZonesTimer.destroy()

    this.highlightZonesTimer = Timer(this.scene, 10,
      function() {
        wwClearOutlinedZones()
      }, this, false)
  }

  function onEventWWArmyStatusChanged(_params) {
    this.updateArmyActionButtons()
    this.showSelectHint(actionModesManager.getCurActionModeId() == AUT_ArtilleryFire)
  }

  function onEventWWNewLogsAdded(params) {
    if (this.currentSelectedObject == mapObjectSelect.NONE &&
        params.isStrengthUpdateNeeded)
      this.updateArmyStrenght()
    if (params.isToBattleUpdateNeeded)
      this.updateToBattleButton()
  }

  function onEventActiveHandlersChanged(_p) {
    if (this.scene.getModalCounter() != 0) {
      wwClearOutlinedZones()
      ww_update_popuped_armies_name([])
    }
  }

  function onEventWWMapRearZoneSelected(params) {
    this.initPageSwitch(g_ww_map_info_type.OBJECTIVE.index)

    let tabsObj = this.scene.findObject("reinforcement_pages_list")
    if (!checkObj(tabsObj))
      return

    let tabBlockId = g_ww_map_reinforcement_tab_type.REINFORCEMENT.tabId
    let tabBlockObj = tabsObj.findObject(tabBlockId)
    if (!checkObj(tabBlockObj) || !tabBlockObj.isVisible())
      return

    tabsObj.setValue(g_ww_map_reinforcement_tab_type.REINFORCEMENT.code)
    this.reinforcementBlockHandler.selectFirstArmyBySide(params.side)
  }

  function onEventMyClanIdChanged(_p) {
    let wwOperation = getOperationById(wwGetOperationId())
    if (!wwOperation)
      return

    let joinCountry = wwOperation.getMyAssignCountry()
    let cantJoinReason = wwOperation.getCantJoinReasonData(joinCountry)

    if (!cantJoinReason.canJoin) {
      this.goBackToHangar()
      showInfoMsgBox(cantJoinReason.reasonText)
    }
  }

  function playFirstObjectiveAnimation() {
    this.initPageSwitch(g_ww_map_info_type.OBJECTIVE.index)

    let objStartBox = this.scene.findObject("wwmap_operation_objective")
    if (!checkObj(objStartBox))
      return

    local objTarget = null
    let objectivesBlk = g_world_war.getOperationObjectives()
    foreach (dataBlk in objectivesBlk.data) {
      if (!dataBlk?.mainObjective)
        continue

      let oType = ::g_ww_objective_type.getTypeByTypeName(dataBlk?.type)
      objTarget = this.scene.findObject(oType.getNameId(dataBlk, wwGetPlayerSide()))
      if (objTarget)
        break
    }

    if (!checkObj(objTarget))
      return

    objStartBox.show(true)
    objStartBox.animation = "show"

    let objStart = showObjById("objective_anim_start_text", true, objStartBox)
    objStart.setValue(objTarget.getValue())

    let animationFunc = function() {
      objStartBox.animation = "hide"
      create_ObjMoveToOBj(this.scene, objStart, objTarget,
        { time = 0.6, bhvFunc = "square", isTargetVisible = true })
    }

    Timer(this.scene, 3, animationFunc, this)
  }

  function onHelp() {
    gui_handlers.HelpInfoHandlerModal.openHelp(this)
  }

  function getWndHelpConfig() {
    let res = {
      textsBlk = "%gui/worldWar/wwMapHelp.blk"
      objContainer = this.scene.findObject("root-box")
    }

    let tab1 = this.currentOperationInfoTabType
    let tab2 = this.currentReinforcementInfoTabType
    let links = [
      { obj = "topmenu_ww_menu_btn"
        msgId = "hint_topmenu_ww_menu_btn"
      },
      { obj = "topmenu_ww_map_filter_btn"
        msgId = "hint_topmenu_ww_map_filter_btn"
      },
      { obj = "to_battle_button"
        msgId = "hint_to_battle_button"
        text = loc($"worldwar/help/map/{(this.isInQueue() ? "leave_queue_btn" : "to_battle_btn")}")
      },
      { obj = ["ww_army_controls_nest"]
        msgId = "hint_ww_army_controls_nest"
      },
      { obj = ["operation_name"]
        msgId = "hint_operation_name"
      },
      { obj = "selected_page_block"
        msgId = "hint_top_block"
        text = loc($"worldwar/help/map/{tab1 == g_ww_map_info_type.OBJECTIVE ? "objective" : "log"}")
      },
      { obj = "reinforcement_block"
        msgId = "hint_reinforcement_block"
        text = loc("".concat("worldwar/help/map/",
          (tab2 == g_ww_map_reinforcement_tab_type.COMMANDERS    ? "commanders"
            : tab2 == g_ww_map_reinforcement_tab_type.REINFORCEMENT ? "reinforcements"
            : tab2 == g_ww_map_reinforcement_tab_type.AIRFIELDS     ? "airfield"
            : "armies")))
      },
      { obj = "content_block_3"
        msgId = "hint_content_block_3"
        text = loc($"worldwar/help/map/{this.isSelectedObjectInfoShown() ? "army_info" : "side_strength"}")
      },
      { obj = this.isRightPanelVisible ? null : "control_block_visibility_switch"
        msgId = "hint_show_right_panel_button"
      }
    ]

    res.links <- links
    return res
  }

  isSelectedObjectInfoShown = @() this.currentSelectedObject == mapObjectSelect.ARMY ||
    this.currentSelectedObject == mapObjectSelect.REINFORCEMENT ||
    this.currentSelectedObject == mapObjectSelect.AIRFIELD ||
    this.currentSelectedObject == mapObjectSelect.LOG_ARMY

  isOperationActive = @() !isOperationFinished()
  isInQueue = @() this.isOperationActive() && isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE)

  function onTransportArmyLoad() {
    this.setActionMode(AUT_TransportLoad)
  }

  function onTransportArmyUnload() {
    this.setActionMode(AUT_TransportUnload)
  }

  function setActionMode(modeId) {
    actionModesManager.trySetActionModeOrCancel(modeId)
    this.updateButtonsAfterSetMode(actionModesManager.getCurActionModeId() == modeId)
  }

  function updateButtonsAfterSetMode(isEnabled) {
    let cancelBtnObj = this.scene.findObject("cancel_action_mode")
    if (checkObj(cancelBtnObj))
      cancelBtnObj.enable(isEnabled)
  }

  function onCancelActionMode() {
    actionModesManager.setActionMode()
    this.updateButtonsAfterSetMode(false)
  }

  showSelectAirfieldHint = @(airfieldIndex)
    actionModesManager.getCurActionModeId() != AUT_ArtilleryFire
      ? this.showSelectHint(airfieldIndex >= 0 && airfieldIndex != wwGetSelectedAirfield())
      : null

  showSelectArmyHint = @(armyName)
    actionModesManager.getCurActionModeId() != AUT_ArtilleryFire
      ? this.showSelectHint(armyName != null && armyName != ww_get_selected_armies_names()?[0])
      : null

  onEventWWHoverArmyItem = @(p) this.showSelectArmyHint(p.armyName)
  onEventWWMapArmyHoverChanged = @(p) this.showSelectArmyHint(p.armyName)

  onEventWWHoverAirfieldItem = @(p) this.showSelectAirfieldHint(p.airfieldIndex)
  onEventWWMapAirfieldHoverChanged = @(p) this.showSelectAirfieldHint(p.airfieldIndex)

  onEventWWHoverLostArmyItem = @(_) this.showSelectHint(false)
  onEventWWHoverLostAirfieldItem = @(_) this.showSelectHint(false)

  function getWidgetParams(placeholderId) {
    let { pos, size } = base.getWidgetParams(placeholderId)
    setWWMapParams({ pos, size })
    return { pos = [0, 0], size = [screen_width(), screen_height()] }
  }

  widgetsList = [
    {
      widgetId = DargWidgets.WORLDWAR_MAP
      placeholderId = "worldwar_map"
    }
  ]

  onMapHoveredStatusUpdate = @(_obj, _dt) isMapHovered.set(this.scene.findObject("worldwar_map_darg")?.isHovered() ?? false)
}

isMapHovered.subscribe(@(v) broadcastEvent("MapHovered", { hovered = v }))

register_command(function() {
    dargMapVisible.set(!dargMapVisible.get())
    let handler = handlersManager.findHandlerClassInScene(gui_handlers.WwMap)
    if (handler == null)
      return

    handler.scene.findObject("worldwar_map").show(!dargMapVisible.get())
}, "wwmap.switch")
