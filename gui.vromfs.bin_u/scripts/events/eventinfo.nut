from "%scripts/dagui_library.nut" import *
from "%scripts/events/eventsConsts.nut" import EVENT_TYPE, GAME_EVENT_TYPE
from "%scripts/mainConsts.nut" import global_max_players_versus

let { is_gdk } = require("%sqstd/platform.nut")
let { getSeparateLeaderboardPlatformValue } = require("%scripts/social/crossplay.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { getFeaturePack } = require("%scripts/user/features.nut")
let { getFeaturePurchaseData } = require("%scripts/onlineShop/onlineShopState.nut")
let { g_event_display_type } = require("%scripts/events/eventDisplayType.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { checkPackageFull, havePackage } = require("%scripts/clientState/contentPacks.nut")
let { isNewbieEventId } = require("%scripts/user/myStatsState.nut")
let { getUserstatTableData } = require("%scripts/userstat/userstat.nut")
let { buildDateTimeStr } = require("%scripts/time.nut")

let eventIdsForMainGameModeList = [
  "tank_event_in_random_battles_arcade"
  "air_arcade"
]

let leaguesConfig = [
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

let getMaxLobbyDisbalance = @(event) event?.maxLobbyDisbalance ?? global_max_players_versus

let getEventReqFeature = @(event) event?.reqFeature ?? ""

let getEventPVETrophyName = @(event) event?.pveTrophyName ?? ""

function isEventVisibleByFeature(event) {
  let feature = getEventReqFeature(event)
  if (isEmpty(feature) || hasFeature(feature))
    return true
  return hasFeature("OnlineShopPacks") && getFeaturePurchaseData(feature).canBePurchased
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

function getCurLeagueConfig(leaderboardContactTable) {
  let tableData = getUserstatTableData(leaderboardContactTable)
  if (tableData == null)
    return null

  let leagueLevel = tableData?.stats.league_level ?? 0
  return leaguesConfig?[leagueLevel]
}

function getEventLeagueName(event) {
  let { leaderboardContactTable = null } = event
  if (leaderboardContactTable == null)
    return ""
  let tableData = getUserstatTableData(leaderboardContactTable)
  if (tableData == null)
    return ""

  let leagueLevel = tableData?.stats.league_level ?? 0
  let { locId = "" } = leaguesConfig?[leagueLevel]
  let leagueName = locId != "" ? loc(locId) : ""
  let endTime = tableData?["$endsAt"] ?? 0
  if (endTime == 0)
    return leagueName

  let endText = loc("battlePass/endDate",
    { time = buildDateTimeStr(endTime, false, false) })
  return $"{leagueName} {endText}"
}

return {
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
  getEventLeagueName
  getCurLeagueConfig
}