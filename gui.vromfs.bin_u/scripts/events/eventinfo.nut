from "%sqStdLibs/helpers/u.nut" import isEmpty
from "%sqstd/platform.nut" import is_gdk
from "%scripts/dagui_library.nut" import *
from "%scripts/events/eventsConsts.nut" import EVENT_TYPE, GAME_EVENT_TYPE
from "%scripts/gameModes/gameModeConsts.nut" import MAX_PLAYERS_VERSUS

let { getSeparateLeaderboardPlatformValue } = require("%scripts/social/crossplay.nut")
let { getFeaturePack } = require("%scripts/user/features.nut")
let { getFeaturePurchaseData } = require("%scripts/onlineShop/onlineShopState.nut")
let { g_event_display_type } = require("%scripts/events/eventDisplayType.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { checkPackageFull, havePackage } = require("%scripts/clientState/contentPacks.nut")
let { isNewbieEventId } = require("%scripts/user/myStatsState.nut")
let { getUserstatTableData } = require("%scripts/userstat/userstat.nut")
let { buildDateStrShort, buildTimeStr, TIME_DAY_IN_SECONDS } = require("%scripts/time.nut")

let eventIdsForMainGameModeList = [
  "tank_event_in_random_battles_arcade"
  "air_arcade"
]

const MAX_LEAGUES_HISTORY_COUNT = 20

const leaguesConfig = [
  { locId = "league/groupStage", minSize = 40, maxSize = 48, bePromoted = 24, beDemoted = 0 }
  { locId = "league/roundOf32", minSize = 30, maxSize = 32, bePromoted = 8, beDemoted = 12 }
  { locId = "league/roundOf16", minSize = 14, maxSize = 16, bePromoted = 4, beDemoted = 6 }
  { locId = "league/quarterfinal", minSize = 7, maxSize = 8, bePromoted = 2, beDemoted = 3 }
  { locId = "league/semifinal", minSize = 4, maxSize = 4, bePromoted = 1, beDemoted = 2 }
  { locId = "league/final", minSize = 2, maxSize = 2, bePromoted = 1, beDemoted = 1 }
]

let isEventAllowedByPackage = @(event) event?.reqPacks.findvalue(@(packName) !havePackage(packName)) == null

let needShowOverrideSlotbar = @(event) (event?.showEditSlotbar ?? false)
  && isEventAllowedByPackage(event)

let getCustomViewCountryData = @(event) event?.customViewCountry

let getEventEconomicName = @(event) event?.economicName ?? ""

let isLeaderboardsAvailable = @(event) (event?.enableEventsLeaderboard ?? false)
  && (!getSeparateLeaderboardPlatformValue()
    || hasFeature("ConsoleSeparateEventsLeaderboards"))

let getEventTournamentMode = @(event) event?.tournament_mode ?? GAME_EVENT_TYPE.TM_NONE

function detectEventType(event_data) {
  local result = 0
  if (isNewbieEventId(event_data.name))
    result = EVENT_TYPE.NEWBIE_BATTLES
  else if ((event_data?.tournament ?? false)
    && getEventTournamentMode(event_data) != GAME_EVENT_TYPE.TM_NONE_RACE)
      result = EVENT_TYPE.TOURNAMENT
  else
    result = EVENT_TYPE.SINGLE
  if (event_data?.clanBattle ?? false)
    result = result | EVENT_TYPE.CLAN
  return result
}

function getEventType(event) {
  if (!("_type" in event))
    event._type <- detectEventType(event)
  return event._type
}

let isEventMatchesType = @(event, typeMask) event ? (getEventType(event) & typeMask) != 0 : false

let getEventDisplayType = @(event) event?._displayType ?? g_event_display_type.NONE

let setEventDisplayType = @(event, displayType) event._displayType <- displayType

let isEventForClan = @(event) isEventMatchesType(event, EVENT_TYPE.CLAN)

let isEventForNewbies = @(event) isEventMatchesType(event, EVENT_TYPE.NEWBIE_BATTLES)

function isEventRandomBattles(event) {
  if (getEventType(event) & EVENT_TYPE.NEWBIE_BATTLES)
    return false
  if (isInArray(event.name, eventIdsForMainGameModeList))
    return true
  return getEventDisplayType(event).canBeSelectedInGcDrawer()
}

function isRaceEvent(event_data) {
  if (!("templates" in event_data))
    return false

  return isInArray("races_template", event_data.templates)
}

let isEventLastManStanding = @(event) ("mission_decl" in event) && ("br_area_change_time" in event.mission_decl)

let getEventRankCalcMode = @(event) event?.rankCalcMode

let isEnableFriendsJoin = @(event) event?.enableFriendsJoin ?? false

let isEventWithLobby = @(event) event?.withLobby ?? false

let getMaxLobbyDisbalance = @(event) event?.maxLobbyDisbalance ?? MAX_PLAYERS_VERSUS

let getEventReqFeature = @(event) event?.reqFeature ?? ""

let getEventPVETrophyName = @(event) event?.pveTrophyName ?? ""

let hasEventFeature = @(event) isEmpty(getEventReqFeature(event))
  || hasFeature(getEventReqFeature(event))

function isEventVisibleByFeature(event) {
  if (hasEventFeature(event))
    return true
  return hasFeature("OnlineShopPacks") && getFeaturePurchaseData(getEventReqFeature(event)).canBePurchased
}


function getEventReqPack(event, checkFeature = false) {
  let feature = getEventReqFeature(event)
  if (isEmpty(feature) || (checkFeature && !hasFeature(feature)))
    return null
  return getFeaturePack(feature)
}



function checkEventFeaturePacks(event, isSilent = false) {
  let pack = getEventReqPack(event)
  if (!pack)
    return true
  return checkPackageFull(pack, isSilent)
}

let getCurGameModeMinMRankForNightBattles = @(event) event?.minMRankForNightBattles

let hasNightGameModes = @(event) getCurGameModeMinMRankForNightBattles(event) != null
let hasSmallTeamsGameModes = @(event) event?.minMRankForSmallTeamsBattles != null

let isEventXboxOnlyAllowed =@(event) (event?.xboxOnlyAllowed ?? false) && is_gdk

let isEventPS4OnlyAllowed =@(event) (event?.ps4OnlyAllowed ?? false) && isPlatformSony

let isEventPlatformOnlyAllowed =@(event) isEventXboxOnlyAllowed(event) || isEventPS4OnlyAllowed(event)

let isTeamSizeBalancedEvent = @(event) event?.balancerMode == "team_size"

let isNoneBalancedEvent = @(event) event?.balancerMode == "none"

let canJoinWithoutRequireCrafts = @(event) !(event?.requireCrafts ?? true)

let isVrModeAllowedInEvent = @(event) event?.isVrModeAllowed != false

let getLeagueConfigByLevel = @(leagueLevel) leaguesConfig?[leagueLevel]

function getLeagueNameByLevel(leagueLevel) {
  let { locId = "leaderboards/notAvailable" } = leaguesConfig?[leagueLevel]
  return loc(locId)
}

function getEventLeagueName(event) {
  let { leaderboardContactTable = null } = event
  if (leaderboardContactTable == null)
    return ""
  let tableData = getUserstatTableData(leaderboardContactTable)
  if (tableData == null)
    return ""

  return getLeagueNameByLevel(tableData?.stats.league_level ?? 0)
}

let buildShortDateTimeStr = @(t)
  " ".concat(buildDateStrShort(t), buildTimeStr(t, false, false))

function getLeaguePeriodText(baseStartTime, baseEndTime, diffIdx) {
  
  let diffTime = TIME_DAY_IN_SECONDS * diffIdx
  let startTime = baseStartTime - diffTime
  let endTime = baseEndTime - diffTime
  return " - ".concat(buildShortDateTimeStr(startTime),
    buildShortDateTimeStr(endTime))
}

function getEventLeaderboardModes(event) {
  let modes = []
  let modesNames = []
  let res = {
    modes
    modesNames
  }
  let { leaderboardContactTable = null } = event
  if (leaderboardContactTable == null)
    return res

  let tableData = getUserstatTableData(leaderboardContactTable)
  if (tableData == null)
    return res

  let endTime = tableData?["$endsAt"] ?? 0
  let startTime = tableData?["$startedAt"] ?? 0
  let tableIdx = (tableData?["$index"] ?? 0)
  if (endTime == 0 || startTime == 0 || tableIdx == 0)
    return res

  for (local i = tableIdx; i > 0; i--) {
    modes.append(i)
    modesNames.append(getLeaguePeriodText(startTime, endTime, tableIdx - i))
    if (modes.len() == MAX_LEAGUES_HISTORY_COUNT)
      break
  }

  return res
}

return {
  hasEventFeature
  eventIdsForMainGameModeList
  getEventEconomicName
  needShowOverrideSlotbar
  getCustomViewCountryData
  isLeaderboardsAvailable
  getEventTournamentMode
  getEventType
  isEventMatchesType
  getEventDisplayType
  setEventDisplayType
  isEventForClan
  isEventForNewbies
  isEventRandomBattles
  isRaceEvent
  isEventLastManStanding
  getEventRankCalcMode
  isEnableFriendsJoin
  isEventWithLobby
  getMaxLobbyDisbalance
  getEventReqFeature
  getEventPVETrophyName
  isEventVisibleByFeature
  getEventReqPack
  checkEventFeaturePacks
  hasNightGameModes
  getCurGameModeMinMRankForNightBattles
  hasSmallTeamsGameModes
  isEventPlatformOnlyAllowed
  isTeamSizeBalancedEvent
  isNoneBalancedEvent
  canJoinWithoutRequireCrafts
  isEventAllowedByPackage
  isVrModeAllowedInEvent
  getLeagueNameByLevel
  getEventLeagueName
  getLeagueConfigByLevel
  getEventLeaderboardModes
}