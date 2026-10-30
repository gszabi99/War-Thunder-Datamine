from "%scripts/events/eventsManager.nut" import events
from "%scripts/events/eventTeamsInfo.nut" import getTeamData, getAlowedCrafts, getForbiddenCrafts, isUnitAllowedByTeamData
from "%scripts/unit/unitInfo.nut" import getUnitTypeByText
from "%scripts/user/profileStates.nut" import userIdStr
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/slotbar/crewsList.nut" import getCrewsListByCountry
from "%scripts/crew/crew.nut" import getCrewUnit
from "%scripts/crew/crewInfo.nut" import isCrewLockedByPrevBattle
from "%scripts/unit/unitStatus.nut" import isUnitBroken
from "%scripts/dagui_library.nut" import *
from "string" import format, startswith
from "%scripts/teamsConsts.nut" import Team
from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "%globalScripts/unitTypeConsts.nut" import ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT
from "%scripts/matching/matchingGameModes.nut" import getGameModeWithTagContains, getGameModesByEconomicName, SMALL_TEAMS_GAME_MODE_TAG_PREFIX, BULLET_HELL_GAME_MODE_TAG_PREFIX, NAVAL_EC_AB_GAME_MODE_TAG_PREFIX, NAVAL_EC_RB_GAME_MODE_TAG_PREFIX, NUCLEAR_ESCALATION_GAME_MODE_TAG_PREFIX
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_CAN_QUEUE_TO_CLASSIC_NAVAL_AB_BATTLES, USEROPT_CAN_QUEUE_TO_CLASSIC_NAVAL_RB_BATTLES, USEROPT_CAN_QUEUE_TO_NAVAL_EC_AB_BATTLES, USEROPT_CAN_QUEUE_TO_NAVAL_EC_RB_BATTLES, USEROPT_CAN_QUEUE_TO_AIR_RB_CLASSIC_BATTLES, USEROPT_CAN_QUEUE_TO_AIR_RB_NUCLEAR_ESCALATION_BATTLES
  , USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES, USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES, USEROPT_CAN_QUEUE_TO_BULLET_HELL_BATTLES
from "%scripts/events/eventInfo.nut" import hasNightGameModes, hasSmallTeamsGameModes, getEventEconomicName
from "%scripts/options/options.nut" import get_gui_option_in_mode, set_gui_option_in_mode
from "%scripts/slotbar/playerCurUnit.nut" import getPlayerCurUnit
from "%scripts/battleRating.nut" import recentBR, getRecentSquadMrank
from "%scripts/unit/unitMrankSelectionState.nut" import getEffectiveMrank, getMrankDeltaByUnit
from "%scripts/squads/squadState.nut" import isInSquad, getMembers

const MIN_MRANK_FOR_NIGHT_BATTLES = 27
const MIN_MRANK_FOR_SMALL_TEAMS = 27
const MIN_MRANK_FOR_BULLET_HELL = 22
const MIN_CRAFTS_FOR_BULLET_HELL = 2
const MIN_MRANK_FOR_NAVAL_EC = 7
const MIN_MRANK_FOR_NUCLEAR_ESCALATION = 23

function getNightBattlesDesc(event) {
  return loc("mode/night_battles/desc", {
    requiredBR = format("%.1f",
      calcBattleRatingFromRank(event?.minMRankForNightBattles ?? MIN_MRANK_FOR_NIGHT_BATTLES))
  })
}

let getTeamSizeRangeText = @(event) " ".concat(events.getMinTeamSize(event), loc("ui/mdash"),
  events.getTeamData(event, Team.A).maxTeamSize)

function getSmallTeamsDesc(event) {
  let usualTeamsCount = getTeamSizeRangeText(event)
  let smallTeamsGameMode = getGameModeWithTagContains(SMALL_TEAMS_GAME_MODE_TAG_PREFIX)

  return loc("mode/small_teams/desc", {
    smallTeamsCount = smallTeamsGameMode != null
      ? getTeamSizeRangeText(smallTeamsGameMode)
      : usualTeamsCount
    usualTeamsCount
    requiredBR = format("%.1f",
      calcBattleRatingFromRank(event?.minMRankForSmallTeamsBattles ?? MIN_MRANK_FOR_SMALL_TEAMS))
  })
}

