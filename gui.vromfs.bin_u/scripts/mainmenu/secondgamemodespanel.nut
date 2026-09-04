from "%scripts/dagui_library.nut" import *
from "string" import format
from "dagor.workcycle" import setTimeout, clearTimer

from "%scripts/events/eventInfo.nut" import hasNightGameModes, hasSmallTeamsGameModes
from "%scripts/options/options.nut" import get_gui_option_in_mode, set_gui_option_in_mode
from "%scripts/battleRating.nut" import getRecentSquadMrank, recentBR
from "%scripts/slotbar/playerCurUnit.nut" import getPlayerCurUnit
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES, USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES, USEROPT_CAN_QUEUE_TO_BULLET_HELL_BATTLES
from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "%scripts/events/secondGameModesUtils.nut" import getNightBattlesDesc, getSmallTeamsDesc, getBulletHellDesc, getBulletHellMrank, getBulletHellRequirement, isBulletHellAvailable, hasBulletHellGameModes, getSquadOnlineMembers, hasGameModeByTagPrefix, getNavalEcMrank, getNavalEcDesc, getNuclearEscalationMrank, getNuclearEscalationDesc, mainModePairs, isClassicModeOn, isSubModeOn, canQueueWithoutClassic

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { events } = require("%scripts/events/eventsManager.nut")

const UPDATE_SECOND_MODES_DELAY_ID = "update_second_modes_delay"
const UPDATE_SECOND_MODES_DELAY = 0.2

local isInUpdate = false

function getCurRank(event) {
  return g_squad_manager.isInSquad()
    ? getRecentSquadMrank()
    : getPlayerCurUnit()?.getEconomicRank(events.getEDiffByEvent(event))
}



function isPresentNightMode(event) {
  return hasNightGameModes(event)
}

function isNightModeSelected(_event) {
  return get_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES, OPTIONS_MODE_GAMEPLAY, false)
}

function isNightModeAvalible(event) {
  let rank = getCurRank(event)
  return rank != null && rank >= (event?.minMRankForNightBattles ?? 0)
}

function isNightModeActive(event) {
  if (!isNightModeAvalible(event))
    return false
  return isNightModeSelected(event)
}

function getNightModeDetails(event) {
  if (!isNightModeAvalible(event))
    return loc("mainmenu/requiredBR", { br = format("%.1f", calcBattleRatingFromRank(event.minMRankForNightBattles)) })

  return null
}

function setNightBattlesActive(isActive) {
  set_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES, isActive, OPTIONS_MODE_GAMEPLAY)
}



function isSmallTeamsModeSelected(_event) {
  return get_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES, OPTIONS_MODE_GAMEPLAY, false)
}

function isSmallTeamsModeAvalible(event) {
  let curUnit = getPlayerCurUnit()
  if (!curUnit || !curUnit.isAir())
    return false

  return getCurRank(event) >= (event?.minMRankForSmallTeamsBattles ?? 0)
}

function isSmallTeamsModeActive(event) {
  if (!isSmallTeamsModeAvalible(event))
    return false
  return isSmallTeamsModeSelected(event)
}

function getSmallTeamsDetails(event) {
  if (!isSmallTeamsModeAvalible(event))
    return loc("mainmenu/requiredBR", { br = format("%.1f", calcBattleRatingFromRank(event.minMRankForSmallTeamsBattles)) })

  return null
}

function isSmallTeamsModePresent(event) {
  return hasSmallTeamsGameModes(event)
}

function setSmallTeamsModeActive(isActive) {
  set_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES, isActive, OPTIONS_MODE_GAMEPLAY)
}



function isBulletHellModeSelected(_event) {
  return get_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_BULLET_HELL_BATTLES, OPTIONS_MODE_GAMEPLAY, false)
}

function isBulletHellModeActive(event) {
  if (!isBulletHellAvailable(event))
    return false
  return isBulletHellModeSelected(event)
}

function getBulletHellBattleRating(event) {
  let mrank = getBulletHellMrank(event)
  return mrank < 0 ? 0 : calcBattleRatingFromRank(mrank)
}

function getBulletHellDetails(event) {
  if (isBulletHellAvailable(event))
    return null

  let text = loc("mainmenu/requiredAircraftCountWithBR", getBulletHellRequirement(event))
  return getSquadOnlineMembers().len() > 0
    ? " ".concat(text, loc("mainmenu/forEachSquadMember"))
    : text
}

function setBulletHellModeActive(isActive) {
  set_gui_option_in_mode(USEROPT_CAN_QUEUE_TO_BULLET_HELL_BATTLES, isActive, OPTIONS_MODE_GAMEPLAY)
}



function isClassicGameModeEnabled(event) {
  return mainModePairs.findvalue(@(cfg)
    hasGameModeByTagPrefix(event, cfg.tagPrefix) && !isClassicModeOn(cfg)) == null
}

let getSubmodeDetails = @(event, cfg)
  cfg.isSubmodeAvailable(event, cfg) ? null : cfg.getSubmodeRequirementText(event, cfg)

