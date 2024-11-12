from "%scripts/dagui_library.nut" import *

let { openUrl } = require("%scripts/onlineShop/url.nut")
let { isCrossPlayEnabled,
  needShowCrossPlayInfo } = require("%scripts/social/crossplay.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { hasMultiplayerRestritionByBalance } = require("%scripts/user/balance.nut")
let { guiStartSkirmish } = require("%scripts/missions/startMissionsList.nut")
let { guiStartModalEvents } = require("%scripts/events/eventsHandler.nut")
let { setCurrentGameModeById, getGameModeById, getGameModeEvent } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { killsOnUnitTypes, newbieNextEvent } = require("%scripts/myStats.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isEventPlatformOnlyAllowed } = require("%scripts/events/eventInfo.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isWorldWarEnabled, getCantPlayWorldwarReasonText } = require("%scripts/globalWorldWarScripts.nut")

let fullRealModeOnBattleButtonClick = @(gameMode)
  guiStartModalEvents({ event = gameMode?.getEventId() ?? gameMode?.modeId })

let createDemandingText = @(reqCount, currentCount, unit, event) loc("mode_unlock_text/item",
  {
    reqCount = colorize("unlockHeaderColor", reqCount)
    currentCount = colorize("unlockHeaderColor", currentCount)
    unitName = unit.getLocName()
    eventName = events.getEventNameText(event)
  }
)

function getCustomGameModeUnlockText() {
  local res = ""

  if (killsOnUnitTypes.len() == 0)
    return res

  local demandCounter = 0
  local demandingText = ""
  foreach(esUnitType, killsOnUnit in killsOnUnitTypes){
    if (killsOnUnit.killsReq <= killsOnUnit.kills)
      continue
    let event = newbieNextEvent?[esUnitType]
    if (!event)
      continue
    let unit = unitTypes.getByEsUnitType(esUnitType)
    demandCounter++
    demandingText = "\n".concat(demandingText, createDemandingText(killsOnUnit.killsReq, killsOnUnit.kills, unit, event))
  }
  if (demandCounter > 0)
    res = "".concat(res, loc($"mode_unlock_text/title/{demandCounter > 1 ? "multiple" : "single"}"), demandingText)
  return res
}

function getRealisticGameModeUnlockText(modeId) {
  local res = ""

  if (killsOnUnitTypes.len() == 0)
    return res

  let mode = getGameModeById(modeId)
  // if mode is "Air realistic", "Ground realistic" or "Naval realistc" show only one condition:
  if (mode?.diffCode == DIFFICULTY_REALISTIC) {
    let unitType = mode?.reqUnitTypes[0] ?? mode.unitTypes[0] ?? -1
    let killsOnUnit = killsOnUnitTypes?[unitType]
    if (!killsOnUnit || killsOnUnit.killsReq <= killsOnUnit.kills)
     return res

    let unit = unitTypes.getByEsUnitType(unitType)
    let event = newbieNextEvent[unitType]
    res = "\n".concat(loc("mode_unlock_text/title/single"), createDemandingText(killsOnUnit.killsReq, killsOnUnit.kills, unit, event))
  }
  return res
}

let customStateByGameModeId = {
  // "World War"
  world_war_featured_game_mode = {
    startFunction = @(_gameMode) ::g_world_war.openMainWnd()
    getUnlockText = @() isWorldWarEnabled() ? getCantPlayWorldwarReasonText() : @() ""
    crossplayTooltip = function() {
      if (!needShowCrossPlayInfo())
        return null
      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")
      if (isCrossPlayEnabled())
        return loc("xbox/crossPlayEnabled")
      return null
    }
  }
  // "War Thunder League"
  tss_featured_game_mode = {
    function startFunction(_gameMode) {
      if (!needShowCrossPlayInfo() || isCrossPlayEnabled())
        openUrl(getCurCircuitOverride("tssAllTournamentsURL", loc("url/tss_all_tournaments")), false, false)
      else if (!isMultiplayerPrivilegeAvailable.value)
        checkAndShowMultiplayerPrivilegeWarning()
      else if (!isShowGoldBalanceWarning())
        checkAndShowCrossplayWarning(@() showInfoMsgBox(loc("xbox/actionNotAvailableCrossNetworkPlay")))
    }
    getUnlockText = @() getCustomGameModeUnlockText()
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
  // "Events"
  tournaments_and_event_featured_game_mode = {
    startFunction = @(_gameMode) guiStartModalEvents()
    getUnlockText = @() getCustomGameModeUnlockText()
    crossplayTooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")
      return null
    }
  }
  // "Custom Battles"
  custom_battles_featured_game_mode = {
    function startFunction(_gameMode) {
      if (!isMultiplayerPrivilegeAvailable.value) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      guiStartSkirmish()
    }
    getUnlockText = @() getCustomGameModeUnlockText()
    crossplayTooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")
      return null
    }
  }
  // "Simulator Battles"
  custom_mode_fullreal = {
    onBattleButtonClick = fullRealModeOnBattleButtonClick
    function startFunction(gameMode) {
      setCurrentGameModeById(gameMode.id, true) //need this for fast start SB battle in next time
      fullRealModeOnBattleButtonClick(gameMode)
    }
    getModeDescription = @() loc("simulator_battles/desc")
    getUnlockText = @() getCustomGameModeUnlockText()
    crossplayTooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")
      return null
    }
  }
}