function getGameModeByTagPrefix(event, tagPrefix) {
  let modes = getGameModesByEconomicName(getEventEconomicName(event))
  modes.sortby(@(a) a.gameModeId)
  foreach (gm in modes)
    if (startswith(gm?.tag ?? "", tagPrefix))
      return gm
  return null
}

let getBulletHellGameMode = @(event) getGameModeByTagPrefix(event, BULLET_HELL_GAME_MODE_TAG_PREFIX)

let hasBulletHellGameModes = @(event) getBulletHellGameMode(event) != null

let getBulletHellMinCrafts = @(event)
  getBulletHellGameMode(event)?.minCraftsToPlay ?? MIN_CRAFTS_FOR_BULLET_HELL

function getBulletHellTeamData(event) {
  let bulletHellGameMode = getBulletHellGameMode(event)
  return bulletHellGameMode != null ? getTeamData(bulletHellGameMode, Team.A) : null
}

function getMinMrankFromAllowedCrafts(teamDataList, isSuitableUnitType, fallbackMrank) {
  local minMrank = null
  foreach (teamData in teamDataList)
    foreach (rule in getAlowedCrafts(teamData)) {
      let unitType = getUnitTypeByText(rule?["class"] ?? "")
      if (isSuitableUnitType(unitType) && rule?.mranks.min != null)
        minMrank = min(minMrank ?? rule.mranks.min, rule.mranks.min)
    }
  return minMrank ?? fallbackMrank
}

let isAircraftType = @(unitType) unitType == ES_UNIT_TYPE_AIRCRAFT
let isShipOrBoatType = @(unitType) unitType == ES_UNIT_TYPE_SHIP || unitType == ES_UNIT_TYPE_BOAT

function getBulletHellMinAircraftMrank(event) {
  return getMinMrankFromAllowedCrafts([getBulletHellTeamData(event)],
    isAircraftType, MIN_MRANK_FOR_BULLET_HELL)
}

function isSuitableAircraft(teamData, unit, ediff, minMRank) {
  if (unit == null || !unit.isAir())
    return false
  if (unit.getEconomicRank(ediff) < minMRank)
    return false
  return teamData == null || isUnitAllowedByTeamData(teamData, unit.name, ediff)
}

function getBulletHellSuitableUnits(event, _tagPrefix, unitNames, brokenNames = []) {
  if (!hasBulletHellGameModes(event))
    return []
  let teamData = getBulletHellTeamData(event)
  let ediff = events.getEDiffByEvent(event)
  let minMRank = getBulletHellMinAircraftMrank(event)
  let units = []
  foreach (unitName in unitNames) {
    if (isInArray(unitName, brokenNames))
      continue
    let unit = getAircraftByName(unitName)
    if (isSuitableAircraft(teamData, unit, ediff, minMRank))
      units.append(unit)
  }
  return units
}

function getOwnCraftNames() {
  let names = []
  foreach (crew in getCrewsListByCountry(profileCountrySq.get())) {
    if (crew.isLocked != 0 || isCrewLockedByPrevBattle(crew))
      continue
    let unit = getCrewUnit(crew)
    if (unit != null && !isUnitBroken(unit))
      names.append(unit.name)
  }
  return names
}

function getSquadOnlineMembers() {
  let members = []
  if (isInSquad())
    foreach (uid, member in getMembers())
      if (member.online && member.country != "" && uid != userIdStr.get())
        members.append(member)
  return members
}

function getMaxMrank(units, ediff, mrankDeltaByUnit) {
  local mrank = -1
  foreach (unit in units)
    mrank = max(mrank, getEffectiveMrank(unit, ediff, mrankDeltaByUnit?[unit.name] ?? 0))
  return mrank
}

function getSuitableUnitsParticipants(event, tagPrefix, getSuitableUnits, needMrankDelta = false) {
  let ownCraftNames = getOwnCraftNames()
  let ownMrankDeltaByUnit = needMrankDelta ? getMrankDeltaByUnit(ownCraftNames) : null
  let participants = [{
    units = getSuitableUnits(event, tagPrefix, ownCraftNames)
    mrankDeltaByUnit = ownMrankDeltaByUnit
  }]
  foreach (member in getSquadOnlineMembers()) {
    let memberMrankDeltaByUnit = needMrankDelta ? member?.mrankDeltaByUnit ?? {} : null
    participants.append({
      units = getSuitableUnits(event, tagPrefix,
        member?.crewAirs?[member.country] ?? [], member?.brokenAirs ?? [])
      mrankDeltaByUnit = memberMrankDeltaByUnit
    })
  }
  return participants
}

