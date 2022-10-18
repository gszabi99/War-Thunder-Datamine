from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let RB_GM_TYPE = require("%scripts/gameModes/rbGmTypes.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { isCrossPlayEnabled,
  needShowCrossPlayInfo } = require("%scripts/social/crossplay.nut")
let { getFirstChosenUnitType } = require("%scripts/firstChoice/firstChoice.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")

::featured_modes <- [
  {
    modeId = "world_war_featured_game_mode"
    text = @() loc("mainmenu/btnWorldwar")
    textDescription = @() ::g_world_war.getPlayedOperationText()
    startFunction = @() ::g_world_war.openMainWnd()
    isWide = @() ::is_me_newbie() || !is_platform_pc
    image = function() {
        let operation = ::g_world_war.getLastPlayedOperation()
        if (operation != null)
          return "#ui/images/game_modes_tiles/worldwar_active_" + (isWide() ? "wide" : "thin") + ".jpg?P1"
        else
          return "#ui/images/game_modes_tiles/worldwar_live_" + (isWide() ? "wide" : "thin") + ".jpg?P1"
      }
    videoPreview = null
    isVisible = @() ::is_worldwar_enabled()
    isCrossPlayRequired = needShowCrossPlayInfo
    inactiveColor = @() !::g_world_war.canPlayWorldwar()
    crossPlayRestricted = @() isMultiplayerPrivilegeAvailable.value && !isCrossPlayEnabled()
    crossplayTooltip = function() {
      if (!needShowCrossPlayInfo()) //No need tooltip on other platforms
        return null

      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")

      //Always send to other platform if enabled
      //Need to notify about it
      if (isCrossPlayEnabled())
        return loc("xbox/crossPlayEnabled")

      //Notify that crossplay is strongly required
      return loc("xbox/crossPlayRequired")
    }
    hasNewIconWidget = true
    updateByTimeFunc = function(scene, objId) {
      let descObj = scene.findObject(objId + "_text_description")
      if (checkObj(descObj))
        descObj.setValue(::g_world_war.getPlayedOperationText())
    }
  }
  {
    /*TSS*/
    modeId = "tss_featured_game_mode"
    text = @() loc("mainmenu/btnTournamentsTSS")
    textDescription = @() null
    startFunction = function() {
      if (!needShowCrossPlayInfo() || isCrossPlayEnabled())
        openUrl(loc("url/tss_all_tournaments"), false, false)
      else if (!isMultiplayerPrivilegeAvailable.value)
        checkAndShowMultiplayerPrivilegeWarning()
      else if (isMultiplayerPrivilegeAvailable.value && !::xbox_try_show_crossnetwork_message())
        ::showInfoMsgBox(loc("xbox/actionNotAvailableCrossNetworkPlay"))
    }
    isWide = false
    image = @() "#ui/images/game_modes_tiles/tss_" + (isWide ? "wide" : "thin") + ".jpg?P1"
    videoPreview = null
    isVisible = @() !::is_vendor_tencent() && !::is_me_newbie() && hasFeature("Tournaments") && hasFeature("AllowExternalLink")
    hasNewIconWidget = true
    isCrossPlayRequired = needShowCrossPlayInfo
    inactiveColor = @() (needShowCrossPlayInfo() && !isCrossPlayEnabled())
                      || !isMultiplayerPrivilegeAvailable.value
    crossPlayRestricted = @() needShowCrossPlayInfo()
                           && isMultiplayerPrivilegeAvailable.value
                           && !isCrossPlayEnabled()
    crossplayTooltip = function() {
      if (!needShowCrossPlayInfo()) //No need tooltip on other platforms
        return null

      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")

      //Always send to other platform if enabled
      //Need to notify about it
      if (isCrossPlayEnabled())
        return loc("xbox/crossPlayEnabled")

      //Notify that crossplay is strongly required
      return loc("xbox/crossPlayRequired")
    }
  }
  {
    /*events*/
    modeId = "tournaments_and_event_featured_game_mode"
    text = function ()
    {
      let activeEventsNum = ::events.getEventsVisibleInEventsWindowCount()
      if (activeEventsNum <= 0)
        return loc("mainmenu/events/eventlist_btn_no_active_events")
      else
        return loc("mainmenu/btnTournamentsAndEvents")

    }
    textDescription = function() { return null }
    startFunction = function ()
    {
      ::gui_start_modal_events()
    }
    isWide = false
    image = function ()
    {
      return "#ui/images/game_modes_tiles/events_" + (isWide ? "wide" : "thin") + ".jpg?P1"
    }
    videoPreview = null
    isVisible = function ()
    {
      return hasFeature("Events") && ::events.getEventsVisibleInEventsWindowCount() > 0
    }
    hasNewIconWidget = false
    inactiveColor = @() !isMultiplayerPrivilegeAvailable.value
    crossplayTooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")

      return null
    }
  }
  {
    /*custom battles*/
    modeId = "custom_battles_featured_game_mode"
    startFunction = function ()
    {
      if (!isMultiplayerPrivilegeAvailable.value) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      ::gui_start_skirmish()
    }
    text = function ()
    {
      return loc("mainmenu/btnSkirmish")
    }
    textDescription = function() { return null }
    isWide = false
    image = function ()
    {
      return "#ui/images/game_modes_tiles/custom_battles_" + (isWide ? "wide" : "thin") + ".jpg?P1"
    }
    videoPreview = null
    isVisible = function ()
    {
      return !::is_me_newbie() && ::is_custom_battles_enabled()
    }
    hasNewIconWidget = false
    newIconWidgetId = ""
    inactiveColor = @() !isMultiplayerPrivilegeAvailable.value
    crossplayTooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")

      return null
    }
  }
  //{
    /*dynamic campaign*/
  //}
  //{
    /*single missions*/
  //}
]