function setClassicModeActive(isActive, event, cfg) {
  if (!isActive && !canQueueWithoutClassic(event, cfg)) {
    showInfoMsgBox(loc("mainmenu/oneMainModeRequired"))
    return
  }
  set_gui_option_in_mode(cfg.classicUseropt, isActive, OPTIONS_MODE_GAMEPLAY)
}

function setSubModeActive(isActive, _event, cfg) {
  if (!isActive && !isClassicModeOn(cfg)) {
    showInfoMsgBox(loc("mainmenu/oneMainModeRequired"))
    return
  }
  set_gui_option_in_mode(cfg.submodeUseropt, isActive, OPTIONS_MODE_GAMEPLAY)
}

let makeClassicModeEntry = @(cfg) {
  modeId = cfg.classicModeId
  isMainMode = true
  name = "#mode/classic"
  isSelected = @(_event) isClassicModeOn(cfg)
  isPresent = @(event) hasGameModeByTagPrefix(event, cfg.tagPrefix)
  setActiveWithEvent = @(isActive, event = null) setClassicModeActive(isActive, event, cfg)
  getTooltipText = @(_event) loc(cfg.classicTooltipLocKey)
}

let navalEcPresentation = {
  icon = "#ui/gameuiskin#ic_confrontation.svg"
  iconSize = "32@sf/@pf, 24@sf/@pf"
  name = "#missions/I2M"
  getTooltipText = @(event, cfg) getNavalEcDesc(event, cfg.tagPrefix)
  getBattleRating = @(event, cfg) calcBattleRatingFromRank(getNavalEcMrank(event, cfg.tagPrefix))
}

let submodeModePresentation = {
  naval_ec_ab_mode = navalEcPresentation
  naval_ec_rb_mode = navalEcPresentation
  nuclear_escalation_mode = {
    icon = "#ui/gameuiskin#ic_nuclear_escalation.svg"
    iconSize = "24@sf/@pf, 24@sf/@pf"
    name = "#mode/nuclear_escalation"
    getTooltipText = @(event, cfg) getNuclearEscalationDesc(event, cfg.tagPrefix)
    getBattleRating = @(event, cfg) calcBattleRatingFromRank(getNuclearEscalationMrank(event, cfg.tagPrefix))
  }
}

let makeSubmodeModeEntry = @(cfg) {
  modeId = cfg.submodeModeId
  getDetails = @(event) getSubmodeDetails(event, cfg)
  isSelected = @(_event) isSubModeOn(cfg)
  isActive = @(event) canQueueWithoutClassic(event, cfg)
  isAvalible = @(event) cfg.isSubmodeAvailable(event, cfg)
  isPresent = @(event) hasGameModeByTagPrefix(event, cfg.tagPrefix)
  setActiveWithEvent = @(isActive, event = null) setSubModeActive(isActive, event, cfg)
}.__update(submodeModePresentation[cfg.submodeModeId], {
  getTooltipText = @(event) submodeModePresentation[cfg.submodeModeId].getTooltipText(event, cfg)
  getBattleRating = @(event) submodeModePresentation[cfg.submodeModeId].getBattleRating(event, cfg)
})

let mainGameModes = []
foreach (cfg in mainModePairs)
  mainGameModes.append(makeClassicModeEntry(cfg), makeSubmodeModeEntry(cfg))

let additionalGameModes = [
  {
    modeId = "reduced_teams_mode",
    icon = "#ui/gameuiskin#ic_reduced_team.svg",
    iconSize = "24@sf/@pf, 24@sf/@pf",
    name = "#mode/small_teams",
    getDetails = getSmallTeamsDetails,
    isSelected = isSmallTeamsModeSelected,
    isActive = isSmallTeamsModeActive,
    isAvalible = isSmallTeamsModeAvalible,
    isPresent = isSmallTeamsModePresent,
    setActive = setSmallTeamsModeActive,
    getTooltipText = getSmallTeamsDesc
  },
  {
    modeId = "bullet_hell_mode",
    icon = "#ui/gameuiskin#ic_bullet_hell.svg",
    iconSize = "24@sf/@pf, 24@sf/@pf",
    name = "#events/bullet_hell",
    getDetails = getBulletHellDetails,
    isSelected = isBulletHellModeSelected,
    isActive = isBulletHellModeActive,
    isAvalible = isBulletHellAvailable,
    isPresent = hasBulletHellGameModes,
    setActive = setBulletHellModeActive,
    getTooltipText = getBulletHellDesc
    getBattleRating = getBulletHellBattleRating
  },
  {
    modeId = "night_battles_mode",
    icon = "#ui/gameuiskin#ic_night_battles.svg",
    iconSize = "24@sf/@pf, 24@sf/@pf",
    name = "#night_battles",
    getDetails = getNightModeDetails,
    isPresent = isPresentNightMode,
    isSelected = isNightModeSelected,
    isActive = isNightModeActive,
    isAvalible = isNightModeAvalible,
    setActive = setNightBattlesActive,
    getTooltipText = getNightBattlesDesc
    additionalBtns = [{
      onClickFunc = "onNightBattlesAdditionalAwardsBtn"
      img = "ui/gameuiskin#sh_unlockachievement.svg"
      tooltip = "#gameMode/unique_themed_rewards"
    }]
  }
]