let isSubmodeAvailableByUnits = @(event, tagPrefix, getSuitableUnits)
  getSuitableUnitsParticipants(event, tagPrefix, getSuitableUnits).findindex(@(p) p.units.len() == 0) == null

function getSubmodeMrank(event, tagPrefix, getSuitableUnits) {
  let ediff = events.getEDiffByEvent(event)
  return getSuitableUnitsParticipants(event, tagPrefix, getSuitableUnits, true)
    .map(@(p) getMaxMrank(p.units, ediff, p.mrankDeltaByUnit))
    .reduce(@(a, b) max(a, b))
}

let getBulletHellParticipantsCrafts = @(event, needMrankDelta = false)
  getSuitableUnitsParticipants(event, null, getBulletHellSuitableUnits, needMrankDelta)

function getBulletHellAvailableCraftsCount(event) {
  return getBulletHellParticipantsCrafts(event)
    .map(@(p) p.units.len())
    .reduce(@(a, b) min(a, b))
}

function getBulletHellMrank(event) {
  let ediff = events.getEDiffByEvent(event)
  return getBulletHellParticipantsCrafts(event, true)
    .map(@(p) getMaxMrank(p.units, ediff, p.mrankDeltaByUnit))
    .reduce(@(a, b) max(a, b))
}

function getBulletHellRequirement(event) {
  return {
    count = getBulletHellMinCrafts(event)
    br = format("%.1f", calcBattleRatingFromRank(getBulletHellMinAircraftMrank(event)))
  }
}

function isBulletHellAvailable(event) {
  return getBulletHellAvailableCraftsCount(event) >= getBulletHellMinCrafts(event)
}

function getBulletHellForbiddenCraftsText(event) {
  let names = []
  foreach (rule in getForbiddenCrafts(getBulletHellTeamData(event))) {
    if (("class" in rule) && rule.len() == 1)
      continue
    names.append(events.generateEventRule(rule, true))
  }
  return names
}

function getBulletHellDesc(event) {
  let req = getBulletHellRequirement(event)
  local desc = loc("mode/bullet_hell/desc", {
    requiredCount = req.count
    requiredBR = req.br
  })
  let forbiddenNames = getBulletHellForbiddenCraftsText(event)
  if (forbiddenNames.len() > 0)
    desc = "".concat(desc, "\n\n", loc("events/forbidden_crafts"), "\n", "\n".join(forbiddenNames))
  return desc
}

let hasGameModeByTagPrefix = @(event, tagPrefix) getGameModeByTagPrefix(event, tagPrefix) != null

function getTeamDataByTagPrefix(event, tagPrefix) {
  let gameMode = getGameModeByTagPrefix(event, tagPrefix)
  return gameMode != null ? getTeamData(gameMode, Team.A) : null
}

function isNavalEcSuitableCraft(teamData, unit, ediff) {
  if (unit == null || !unit.isShipOrBoat())
    return false
  return teamData == null || isUnitAllowedByTeamData(teamData, unit.name, ediff)
}

function getNavalEcSuitableUnits(event, tagPrefix, unitNames, brokenNames = []) {
  if (!hasGameModeByTagPrefix(event, tagPrefix))
    return []
  let teamData = getTeamDataByTagPrefix(event, tagPrefix)
  let ediff = events.getEDiffByEvent(event)
  let units = []
  foreach (unitName in unitNames) {
    if (isInArray(unitName, brokenNames))
      continue
    let unit = getAircraftByName(unitName)
    if (isNavalEcSuitableCraft(teamData, unit, ediff))
      units.append(unit)
  }
  return units
}

let isNavalEcAvailable = @(event, tagPrefix) isSubmodeAvailableByUnits(event, tagPrefix, getNavalEcSuitableUnits)
let getNavalEcMrank = @(event, tagPrefix) getSubmodeMrank(event, tagPrefix, getNavalEcSuitableUnits)

function getNavalEcMinShipMrank(event, tagPrefix) {
  return getMinMrankFromAllowedCrafts([getTeamDataByTagPrefix(event, tagPrefix)],
    isShipOrBoatType, MIN_MRANK_FOR_NAVAL_EC)
}