::custom_game_modes_battles <- [
  {
    id = "custom_mode_fullreal"
    difficulty = ::g_difficulty.SIMULATOR
    image = "#ui/images/game_modes_tiles/mixed_event_02_wide.jpg?P1"
    type = ::g_event_display_type.REGULAR
    displayWide = true
    getEventId = function() {
      let curUnit = ::get_cur_slotbar_unit()
      let chapter = ::events.chapters.getChapter("simulation_battles")
      let chapterEvents = chapter? chapter.getEvents() : []

      local openEventId = null
      if (chapterEvents.len())
      {
        let lastPlayedEventId = ::events.getLastPlayedEvent()?.name
        let lastPlayedEventRelevance = isInArray(lastPlayedEventId, chapterEvents) ?
          ::events.checkUnitRelevanceForEvent(lastPlayedEventId, curUnit) : UnitRelevance.NONE
        let relevanceList = ::u.map(chapterEvents, function(id) {
          return { eventId = id, relevance = ::events.checkUnitRelevanceForEvent(id, curUnit) }
        })
        relevanceList.sort(@(a,b) b.relevance <=> a.relevance || a.eventId <=> b.eventId)
        openEventId = relevanceList.findvalue(@(item) lastPlayedEventRelevance >= item.relevance)?.eventId
          ?? lastPlayedEventId
          ?? relevanceList[0].eventId
      }
      return openEventId
    }
    onBattleButtonClick = @() ::gui_start_modal_events({ event = getEventId() })
    startFunction = function() {
      ::game_mode_manager.setCurrentGameModeById(id, true) //need this for fast start SB battle in next time
      onBattleButtonClick()
    }
    inactiveColor = function() {
      if (!isMultiplayerPrivilegeAvailable.value)
        return true

      let chapter = ::events.chapters.getChapter("simulation_battles")
      return !chapter || chapter.isEmpty()
    }
    isVisible = function() {
      return hasFeature("AllModesInRandomBattles")
             && ::g_difficulty.SIMULATOR.isAvailable(GM_DOMINATION)
             && !::is_me_newbie()
    }
    getTooltipText = function() { return loc("simulator_battles/desc") }
  }
]

