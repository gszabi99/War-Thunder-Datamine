let time = require("%scripts/time.nut")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let mapAirfields = require("%scripts/worldWar/inOperation/model/wwMapAirfields.nut")
let actionModesManager = require("%scripts/worldWar/inOperation/wwActionModesManager.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { subscribeOperationNotifyOnce } = require("%scripts/worldWar/services/wwService.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")

::gui_handlers.WwMap <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/worldWar/worldWarMap.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  operationStringTpl = "%gui/worldWar/operationString"
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

  static renderFlagPID = ::dagui_propid.add_name_id("_renderFlag")

  afkData = null

  canQuitByGoBack = false

  function initScreen()
  {
    backSceneFunc = ::gui_start_mainmenu
    ::g_world_war_render.init()
    registerSubHandler(::handlersManager.loadHandler(::gui_handlers.wwMapTooltip,
      { scene = scene.findObject("hovered_map_object_info"),
        controllerScene = scene.findObject("hovered_map_object_controller") }))

    leftSectionHandlerWeak = ::gui_handlers.TopMenuButtonsHandler.create(
      scene.findObject("topmenu_menu_panel"),
      this,
      ::g_ww_top_menu_left_side_sections,
      scene.findObject("left_gc_panel_free_width")
    )
    registerSubHandler(leftSectionHandlerWeak)
    afkData = {
      loseSide = 0,
      afkLoseTimeMsec = 0,
      isMeLost = false,
      haveAccess = false,
      isNeedAFKTimer = false
    }

    clearSavedData()
    initMapName()
    initOperationStatus(false)
    updateAFKTimer()
    initGCBottomBar()
    initToBattleButton()
    initArmyControlButtons()
    initControlBlockVisibiltiySwitch()
    initPageSwitch()
    initReinforcementPageSwitch()
    setCurrentSelectedObject(mapObjectSelect.NONE)
    markMainObjectiveZones()

    ::g_operations.forcedFullUpdate()
    ::g_ww_logs.lastReadLogMark = ::loadLocalByAccount(::g_world_war.getSaveOperationLogId(), "")
    ::g_ww_logs.requestNewLogs(WW_LOG_MAX_LOAD_AMOUNT, !::g_ww_logs.loaded.len())

    scene.findObject("update_timer").setUserData(this)
    if (::g_world_war_render.isCategoryEnabled(::ERC_ARMY_RADIUSES))
      ::g_world_war_render.setCategory(::ERC_ARMY_RADIUSES, false)

    guiScene.performDelayed(this, function() {
      if (isValid())
        ::checkNonApprovedResearches(true)
    })
  }

  function clearSavedData()
  {
    savedReinforcements = {}
    mapAirfields.reset()
  }

  function initMapName()
  {
    let headerObj = scene.findObject("operation_name")
    if (!::check_obj(headerObj))
      return

    let curOperation = getOperationById(::ww_get_operation_id())
    headerObj.setValue(curOperation
      ? "".concat(curOperation.getNameText(), "\n",
        ::loc("worldwar/cluster"), ::loc("ui/colon"), ::loc($"cluster/{curOperation.getCluster()}"))
      : "")
  }

  function initControlBlockVisibiltiySwitch()
  {
    this.showSceneBtn("control_block_visibility_switch", isSwitchPanelBtnVisible())
    updateGamercardType()
  }

  function isSwitchPanelBtnVisible()
  {
    return ::is_low_width_screen()
  }

  function updateGamercardType()
  {
    let gamercardObj = scene.findObject("gamercard_div")
    if (!::check_obj(gamercardObj))
      return

    gamercardObj.switchBtnStat = !isSwitchPanelBtnVisible() ? "hidden"
      : isRightPanelVisible ? "switchOff"
      : "switchOn"
  }

  function initPageSwitch(forceTabSwitch = null)
  {
    let pagesObj = scene.findObject("pages_list")
    if (!::checkObj(pagesObj))
      return

    let tabIndex = forceTabSwitch != null ? forceTabSwitch
      : currentOperationInfoTabType ? currentOperationInfoTabType.index : 0

    pagesObj.setValue(tabIndex)
    onPageChange(pagesObj)
  }

  function onPageChange(obj)
  {
    currentOperationInfoTabType = ::g_ww_map_info_type.getTypeByIndex(obj.getValue())
    this.showSceneBtn("content_block_2", currentOperationInfoTabType == ::g_ww_map_info_type.OBJECTIVE)
    updatePage()
    onTabChange()
  }


  function onReinforcementTabChange(obj)
  {
    currentReinforcementInfoTabType = ::g_ww_map_reinforcement_tab_type.getTypeByCode(obj.getValue())

    if (currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      setCurrentSelectedObject(mapObjectSelect.NONE)

    updateSecondaryBlock()
    updateSecondaryBlockTabs()
    onTabChange()
  }


  function initReinforcementPageSwitch()
  {
    let tabsObj = scene.findObject("reinforcement_pages_list")
    if (!::check_obj(tabsObj))
      return

    let show = ::g_world_war.haveManagementAccessForAnyGroup()
    this.showSceneBtn("reinforcements_block", show)
    this.showSceneBtn("armies_block", show)

    local defaultTabId = 0
    if (show)
    {
      let reinforcement = ::g_ww_map_reinforcement_tab_type.REINFORCEMENT
      updateSecondaryBlockTab(reinforcement)
      if (reinforcement.needAutoSwitch())
        defaultTabId = reinforcement.code
    }

    tabsObj.setValue(defaultTabId)
  }

  function updatePage()
  {
    updateMainBlock()
    updateSecondaryBlock()
  }

  function updateMainBlock()
  {
    let operationBlockObj = scene.findObject("selected_page_block")
    if (!::checkObj(operationBlockObj))
      return

    mainBlockHandler = currentOperationInfoTabType.getMainBlockHandler(operationBlockObj,
      ::ww_get_player_side(), {})
    if (mainBlockHandler)
      registerSubHandler(mainBlockHandler)
  }

  function onTabChange()
  {
    if (!mainBlockHandler.isValid())
      return

    if ("onTabChange" in mainBlockHandler)
      mainBlockHandler.onTabChange()
  }

  function updateSecondaryBlockTabs()
  {
    let blockObj = scene.findObject("reinforcement_pages_list")
    if (!::checkObj(blockObj))
      return

    foreach (tab in ::g_ww_map_reinforcement_tab_type.types)
      updateSecondaryBlockTab(tab, blockObj)
  }

  function updateSecondaryBlockTab(tab, blockObj = null, hasUnseenIcon = false)
  {
    blockObj = blockObj || scene.findObject("reinforcement_pages_list")
    if (!::checkObj(blockObj))
      return

    let tabId = ::getTblValue("tabId", tab, "")
    let tabObj = blockObj.findObject(tabId + "_text")
    if (!::checkObj(tabObj))
      return

    local tabName = ::loc(::getTblValue("tabIcon", tab, ""))
    if (currentReinforcementInfoTabType == tab)
      tabName += " " + ::loc(::getTblValue("tabText", tab, ""))

    tabObj.setValue(tabName + tab.getTabTextPostfix())

    let tabAlertObj = blockObj.findObject(tabId + "_alert")
    if (!::check_obj(tabAlertObj))
      return

    if (currentReinforcementInfoTabType == tab)
      tabAlertObj.show(false)
    else if (hasUnseenIcon)
      tabAlertObj.show(true)
  }

  function updateSecondaryBlock()
  {
    if (!currentReinforcementInfoTabType || !isSecondaryBlockVisible())
      return

    let commandersObj = scene.findObject("reinforcement_block")
    if (!::checkObj(commandersObj))
      return

    reinforcementBlockHandler = currentReinforcementInfoTabType.getHandler(commandersObj)
    if (reinforcementBlockHandler)
      registerSubHandler(reinforcementBlockHandler)
  }

  function isSecondaryBlockVisible()
  {
    let secondaryBlockObj = scene.findObject("content_block_2")
    return ::check_obj(secondaryBlockObj) && secondaryBlockObj.isVisible()
  }

  function initGCBottomBar()
  {
    let obj = scene.findObject("gamercard_bottom_navbar_place")
    if (!::checkObj(obj))
      return
    guiScene.replaceContent(obj, "%gui/worldWar/worldWarMapGCBottom.blk", this)
  }

  function initArmyControlButtons()
  {
    let obj = scene.findObject("ww_army_controls_place")
    if (!::checkObj(obj))
      return

    local markUp = ""
    foreach (buttonView in ::g_ww_map_controls_buttons.types)
      markUp += ::handyman.renderCached("%gui/commonParts/button", buttonView)

    guiScene.replaceContentFromText(obj, markUp, markUp.len(), this)
  }

  function updateArmyActionButtons()
  {
    let nestObj = scene.findObject("ww_army_controls_nest")
    if (!::check_obj(nestObj))
      return

    if (!::g_world_war.haveManagementAccessForAnyGroup())
    {
      nestObj.show(false)
      return
    }

    local hasAccess = false
    if (currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      hasAccess = true
    else if (currentSelectedObject == mapObjectSelect.AIRFIELD)
    {
      let airfield = ::g_world_war.getAirfieldByIndex(::ww_get_selected_airfield())
      if (airfield.getAvailableFormations().len())
        hasAccess = true
    }
    else if (currentSelectedObject == mapObjectSelect.ARMY ||
             currentSelectedObject == mapObjectSelect.LOG_ARMY)
      hasAccess = ::g_world_war.haveManagementAccessForSelectedArmies()

    let btnBlockObj = scene.findObject("ww_army_controls_place")
    if (!::check_obj(btnBlockObj))
      return

    local showAny = false
    foreach (buttonView in ::g_ww_map_controls_buttons.types)
    {
      let showButton = hasAccess && !buttonView.isHidden()
      let buttonObj = ::showBtn(buttonView.id, showButton, btnBlockObj)
      if (showButton && ::check_obj(buttonObj))
      {
        buttonObj.enable(buttonView.isEnabled())
        buttonObj.setValue(buttonView.text())
      }

      showAny = showAny || showButton
    }
    btnBlockObj.show(showAny)

    let warningTextObj = scene.findObject("ww_no_army_to_controls")
    if (::check_obj(warningTextObj))
      warningTextObj.show(!showAny)
  }

  function initToBattleButton()
  {
    let toBattleNest = this.showSceneBtn("gamercard_tobattle", true)
    if (toBattleNest)
    {
      scene.findObject("top_gamercard_bg").needRedShadow = "no"
      let toBattleBlk = ::handyman.renderCached("%gui/mainmenu/toBattleButton", {
        enableEnterKey = !::is_platform_shield_tv()
      })
      guiScene.replaceContentFromText(toBattleNest, toBattleBlk, toBattleBlk.len(), this)
    }
    this.showSceneBtn("gamercard_logo", false)

    updateToBattleButton()
  }

  function updateToBattleButton()
  {
    let toBattleButtonObj = scene.findObject("to_battle_button")
    if (!::checkObj(scene) || !::checkObj(toBattleButtonObj))
      return

    let isSquadMember = isOperationActive() && ::g_squad_manager.isSquadMember()
    local txt = ::loc("worldWar/btn_battles")
    local isCancel = false

    if (isSquadMember)
    {
      let isReady = ::g_squad_manager.isMeReady()
      txt = ::loc(isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady")
      isCancel = isReady
    }
    else if (isInQueue())
    {
      txt = ::loc("mainmenu/btnCancel")
      isCancel = true
    }

    let enable = isOperationActive() && hasBattlesToPlay()
    toBattleButtonObj.inactiveColor = enable? "no" : "yes"
    toBattleButtonObj.setValue(txt)
    toBattleButtonObj.findObject("to_battle_button_text").setValue(txt)
    toBattleButtonObj.isCancel = isCancel ? "yes" : "no"
    toBattleButtonObj.fontOverride = daguiFonts.getMaxFontTextByWidth(txt,
      to_pixels("1@maxToBattleButtonTextWidth"), "bold")
  }

  function hasBattlesToPlay()
  {
    return ::u.search(::g_world_war.getBattles(),
      ::g_world_war.isBattleAvailableToPlay)
  }

  function onStart()
  {
    if (::g_world_war.isCurrentOperationFinished())
      return ::showInfoMsgBox(::loc("worldwar/operation_complete"))

    let isSquadMember = ::g_squad_manager.isSquadMember()
    if (isSquadMember)
      return ::g_squad_manager.setReadyFlag()

    let isInOperationQueue = ::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE)
    if (isInOperationQueue)
      return ::g_world_war.leaveWWBattleQueues()

    let playerSide = ::ww_get_player_side()
    if (playerSide == ::SIDE_NONE)
      return ::showInfoMsgBox(::loc("msgbox/internal_error_header"))

    openBattleDescriptionModal(::WwBattle())
  }

  function goBackToHangar()
  {
    ::g_world_war.stopWar()
    goBack()
  }

  function onEventWWStopWorldWar(p)
  {
    if (!::g_login.isProfileReceived())
      return // to avoid MainMenu initialization during logout stage

    goBack()
  }

  _isGoBackInProgress = false
  function goBack()
  {
    if (_isGoBackInProgress)
      return
    _isGoBackInProgress = true
    base.goBack()
  }

  function onEventMatchingConnect(params)
  {
    subscribeOperationNotifyOnce(::ww_get_operation_id())
  }

  function onArmyMove(obj)
  {
    let cursorPos = ::get_dagui_mouse_cursor_pos()

    if (currentSelectedObject == mapObjectSelect.ARMY ||
        currentSelectedObject == mapObjectSelect.LOG_ARMY)
      ::g_world_war.moveSelectedArmes(cursorPos[0], cursorPos[1],
        ::ww_find_army_name_by_coordinates(cursorPos[0], cursorPos[1]))
    else if (currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      ::ww_event("MapRequestReinforcement", {
        cellIdx = ::ww_get_map_cell_by_coords(cursorPos[0], cursorPos[1])
      })
    else if (currentSelectedObject == mapObjectSelect.AIRFIELD)
    {
      let mapObj = scene.findObject("worldwar_map")
      if (!::checkObj(mapObj))
        return

      ::ww_gui_bhv.worldWarMapControls.onMoveCommand.call(
        ::ww_gui_bhv.worldWarMapControls, mapObj, ::Point2(cursorPos[0], cursorPos[1]), false
      )
    }
  }

  function onArmyStop(obj)
  {
    ::g_world_war.stopSelectedArmy()
  }

  function onArmyEntrench(obj)
  {
    ::g_world_war.entrenchSelectedArmy()
  }

  function onArtilleryArmyPrepareToFire(obj)
  {
    setActionMode(::AUT_ArtilleryFire)
  }

  function onForceShowArmiesPath(obj)
  {
    isArmiesPathSwitchedOn = ::g_world_war_render.isCategoryEnabled(::ERC_ARROWS_FOR_SELECTED_ARMIES)
    if (isArmiesPathSwitchedOn)
      ::g_world_war_render.setCategory(::ERC_ARROWS_FOR_SELECTED_ARMIES, false)
  }

  function onRemoveForceShowArmiesPath(obj)
  {
    if (isArmiesPathSwitchedOn != ::g_world_war_render.isCategoryEnabled(::ERC_ARROWS_FOR_SELECTED_ARMIES))
      ::g_world_war_render.setCategory(::ERC_ARROWS_FOR_SELECTED_ARMIES, true)
  }

  function collectArmyStrengthData()
  {
    let result = {}

    let currentStrenghtInfo = ::g_world_war.getSidesStrenghtInfo()
    for (local side = ::SIDE_NONE; side < ::SIDE_TOTAL; side++)
    {
      if (!(side in currentStrenghtInfo))
        continue

      let sideName = ::ww_side_val_to_name(side)
      let armyGroups = ::g_world_war.getArmyGroupsBySide(side)
      if (!armyGroups.len())
        continue

      if (!(sideName in result))
        result[sideName] <- {}

      if (!("country" in result[sideName]))
        result[sideName].country <- []

      foreach(group in armyGroups)
      {
        let country = group.getArmyCountry()
        if (!::isInArray(country, result[sideName].country))
          result[sideName].country.append(country)
      }

      result[sideName].units <- currentStrenghtInfo[side]
    }

    return result
  }

  function collectUnitsData(formationsArray)
  {
    let unitsList = []
    foreach(formation in formationsArray)
      unitsList.extend(formation.getUnits())

    return ::g_world_war.collectUnitsData(unitsList, false)
  }

  function markMainObjectiveZones()
  {
    let objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    let staticBlk = ::u.copy(objectivesBlk?.data) || ::DataBlock()
    let dynamicBlk = ::u.copy(objectivesBlk?.status) || ::DataBlock()

    for (local i = 0; i < staticBlk.blockCount(); i++)
    {
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
        dynBlock, statBlk, ::ww_side_val_to_name(::ww_get_player_side())
      )
      if (!zones.len())
        continue

      for (local j = WW_MAP_HIGHLIGHT.LAYER_0; j<= WW_MAP_HIGHLIGHT.LAYER_2; j++)
      {
        let filteredZones = zones.filter(@(zone) zone.mapLayer == j)
        let zonesArray = ::u.map(filteredZones, @(zone) zone.id)
        ::ww_highlight_zones_by_name(zonesArray, j)
      }
    }
  }

  function showSidesStrenght()
  {
    let blockObj = scene.findObject("content_block_3")
    let armyStrengthData = collectArmyStrengthData()

    let orderArray = ::g_world_war.getSidesOrder()

    let side1Name = ::ww_side_val_to_name(orderArray.len()? orderArray[0] : ::SIDE_NONE)
    let side1Data = ::getTblValue(side1Name, armyStrengthData, {})

    let side2Name = ::ww_side_val_to_name(orderArray.len() > 1? orderArray[1] : ::SIDE_NONE)
    let side2Data = ::getTblValue(side2Name, armyStrengthData, {})

    let mapName = getOperationById(::ww_get_operation_id())?.getMapId() ?? ""
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
        if (wwUnit.isValid())
        {
          local strenght = ::getTblValue(wwUnit.stengthGroupExpClass, armyStrengthsTable)
          if (!strenght)
          {
            strenght = {
              unitIcon = wwUnit.getWwUnitClassIco()
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

    foreach (idx, strength in armyStrengths)
    {
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

    let data = ::handyman.renderCached("%gui/worldWar/worldWarMapSidesStrenght", view)
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)

    needUpdateSidesStrenghtView = false
  }

  function showSelectedArmy()
  {
    let blockObj = scene.findObject("content_block_3")
    let selectedArmyNames = ::ww_get_selected_armies_names()
    if (!selectedArmyNames.len())
      return

    let selectedArmy = ::g_world_war.getArmyByName(selectedArmyNames[0])
    if (!selectedArmy.isValid())
    {
      ::ww_event("MapClearSelection")
      return
    }

    let data = ::handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo", selectedArmy.getView())
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)

    if (timerDescriptionHandler)
    {
      timerDescriptionHandler.destroy()
      timerDescriptionHandler = null
    }

    if (!selectedArmy.needUpdateDescription())
      return

    timerDescriptionHandler = ::Timer(blockObj, 1, (@(blockObj, selectedArmy) function() {
      updateSelectedArmy(blockObj, selectedArmy)
    })(blockObj, selectedArmy), this, true)
  }

  function showSelectedLogArmy(params)
  {
    let blockObj = scene.findObject("content_block_3")
    if (!::check_obj(blockObj) || !("wwArmy" in params))
      return

    local data = ::handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo", params.wwArmy.getView())
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function updateSelectedArmy(blockObj, selectedArmy)
  {
    blockObj = blockObj || scene.findObject("content_block_3")
    if (!::check_obj(blockObj) || !selectedArmy)
      return

    let armyView = selectedArmy.getView()
    foreach (fieldId, func in armyView.getRedrawArmyStatusData())
    {
      let redrawFieldObj = blockObj.findObject(fieldId)
      if (::check_obj(redrawFieldObj))
        redrawFieldObj.setValue(func.call(armyView))
    }

    updateArmyActionButtons()
  }

  function showSelectedReinforcement(params)
  {
    let blockObj = scene.findObject("content_block_3")
    let reinforcement = ::g_world_war.getReinforcementByName(::getTblValue("name", params))
    if (!reinforcement)
      return

    let reinfView = reinforcement.getView()
    let data = ::handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo", reinfView)
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function showSelectedAirfield(params)
  {
    if (currentReinforcementInfoTabType != ::g_ww_map_reinforcement_tab_type.AIRFIELDS)
      return

    if (!getTblValue("formationType", params) ||
        getTblValue("formationId", params, -1) < 0)
      return

    let airfield = ::g_world_war.getAirfieldByIndex(::ww_get_selected_airfield())
    local formation = null

    if (params.formationType == "formation")
    {
      formation = params.formationId == WW_ARMY_RELATION_ID.CLAN ?
        airfield.clanFormation : airfield.allyFormation
    }
    else if (params.formationType == "cooldown")
    {
      if (airfield.cooldownFormations.len() > params.formationId)
        formation = airfield.cooldownFormations[params.formationId]
    }

    if (!formation)
    {
      reinforcementBlockHandler.selectDefaultFormation()
      return
    }

    let blockObj = scene.findObject("content_block_3")
    let data = ::handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo", formation.getView())
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function setCurrentSelectedObject(value, params = {})
  {
    let lastSelectedOject = currentSelectedObject
    currentSelectedObject = value
    ::g_ww_map_controls_buttons.setSelectedObjectCode(currentSelectedObject)

    if (currentSelectedObject == mapObjectSelect.ARMY)
      showSelectedArmy()
    else if (currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      showSelectedReinforcement(params)
    else if (currentSelectedObject == mapObjectSelect.AIRFIELD)
      showSelectedAirfield(params)
    else if (currentSelectedObject == mapObjectSelect.NONE)
    {
      needUpdateSidesStrenghtView = true
      if (lastSelectedOject != mapObjectSelect.NONE)
        showSidesStrenght()
    }

    updateArmyActionButtons()
  }

  function onSecondsUpdate(obj, dt)
  {
    if (needReindforcementsUpdate)
      needReindforcementsUpdate = updateReinforcements()

    armyStrengthUpdateTimeRemain -= dt
    if (armyStrengthUpdateTimeRemain >= 0)
    {
      updateArmyStrenght()
      armyStrengthUpdateTimeRemain = UPDATE_ARMY_STRENGHT_DELAY
    }

    ::g_operations.fullUpdate()
  }

  function updateReinforcements()
  {
    let hasUnseenIcon = updateRearZonesHighlight()
    updateSecondaryBlockTab(::g_ww_map_reinforcement_tab_type.REINFORCEMENT, null, hasUnseenIcon)
    return ::g_world_war.hasSuspendedReinforcements()
  }

  function updateRearZonesHighlight()
  {
    let emptySidesReinforcementList = {}
    let rearZones = ::g_world_war.getRearZones()
    foreach (sideName, zones in rearZones)
      emptySidesReinforcementList[::ww_side_name_to_val(sideName)] <- true

    local hasUnseenIcon = false
    let arrivingReinforcementSides = {}
    let reinforcements = ::g_world_war.getMyReadyReinforcementsArray()
    foreach (reinforcement in reinforcements)
    {
      let name = reinforcement?.name
      let side = reinforcement?.armyGroup.owner.side
      if (!side)
        continue

      emptySidesReinforcementList[side] = false

      if (name && !(name in savedReinforcements))
      {
        hasUnseenIcon = true
        savedReinforcements[name] <- side
        if (!(side in arrivingReinforcementSides))
          arrivingReinforcementSides[side] <- null
      }
    }

    foreach (side, isEmpty in emptySidesReinforcementList)
      if (isEmpty)
        ::ww_turn_off_sector_sprites("Reinforcement", rearZones[::ww_side_val_to_name(side)])
      else
      {
        ::ww_turn_off_sector_sprites("Reinforcement", ::g_world_war.getRearZonesLostBySide(side))
        if (!(side in arrivingReinforcementSides))
          ::ww_turn_on_sector_sprites("Reinforcement", ::g_world_war.getRearZonesOwnedToSide(side), 0)
      }

    foreach (side, value in arrivingReinforcementSides)
      ::ww_turn_on_sector_sprites("Reinforcement", ::g_world_war.getRearZonesOwnedToSide(side), 5000)

    return hasUnseenIcon
  }

  function updateArmyStrenght()
  {
    if (!needUpdateSidesStrenghtView)
      return

    showSidesStrenght()
  }

  function updateAFKData()
  {
    let blk = ::DataBlock()
    ::ww_get_sides_info(blk)
    let sidesBlk = blk?.sides
    if (sidesBlk == null)
      return
    let loseSide = sidesBlk[::SIDE_2.tostring()].afkLoseTimeMsec
      < sidesBlk[::SIDE_1.tostring()].afkLoseTimeMsec
        ? ::SIDE_2 : ::SIDE_1
    let newLoseTime = sidesBlk[loseSide.tostring()].afkLoseTimeMsec
    afkData.isNeedAFKTimer = afkData.loseSide != loseSide || afkData.afkLoseTimeMsec != newLoseTime
    afkData.loseSide = loseSide
    afkData.afkLoseTimeMsec = newLoseTime
    afkData.isMeLost = ::ww_get_player_side() == loseSide
    afkData.haveAccess = ::g_world_war.haveManagementAccessForAnyGroup()
  }

  function destroyAllAFKTimers()
  {
    if(afkLostTimer?.isValid() ?? false)
      afkLostTimer.destroy()
    if(afkCountdownTimer?.isValid() ?? false)
      afkCountdownTimer.destroy()
    if(animationTimer?.isValid() ?? false)
      animationTimer.destroy()
    ::ww_event("AFKTimerStop")
  }

  function updateAFKTimer()
  {
    if(animationTimer && animationTimer.isValid())
      ::Timer(scene, 2, updateAFKTimer, this)
    else if(!::g_world_war.isCurrentOperationFinished() && !::ww_is_operation_paused())
    {
      updateAFKData()
      if (!afkData.isNeedAFKTimer && (afkLostTimer || afkCountdownTimer))
        return

      fillAFKTimer()
    }
    else if(::g_world_war.isCurrentOperationFinished())
      destroyAllAFKTimers()
  }

  function fillAFKTimer()
  {
    destroyAllAFKTimers()
    let afkLostObj = scene.findObject("afk_lost")
    if(::check_obj(afkLostObj))
      afkLostObj.show(false)
    let operStatObj = scene.findObject("wwmap_operation_status")
    if(::check_obj(operStatObj))
      operStatObj.animation = "hide"
    let afkLoseTimeShowSec = (::g_world_war.getSetting("afkLoseTimeShowSec", 0)
      / ::ww_get_speedup_factor()).tointeger()
    let delayTime = max(time.millisecondsToSecondsInt(afkData.afkLoseTimeMsec)
      - ::g_world_war.getOperationTimeSec() - afkLoseTimeShowSec, 0)

    afkLostTimer = ::Timer(scene, delayTime,
      function()
      {
        let needMsgWnd = afkData.haveAccess && afkData.isMeLost
        let textColor = needMsgWnd ? "white" : afkData.isMeLost
          ? "wwTeamEnemyColor" : "wwTeamAllyColor"
        let msgLoc = "".concat(
          ::loc(afkData.isMeLost
            ? "worldwar/operation/myTechnicalDefeatWarning"
            : "worldwar/operation/enemyTechnicalDefeatWarning"),
          ::loc("ui/colon"))

        afkCountdownTimer = ::Timer(scene, 1,
          function()
          {
            let afkObj = scene.findObject("afk_lost")
            let statObj = scene.findObject("wwmap_operation_status")
            let textObj = statObj.findObject("wwmap_operation_status_text")
            let afkLoseTime = time.millisecondsToSecondsInt(afkData.afkLoseTimeMsec)
              - ::g_world_war.getOperationTimeSec()
            if(afkLoseTime <= 0)
              afkCountdownTimer?.destroy()
            let txt = afkLoseTime > 0
              ? "".concat(::colorize(textColor, msgLoc), time.secondsToString(afkLoseTime))
              : ::colorize(textColor, ::loc(afkData.isMeLost
                ? "worldwar/operation/myTechnicalDefeat"
                : "worldwar/operation/enemyTechnicalDefeat"))
            if (needMsgWnd && ::check_obj(textObj))
            {
              textObj.setValue(txt)
              statObj.show(!::ww_is_operation_paused())
              statObj.animation = "show"
            }
            if (!needMsgWnd && ::check_obj(afkObj))
            {
              afkObj.setValue(txt)
              afkObj.show(!::ww_is_operation_paused())
            }
          }, this, true)
        ::ww_event("AFKTimerStart", {needResize = !needMsgWnd})
      }, this)
  }

  function initOperationStatus(sendEvent = true)
  {
    let objStartBox = scene.findObject("wwmap_operation_status")
    if (!::check_obj(objStartBox))
      return

    let objTarget = scene.findObject("operation_status")
    if (!::check_obj(objTarget))
      return

    let isFinished = ::g_world_war.isCurrentOperationFinished()
    let isPaused = ::ww_is_operation_paused()
    local statusText = ""

    if (isFinished)
    {
      let isVictory = ::ww_get_operation_winner() == ::ww_get_player_side()
      statusText = ::loc(isVictory ? "debriefing/victory" : "debriefing/defeat")
      guiScene.playSound(isVictory ? "ww_oper_end_win" : "ww_oper_end_fail")
      objStartBox.show(true)
    }
    else if (isPaused)
    {
      let activationTime = ::ww_get_operation_activation_time()
      objStartBox.show(true)
      if (activationTime)
      {
        if (operationPauseTimer && operationPauseTimer.isValid())
          operationPauseTimer.destroy()

        statusText = getTimeToStartOperationText(activationTime)
        operationPauseTimer = ::Timer(scene, 1,
          @() fullTimeToStartOperation(), this, true)

        clearSavedData()
      }
      else
        statusText = ::loc("debriefing/pause")
    }
    else
    {
      objTarget.show(false)
      return
    }
    objTarget.setValue(statusText)
    objTarget.show(false)

    let copyObjTarget = scene.findObject("operation_status_hidden_copy")
    if (::check_obj(copyObjTarget))
      copyObjTarget.setValue(statusText)

    let objStart = objStartBox.findObject("wwmap_operation_status_text")
    if (!::check_obj(objStart))
    {
      objTarget.setValue(statusText)
      objStartBox.show(false)
      return
    }
    objStart.setValue(statusText)

    objStartBox.animation = "show"

    animationTimer = ::Timer(scene, 2,
      function() {
        objTarget.needAnim = "yes"
        objTarget.show(true)

        objStartBox.animation = "hide"

        ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = 0.6, bhvFunc = "square" })
      },
    this)

    if (sendEvent && isFinished)
      ::ww_event("OperationFinished")
  }

  function fullTimeToStartOperation()
  {
    let activationTime = ::ww_get_operation_activation_time()
    if (activationTime)
      foreach (objName in ["operation_status", "wwmap_operation_status_text"])
      {
        let obj = scene.findObject(objName)
        if (::check_obj(obj))
          obj.setValue(getTimeToStartOperationText(activationTime))
      }
    else
    {
      operationPauseTimer.destroy()
      playFirstObjectiveAnimation()
    }
  }

  function getTimeToStartOperationText(activationTime)
  {
    let activationMillis = activationTime - get_charserver_time_millisec()
    if (activationMillis <= 0)
      return ""

    let activationSec = time.millisecondsToSecondsInt(activationMillis)
    if (activationSec == 0)
      return ::loc("debriefing/pause")

    let timeToActivation = ::loc("worldwar/activationTime",
      {text = time.hoursToString(time.secondsToHours(activationSec), false, true)})
    return ::loc("debriefing/pause") + ::loc("ui/parentheses/space",
      {text = timeToActivation})
  }

  function onEventWWChangedDebugMode(params)
  {
    updatePage()
  }

  function onEventWWMapArmySelected(params)
  {
    setCurrentSelectedObject(params.armyType, params)
  }

  function onEventWWMapSelectedReinforcement(params)
  {
    setCurrentSelectedObject(mapObjectSelect.REINFORCEMENT, params)
  }

  function onEventWWMapAirfieldSelected(params)
  {
    let tabsObj = scene.findObject("reinforcement_pages_list")
    if (tabsObj.getValue() != 2)
    {
      tabsObj.setValue(2)
      onReinforcementTabChange(tabsObj)
    }
    setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapAirfieldFormationSelected(params)
  {
    setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapAirfieldCooldownSelected(params)
  {
    setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapClearSelection(params)
  {
    setCurrentSelectedObject(mapObjectSelect.NONE)
  }

  function onEventWWLoadOperation(params = {})
  {
    updateSecondaryBlockTab(::g_ww_map_reinforcement_tab_type.REINFORCEMENT)
    needReindforcementsUpdate = true

    setCurrentSelectedObject(currentSelectedObject)
    markMainObjectiveZones()
    initOperationStatus()
    updateAFKTimer()

    mapAirfields.updateMapIcons()

    onSecondsUpdate(null, 0)
    startRequestNewLogsTimer()
  }

  function startRequestNewLogsTimer()
  {
    if (updateLogsTimer)
      return

    updateLogsTimer = ::Timer(scene, WW_LOG_REQUEST_DELAY,
      function()
      {
        updateLogsTimer = null
        local logHandler = null
        if (currentOperationInfoTabType &&
            currentOperationInfoTabType == ::g_ww_map_info_type.LOG)
          logHandler = mainBlockHandler

        ::g_ww_logs.requestNewLogs(WW_LOG_EVENT_LOAD_AMOUNT, false, logHandler)
      }, this, false)
  }

  function onEventWWMapSelectedBattle(params)
  {
    let wwBattle = ::getTblValue("battle", params, ::WwBattle())
    openBattleDescriptionModal(wwBattle)
  }

  function openBattleDescriptionModal(wwBattle)
  {
    ::gui_handlers.WwBattleDescription.open(wwBattle)
  }

  function onEventWWSelectedReinforcement(params)
  {
    let mapObj = scene.findObject("worldwar_map")
    if (!::checkObj(mapObj))
      return

    let name = ::getTblValue("name", params, "")
    if (::u.isEmpty(name))
      return

    ::ww_gui_bhv.worldWarMapControls.selectedReinforcement.call(::ww_gui_bhv.worldWarMapControls, mapObj, name)
  }

  function onEventMyStatsUpdated(params)
  {
    updateToBattleButton()
  }

  function onEventSquadSetReady(params)
  {
    updateToBattleButton()
  }

  function onEventSquadStatusChanged(params)
  {
    updateToBattleButton()
  }

  function onEventQueueChangeState(params)
  {
    updateToBattleButton()
  }

  function onChangeInfoBlockVisibility(obj)
  {
    let blockObj = getObj("ww-right-panel")
    if (!::check_obj(blockObj))
      return

    isRightPanelVisible = !isRightPanelVisible
    blockObj.show(isRightPanelVisible)

    let rootObj = obj.getParent()
    rootObj.collapsed = isRightPanelVisible ? "no" : "yes"
    updateGamercardType()
  }

  function onEventWWShowLogArmy(params)
  {
    let mapObj = guiScene["worldwar_map"]
    if (::check_obj(mapObj))
      ::ww_gui_bhv.worldWarMapControls.selectArmy.call(
        ::ww_gui_bhv.worldWarMapControls, mapObj, params.wwArmy.getName(), true, mapObjectSelect.LOG_ARMY
      )
    showSelectedLogArmy({wwArmy = params.wwArmy})
  }

  function onEventWWNewLogsDisplayed(params)
  {
    let tabObj = getObj("operation_log_block_text")
    if (!::check_obj(tabObj))
      return

    local text = ::loc("mainmenu/log/short")
    if (params.amount > 0)
      text += ::loc("ui/parentheses/space", { text = params.amount })
    tabObj.setValue(text)
  }

  function onEventWWMapArmiesByStatusUpdated(params)
  {
    let armies = ::getTblValue("armies", params, [])
    if (armies.len() == 0)
      return

    updateSecondaryBlockTab(::g_ww_map_reinforcement_tab_type.ARMIES)

    let selectedArmyNames = ::ww_get_selected_armies_names()
    if (!selectedArmyNames.len())
      return

    let army = armies[0]
    if (army.name != selectedArmyNames[0])
      return

    updateSelectedArmy(null, army)
  }

  function onEventWWShowRearZones(params)
  {
    let reinforcement = ::g_world_war.getReinforcementByName(params?.name)
    if (!reinforcement)
      return

    let reinforcementSide = reinforcement.getArmySide()
    let reinforcementType = reinforcement.getOverrideUnitType() || reinforcement.getUnitType()
    local highlightedZones = []
    if (::g_ww_unit_type.isAir(reinforcementType)) {
      let filterType = ::g_ww_unit_type.isHelicopter(reinforcementType) ? "AT_HELIPAD" : "AT_RUNWAY"
      highlightedZones = ::u.map(::g_world_war.getAirfieldsArrayBySide(reinforcementSide, filterType),
        function(airfield) {
          return ::ww_get_zone_name(::ww_get_zone_idx_world(airfield.getPos()))
        })
    }
    else
      highlightedZones = ::g_world_war.getRearZonesOwnedToSide(reinforcementSide)

    ::ww_mark_zones_as_outlined_by_name(highlightedZones)

    if (highlightZonesTimer)
      highlightZonesTimer.destroy()

    highlightZonesTimer = ::Timer(scene, 10,
      function()
      {
        ::ww_clear_outlined_zones()
      }, this, false)
  }

  function onEventWWArmyStatusChanged(params)
  {
    updateArmyActionButtons()
  }

  function onEventWWNewLogsAdded(params)
  {
    if (currentSelectedObject == mapObjectSelect.NONE &&
        params.isStrengthUpdateNeeded)
      updateArmyStrenght()
    if (params.isToBattleUpdateNeeded)
      updateToBattleButton()
  }

  function onEventActiveHandlersChanged(p)
  {
    if (scene.getModalCounter() != 0)
    {
      ::ww_clear_outlined_zones()
      ::ww_update_popuped_armies_name([])
    }
  }

  function onEventWWMapRearZoneSelected(params)
  {
    initPageSwitch(::g_ww_map_info_type.OBJECTIVE.index)

    let tabsObj = scene.findObject("reinforcement_pages_list")
    if (!::check_obj(tabsObj))
      return

    let tabBlockId = ::g_ww_map_reinforcement_tab_type.REINFORCEMENT.tabId
    let tabBlockObj = tabsObj.findObject(tabBlockId)
    if (!::check_obj(tabBlockObj) || !tabBlockObj.isVisible())
      return

    tabsObj.setValue(::g_ww_map_reinforcement_tab_type.REINFORCEMENT.code)
    reinforcementBlockHandler.selectFirstArmyBySide(params.side)
  }

  function onEventMyClanIdChanged(p)
  {
    let wwOperation = getOperationById(::ww_get_operation_id())
    if (!wwOperation)
      return

    let joinCountry = wwOperation.getMyAssignCountry()
    let cantJoinReason = wwOperation.getCantJoinReasonData(joinCountry)

    if (!cantJoinReason.canJoin)
    {
      goBackToHangar()
      ::showInfoMsgBox(cantJoinReason.reasonText)
    }
  }

  function playFirstObjectiveAnimation()
  {
    initPageSwitch(::g_ww_map_info_type.OBJECTIVE.index)

    let objStartBox = scene.findObject("wwmap_operation_objective")
    if (!::check_obj(objStartBox))
      return

    local objTarget = null
    let objectivesBlk = ::g_world_war.getOperationObjectives()
    foreach (dataBlk in objectivesBlk.data)
    {
      if (!dataBlk?.mainObjective)
        continue

      let oType = ::g_ww_objective_type.getTypeByTypeName(dataBlk?.type)
      objTarget = scene.findObject(oType.getNameId(dataBlk, ::ww_get_player_side()))
      if (objTarget)
        break
    }

    if (!::check_obj(objTarget))
      return

    objStartBox.show(true)
    objStartBox.animation = "show"

    let objStart = ::showBtn("objective_anim_start_text", true, objStartBox)
    objStart.setValue(objTarget.getValue())

    let animationFunc = function() {
      objStartBox.animation = "hide"
      ::create_ObjMoveToOBj(scene, objStart, objTarget,
        {time = 0.6, bhvFunc = "square", isTargetVisible = true})
    }

    ::Timer(scene, 3, animationFunc, this)
  }

  function getWndHelpConfig()
  {
    let res = {
      textsBlk = "%gui/worldWar/wwMapHelp.blk"
      objContainer = scene.findObject("root-box")
    }

    let tab1 = currentOperationInfoTabType
    let tab2 = currentReinforcementInfoTabType
    let links = [
      { obj = "topmenu_ww_menu_btn"
        msgId = "hint_topmenu_ww_menu_btn"
      },
      { obj = "topmenu_ww_map_filter_btn"
        msgId = "hint_topmenu_ww_map_filter_btn"
      },
      { obj = "to_battle_button"
        msgId = "hint_to_battle_button"
        text = ::loc("worldwar/help/map/" + (isInQueue() ? "leave_queue_btn" : "to_battle_btn"))
      },
      { obj = ["ww_army_controls_nest"]
        msgId = "hint_ww_army_controls_nest"
      },
      { obj = ["operation_name"]
        msgId = "hint_operation_name"
      },
      { obj = "selected_page_block"
        msgId = "hint_top_block"
        text = ::loc("worldwar/help/map/"
          + (tab1 == ::g_ww_map_info_type.OBJECTIVE ? "objective" : "log"))
      },
      { obj = "reinforcement_block"
        msgId = "hint_reinforcement_block"
        text = ::loc("worldwar/help/map/"
          + ( tab2 == ::g_ww_map_reinforcement_tab_type.COMMANDERS    ? "commanders"
            : tab2 == ::g_ww_map_reinforcement_tab_type.REINFORCEMENT ? "reinforcements"
            : tab2 == ::g_ww_map_reinforcement_tab_type.AIRFIELDS     ? "airfield"
            : "armies"))
      },
      { obj = "content_block_3"
        msgId = "hint_content_block_3"
        text = ::loc("worldwar/help/map/"
          + (isSelectedObjectInfoShown() ? "army_info" : "side_strength"))
      },
      { obj = isRightPanelVisible ? null : "control_block_visibility_switch"
        msgId = "hint_show_right_panel_button"
      }
    ]

    res.links <- links
    return res
  }

  isSelectedObjectInfoShown = @() currentSelectedObject == mapObjectSelect.ARMY ||
    currentSelectedObject == mapObjectSelect.REINFORCEMENT ||
    currentSelectedObject == mapObjectSelect.AIRFIELD ||
    currentSelectedObject == mapObjectSelect.LOG_ARMY

  isOperationActive = @() !::g_world_war.isCurrentOperationFinished()
  isInQueue = @() isOperationActive() && ::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE)

  function onTransportArmyLoad()
  {
    setActionMode(::AUT_TransportLoad)
  }

  function onTransportArmyUnload()
  {
    setActionMode(::AUT_TransportUnload)
  }

  function setActionMode(modeId)
  {
    actionModesManager.trySetActionModeOrCancel(modeId)
    updateButtonsAfterSetMode(actionModesManager.getCurActionModeId() == modeId)
  }

  function updateButtonsAfterSetMode(isEnabled)
  {
    let cancelBtnObj = scene.findObject("cancel_action_mode")
    if (::check_obj(cancelBtnObj))
      cancelBtnObj.enable(isEnabled)
  }

  function onCancelActionMode()
  {
    actionModesManager.setActionMode()
    updateButtonsAfterSetMode(false)
  }
}