let getNavalEcRequirement = @(event, tagPrefix) {
  br = format("%.1f", calcBattleRatingFromRank(getNavalEcMinShipMrank(event, tagPrefix)))
}

let getNavalEcDesc = @(event, tagPrefix) loc("mode/naval_ec/desc", {
  requiredBR = getNavalEcRequirement(event, tagPrefix).br
})

function getNavalEcRequirementText(event, tagPrefix) {
  let text = loc("mainmenu/requiredShipWithBR", getNavalEcRequirement(event, tagPrefix))
  return getSquadOnlineMembers().len() > 0
    ? " ".concat(text, loc("mainmenu/forEachSquadMember"))
    : text
}

let isNavalEcSubmodeAvailable = @(event, cfg) isNavalEcAvailable(event, cfg.tagPrefix)
let getNavalEcSubmodeRequirementText = @(event, cfg) getNavalEcRequirementText(event, cfg.tagPrefix)

function getTeamDataPerSide(event, tagPrefix) {
  let gameMode = getGameModeByTagPrefix(event, tagPrefix)
  if (gameMode == null)
    return []
  let res = []
  foreach (side in const [Team.A, Team.B]) {
    let teamData = getTeamData(gameMode, side)
    if (teamData != null)
      res.append(teamData)
  }
  return res
}

function getNuclearEscalationMinAircraftMrank(event, tagPrefix) {
  return getMinMrankFromAllowedCrafts(getTeamDataPerSide(event, tagPrefix),
    isAircraftType, MIN_MRANK_FOR_NUCLEAR_ESCALATION)
}

function getNuclearEscalationSuitableUnits(event, tagPrefix, unitNames, brokenNames = []) {
  if (!hasGameModeByTagPrefix(event, tagPrefix))
    return []
  let teamDataPerSide = getTeamDataPerSide(event, tagPrefix)
  let ediff = events.getEDiffByEvent(event)
  let minMrank = getNuclearEscalationMinAircraftMrank(event, tagPrefix)
  let units = []
  foreach (unitName in unitNames) {
    if (isInArray(unitName, brokenNames))
      continue
    let unit = getAircraftByName(unitName)
    if (teamDataPerSide.findvalue(@(teamData) isSuitableAircraft(teamData, unit, ediff, minMrank)) != null)
      units.append(unit)
  }
  return units
}

let isNuclearEscalationAvailable = @(event, tagPrefix) isSubmodeAvailableByUnits(event, tagPrefix, getNuclearEscalationSuitableUnits)
let getNuclearEscalationMrank = @(event, tagPrefix) getSubmodeMrank(event, tagPrefix, getNuclearEscalationSuitableUnits)

let getNuclearEscalationRequirement = @(event, tagPrefix) {
  br = format("%.1f", calcBattleRatingFromRank(getNuclearEscalationMinAircraftMrank(event, tagPrefix)))
}

let getNuclearEscalationDesc = @(event, tagPrefix) loc("mode/nuclear_escalation/desc", {
  requiredBR = getNuclearEscalationRequirement(event, tagPrefix).br
})

function getNuclearEscalationRequirementText(event, tagPrefix) {
  let text = loc("mainmenu/requiredBR", getNuclearEscalationRequirement(event, tagPrefix))
  return getSquadOnlineMembers().len() > 0
    ? " ".concat(text, loc("mainmenu/forEachSquadMember"))
    : text
}

let isNuclearEscalationSubmodeAvailable = @(event, cfg) isNuclearEscalationAvailable(event, cfg.tagPrefix)
let getNuclearEscalationSubmodeRequirementText = @(event, cfg) getNuclearEscalationRequirementText(event, cfg.tagPrefix)