::game_mode_select_partitions_data <- [
  {
    diffCode = DIFFICULTY_ARCADE
    forClan = false
    skipFeatured = true
    skipEnableOnDebug = true
  }
  {
    diffCode = DIFFICULTY_REALISTIC
    forClan = false
    skipFeatured = true
    skipEnableOnDebug = true
  }
  {
    diffCode = DIFFICULTY_HARDCORE
    forClan = false
    skipFeatured = true
    skipEnableOnDebug = true
  }
  {
    diffCode = -1
    forClan = true
    skipFeatured = true
    skipEnableOnDebug = true
  }
]

/**
 * Game mode manager incapsulates working
 * with current game mode id and game modes data.
 *
 * Game mode data has following structure:
 * {
 *   id       - string id (eventId for events or id for domination modes)
 *   source   - link to dominationModes item or event
 *   type     - event or dominationModes item
 *   locId    - localization to show in list
 *   modeIdx  - index in ::dominationModes array
 *   diffCode - difficulty code (0, 1, 2...) or -1 if code is invalid
 * }
 *
 * Setting new game mode will cause manager
 * to broadcast "CurrentGameModeIdChanged" event.
 *
 * Manager updates game modes array when (game) events
 * and player stats data is updated.
 */
::GameModeManager <- class
{
  queueMask = QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE
  SEEN_MODES_SAVE_PATH = "seen/gameModes"

  defaultSeenGameModeIDs = ["air_arcade",
                           "air_realistic",
                           "tank_event_in_random_battles_arcade",
                           "tank_event_in_random_battles_historical",
                           "clan_battles_1_e",
                           "clan_battles_2_e",
                           "custom_mode_fullreal"]

  /**
   * Constructor. Subscribes manager to events that
   * require it to update.
   */
  constructor()
  {
    ::add_event_listener("EventsDataUpdated", _onEventsDataUpdated.bindenv(this))
    ::add_event_listener("MyStatsUpdated", _onMyStatsUpdated.bindenv(this))
    ::add_event_listener("UnitTypeChosen", _onUnitTypeChosen.bindenv(this))
    ::add_event_listener("GameLocalizationChanged", _onGameLocalizationChanged.bindenv(this))
    ::add_event_listener("CrewTakeUnit", _onEventCrewTakeUnit.bindenv(this))
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    foreach (idx, id in defaultSeenGameModeIDs)
      defaultSeenGameModeIDs[idx] = getGameModeItemId(id)
  }

  /**
   * Updates current game mode id and game modes array.
   */
  function updateManager()
  {
    _updateGameModes()
    initShowingGameModesSeen()
    _updateCurrentGameModeId()
  }

  //
  // Current game mode ID
  //

  /**
   * Current game mode id getter.
   */
  function getCurrentGameModeId()
  {
    return _currentGameModeId
  }

  /**
   * Sets current game mode by id
   * and saves it in user account.
   */
  function setCurrentGameModeById(id, isUserSelected=false)
  {
    _setCurrentGameModeId(id, true, isUserSelected)
  }

  /**
   * Sets current game mode by index
   * and saves it in user account.
   */
  function setCurrentGameModeByIndex(index, isUserSelected=false)
  {
    if (0 <= index || index < _gameModes.len())
    {
      let gameMode = _gameModes[index]
      _setCurrentGameModeId(gameMode.id, true, isUserSelected)
    }
  }

  //
  // User game mode ID
  //

  /**
   * User game mode id getter.
   */
  function getUserGameModeId()
  {
    return _userGameModeId
  }

  /**
   * Sets user game mode  id.
   */

  function setUserGameModeId(id)
  {
    _userGameModeId = id
  }

  //
  // Game modes
  //

  /**
   * Returns current game mode data.
   */
  function getCurrentGameMode()
  {
    return getTblValue(_currentGameModeId, _gameModeById, null)
  }

  /**
   * Returns game mode data by id.
   */
  function getGameModeById(id)
  {
    return getTblValue(id, _gameModeById, null)
  }

  /**
   * Game modes retrieve method.
   * @param unitType Optional parameter providing method with unit type filter.
   *                 Parameter will be ignored if it set to ES_UNIT_TYPE_INVALID.
   * @param filterFunc Optional filter function with game mode as parameter and
   *                   boolean return type.
   * @return Returns array with available game modes.
   */
  function getGameModes(unitType = ES_UNIT_TYPE_INVALID, filterFunc = null)
  {
    if (unitType == ES_UNIT_TYPE_INVALID && filterFunc == null)
      return _gameModes
    let gameModes = []
    foreach (gameMode in _gameModes)
    {
      if (filterFunc != null && !filterFunc(gameMode))
        continue
      if (unitType != ES_UNIT_TYPE_INVALID && !isInArray(unitType, gameMode.unitTypes))
        continue
      gameModes.append(gameMode)
    }
    return gameModes
  }

  /**
   * Returns game mode by unit type and (optionaly) difficulty.
   * @param unitType Unit type for game mode.
   * @param diffCode Requires game mode to be with specific difficulty.
   *                 Not applied if parameter is below zero and game mode
   *                 with lowest difficulty will be returned.
   * @param excludeClanGameModes Clan game mode will be skipped during search.
   * @return Null if game mode not found.
   */
  function getGameModeByUnitType(unitType, diffCode = -1, excludeClanGameModes = false)
  {
    local bestGameMode
    foreach (gameMode in _gameModes)
    {
      if (gameMode.displayType != ::g_event_display_type.RANDOM_BATTLE)
        continue
      let checkedUnitTypes = getRequiredUnitTypes(gameMode)

      if (!isInArray(unitType, checkedUnitTypes))
        continue
      if (excludeClanGameModes && gameMode.forClan)
        continue
      if (diffCode < 0)
      {
        if (bestGameMode == null || gameMode.diffCode < bestGameMode.diffCode)
          bestGameMode = gameMode
      }
      else if (gameMode.diffCode == diffCode)
      {
        bestGameMode = gameMode
        break
      }
    }
    return bestGameMode
  }

  function getUnitEconomicRankByGameMode(gameMode, unit)
  {
    if (gameMode.type == RB_GM_TYPE.EVENT)
      return ::events.getUnitEconomicRankByEvent(getGameModeEvent(gameMode), unit)
    return unit.getEconomicRank(gameMode.ediff)
  }

  /**
   * Function checks if unit suitable for specified game mode.
   * @param gameMode Gets current game mode if not speficied.
   */
  function isUnitAllowedForGameMode(unit, gameMode = null)
  {
    if (!unit || unit.disableFlyout)
      return false
    if (gameMode == null)
      gameMode = getCurrentGameMode()
    if (!gameMode)
      return false
    return gameMode.type != RB_GM_TYPE.EVENT || ::events.isUnitAllowedForEvent(getGameModeEvent(gameMode), unit)
  }

  /**
   * Returns true if preset has at least
   * one unit allowed for speficied game mode.
   * @param gameMode Gets current game mode if not speficied.
   */
  function isPresetValidForGameMode(preset, gameMode = null)
  {
    let unitNames = getTblValue("units", preset, null)
    if (unitNames == null)
      return false
    if (gameMode == null)
      gameMode = getCurrentGameMode()
    let checkedUnitTypes = ::game_mode_manager.getRequiredUnitTypes(gameMode)
    foreach (unitName in unitNames)
    {
      let unit = ::getAircraftByName(unitName)
      if (isInArray(unit?.esUnitType, checkedUnitTypes)
        && isUnitAllowedForGameMode(unit, gameMode))
        return true
    }
    return false
  }

  function findPresetValidForGameMode(countryId, gameMode = null /* if null then current game mode*/)
  {
    let presets = getTblValue(countryId, ::slotbarPresets.presets, null)
    if (presets == null)
      return null
    foreach (preset in presets)
    {
      if (isPresetValidForGameMode(preset, gameMode))
        return preset
    }
    return null
  }

  /**
   * Attempts to determine current game mode id
   * based on local profile data, current unit, etc...
   * @param ignoreLocalProfile This flag disables attempts to retrieve
   *                           id from local profile.
   * @param preferredDiffCode If specified this difficulty will have highest priority.
   */
  function findCurrentGameModeId(ignoreLocalProfile = false, preferredDiffCode = -1)
  {
    //Step 0. Check current queue for gamemode.
    let queue = ::queues.findQueue(null, queueMask, true)
    if (queue && (queue.name in _gameModeById))
      return queue.name

    local idFromAccount = null
    local unitType = ES_UNIT_TYPE_INVALID
    if (!ignoreLocalProfile && ::g_login.isProfileReceived())
    {
      // Step 1. Attempting to retrieve current game mode id from account.
      idFromAccount = ::loadLocalByAccount("selected_random_battle", null)
      if (idFromAccount in _gameModeById)
        return idFromAccount

      // Step 2. Player's newbie event is may be not longer available.
      //         Attempting to get event with same unit type.
      unitType = ::my_stats.getUnitTypeByNewbieEventId(idFromAccount)
      if (unitType != ES_UNIT_TYPE_INVALID)
      {
        local gameMode = null
        if (preferredDiffCode != -1)
          gameMode = getGameModeByUnitType(unitType, preferredDiffCode, true)
        if (gameMode == null)
          gameMode = getGameModeByUnitType(unitType, -1, true)
        if (gameMode != null)
          return gameMode.id
      }
    }

    // Step 4. Attempting to retrieve current game mode id from newbie event.
    let event = ::my_stats.getNextNewbieEvent(null, null, true)
    let idFromEvent = getTblValue("name", event, null)
    if (idFromEvent in _gameModeById)
      return idFromEvent

    // Step 5. Attempting to get unit type from currently selected unit.
    let unit = ::get_cur_slotbar_unit()
    if (unitType == ES_UNIT_TYPE_INVALID && unit != null)
        unitType = ::get_es_unit_type(unit)

    // Step 6. Newbie event not found. If player is newbie and he has
    //         valid unit type we select easiest game mode.
    let firstUnitType = getFirstChosenUnitType(ES_UNIT_TYPE_INVALID)
    if (unitType == ES_UNIT_TYPE_INVALID
        && firstUnitType != ES_UNIT_TYPE_INVALID
        && ::my_stats.isMeNewbie())
      unitType = firstUnitType

    // Step 8. We have unit type. Selecting easiest game mode.
    local gameModeByUnitType = null
    if (preferredDiffCode != -1)
      gameModeByUnitType = getGameModeByUnitType(unitType, preferredDiffCode, true)
    if (gameModeByUnitType == null)
      gameModeByUnitType = getGameModeByUnitType(unitType, -1, true)
    let idFromUnitType = gameModeByUnitType != null ? gameModeByUnitType.id : null
    if (idFromUnitType != null)
      return idFromUnitType

    // Step 9. Player does not have valid unit type.
    //         Selecting any or nothing.
    if (_gameModes.len() > 0)
      return _gameModes[0].id

    // Step 10. Nothing found.
    return null
  }

  /**
   * Returns index of current game
   * mode in game modes array.
   */
  function getCurrentGameModeIndex()
  {
    return ::find_in_array(_gameModes, getCurrentGameMode(), 0)
  }

  //
  // Private
  //

  _userGameModeId = null
  _currentGameModeId = null
  _gameModeById = {}
  _gameModes = []

  seenShowingGameModesInited = false
  isSeenByGameModeId = {}

  function _setCurrentGameModeId(id, save, isUserSelected=false)
  {
    if(!::events.eventsLoaded)
      return

    if(isUserSelected)
      _userGameModeId = id

    if(_currentGameModeId == id && !isUserSelected)
      return

    _currentGameModeId = id

    if (save)
      ::saveLocalByAccount("selected_random_battle", _currentGameModeId)

    ::broadcastEvent("CurrentGameModeIdChanged", {isUserSelected=isUserSelected})
  }

  function _clearGameModes()
  {
    _gameModes = []
    _gameModeById = {}
  }

  function _appendGameMode(gameMode, isTempGameMode = false)
  {
    _gameModeById[gameMode.id] <- gameMode
    if(isTempGameMode)
      return gameMode

    _gameModes.append(gameMode)
    return gameMode
  }

  function _createEventGameMode(event, isTempGameMode = false)
  {
    if (!event)
       return

    let isForClan = ::events.isEventForClan(event)
    if (isForClan && !hasFeature("Clans"))
      return

    let gameMode = {
      id = event.name
      source = event
      eventForSquad = null
      modeId = event.name
      type = RB_GM_TYPE.EVENT
      text = ::events.getEventNameText(event)
      diffCode = ::events.getEventDiffCode(event)
      ediff = ::events.getEDiffByEvent(event)
      image = ::events.getEventTileImageName(event, ::events.isEventDisplayWide(event))
      videoPreview = hasFeature("VideoPreview") ? ::events.getEventPreviewVideoName(event, ::events.isEventDisplayWide(event)) : null
      displayType = ::events.getEventDisplayType(event)
      forClan = isForClan
      countries = ::events.getAvailableCountriesByEvent(event)
      displayWide = ::events.isEventDisplayWide(event)
      enableOnDebug = ::events.isEventEnableOnDebug(event)

      getEvent = function() { return (::g_squad_manager.isNotAloneOnline() && eventForSquad) || event }
      getTooltipText = function()
      {
        let ev = getEvent()
        return ev ? ::events.getEventDescriptionText(ev, null, true) : ""
      }
      unitTypes = null
      reqUnitTypes = null
      inactiveColor = null
    }
    gameMode.unitTypes = _getUnitTypesByGameMode(gameMode, false)
    let reqUnitTypes = _getUnitTypesByGameMode(gameMode, false, true)
    gameMode.reqUnitTypes = reqUnitTypes
    gameMode.inactiveColor = function() {
      local inactiveColor = !::events.checkEventFeature(event, true)

      if (!inactiveColor)
        foreach(esUnitType in reqUnitTypes)
        {
          inactiveColor = !unitTypes.getByEsUnitType(esUnitType).isAvailable()
          if (inactiveColor)
            break
        }

      return inactiveColor
    }
    return _appendGameMode(gameMode, isTempGameMode)
  }

  function _createCustomGameMode(gm)
  {
    let gameMode = {
      id = gm.id
      source = null
      type = RB_GM_TYPE.CUSTOM
      text = gm.difficulty.getLocName()
      diffCode = gm.difficulty.diffCode
      ediff = gm.difficulty.getEdiff()
      image = gm.image
      linkIcon = getTblValue("linkIcon", gm, false)
      videoPreview = null
      displayType = gm.type
      forClan = false
      countries = []
      displayWide = gm.displayWide
      enableOnDebug = false
      inactiveColor = gm?.inactiveColor ?? @() false
      unitTypes = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_HELICOPTER]
      startFunction = @() gm?.startFunction()
      onBattleButtonClick = @() gm?.onBattleButtonClick()

      getEvent = @() ::events.getEvent(gm?.getEventId())
      getTooltipText = getTblValue("getTooltipText", gm, function() { return "" })
    }
    return _appendGameMode(gameMode)
  }

  function _updateGameModes()
  {
    _clearGameModes()

    let newbieGmByUnitType = {}
    foreach (unitType in unitTypes.types)
    {
      let event = ::my_stats.getNextNewbieEvent(null, unitType.esUnitType, false)
      if (event)
        newbieGmByUnitType[unitType.esUnitType] <- _createEventGameMode(event)
    }

    for (local idx = 0; idx < ::custom_game_modes_battles.len(); idx++)
    {
      let dm = ::custom_game_modes_battles[idx]
      if (!("isVisible" in dm) || dm.isVisible())
            _createCustomGameMode(dm)
    }

    foreach (eventId in ::events.getEventsForGcDrawer()) {
      let event = ::events.getEvent(eventId)
      local skip = false
      foreach (unitType, newbieGm in newbieGmByUnitType) {
        if (::events.isUnitTypeAvailable(event, unitType) && ::events.isUnitTypeRequired(event, unitType, true)) {
          if (::events.getEventDiffCode(event) == newbieGm.diffCode && ::events.isEventForNewbies(event)) {
            newbieGm.eventForSquad = event
          }
          skip = true
          break
        }
      }
      if (!skip)
        _createEventGameMode(event)
    }

    ::broadcastEvent("GameModesUpdated")
  }

  function _updateCurrentGameModeId()
  {
    let currentGameModeId = findCurrentGameModeId()
    if (currentGameModeId != null)
    {
      // This activates saving to profile on first update after profile loaded.
      let save = _currentGameModeId == null && ::events.eventsLoaded
      _setCurrentGameModeId(currentGameModeId, save)
    }
  }

  function _getUnitTypesByGameMode(gameMode,isOnlyAvailable = true, needReqUnitType = false)
  {
    if (!gameMode)
      return []

    let filteredUnitTypes = ::u.filter(unitTypes.types,
      @(unitType) isOnlyAvailable ? unitType.isAvailable() : unitType)
    if (gameMode.type != RB_GM_TYPE.EVENT)
      return ::u.map(filteredUnitTypes, @(unitType) unitType.esUnitType)

    let event = getGameModeEvent(gameMode)
    return ::u.map(
      ::u.filter(filteredUnitTypes,
        @(unitType) needReqUnitType ? ::events.isUnitTypeRequired(event, unitType.esUnitType)
          : ::events.isUnitTypeAvailable(event, unitType.esUnitType)
      ),
      @(unitType) unitType.esUnitType)
  }

  function getGameModesPartitions()
  {
    let partitions = []
    foreach (partitionData in ::game_mode_select_partitions_data)
    {
      let partition = {
        separator = partitionData.forClan
        gameModes = ::game_mode_manager.getGameModes(
          ES_UNIT_TYPE_INVALID,
          (@(partitionData) function (gameMode) {
            let checkForClan = gameMode.forClan == partitionData.forClan
            let checkDiffCode = partitionData.diffCode == -1 || gameMode.diffCode == partitionData.diffCode
            let checkSkipFeatured = !partitionData.skipFeatured || gameMode.displayType != ::g_event_display_type.FEATURED
            let isPVEBattle = gameMode.displayType == ::g_event_display_type.PVE_BATTLE
            let checkSkipEnableOnDebug = !partitionData.skipEnableOnDebug || !gameMode.enableOnDebug
            return checkForClan && checkDiffCode && checkSkipFeatured
              && checkSkipEnableOnDebug && !isPVEBattle && !gameMode.forClan
          })(partitionData)
        )
      }
      // If diff code is not provided
      // sort game modes by difficulty.
      if (partitionData.diffCode == -1)
      {
        partition.gameModes.sort(function (gm1, gm2) {
          return ::events.diffCodeCompare(gm1.diffCode, gm2.diffCode)
        })
      }
      partitions.append(partition)
    }
    return partitions
  }

  function getFeaturedGameModes()
  {
    return getGameModes(ES_UNIT_TYPE_INVALID, function (gameMode) {
      return gameMode.displayType == ::g_event_display_type.FEATURED && !gameMode.enableOnDebug
    })
  }

  function getDebugGameModes()
  {
    return getGameModes(ES_UNIT_TYPE_INVALID, function (gameMode) {
      return gameMode.enableOnDebug
    })
  }

  function getPveBattlesGameModes()
  {
    return getGameModes(ES_UNIT_TYPE_INVALID, function (gameMode) {
      return gameMode.displayType == ::g_event_display_type.PVE_BATTLE && !gameMode.enableOnDebug
    })
  }

  function getClanBattlesGameModes()
  {
    return getGameModes(ES_UNIT_TYPE_INVALID, function (gameMode) {
      return gameMode.forClan && !gameMode.enableOnDebug
    })
  }

  function getGameModeItemId(gameModeId)
  {
    return "game_mode_item_" + gameModeId
  }

  function getGameModeEvent(gm) {
    if (gm?.getEvent)
      return gm.getEvent()

    return gm?.getEventId ? ::events.getEvent(gm.getEventId()) : null
  }

