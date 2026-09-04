from "%scripts/dagui_library.nut" import *
from "string" import format, startswith
from "%scripts/teamsConsts.nut" import Team
from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "%globalScripts/unitTypeConsts.nut" import ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT
from "%scripts/matching/matchingGameModes.nut" import getGameModeWithTagContains, getGameModesByEconomicName, SMALL_TEAMS_GAME_MODE_TAG_PREFIX, BULLET_HELL_GAME_MODE_TAG_PREFIX, NAVAL_EC_AB_GAME_MODE_TAG_PREFIX, NAVAL_EC_RB_GAME_MODE_TAG_PREFIX, NUCLEAR_ESCALATION_GAME_MODE_TAG_PREFIX
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_CAN_QUEUE_TO_CLASSIC_NAVAL_AB_BATTLES, USEROPT_CAN_QUEUE_TO_CLASSIC_NAVAL_RB_BATTLES, USEROPT_CAN_QUEUE_TO_NAVAL_EC_AB_BATTLES, USEROPT_CAN_QUEUE_TO_NAVAL_EC_RB_BATTLES, USEROPT_CAN_QUEUE_TO_AIR_RB_CLASSIC_BATTLES, USEROPT_CAN_QUEUE_TO_AIR_RB_NUCLEAR_ESCALATION_BATTLES

let { events } = require("%scripts/events/eventsManager.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { getTeamData, getAlowedCrafts, getForbiddenCrafts, isUnitAllowedByTeamData } = require("%scripts/events/eventTeamsInfo.nut")
let { getUnitTypeByText } = require("%scripts/unit/unitInfo.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { isInSquad, getMembers } = require("%scripts/squads/squadState.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { isCrewLockedByPrevBattle } = require("%scripts/crew/crewInfo.nut")
let { isUnitBroken } = require("%scripts/unit/unitStatus.nut")

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
  modes.sort(@(a, b) a.gameModeId - b.gameModeId)
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

function getMaxMrank(units, ediff) {
  local mrank = -1
  foreach (unit in units)
    mrank = max(mrank, unit.getEconomicRank(ediff))
  return mrank
}

function getSuitableUnitsParticipants(event, tagPrefix, getSuitableUnits) {
  let participants = [ getSuitableUnits(event, tagPrefix, getOwnCraftNames()) ]
  foreach (member in getSquadOnlineMembers())
    participants.append(getSuitableUnits(event, tagPrefix,
      member?.crewAirs?[member.country] ?? [], member?.brokenAirs ?? []))
  return participants
}

let isSubmodeAvailableByUnits = @(event, tagPrefix, getSuitableUnits)
  getSuitableUnitsParticipants(event, tagPrefix, getSuitableUnits).findindex(@(units) units.len() == 0) == null

function getSubmodeMrank(event, tagPrefix, getSuitableUnits) {
  let ediff = events.getEDiffByEvent(event)
  return getSuitableUnitsParticipants(event, tagPrefix, getSuitableUnits)
    .map(@(units) getMaxMrank(units, ediff))
    .reduce(@(a, b) max(a, b))
}

let getBulletHellParticipantsCrafts = @(event)
  getSuitableUnitsParticipants(event, null, getBulletHellSuitableUnits)

function getBulletHellAvailableCraftsCount(event) {
  return getBulletHellParticipantsCrafts(event)
    .map(@(units) units.len())
    .reduce(@(a, b) min(a, b))
}

function getBulletHellMrank(event) {
  let ediff = events.getEDiffByEvent(event)
  return getBulletHellParticipantsCrafts(event)
    .map(@(units) getMaxMrank(units, ediff))
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

return {
  getNightBattlesDesc
  getSmallTeamsDesc
  getBulletHellDesc
  getBulletHellMrank
  getBulletHellRequirement
  isBulletHellAvailable
  hasBulletHellGameModes
  getSquadOnlineMembers
  hasGameModeByTagPrefix
  isNavalEcAvailable
  getNavalEcMrank
  getNavalEcDesc
  isNuclearEscalationAvailable
  getNuclearEscalationMrank
  getNuclearEscalationDesc
  navalModePairs
  airModePairs
  mainModePairs
  isClassicModeOn
  isSubModeOn
  canQueueWithoutClassic
  getJoinBlockReason
  getGmsTagRequests
}