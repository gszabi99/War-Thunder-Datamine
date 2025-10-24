from "%scripts/dagui_library.nut" import *
from "%scripts/events/eventsConsts.nut" import UnitRelevance

let { isPC } = require("%sqstd/platform.nut")
let { EDifficulties } = require("%appGlobals/ranks_common_shared.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let RB_GM_TYPE = require("%scripts/gameModes/rbGmTypes.nut")
let { broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION
} = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isCrossPlayEnabled, needShowCrossPlayInfo } = require("%scripts/social/crossplay.nut")
let { getFirstChosenUnitType } = require("%scripts/firstChoice/firstChoice.nut")
let { isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { hasMultiplayerRestritionByBalance } = require("%scripts/user/balance.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { getEventDisplayType, isEventForClan, isEventForNewbies } = require("%scripts/events/eventInfo.nut")
let { getCurSlotbarUnit } = require("%scripts/slotbar/slotbarState.nut")
let { getNextNewbieEvent, getUnitTypeByNewbieEventId, isMeNewbie } = require("%scripts/myStats.nut")
let { g_event_display_type } = require("%scripts/events/eventDisplayType.nut")
let { isWorldWarEnabled, canPlayWorldwar } = require("%scripts/globalWorldWarScripts.nut")
let { deferOnce } = require("dagor.workcycle")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { isQueueActive, findQueue, checkQueueType } = require("%scripts/queue/queueState.nut")
let { get_game_mode } = require("mission")






















local userGameModeId = null
local currentGameModeId = null
let gameModeById = {}
let gameModes = []

local seenShowingGameModesInited = false
let isSeenByGameModeId = {}

const SEEN_MODES_SAVE_PATH = "seen/gameModes"

let queueMask = QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE

let gameModeSelectPartitionsData = [
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

let getGameModeItemId = @(gameModeId) $"game_mode_item_{gameModeId}"

let defaultSeenGameModeIDs = ["air_arcade",
  "air_realistic",
  "tank_event_in_random_battles_arcade",
  "tank_event_in_random_battles_historical",
  "clan_battles_1_e",
  "clan_battles_2_e",
  "custom_mode_fullreal"].map(@(id) getGameModeItemId(id))

let getCurrentGameModeId = @() currentGameModeId

let getUserGameModeId = @() userGameModeId
let setUserGameModeId = @(id) userGameModeId = id




let getGameModeById = @(id) gameModeById?[id]

function setCurrentGameModeId(id, save, isUserSelected = false) {
  if (!events.isEventsLoaded())
    return

  if (isUserSelected)
    userGameModeId = id

  if (currentGameModeId == id && !isUserSelected)
    return

  currentGameModeId = id

  if (save)
    saveLocalByAccount("selected_random_battle", currentGameModeId)

  broadcastEvent("CurrentGameModeIdChanged", { isUserSelected = isUserSelected })
}

function setCurrentGameModeById(id, isUserSelected = false) {
  setCurrentGameModeId(id, true, isUserSelected)
}

let featuredModes = [
  {
    
    modeId = "world_war_featured_game_mode"
    text = @() loc("mainmenu/btnWorldwar")
    textDescription = @() ::g_world_war.getPlayedOperationText()
    isWide = @() isMeNewbie() || !isPC
    image = function() {
      let operation = ::g_world_war.getLastPlayedOperation()
      if (operation != null)
        return $"#ui/images/game_modes_tiles/worldwar_active_{(this.isWide() ? "wide" : "thin")}?P1"
      else
        return $"#ui/images/game_modes_tiles/worldwar_live_{(this.isWide() ? "wide" : "thin")}?P1"
    }
    videoPreview = null
    isVisible = @() isWorldWarEnabled()
    isCrossPlayRequired = needShowCrossPlayInfo
    inactiveColor = @() !canPlayWorldwar()
    crossPlayRestricted = @() isMultiplayerPrivilegeAvailable.get() && !isCrossPlayEnabled()
    hasNewIconWidget = true
    updateByTimeFunc = function(scene, objId) {
      let descObj = scene.findObject($"{objId}_text_description")
      if (checkObj(descObj))
        descObj.setValue(::g_world_war.getPlayedOperationText())
    }
  }
  {
    
    modeId = "tss_featured_game_mode"
    text = @() loc("mainmenu/btnTournamentsTSS")
    textDescription = @() null
    isWide = false
    image = @() $"#ui/images/game_modes_tiles/tss_{(this.isWide ? "wide" : "thin")}?P1"
    videoPreview = null
    isVisible = @() hasFeature("Tournaments") && hasFeature("AllowExternalLink")
    hasNewIconWidget = true
    isCrossPlayRequired = needShowCrossPlayInfo
    inactiveColor = @() isMeNewbie() || (needShowCrossPlayInfo() && !isCrossPlayEnabled())
      || !isMultiplayerPrivilegeAvailable.get() || hasMultiplayerRestritionByBalance()
    crossPlayRestricted = @() needShowCrossPlayInfo()
      && isMultiplayerPrivilegeAvailable.get()
      && !isCrossPlayEnabled()
  }
  {
    
    modeId = "tournaments_and_event_featured_game_mode"
    text = function () {
      let activeEventsNum = events.getEventsVisibleInEventsWindowCount()
      if (activeEventsNum <= 0)
        return loc("mainmenu/events/eventlist_btn_no_active_events")
      else
        return loc("mainmenu/btnTournamentsAndEvents")

    }
    textDescription = function() { return null }
    isWide = false
    image = function () {
      return $"#ui/images/game_modes_tiles/events_{(this.isWide ? "wide" : "thin")}?P1"
    }
    videoPreview = null
    isVisible = @() hasFeature("Events") && events.getEventsVisibleInEventsWindowCount() > 0
    hasNewIconWidget = false
    inactiveColor = @() !isMultiplayerPrivilegeAvailable.get()
  }
  {
    
    modeId = "custom_battles_featured_game_mode"
    text = function () {
      return loc("mainmenu/btnSkirmish")
    }
    textDescription = function() { return null }
    isWide = false
    image = function () {
      return $"#ui/images/game_modes_tiles/custom_battles_{(this.isWide ? "wide" : "thin")}?P1"
    }
    videoPreview = null
    isVisible = @() true
    hasNewIconWidget = false
    newIconWidgetId = ""
    inactiveColor = @() !isMultiplayerPrivilegeAvailable.get()
      || hasMultiplayerRestritionByBalance()
  }
  
    
  
  
    
  
]

let customGameModesBattles = [
  {
    
    id = "custom_mode_fullreal"
    difficulty = g_difficulty.SIMULATOR
    image = "#ui/images/game_modes_tiles/mixed_event_02_wide?P1"
    type = g_event_display_type.REGULAR
    displayWide = true
    getEventId = function() {
      let curUnit = getCurSlotbarUnit()
      let chapter = events.getChapter("simulation_battles")
      let chapterEvents = chapter ? chapter.getEvents() : []

      local openEventId = null
      if (chapterEvents.len()) {
        let lastPlayedEventId = events.getLastPlayedEvent()?.name
        let lastPlayedEventRelevance = isInArray(lastPlayedEventId, chapterEvents) ?
          events.checkUnitRelevanceForEvent(lastPlayedEventId, curUnit) : UnitRelevance.NONE
        let relevanceList = chapterEvents.map(@(id) { eventId = id,
          relevance = events.checkUnitRelevanceForEvent(id, curUnit) })
        relevanceList.sort(@(a, b) b.relevance <=> a.relevance || a.eventId <=> b.eventId)
        openEventId = relevanceList.findvalue(@(item) lastPlayedEventRelevance >= item.relevance)?.eventId
          ?? lastPlayedEventId
          ?? relevanceList[0].eventId
      }
      return openEventId
    }
    inactiveColor = function() {
      if (!isMultiplayerPrivilegeAvailable.get())
        return true
      let chapter = events.getChapter("simulation_battles")
      return !chapter || chapter.isEmpty()
    }
    isVisible = @() hasFeature("AllModesInRandomBattles") && g_difficulty.SIMULATOR.isAvailable(GM_DOMINATION)
  }
]

  


let getCurrentGameMode = @() gameModeById?[currentGameModeId]

  







function getGameModes(unitType = ES_UNIT_TYPE_INVALID, filterFunc = null) {
  if (unitType == ES_UNIT_TYPE_INVALID && filterFunc == null)
    return gameModes
  let res = []
  foreach (gameMode in gameModes) {
    if (filterFunc != null && !filterFunc(gameMode))
      continue
    if (unitType != ES_UNIT_TYPE_INVALID && !isInArray(unitType, gameMode.unitTypes))
      continue
    res.append(gameMode)
  }
  return res
}

function getRequiredUnitTypes(gameMode) {
  return (gameMode?.reqUnitTypes && gameMode.reqUnitTypes.len() > 0)
    ? gameMode.reqUnitTypes
    : (gameMode?.unitTypes ?? [])
}

  








function getGameModeByUnitType(unitType, diffCode = -1, excludeClanGameModes = false) {
  local bestGameMode
  foreach (gameMode in gameModes) {
    if (gameMode.displayType != g_event_display_type.RANDOM_BATTLE)
      continue
    let checkedUnitTypes = getRequiredUnitTypes(gameMode)

    if (!isInArray(unitType, checkedUnitTypes))
      continue
    if (excludeClanGameModes && gameMode.forClan)
      continue
    if (diffCode < 0) {
      if (bestGameMode == null || gameMode.diffCode < bestGameMode.diffCode)
        bestGameMode = gameMode
    }
    else if (gameMode.diffCode == diffCode) {
      bestGameMode = gameMode
      break
    }
  }
  return bestGameMode
}

function getGameModesPartitions() {
  let partitions = []
  foreach (partitionData in gameModeSelectPartitionsData) {
    let { forClan, diffCode, skipFeatured, skipEnableOnDebug } = partitionData
    let partition = {
      separator = forClan
      gameModes = getGameModes(
        ES_UNIT_TYPE_INVALID,
        function (gameMode) {
          let checkForClan = gameMode.forClan == forClan
          let checkDiffCode = diffCode == -1 || gameMode.diffCode == diffCode
          let checkSkipFeatured = !skipFeatured || gameMode.displayType != g_event_display_type.FEATURED
          let isPVEBattle = gameMode.displayType == g_event_display_type.PVE_BATTLE
          let checkSkipEnableOnDebug = !skipEnableOnDebug || !gameMode.enableOnDebug
          return checkForClan && checkDiffCode && checkSkipFeatured
            && checkSkipEnableOnDebug && !isPVEBattle && !gameMode.forClan
        }
      )
    }
    
    
    if (diffCode == -1) {
      partition.gameModes.sort(function (gm1, gm2) {
        return events.diffCodeCompare(gm1.diffCode, gm2.diffCode)
      })
    }
    partitions.append(partition)
  }
  return partitions
}

function getFeaturedGameModes() {
  return getGameModes(ES_UNIT_TYPE_INVALID, function (gameMode) {
    return gameMode.displayType == g_event_display_type.FEATURED && !gameMode.enableOnDebug
  })
}

function getDebugGameModes() {
  return getGameModes(ES_UNIT_TYPE_INVALID, function (gameMode) {
    return gameMode.enableOnDebug
  })
}

function getPveBattlesGameModes() {
  return getGameModes(ES_UNIT_TYPE_INVALID, function (gameMode) {
    return gameMode.displayType == g_event_display_type.PVE_BATTLE && !gameMode.enableOnDebug
  })
}

function getClanBattlesGameModes() {
  return getGameModes(ES_UNIT_TYPE_INVALID, function (gameMode) {
    return gameMode.forClan && !gameMode.enableOnDebug
  })
}

  






function findCurrentGameModeId(ignoreLocalProfile = false, preferredDiffCode = -1) {
  
  let queue = findQueue(null, queueMask, true)
  if (queue && (queue.name in gameModeById))
    return queue.name

  local idFromAccount = null
  local unitType = ES_UNIT_TYPE_INVALID
  if (!ignoreLocalProfile && isProfileReceived.get()) {
    
    idFromAccount = loadLocalByAccount("selected_random_battle", null)
    if (idFromAccount in gameModeById)
      return idFromAccount

    
    
    unitType = getUnitTypeByNewbieEventId(idFromAccount)
    if (unitType != ES_UNIT_TYPE_INVALID) {
      local gameMode = null
      if (preferredDiffCode != -1)
        gameMode = getGameModeByUnitType(unitType, preferredDiffCode, true)
      if (gameMode == null)
        gameMode = getGameModeByUnitType(unitType, -1, true)
      if (gameMode != null)
        return gameMode.id
    }
  }

  
  let event = getNextNewbieEvent(null, null, true)
  let idFromEvent = getTblValue("name", event, null)
  if (idFromEvent in gameModeById)
    return idFromEvent

  
  let unit = getCurSlotbarUnit()
  if (unitType == ES_UNIT_TYPE_INVALID && unit != null)
      unitType = getEsUnitType(unit)

  
  
  let firstUnitType = getFirstChosenUnitType(ES_UNIT_TYPE_INVALID)
  if (unitType == ES_UNIT_TYPE_INVALID
      && firstUnitType != ES_UNIT_TYPE_INVALID
      && isMeNewbie())
    unitType = firstUnitType

  
  local gameModeByUnitType = null
  if (preferredDiffCode != -1)
    gameModeByUnitType = getGameModeByUnitType(unitType, preferredDiffCode, true)
  if (gameModeByUnitType == null)
    gameModeByUnitType = getGameModeByUnitType(unitType, -1, true)
  let idFromUnitType = gameModeByUnitType != null ? gameModeByUnitType.id : null
  if (idFromUnitType != null)
    return idFromUnitType

  
  
  if (gameModes.len() > 0)
    return gameModes[0].id

  
  return null
}

function updateCurrentGameModeId() {
  let curGameModeId = findCurrentGameModeId()
  if (curGameModeId != null) {
    
    let save = curGameModeId == null && events.isEventsLoaded()
    setCurrentGameModeId(curGameModeId, save)
  }
}

function clearGameModes() {
  gameModes.clear()
  gameModeById.clear()
}

function appendGameMode(gameMode, isTempGameMode = false) {
  gameModeById[gameMode.id] <- gameMode
  if (isTempGameMode)
    return gameMode

  gameModes.append(gameMode)
  return gameMode
}

function getGameModeEvent(gm) {
  if (gm?.getEvent)
    return gm.getEvent()

  return gm?.getEventId ? events.getEvent(gm.getEventId()) : null
}

function getUnitTypesByGameMode(gameMode, isOnlyAvailable = true, needReqUnitType = false) {
  if (!gameMode)
    return []

  let filteredUnitTypes = unitTypes.types.filter(@(unitType) isOnlyAvailable ? unitType.isAvailable() : unitType)
  if (gameMode.type != RB_GM_TYPE.EVENT)
    return filteredUnitTypes.map(@(unitType) unitType.esUnitType)

  let event = getGameModeEvent(gameMode)
  return filteredUnitTypes
    .filter(@(unitType) needReqUnitType ? events.isUnitTypeRequired(event, unitType.esUnitType)
      : events.isUnitTypeAvailable(event, unitType.esUnitType))
    .map(@(unitType) unitType.esUnitType)
}

function createEventGameMode(event, isTempGameMode = false) {
  if (!event)
    return

  let isForClan = isEventForClan(event)
  if (isForClan && !hasFeature("Clans"))
    return

  let gameMode = {
    id = event.name
    source = event
    eventForSquad = null
    modeId = event.name
    type = RB_GM_TYPE.EVENT
    text = events.getEventNameText(event)
    diffCode = events.getEventDiffCode(event)
    ediff = events.getEDiffByEvent(event)
    image = events.getEventTileImageName(event, events.isEventDisplayWide(event))
    videoPreview = hasFeature("VideoPreview") ? events.getEventPreviewVideoName(event, events.isEventDisplayWide(event)) : null
    displayType = getEventDisplayType(event)
    forClan = isForClan
    countries = events.getAvailableCountriesByEvent(event)
    displayWide = events.isEventDisplayWide(event)
    enableOnDebug = events.isEventEnableOnDebug(event)
    getEvent = function() { return (g_squad_manager.isNotAloneOnline() && this.eventForSquad) || event }
    unitTypes = null
    reqUnitTypes = null
    inactiveColor = null
  }
  gameMode.unitTypes = getUnitTypesByGameMode(gameMode, false)
  let reqUnitTypes = getUnitTypesByGameMode(gameMode, false, true)
  gameMode.reqUnitTypes = reqUnitTypes
  gameMode.inactiveColor = function() {
    local inactiveColor = !events.checkEventFeature(event, true)

    if (!inactiveColor)
      foreach (esUnitType in reqUnitTypes) {
        inactiveColor = !unitTypes.getByEsUnitType(esUnitType).isAvailable()
        if (inactiveColor)
          break
      }

    return inactiveColor
  }
  return appendGameMode(gameMode, isTempGameMode)
}

function createCustomGameMode(gm) {
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
    getEventId = @() gm?.getEventId()
    getEvent = @() events.getEvent(gm?.getEventId())
  }
  return appendGameMode(gameMode)
}

function updateGameModes() {
  clearGameModes()

  let newbieGmByUnitType = {}
  foreach (unitType in unitTypes.types) {
    let event = getNextNewbieEvent(null, unitType.esUnitType, false)
    if (event)
      newbieGmByUnitType[unitType.esUnitType] <- createEventGameMode(event)
  }

  foreach (dm in customGameModesBattles) {
    if (!("isVisible" in dm) || dm.isVisible())
      createCustomGameMode(dm)
  }

  foreach (eventId in events.getEventsForGcDrawer()) {
    let event = events.getEvent(eventId)
    local skip = false
    local hasNewbieEvent = false
    foreach (unitType, newbieGm in newbieGmByUnitType) {
      if (!(events.isUnitTypeAvailable(event, unitType) && events.isUnitTypeRequired(event, unitType, true)))
        continue
      hasNewbieEvent = true
      if (events.getEventDiffCode(event) != newbieGm.diffCode)
        break
      if (isEventForNewbies(event))
        newbieGm.eventForSquad = event

      skip = true
      break
    }
    if (skip)
      continue

    let gm = createEventGameMode(event)
    if (hasNewbieEvent)
      gm.inactiveColor = @() true
  }

  broadcastEvent("GameModesUpdated")
}


function initShowingGameModesSeen() {
  if (seenShowingGameModesInited)
    return true

  if (!isLoggedIn.get())
    return false

  let blk = loadLocalByAccount(SEEN_MODES_SAVE_PATH, DataBlock())
  for (local i = 0; i < blk.paramCount(); i++) {
    let id = blk.getParamName(i)
    isSeenByGameModeId[id] <- blk.getParamValue(i)
  }

  foreach (gmId in defaultSeenGameModeIDs)
    if (!(gmId in isSeenByGameModeId))
      isSeenByGameModeId[gmId] <- true

  seenShowingGameModesInited = true

  broadcastEvent("ShowingGameModesUpdated")

  return true
}

function getAllVisibleGameModes() {
  let gameModePartitions = getGameModesPartitions()
  let res = []
  foreach (partition in gameModePartitions)
    res.extend(partition.gameModes)

  res.extend(getPveBattlesGameModes())
  res.extend(getFeaturedGameModes())
  res.extend(getDebugGameModes())
  return res
}

function saveSeenGameModes() {
  if (!seenShowingGameModesInited)
    return 

  let blk = DataBlock()
  foreach (gameMode in getAllVisibleGameModes()) {
    let id = getGameModeItemId(gameMode.id)
    if (id in isSeenByGameModeId)
      blk[id] = isSeenByGameModeId[id]
  }

  foreach (mode in featuredModes) {
    let id = getGameModeItemId(mode.modeId)
    if (id in isSeenByGameModeId)
      blk[id] = isSeenByGameModeId[id]
  }

  saveLocalByAccount(SEEN_MODES_SAVE_PATH, blk)
}

function markShowingGameModeAsSeen(gameModeId) {
  isSeenByGameModeId[gameModeId] <- true
  saveSeenGameModes()
  broadcastEvent("ShowingGameModesUpdated")
}

let isGameModeSeen = @(gameModeId) isSeenByGameModeId?[gameModeId] ?? false

function getUnseenGameModeCount() {
  local unseenGameModesCount = 0
  foreach (gameMode in getAllVisibleGameModes())
    if (!isGameModeSeen(getGameModeItemId(gameMode.id)))
      unseenGameModesCount++

  foreach (mode in featuredModes)
    if (mode.hasNewIconWidget && mode.isVisible() && !isGameModeSeen(getGameModeItemId(mode.modeId)))
      unseenGameModesCount++

  return unseenGameModesCount
}



  


function updateManager() {
  updateGameModes()
  initShowingGameModesSeen()
  updateCurrentGameModeId()
}

function setLeaderGameMode(id) {
  if (!getGameModeById(id))
    createEventGameMode(events.getEvent(id), true)

  setCurrentGameModeId(id, false, false)
}





function isUnitAllowedForGameMode(unit, gameMode = null) {
  if (!unit || unit.disableFlyout)
    return false
  if (gameMode == null)
    gameMode = getCurrentGameMode()
  if (!gameMode)
    return false
  return gameMode.type != RB_GM_TYPE.EVENT
    || events.isUnitAllowedForEvent(getGameModeEvent(gameMode), unit)
}

  




function isPresetValidForGameMode(preset, gameMode = null) {
  let unitNames = getTblValue("units", preset, null)
  if (unitNames == null)
    return false
  if (gameMode == null)
    gameMode = getCurrentGameMode()
  let checkedUnitTypes = getRequiredUnitTypes(gameMode)
  foreach (unitName in unitNames) {
    let unit = getAircraftByName(unitName)
    if (isInArray(unit?.esUnitType, checkedUnitTypes)
      && isUnitAllowedForGameMode(unit, gameMode))
      return true
  }
  return false
}

function findPresetValidForGameMode(countryId, gameMode = null  ) {
  let presets = getTblValue(countryId, ::slotbarPresets.presets, null)
  if (presets == null)
    return null
  foreach (preset in presets) {
    if (isPresetValidForGameMode(preset, gameMode))
      return preset
  }
  return null
}

function getCurrentShopDifficulty() {
  let gameMode = getCurrentGameMode()
  if (gameMode)
    return g_difficulty.getDifficultyByDiffCode(gameMode.diffCode)
  return g_difficulty.ARCADE
}

function getCurrentGameModeEdiff() {
  let gameMode = getCurrentGameMode()
  return gameMode && gameMode.ediff != -1 ? gameMode.ediff : EDifficulties.ARCADE
}

function updateVisibleGameMode() {
  if (g_squad_manager.isSquadLeader())
    return

  if (g_squad_manager.isMeReady()) {
    let id = g_squad_manager.getLeaderGameModeId()
    if (id != "" && id != getCurrentGameModeId())
      setLeaderGameMode(id)
    return
  }

  let id = getUserGameModeId()
  if (id && id != "")
    setCurrentGameModeById(id)
}

addListenersWithoutEnv({
  EventsDataUpdated          = @(_) updateManager()
  MyStatsUpdated             = @(_) updateManager()
  UnitTypeChosen             = @(_) updateManager()
  CrewTakeUnit               = @(_) updateManager()
  function GameLocalizationChanged(_) {
    if (!isLoggedIn.get())
      return
    updateManager()
  }
  function QueueChangeState(p) {
    if (checkQueueType(p?.queue, queueMask) && isQueueActive(p?.queue))
      updateCurrentGameModeId()
  }
  function SignOut(_p) {
    currentGameModeId = null
    clearGameModes()
  }
  SquadDataUpdated = @(_) deferOnce(updateVisibleGameMode)
}, CONFIG_VALIDATION)


function isGameModeWithSpendableWeapons() {
  let mode = get_game_mode()
  return mode == GM_DOMINATION || mode == GM_TOURNAMENT
}

return {
  getCurrentGameModeId
  getUserGameModeId
  setUserGameModeId
  setCurrentGameModeById
  getCurrentGameMode
  getGameModeById
  getGameModeByUnitType
  findCurrentGameModeId
  getGameModesPartitions
  getFeaturedGameModes
  getDebugGameModes
  getPveBattlesGameModes
  getClanBattlesGameModes
  markShowingGameModeAsSeen
  getUnseenGameModeCount
  isGameModeSeen
  getFeaturedModesConfig = @() freeze(featuredModes)
  getRequiredUnitTypes
  getUnitTypesByGameMode
  getGameModeItemId
  isUnitAllowedForGameMode
  getGameModeEvent
  isPresetValidForGameMode
  findPresetValidForGameMode
  getCurrentShopDifficulty
  getCurrentGameModeEdiff
  isGameModeWithSpendableWeapons
}