//------------- <New Icon Widget> ----------------------
  function initShowingGameModesSeen()
  {
    if (seenShowingGameModesInited)
      return true

    if (!::g_login.isLoggedIn())
      return false

    let blk = ::loadLocalByAccount(SEEN_MODES_SAVE_PATH, ::DataBlock())
    for (local i = 0; i < blk.paramCount(); i++)
    {
      let id = blk.getParamName(i)
      isSeenByGameModeId[id] <- blk.getParamValue(i)
    }

    foreach (gmId in defaultSeenGameModeIDs)
      if (!(gmId in isSeenByGameModeId))
        isSeenByGameModeId[gmId] <- true

    seenShowingGameModesInited = true

    ::broadcastEvent("ShowingGameModesUpdated")

    return true
  }

  function markShowingGameModeAsSeen(gameModeId)
  {
    isSeenByGameModeId[gameModeId] <- true
    saveSeenGameModes()
    ::broadcastEvent("ShowingGameModesUpdated")
  }

  function getUnseenGameModeCount()
  {
    local unseenGameModesCount = 0
    foreach(gameMode in getAllVisibleGameModes())
      if (!isSeen(getGameModeItemId(gameMode.id)))
        unseenGameModesCount++

    foreach (mode in ::featured_modes)
      if (mode.hasNewIconWidget && mode.isVisible() && !isSeen(getGameModeItemId(mode.modeId)))
        unseenGameModesCount++

    return unseenGameModesCount
  }

  function isSeen(gameModeId)
  {
    return getTblValue(gameModeId, isSeenByGameModeId, false)
  }

  function saveSeenGameModes()
  {
    if (!seenShowingGameModesInited)
      return //data not loaded yet

    let blk = ::DataBlock()
    foreach(gameMode in getAllVisibleGameModes())
    {
      let id = getGameModeItemId(gameMode.id)
      if (id in isSeenByGameModeId)
        blk[id] = isSeenByGameModeId[id]
    }

    foreach (mode in ::featured_modes)
    {
      let id = getGameModeItemId(mode.modeId)
      if (id in isSeenByGameModeId)
        blk[id] = isSeenByGameModeId[id]
    }

    ::saveLocalByAccount(SEEN_MODES_SAVE_PATH, blk)
  }

  function getAllVisibleGameModes()
  {
    let gameModePartitions = ::game_mode_manager.getGameModesPartitions()
    let gameModes = []
    foreach(partition in gameModePartitions)
      gameModes.extend(partition.gameModes)

    gameModes.extend(getPveBattlesGameModes())
    gameModes.extend(getFeaturedGameModes())
    gameModes.extend(getDebugGameModes())
    return gameModes
  }