let navalModePairs = [
  {
    tagPrefix = NAVAL_EC_AB_GAME_MODE_TAG_PREFIX
    classicUseropt = USEROPT_CAN_QUEUE_TO_CLASSIC_NAVAL_AB_BATTLES
    submodeUseropt = USEROPT_CAN_QUEUE_TO_NAVAL_EC_AB_BATTLES
    classicModeId = "classic_naval_ab_mode"
    submodeModeId = "naval_ec_ab_mode"
    classicTooltipLocKey = "missions/ship_event_arcade/desc"
    isSubmodeAvailable = isNavalEcSubmodeAvailable
    getSubmodeRequirementText = getNavalEcSubmodeRequirementText
  },
  {
    tagPrefix = NAVAL_EC_RB_GAME_MODE_TAG_PREFIX
    classicUseropt = USEROPT_CAN_QUEUE_TO_CLASSIC_NAVAL_RB_BATTLES
    submodeUseropt = USEROPT_CAN_QUEUE_TO_NAVAL_EC_RB_BATTLES
    classicModeId = "classic_naval_rb_mode"
    submodeModeId = "naval_ec_rb_mode"
    classicTooltipLocKey = "missions/ship_event_historical/desc"
    isSubmodeAvailable = isNavalEcSubmodeAvailable
    getSubmodeRequirementText = getNavalEcSubmodeRequirementText
  }
]

let airModePairs = [
  {
    tagPrefix = NUCLEAR_ESCALATION_GAME_MODE_TAG_PREFIX
    classicUseropt = USEROPT_CAN_QUEUE_TO_AIR_RB_CLASSIC_BATTLES
    submodeUseropt = USEROPT_CAN_QUEUE_TO_AIR_RB_NUCLEAR_ESCALATION_BATTLES
    classicModeId = "classic_air_rb_mode"
    submodeModeId = "nuclear_escalation_mode"
    classicTooltipLocKey = "encyclopedia/historical_battles/desc"
    isSubmodeAvailable = isNuclearEscalationSubmodeAvailable
    getSubmodeRequirementText = getNuclearEscalationSubmodeRequirementText
  }
]

let mainModePairs = clone navalModePairs
mainModePairs.extend(airModePairs)

let isClassicModeOn = @(cfg) get_gui_option_in_mode(cfg.classicUseropt, OPTIONS_MODE_GAMEPLAY, true)
let isSubModeOn = @(cfg) get_gui_option_in_mode(cfg.submodeUseropt, OPTIONS_MODE_GAMEPLAY, false)
let canQueueWithoutClassic = @(event, cfg) isSubModeOn(cfg) && cfg.isSubmodeAvailable(event, cfg)

function hasQueueableMainMode(event, cfg) {
  if (!hasGameModeByTagPrefix(event, cfg.tagPrefix))
    return true
  return isClassicModeOn(cfg) || canQueueWithoutClassic(event, cfg)
}

function getJoinBlockReason(event, modePairs) {
  let blockCfg = modePairs.findvalue(@(cfg) !hasQueueableMainMode(event, cfg))
  if (blockCfg == null)
    return null
  return isSubModeOn(blockCfg)
    ? blockCfg.getSubmodeRequirementText(event, blockCfg)
    : loc("mainmenu/oneMainModeRequired")
}

function getGmsTagRequests(event, modePairs) {
  let res = { exclude = [], only = [] }
  foreach (cfg in modePairs) {
    if (!hasGameModeByTagPrefix(event, cfg.tagPrefix))
      continue
    if (!canQueueWithoutClassic(event, cfg))
      res.exclude.append(cfg.tagPrefix)
    else if (!isClassicModeOn(cfg))
      res.only.append(cfg.tagPrefix)
  }
  return res
}

function getCurRank(event) {
  if (isInSquad())
    return getRecentSquadMrank()

  let unit = getPlayerCurUnit()
  return unit == null ? null : getEffectiveMrank(unit, events.getEDiffByEvent(event))
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

function getSecondGameModesForSquadLeader(event) {
  let modes = {}
  foreach (modeData in secondGameModes) {
    let isModePresent = modeData.isPresent(event)
    if (!isModePresent)
      continue

    let isSelected = modeData?.isSelected(event) ?? true
    let isAvalible = modeData?.isAvalible(event) ?? true
    let br = modeData?.getBattleRating != null
      ? modeData.getBattleRating(event)
      : recentBR.get()
    modes[modeData.modeId] <- { isAvalible, isSelected, br }
  }
  return modes
}

return {
  mainGameModes
  secondGameModes
  isBulletHellAvailable
  hasBulletHellGameModes
  mainModePairs
  getJoinBlockReason
  getGmsTagRequests
  hasSecondGameModes
  getSecondGameModesForSquadLeader
  isClassicGameModeEnabled
}