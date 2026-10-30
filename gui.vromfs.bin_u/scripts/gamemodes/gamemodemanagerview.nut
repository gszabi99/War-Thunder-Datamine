from "%scripts/onlineShop/url.nut" import openUrl
from "%scripts/social/crossplay.nut" import isCrossPlayEnabled, needShowCrossPlayInfo
from "%scripts/user/xboxFeatures.nut" import checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning, isMultiplayerPrivilegeAvailable
from "%scripts/user/balanceFeatures.nut" import isShowGoldBalanceWarning
from "%scripts/user/balance.nut" import hasMultiplayerRestritionByBalance
from "%scripts/missions/startMissionsList.nut" import guiStartSkirmish
from "%scripts/events/eventsHandler.nut" import guiStartModalEvents
from "%scripts/gameModes/gameModeManagerState.nut" import setCurrentGameModeById, getGameModeById, getGameModeEvent
from "%scripts/events/eventInfo.nut" import isEventPlatformOnlyAllowed
from "%scripts/events/eventsManager.nut" import events
from "%scripts/globalWorldWarScripts.nut" import isWorldWarEnabled, getCantPlayWorldwarReasonText
from "%scripts/globalWorldwarUtils.nut" import openWWMainWnd
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "%globalScripts/loc_helpers.nut" import locByVendor
from "%scripts/dagui_library.nut" import *
from "%globalScripts/difficultyConsts.nut" import *

let { killsOnUnitTypes, newbieNextEvent } = require("%scripts/myStats.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")

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
  
  world_war_featured_game_mode = {
    startFunction = @(_gameMode) openWWMainWnd()
    getUnlockText = @() isWorldWarEnabled() ? getCantPlayWorldwarReasonText() : @() ""
    crossplayTooltip = function() {
      if (!needShowCrossPlayInfo())
        return null
      if (!isMultiplayerPrivilegeAvailable.get())
        return loc("xbox/noMultiplayer")
      if (isCrossPlayEnabled())
        return locByVendor("xbox/crossPlayEnabled")
      return null
    }
  }
  
  tss_featured_game_mode = {
    function startFunction(_gameMode) {
      if (!needShowCrossPlayInfo() || isCrossPlayEnabled())
        openUrl(getCurCircuitOverride("tssAllTournamentsURL", loc("url/tss_all_tournaments")), false, false)
      else if (!isMultiplayerPrivilegeAvailable.get())
        checkAndShowMultiplayerPrivilegeWarning()
      else if (!isShowGoldBalanceWarning())
        checkAndShowCrossplayWarning(@() showInfoMsgBox(locByVendor("xbox/actionNotAvailableCrossNetworkPlay")))
    }
    getUnlockText = @() getCustomGameModeUnlockText()
    crossplayTooltip = function() {
      if (!needShowCrossPlayInfo()) 
        return null
      if (!isMultiplayerPrivilegeAvailable.get())
        return loc("xbox/noMultiplayer")
      
      
      if (isCrossPlayEnabled())
        return locByVendor("xbox/crossPlayEnabled")
      
      return locByVendor("xbox/crossPlayRequired")
    }

  }
  
  tournaments_and_event_featured_game_mode = {
    startFunction = @(_gameMode) guiStartModalEvents()
    getUnlockText = @() getCustomGameModeUnlockText()
    crossplayTooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.get())
        return loc("xbox/noMultiplayer")
      return null
    }
  }
  
  custom_battles_featured_game_mode = {
    function startFunction(_gameMode) {
      if (!isMultiplayerPrivilegeAvailable.get()) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      guiStartSkirmish()
    }
    crossplayTooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.get())
        return loc("xbox/noMultiplayer")
      return null
    }
  }
  
  custom_mode_fullreal = {
    onBattleButtonClick = fullRealModeOnBattleButtonClick
    function startFunction(gameMode) {
      setCurrentGameModeById(gameMode.id, true) 
      fullRealModeOnBattleButtonClick(gameMode)
    }
    getModeDescription = @() loc("simulator_battles/desc")
    crossplayTooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.get())
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


function getGameModeUnlockTooltipText(gameMode) {
  let id = gameMode?.modeId ?? gameMode?.id
  if (gameMode?.forClan)
    return getCustomGameModeUnlockText()
  return customStateByGameModeId?[id].getUnlockText() ?? getRealisticGameModeUnlockText(id)
}


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


function getGameModeUnlockFullText(gameMode) {
  let tooltipText = getGameModeUnlockTooltipText(gameMode)

  local otherResctrictionsText = ""
  if (!isMultiplayerPrivilegeAvailable.get())
    otherResctrictionsText = "".concat(loc("xbox/noMultiplayer"), "\n")
  if (hasMultiplayerRestritionByBalance())
    otherResctrictionsText = "".concat(loc("revoking_fraudulent_purchases"), "\n")
  let event = getGameModeEvent(gameMode)
  if (event && !isEventPlatformOnlyAllowed(event) && needShowCrossPlayInfo() && !isCrossPlayEnabled())
    otherResctrictionsText = "".concat(locByVendor("xbox/crossPlayRequired"), "\n")

  return tooltipText != "" && otherResctrictionsText != "" ? "".concat(otherResctrictionsText, tooltipText)
    : tooltipText ?? otherResctrictionsText
}

return freeze({
  getGameModeStartFunction = @(id) customStateByGameModeId?[id].startFunction
  getGameModeOnBattleButtonClick = @(id) customStateByGameModeId?[id].onBattleButtonClick
  getGameModeCrossplayTooltip = @(id) customStateByGameModeId?[id].crossplayTooltip
  getGameModeUnlockTooltipText
  getGameModeDescrAndUnlockTooltipText
  getGameModeUnlockFullText
})