//------------- </New Icon Widget> ----------------------

  function _onEventsDataUpdated(_params)
  {
    updateManager()
  }

  function _onMyStatsUpdated(_params)
  {
    updateManager()
  }

  function _onUnitTypeChosen(_params)
  {
    updateManager()
  }

  function _onGameLocalizationChanged(_params)
  {
    if (!::g_login.isLoggedIn())
      return
    updateManager()
  }

  function _onEventCrewTakeUnit(_params)
  {
    updateManager()
  }

  function onEventQueueChangeState(p)
  {
    if (::queues.checkQueueType(p?.queue, queueMask) && ::queues.isQueueActive(p?.queue))
      _updateCurrentGameModeId()
  }

  function onEventSignOut(_p)
  {
    _currentGameModeId = null
    _gameModeById.clear()
    _gameModes.clear()
  }

  function getRequiredUnitTypes(gameMode)
  {
    return (gameMode?.reqUnitTypes && gameMode.reqUnitTypes.len() > 0)
        ? gameMode.reqUnitTypes
        : (gameMode?.unitTypes ?? [])
  }

  function setLeaderGameMode(id)
  {
   if (!getGameModeById(id))
     _createEventGameMode(::events.getEvent(id), true)

   ::game_mode_manager._setCurrentGameModeId(id, false, false)
  }

}

::game_mode_manager <- ::GameModeManager()
