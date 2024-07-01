from "%scripts/dagui_natives.nut" import can_receive_pve_trophy
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let mapPreferencesModal = require("%scripts/missions/mapPreferencesModal.nut")
let mapPreferencesParams = require("%scripts/missions/mapPreferencesParams.nut")
let clustersModule = require("%scripts/clusterSelect.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let openClustersMenuWnd = require("%scripts/onlineInfo/clustersMenuWnd.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getEventPVETrophyName, hasNightGameModes, hasSmallTeamsGameModes } = require("%scripts/events/eventInfo.nut")
let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")
let nightBattlesOptionsWnd = require("%scripts/events/nightBattlesOptionsWnd.nut")
let smallTeamsOptionsWnd = require("%scripts/events/smallTeamsOptionsWnd.nut")
let newIconWidget = require("%scripts/newIconWidget.nut")
let { move_mouse_on_child, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { guiStartModalEvents } = require("%scripts/events/eventsHandler.nut")
let { getCurrentGameModeId, setCurrentGameModeById, getCurrentGameMode, getGameModeById,
  getGameModesPartitions, getFeaturedGameModes, getDebugGameModes, getPveBattlesGameModes,
  getClanBattlesGameModes, markShowingGameModeAsSeen, isGameModeSeen, getFeaturedModesConfig,
  getRequiredUnitTypes, getGameModeItemId, getGameModeEvent
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { getGameModeStartFunction } = require("%scripts/gameModes/gameModeManagerView.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")

dagui_propid_add_name_id("modeId")

gui_handlers.GameModeSelect <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneTplName = "%gui/gameModeSelect/gameModeSelect.tpl"
  shouldBlurSceneBgFn = needUseHangarDof
  needAnimatedSwitchScene = false

  restoreFromModal = false
  newIconWidgetsByGameModeID = {}
  gameModesWithTimer = {}

  filledGameModes = []

  categories = [
    {
      id = "general_game_modes"
      separator = false
      modesGenFunc = "createGameModesView"
      textWhenEmpty = "#mainmenu/gamemodesNotLoaded/desc"
    }
    {
      id = "featured_game_modes"
      separator = true
      modesGenFunc = "createFeaturedModesView"
    }
    {
      id = "debug_game_modes"
      separator = false
      modesGenFunc = "createDebugGameModesView"
    }
  ]

  static basePanelConfig = [
    ES_UNIT_TYPE_AIRCRAFT,
    ES_UNIT_TYPE_TANK,
    ES_UNIT_TYPE_SHIP
  ]

  static function open() {
    loadHandler(gui_handlers.GameModeSelect)
  }

  function getSceneTplView() {
    return { categories = this.categories }
  }

  function initScreen() {
    this.backSceneParams = { eventbusName = "gui_start_mainmenu" }
    this.updateContent()
  }

  function fillModesList() {
    this.filledGameModes.clear()

    foreach (cat in this.categories) {
      let modes = this[cat.modesGenFunc]()
      if (modes.len() == 0) {
        this.filledGameModes.append({
          isEmpty = true
          textWhenEmpty = cat?.textWhenEmpty || ""
          isMode = false
        })
        continue
      }

      if (cat?.separator)
        this.filledGameModes.append({ separator = true, isMode = false })
      this.filledGameModes.extend(modes)
    }

    let placeObj = this.scene.findObject("general_game_modes")
    if (!checkObj(placeObj))
      return

    let data = handyman.renderCached("%gui/gameModeSelect/gameModeBlock.tpl", { block = this.filledGameModes })
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)

    this.setGameModesTimer()
  }

  function updateContent() {
    this.gameModesWithTimer.clear()
    this.newIconWidgetsByGameModeID.clear()

    this.fillModesList()

    this.registerNewIconWidgets()
    this.updateClusters()
    this.updateButtons()
    this.updateEventDescriptionConsoleButton(getCurrentGameMode())

    this.updateSelection()
  }

  function updateSelection() {
    let curGM = getCurrentGameMode()
    if (curGM == null)
      return

    let curGameModeObj = this.scene.findObject("general_game_modes")
    if (!checkObj(curGameModeObj))
      return

    let index = this.filledGameModes.findindex(@(gm) gm.isMode && gm?.hasContent && gm.modeId == curGM.id) ?? -1
    curGameModeObj.setValue(index)
    move_mouse_on_child(curGameModeObj, index)
  }

  function registerNewIconWidgets() {
    foreach (gameMode in this.filledGameModes) {
      if (!gameMode.isMode || !gameMode?.hasContent)
        continue

      let widgetObj = this.scene.findObject(this.getWidgetId(gameMode.id))
      if (!checkObj(widgetObj))
        continue

      let widget = newIconWidget(this.guiScene, widgetObj)
      this.newIconWidgetsByGameModeID[gameMode.id] <- widget
      widget.setWidgetVisible(!isGameModeSeen(gameMode.id))
    }
  }

  function createFeaturedModesView() {
    let view = []
    view.extend(this.getViewArray(getPveBattlesGameModes()))
    view.extend(this.getViewArray(getFeaturedGameModes()))
    view.extend(this.createFeaturedLinksView())
    view.extend(this.getViewArray(getClanBattlesGameModes()))
    return view
  }

  function getViewArray(gameModesArray) {
    let view = []
    // First go all wide featured game modes then - non-wide.
    local numNonWideGameModes = 0
    foreach (isWide in [ true, false ]) {
      while (true) {
        let gameMode = this.getGameModeByCondition(gameModesArray,
          @(gameMode) gameMode.displayWide == isWide) // warning disable: -iterator-in-lambda
        if (gameMode == null)
          break
        if (!isWide)
          ++numNonWideGameModes
        let index = u.find_in_array(gameModesArray, gameMode)
        gameModesArray.remove(index)
        view.append(this.createGameModeView(gameMode))
      }
    }
    this.sortByUnitType(view)
    // Putting a dummy block to show featured links in one line.
    if ((numNonWideGameModes & 1) == 1)
      view.append(this.createGameModeView(null))
    return view
  }

  function sortByUnitType(gameModeViews) {
    gameModeViews.sort(function(a, b) { // warning disable: -return-different-types
      foreach (unitType in unitTypes.types) {
        if (b.isWide != a.isWide)
          return b.isWide <=> a.isWide
        let isAContainsType = a.gameMode.unitTypes.indexof(unitType.esUnitType) != null
        let isBContainsType = b.gameMode.unitTypes.indexof(unitType.esUnitType) != null
        if (! isAContainsType && ! isBContainsType)
          continue
        return isBContainsType <=> isAContainsType
        || b.gameMode.unitTypes.len() <=> a.gameMode.unitTypes.len()
      }
      return 0
    })
  }

  function createDebugGameModesView() {
    let view = []
    let debugGameModes = getDebugGameModes()
    foreach (gameMode in debugGameModes)
      view.append(this.createGameModeView(gameMode))
    return view
  }

  function createFeaturedLinksView() {
    let res = []
    foreach (_idx, mode in getFeaturedModesConfig()) {
      if (!mode.isVisible())
        continue

      let id = getGameModeItemId(mode.modeId)
      let hasNewIconWidget = mode.hasNewIconWidget && !isGameModeSeen(id)
      let newIconWidgetContent = hasNewIconWidget ? newIconWidget.createLayout() : null

      res.append({
        id = id
        modeId = mode.modeId
        hasContent = true
        isMode = true
        text  = mode.text
        textDescription = mode.textDescription
        hasCountries = false
        isWide = mode.isWide
        image = mode.image()
        gameMode = mode
        checkBox = false
        linkIcon = true
        isFeatured = true
        onClick = "onGameModeSelect"
        onHover = "markGameModeSeen"
        newIconWidgetId = this.getWidgetId(id)
        newIconWidgetContent = newIconWidgetContent
        inactiveColor = mode?.inactiveColor ?? @() false
        crossPlayRestricted = mode?.crossPlayRestricted ?? @() false
        crossplayTooltip = mode?.crossplayTooltip
        isCrossPlayRequired = mode?.isCrossPlayRequired ?? @() false
        tooltip = mode?.getTooltipText ?? @() ""
      })
      if (mode?.updateByTimeFunc)
        this.gameModesWithTimer[id] <- mode.updateByTimeFunc
    }
    return res
  }

  function createGameModesView() {
    let gameModesView = []
    let partitions = getGameModesPartitions()
    foreach (partition in partitions) {
      let partitionView = this.createGameModesPartitionView(partition)
      if (partitionView)
        gameModesView.extend(partitionView)
    }
    return gameModesView
  }

  function createGameModeView(gameMode, _separator = false, isNarrow = false) {
    if (gameMode == null)
      return {
        hasContent = false
        isNarrow = isNarrow
        isMode = true
      }

    let countries = this.createGameModeCountriesView(gameMode)
    let isLink = gameMode.displayType.showInEventsWindow
    let event = getGameModeEvent(gameMode)
    let trophyName = getEventPVETrophyName(event)

    let id = getGameModeItemId(gameMode.id)
    let hasNewIconWidget = !isGameModeSeen(id)
    let newIconWidgetContent = hasNewIconWidget ? newIconWidget.createLayout() : null

    let crossPlayRestricted = isMultiplayerPrivilegeAvailable.value && !this.isCrossPlayEventAvailable(event)
    let inactiveColor = !isMultiplayerPrivilegeAvailable.value || crossPlayRestricted

    if (gameMode?.updateByTimeFunc)
      this.gameModesWithTimer[id] <- this.mode.updateByTimeFunc

    let settingsButtons = []
    if (hasSmallTeamsGameModes(event))
      settingsButtons.append({
        settingsButtonClick = "onSmallTeams"
        settingsButtonTooltip = loc("game_mode_settings")
        settingsButtonImg = "#ui/gameuiskin#slot_modifications.svg"
      })
    if (hasNightGameModes(event))
      settingsButtons.append({
        settingsButtonClick = "onNightBattles"
        settingsButtonTooltip = loc("night_battles")
        settingsButtonImg = "#ui/gameuiskin#night_battles.svg"
      })
    if (this.isShowMapPreferences(event))
      settingsButtons.append({
        settingsButtonClick = "onMapPreferences"
        settingsButtonTooltip = mapPreferencesParams.getPrefTitle(event)
        settingsButtonImg = "#ui/gameuiskin#btn_like_dislike.svg"
      })
    if (!isLink && ::events.isEventNeedInfoButton(event))
      settingsButtons.append({
        settingsButtonClick = "onEventDescription"
        settingsButtonTooltip = loc("mainmenu/titleEventDescription")
        settingsButtonImg = "#ui/gameuiskin#country_0.svg"
      })

    return {
      id = id
      modeId = gameMode.id
      hasContent = true
      isMode = true
      isConsoleBtn = showConsoleButtons.value
      text = gameMode.text
      getEvent = gameMode?.getEvent
      textDescription = getTblValue("textDescription", gameMode, null)
      tooltip = gameMode.getTooltipText()
      hasCountries = countries.len() != 0
      countries = countries
      isCurrentGameMode = gameMode.id == getCurrentGameModeId()
      isWide = gameMode.displayWide
      isNarrow = isNarrow
      image = gameMode.image
      videoPreview = gameMode.videoPreview
      checkBox = !isLink
      linkIcon = isLink
      newIconWidgetId = this.getWidgetId(id)
      newIconWidgetContent = newIconWidgetContent
      isFeatured = true
      onClick = "onGameModeSelect"
      onHover = "markGameModeSeen"
      // Used to easily backtrack corresponding game mode.
      gameMode = gameMode
      inactiveColor = (gameMode?.inactiveColor ?? @() false)() || inactiveColor
      crossPlayRestricted = crossPlayRestricted
      crossplayTooltip = this.getRestrictionTooltipText(event)
      isCrossPlayRequired = crossplayModule.needShowCrossPlayInfo() && !::events.isEventPlatformOnlyAllowed(event)
      eventTrophyImage = this.getTrophyMarkUpData(trophyName)
      isTrophyReceived = trophyName == "" ? false : !can_receive_pve_trophy(-1, trophyName)
      settingsButtons
    }
  }

  function getRestrictionTooltipText(event) {
    if (!isMultiplayerPrivilegeAvailable.value)
      return loc("xbox/noMultiplayer")

    if (!crossplayModule.needShowCrossPlayInfo()) //No need tooltip on other platforms
      return null

    //Always send to other platform if enabled
    //Need to notify about it
    if (crossplayModule.isCrossPlayEnabled())
      return loc("xbox/crossPlayEnabled")

    //If only platform - no need to notify
    if (::events.isEventPlatformOnlyAllowed(event))
      return null

    //Notify that crossplay is strongly required
    return loc("xbox/crossPlayRequired")
  }

  function isCrossPlayEventAvailable(event) {
    return crossplayModule.isCrossPlayEnabled()
           || ::events.isEventPlatformOnlyAllowed(event)
  }

  function getWidgetId(gameModeId) {
    return $"{gameModeId}_widget"
  }

  function getTrophyMarkUpData(trophyName) {
    if (u.isEmpty(trophyName))
      return null

    let trophyItem = findItemById(trophyName, itemType.TROPHY)
    if (!trophyItem)
      return null

    return trophyItem.getNameMarkup(0, false)
  }

  function createGameModeCountriesView(gameMode) {
    let res = []
    local countries = gameMode.countries
    if (!countries.len() || countries.len() >= getCrewsList().len())
      return res

    local needShowLocked = false
    if (countries.len() >= 0.7 * getCrewsList().len()) {
      let lockedCountries = []
      foreach (countryData in getCrewsList()) {
        let country = countryData.country
        if (!isInArray(country, countries))
          lockedCountries.append(country)
      }

      needShowLocked = true
      countries = lockedCountries
    }

    foreach (country in countries)
      res.append({ img = getCountryIcon(country, false, needShowLocked) })
    return res
  }

  function createGameModesPartitionView(partition) {
    if (partition.gameModes.len() == 0)
      return null

    let gameModes = partition.gameModes
    let needEmptyGameModeBlocks = !!u.search(gameModes, @(gm) !gm.displayWide)
    let view = []
    foreach (_idx, esUnitType in this.basePanelConfig) {
      let gameMode = this.chooseGameModeEsUnitType(gameModes, esUnitType, this.basePanelConfig)
      if (gameMode)
        view.append(this.createGameModeView(gameMode, false, true))
      else if (needEmptyGameModeBlocks)
        view.append(this.createGameModeView(null, false, true))
    }

    return view
  }

  /**
   * Find appropriate game mode from array and returns it.
   * If game mode is not null, it will be removed from array.
   */
  function chooseGameModeEsUnitType(gameModes, esUnitType, esUnitTypesFilter) {
    return this.getGameModeByCondition(gameModes,
      @(gameMode) u.max(getRequiredUnitTypes(gameMode).filter(
        @(esUType) isInArray(esUType, esUnitTypesFilter))) == esUnitType)
  }

  function getGameModeByCondition(gameModes, conditionFunc) {
    return u.search(gameModes, conditionFunc)
  }

  function onGameModeSelect(obj) {
    this.markGameModeSeen(obj)
    let gameModeView = u.search(this.filledGameModes, @(gm) gm.isMode && gm?.hasContent && gm.modeId == obj.modeId)
    this.performGameModeSelect(gameModeView.gameMode)
  }

  function performGameModeSelect(gameMode) {
    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    if (gameMode?.diffCode == DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return

    let event = getGameModeEvent(gameMode)
    if (event && !this.isCrossPlayEventAvailable(event)) {
      checkAndShowCrossplayWarning(@() showInfoMsgBox(loc("xbox/actionNotAvailableCrossNetworkPlay")))
      return
    }

    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.goBack()

      let startFunction = getGameModeStartFunction(gameMode?.id ?? gameMode?.modeId)
      if (startFunction != null)
        startFunction(gameMode)
      else if (gameMode?.displayType?.showInEventsWindow)
        guiStartModalEvents({ event = event?.name })
      else
        setCurrentGameModeById(gameMode.modeId, true)
    })
  }

  function markGameModeSeen(obj) {
    if (!obj?.id || isGameModeSeen(obj.id))
      return

    let widget = getTblValue(obj.id, this.newIconWidgetsByGameModeID)
    if (!widget)
      return

    markShowingGameModeAsSeen(obj.id)
    widget.setWidgetVisible(false)
  }

  function onGameModeGamepadSelect(obj) {
    let val = obj.getValue()
    if (val < 0 || val >= obj.childrenCount())
      return

    let gmView = this.filledGameModes[val]
    let modeObj = this.scene.findObject(gmView.id)

    this.markGameModeSeen(modeObj)
    this.updateEventDescriptionConsoleButton(gmView.gameMode)
  }

  function onOpenClusterSelect(obj) {
    openClustersMenuWnd(obj)
  }

  function onEventClusterChange(_params) {
    this.updateClusters()
  }

  function updateClusters() {
    clustersModule.updateClusters(this.scene.findObject("cluster_select_button"))
  }

  function onClusterSelectActivate(obj) {
    let value = obj.getValue()
    let childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (checkObj(childObj))
      this.onOpenClusterSelect(childObj)
  }

  function onGameModeActivate(obj) {
    let value = getObjValidIndex(obj)
    if (value < 0)
      return

    this.performGameModeSelect(this.filledGameModes[value].gameMode)
  }

  function onEventDescription(obj) {
    this.openEventDescription(getGameModeById(obj.modeId))
  }

  function onGamepadEventDescription(_obj) {
    let gameModesObject = this.getObj("general_game_modes")
    if (!checkObj(gameModesObject))
      return

    let value = gameModesObject.getValue()
    if (value < 0)
      return

    this.openEventDescription(this.filledGameModes[value].gameMode)
  }

  function openEventDescription(gameMode) {
    let event = getGameModeEvent(gameMode)
    if (event != null) {
      this.restoreFromModal = true
      ::events.openEventInfo(event)
    }
  }

  function updateEventDescriptionConsoleButton(gameMode) {
    showObjById("event_description_console_button", gameMode != null
      && gameMode?.forClan
      && showConsoleButtons.value
      && isMultiplayerPrivilegeAvailable.value, this.scene
    )
    showObjById("night_battles_console_button", showConsoleButtons.value
      && hasNightGameModes(gameMode?.getEvent()), this.scene)

    let prefObj = showObjById("map_preferences_console_button",
      this.isShowMapPreferences(gameMode?.getEvent()) && showConsoleButtons.value,
      this.scene)

    if (!checkObj(prefObj))
      return

    prefObj.setValue(mapPreferencesParams.getPrefTitle(gameMode?.getEvent()))
    prefObj.modeId = gameMode?.id
  }

  function onEventCurrentGameModeIdChanged(_p) { this.updateContent() }
  function onEventGameModesUpdated(_p) { this.updateContent() }
  function onEventWWLoadOperation(_p) { this.updateContent() }
  function onEventWWStopWorldWar(_p) { this.updateContent() }
  function onEventWWGlobalStatusChanged(_p) { this.updateContent() }
  function onEventCrossPlayOptionChanged(_p) { this.updateContent() }
  function onEventXboxMultiplayerPrivilegeUpdated(_p) { this.updateContent() }

  function updateButtons() {
    let wikiLinkBtn = showObjById("wiki_link", hasFeature("AllowExternalLink"), this.scene)
    wikiLinkBtn.link = getCurCircuitOverride("wikiMatchmakerURL", loc("url/wiki_matchmaker"))
  }

  function setGameModesTimer() {
    let timerObj = this.scene.findObject("game_modes_timer")
    if (checkObj(timerObj))
      timerObj.setUserData(this.gameModesWithTimer.len() ? this : null)
  }

  function onTimerUpdate(_obj, _dt) {
    foreach (gameModeId, updateFunc in this.gameModesWithTimer) {
      updateFunc(this.scene, gameModeId)
    }
  }

  function isShowMapPreferences(curEvent) {
    return hasFeature("MapPreferences") && !isMeNewbie()
      && isMultiplayerPrivilegeAvailable.value
      && mapPreferencesParams.hasPreferences(curEvent)
      && ((curEvent?.maxDislikedMissions ?? 0) > 0 || (curEvent?.maxBannedMissions ?? 0) > 0)
  }

  function onMapPreferences(obj) {
    let curEvent = obj?.modeId != null
      ? getGameModeById(obj.modeId)?.getEvent()
      : getCurrentGameMode()?.getEvent()
    checkSquadUnreadyAndDo(
      Callback(@() mapPreferencesModal.open({ curEvent = curEvent }), this),
      null, this.shouldCheckCrewsReady)
  }

  onNightBattles = @(obj) nightBattlesOptionsWnd(obj?.modeId)
  onSmallTeams = @(obj) smallTeamsOptionsWnd(obj?.modeId)
}