let headerEntry = {
  modeId = "second_game_modes_header"
  isHeader = true
  name = "#events/secondGameModes"
  isPresent = @(event) additionalGameModes.findvalue(@(mode) mode.isPresent(event)) != null
}

let secondGameModes = clone mainGameModes
secondGameModes.append(headerEntry)
secondGameModes.extend(additionalGameModes)

function hasSecondGameModes(event) {
  return secondGameModes.findvalue(@(mode) mode.isPresent(event)) != null
}

function setSecondGameModeActive(modeId, isActive, event = null) {
  let gameModeData = secondGameModes.findvalue(@(mode) mode.modeId == modeId)
  if (gameModeData?.setActiveWithEvent != null)
    gameModeData.setActiveWithEvent(isActive, event)
  else if (gameModeData)
    gameModeData.setActive(isActive)
}

function updateSecondGameModes(nest, event, handler) {
  isInUpdate = true
  let detailsNest = nest.findObject("second_game_modes_details")
  let statusesNest = nest.findObject("second_game_modes_status")
  let hasMainModes = mainGameModes.findvalue(@(mode) mode.isPresent(event)) != null
  foreach (modeData in secondGameModes) {
    let detailsObj = detailsNest.findObject(modeData.modeId)
    let statusObj = statusesNest.findObject(modeData.modeId)
    let isModePresent = modeData.isPresent(event)
    detailsObj.show(isModePresent)
    if (modeData?.isHeader) {
      detailsObj["margin-top"] = hasMainModes ? "2@blockInterval" : "0"
      continue
    }
    if (statusObj?.isValid())
      statusObj.show(isModePresent)
    if (!isModePresent)
      continue

    let detailsTextObj = detailsObj.findObject("details")
    let detailsText = modeData?.getDetails ? modeData.getDetails(event) : null
    detailsTextObj.show(detailsText != null)
    if (detailsText)
      detailsTextObj.setValue(detailsText)

    let isModeSelected = modeData.isSelected(event)
    let switchBox = detailsObj.findObject("switch_box")
    switchBox.setValue(isModeSelected)
    let isModeAvalible = modeData?.isAvalible(event) ?? true
    switchBox.enable(isModeAvalible)
    detailsObj.findObject("switch_box_holder").tooltip = modeData?.getTooltipText(event)

    if (!statusObj?.isValid())
      continue

    let battleRating = modeData?.getBattleRating != null ? modeData.getBattleRating(event) : recentBR.get()
    let isModeActive = battleRating != 0 && (modeData?.isActive(event) ?? true)

    let statusTextObj = statusObj.findObject("text")
    statusTextObj.setValue(!isModeAvalible || battleRating == 0 ? loc("leaderboards/notAvailable")
      : isModeActive ? " ".concat(loc("mainmenu/brText"), format("%.1f", battleRating))
      : loc("options/disabled/short")
    )
  }
  handler.updateTopNoticesBlockPos?()
  isInUpdate = false
}

function fillSecondModes(nest, handler) {
  let modesData = handyman.renderCached("%gui/secondGameModes.tpl", {
    secondModes = secondGameModes
    secondStatusModes = secondGameModes.filter(@(mode) !(mode?.isMainMode ?? false) && !(mode?.isHeader ?? false))
  })
  nest.getScene().replaceContentFromText(nest, modesData, modesData.len(), handler)
}

function implUpdateSecondGameModesPanel(event, panelObj, handler) {
  if (!handler?.isValid() || !panelObj.isValid())
    return

  if (event == null || g_squad_manager.isSquadMember()) {
    panelObj.isEmpty = "yes"
    handler.updateTopNoticesBlockPos?()
    return
  }

  if (panelObj.childrenCount() == 0)
    fillSecondModes(panelObj, handler)

  let isPanelEmpty = !hasSecondGameModes(event)
  panelObj.isEmpty = isPanelEmpty ? "yes" : "no"
  if (isPanelEmpty)
    handler.updateTopNoticesBlockPos?()
  else
    updateSecondGameModes(panelObj, event, handler)
}

function updateSecondGameModesPanel(event, panelObj, handler, forceUpdate = false) {
  if (isInUpdate)
    return

  clearTimer(UPDATE_SECOND_MODES_DELAY_ID)
  if (forceUpdate) {
    implUpdateSecondGameModesPanel(event, panelObj, handler)
    return
  }

  setTimeout(UPDATE_SECOND_MODES_DELAY, @() implUpdateSecondGameModesPanel(event, panelObj, handler), UPDATE_SECOND_MODES_DELAY_ID)
}

return {
  updateSecondGameModesPanel
  setSecondGameModeActive
  isClassicGameModeEnabled
}