function getEventDescription(gameMode) {
  if (!gameMode?.getEvent() || !gameMode?.source)
    return ""
  return events.getEventDescriptionText(gameMode.source, null, true) ?? ""
}

// Tooltip text, does not includes text from "crossplayTooltip"
function getGameModeUnlockTooltipText(gameMode) {
  let id = gameMode?.modeId ?? gameMode?.id
  if (gameMode?.forClan)
    return getCustomGameModeUnlockText()
  return customStateByGameModeId?[id].getUnlockText() ?? getRealisticGameModeUnlockText(id)
}

// Tooltip text with "getModeDescription", does not includes text from "crossplayTooltip"
function getGameModeDescrAndUnlockTooltipText(gameMode) {
  let id = gameMode?.modeId ?? gameMode?.id
  let eventDescription = getEventDescription(gameMode)
  let description = eventDescription != "" ? eventDescription : customStateByGameModeId?[id].getModeDescription()
  let modeUnlockText = gameMode?.inactiveColor()
    ? getGameModeUnlockTooltipText(gameMode)
    : null
  return description && modeUnlockText ? "\n".concat(description, modeUnlockText)
    : description ?? modeUnlockText
}

// Text for modal messages, includes text from "getUnlockText" and other restrictions to play in current gameMode
function getGameModeUnlockFullText(gameMode) {
  let tooltipText = getGameModeUnlockTooltipText(gameMode)

  local otherResctrictionsText = ""
  if (!isMultiplayerPrivilegeAvailable.value)
    otherResctrictionsText = "".concat(loc("xbox/noMultiplayer"), "\n")
  if (hasMultiplayerRestritionByBalance())
    otherResctrictionsText = "".concat(loc("revoking_fraudulent_purchases"), "\n")
  let event = getGameModeEvent(gameMode)
  if (event && !isEventPlatformOnlyAllowed(event) && needShowCrossPlayInfo() && !isCrossPlayEnabled())
    otherResctrictionsText = "".concat(loc("xbox/crossPlayRequired"), "\n")

  return tooltipText != "" && otherResctrictionsText != "" ? "".concat(otherResctrictionsText, tooltipText)
    : tooltipText ?? otherResctrictionsText
}

return {
  getGameModeStartFunction = @(id) customStateByGameModeId?[id].startFunction
  getGameModeOnBattleButtonClick = @(id) customStateByGameModeId?[id].onBattleButtonClick
  getGameModeCrossplayTooltip = @(id) customStateByGameModeId?[id].crossplayTooltip
  getGameModeUnlockTooltipText
  getGameModeDescrAndUnlockTooltipText
  getGameModeUnlockFullText
}