from "%scripts/dagui_library.nut" import *
from "%scripts/leaderboard/leaderboardConsts.nut" import WW_LB_MODE
from "%scripts/events/eventsConsts.nut" import GAME_EVENT_TYPE

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { startsWith, stripTags } = require("%sqstd/string.nut")
let { getEventTournamentMode, isEventLastManStanding
} = require("%scripts/events/eventInfo.nut")

enum LB_MODE {
  ARCADE            = 0x00001
  HISTORICAL        = 0x00002
  SIMULATION        = 0x00004

  AIR_ARCADE        = 0x00010
  AIR_REALISTIC     = 0x00020
  AIR_SIMULATION    = 0x00040

  TANK_ARCADE       = 0x00100
  TANK_REALISTIC    = 0x00200
  TANK_SIMULATION   = 0x00400

  SHIP_ARCADE       = 0x01000
  SHIP_REALISTIC    = 0x02000

  HELICOPTER_ARCADE = 0x10000

  // masks
  COMMON            = 0x0000F
  AIR               = 0x000F0
  TANK              = 0x00F00
  SHIP              = 0x0F000
  HELICOPTER        = 0xF0000
  ALL               = 0xFFFFF
}


let lbModeName = {
  arcade              = LB_MODE.ARCADE
  historical          = LB_MODE.HISTORICAL
  simulation          = LB_MODE.SIMULATION

  air_arcade          = LB_MODE.AIR_ARCADE
  air_realistic       = LB_MODE.AIR_REALISTIC
  air_simulation      = LB_MODE.AIR_SIMULATION

  tank_arcade         = LB_MODE.TANK_ARCADE
  tank_realistic      = LB_MODE.TANK_REALISTIC
  tank_simulation     = LB_MODE.TANK_SIMULATION

  test_ship_arcade    = LB_MODE.SHIP_ARCADE
  test_ship_realistic = LB_MODE.SHIP_REALISTIC

  helicopter_arcade   = LB_MODE.HELICOPTER_ARCADE
}

let wwLbModeName = {
  ww_users            = WW_LB_MODE.WW_USERS
  ww_clans            = WW_LB_MODE.WW_CLANS
  ww_countries        = WW_LB_MODE.WW_COUNTRIES
  ww_users_manager    = WW_LB_MODE.WW_CLANS_MANAGER
  ww_users_clan       = WW_LB_MODE.WW_USERS_CLAN
}

let cache = {
  byField = {}
}

let lbCategoryTypes = {}

function getLbMode(name, isWwLeaderboard = false) {
  if (!isWwLeaderboard && isEmpty(name))
    return 0

  if (isEmpty(name))  //if not mode name then it events leaderboard and WW_LB_MODE need all
    return WW_LB_MODE.ALL

  let lbModeNames = isWwLeaderboard ? wwLbModeName : lbModeName
  if (name in lbModeNames)
    return lbModeNames[name]

  logerr($"Invalid leaderboard mode '{name}'")
  return 0
}

let getLbCategoryTypeById = @(id) lbCategoryTypes?[id] ?? lbCategoryTypes.UNKNOWN

function getLbCategoryTypeByField(field) {
  if (field in cache.byField)
    return cache.byField[field]

  let category = lbCategoryTypes.findvalue(@(v) v.field == field)
  if (category != null)
    cache.byField[field] <- category
  return category ?? lbCategoryTypes.UNKNOWN
}

let categoryTemplate = {
  id = "" //filled automatically by typeName [DEPRECATED]
  field = "" //field name from server response
  lbDataType = lbDataType.NUM
  sort_default = false
  inverse = false
  visualKey = ""
  headerImage = ""
  headerTooltip = ""
  reqFeature = null //show row only when has_feature
  modesMask = LB_MODE.ALL
  wwModesMask = WW_LB_MODE.ALL
  ownProfileOnly = false  //show row only if in checkVisibility params will be set flag "isOwnStats"
  additionalTooltipCategoryes = null
  hideInAdditionalTooltipIfZero = false
  isSortDefaultFilter = false // This field is sort default for events where it is visible.
  showFieldFilter = null // This field will show up only for following events (by tournament_mode).
  showEventFilterFunc = null // This field will show up only for following events (by eventData).

  function getAdditionalTooltipPart(row) {
    if (!this.additionalTooltipCategoryes || !row)
      return ""

    local res = []
    local additionalCategory = null

    foreach (categoryTypeName in this.additionalTooltipCategoryes) {
      additionalCategory = lbCategoryTypes[categoryTypeName]
      if (!(additionalCategory.field in row))
        continue

      // check reqFeature
      if (!additionalCategory.isVisibleByFeature())
        continue

      let value = additionalCategory.lbDataType.getAdditionalTooltipPartValueText(
        row[additionalCategory.field], additionalCategory.hideInAdditionalTooltipIfZero)

      if (!value.len())
        continue

      local tooltipKey = additionalCategory.headerTooltip
      if (startsWith(tooltipKey, "#"))
        tooltipKey = tooltipKey.slice(1)

      res.append(loc("ui/colon").concat(loc(tooltipKey), stripTags(value.tostring())))
    }

    return "\n".join(res)
  }

  function getItemCell(value, row = null, allowNegative = false, forceDataType = null) {
    let res = ::getLbItemCell(this.id, value, (forceDataType ? forceDataType : this.lbDataType), allowNegative)
    let additionalTooltipPart = this.getAdditionalTooltipPart(row)
    if (additionalTooltipPart != "") {
      let resTooltip = ("tooltip" in res) ? $"{res.tooltip}\n" : ""
      res.tooltip <- $"{resTooltip}{additionalTooltipPart}"
    }

    return res
  }

  isVisibleByFeature = @() hasAllFeatures(this.reqFeature) // check reqFeature

  function isVisibleByLbModeName(modeName) {
    // check modesMask
    return ((this.modesMask == LB_MODE.ALL) || ((getLbMode(modeName) & this.modesMask) != 0)) &&
      ((this.wwModesMask == WW_LB_MODE.ALL) || ((getLbMode(modeName, true) & this.wwModesMask) != 0))
  }

  function isVisibleInEvent(event) {
    if (this.showFieldFilter && !isInArray(getEventTournamentMode(event), this.showFieldFilter))
      return false

    if (this.showEventFilterFunc && !this.showEventFilterFunc(event))
      return false

    return true
  }

  isDefaultSortRowInEvent = @(event) this.isSortDefaultFilter && this.isVisibleInEvent(event)
}


function mkCategory(config, id) {
  let category = categoryTemplate.__merge(config)
  let imageId = category.headerImage != "" ? category.headerImage : category.visualKey
  let tooltipId = category.headerTooltip != "" ? category.headerTooltip : category.visualKey
  category.headerImage = $"#ui/gameuiskin#lb_{imageId}.svg"
  category.headerTooltip = $"#multiplayer/{tooltipId}"
  category.id = id
  return category
}

lbCategoryTypes.__update({
  UNKNOWN = {}

  /*COMMON*/
  EACH_PLAYER_VICTORIES = {
    visualKey = "each_player_victories"
    field = "each_player_victories"
  }

  EACH_PLAYER_SESSION = {
    visualKey = "each_player_session"
    field = "each_player_session"
  }

  AVERAGE_POSITION = {
    field = "average_position"
    visualKey = "average_position"
    headerTooltip = "averagePosition"
  }

  FLYOUTS = {
    visualKey = "flyouts"
    field = "flyouts"
    wwModesMask = ~WW_LB_MODE.WW_CLANS_MANAGER
  }

  DEATHS = {
    visualKey = "deaths"
    field  = "deaths"
    wwModesMask = ~WW_LB_MODE.WW_CLANS_MANAGER
  }

  SCORE = {
    field = "score"
    visualKey = "average_score"
    headerTooltip = "score"
  }

  MISSION_SCORE = {
    field = "score"
    visualKey = "average_score"
    headerTooltip = "mission_score"
  }

  WP_EARNED = {
    field = "wpEarned"
    visualKey = "wp_total_gained"
    headerTooltip = "mission_wp_earned"
  }

  TOTAL_SCORE = {
    field = "totalScore"
    visualKey = "total_score"
    headerTooltip = "total_score"
  }

  ACTIVITY = {
    field = "activity"
    visualKey = "activity"
    lbDataType = lbDataType.PERCENT
    headerTooltip = "commander_activity"
  }

  VICTORIES_BATTLES = {
    field = "victories_battles"
    visualKey = "victories_battles"
    lbDataType = lbDataType.PERCENT
    additionalTooltipCategoryes = ["EACH_PLAYER_VICTORIES", "EACH_PLAYER_SESSION"]
  }

  AVERAGE_RELATIVE_POSITION = {
    field = "averageRelativePosition"
    visualKey = "average_relative_position"
    headerTooltip = "averageRelativePosition"
    lbDataType = lbDataType.PERCENT
    additionalTooltipCategoryes = ["AVERAGE_POSITION"]
    modesMask = ~(LB_MODE.AIR_SIMULATION | LB_MODE.HELICOPTER_ARCADE)
  }

  PVP_RATIO = {
    visualKey = "pvp_ratio"
    field = "pvp_ratio"
  }

  AIR_KILLS = {
    visualKey = "air_kills"
    field = "air_kills"
    additionalTooltipCategoryes = ["DEATHS", "FLYOUTS"]
    modesMask = LB_MODE.COMMON
  }

  GROUND_KILLS = {
    visualKey = "ground_kills"
    field = "ground_kills"
    additionalTooltipCategoryes = ["DEATHS", "FLYOUTS"]
    modesMask = LB_MODE.COMMON
  }

  NAVAL_KILLS = {
    visualKey = "naval_kills"
    field = "naval_kills"
    additionalTooltipCategoryes = ["DEATHS", "FLYOUTS"]
    modesMask = LB_MODE.COMMON
  }

  AVERAGE_SCORE = {
    field = "averageScore"
    visualKey = "average_score"
    headerTooltip = "averageScore"
    additionalTooltipCategoryes = ["SCORE"]
    modesMask = (LB_MODE.AIR | LB_MODE.TANK | LB_MODE.SHIP) & (~LB_MODE.AIR_SIMULATION)
  }

  AIR_KILLS_PLAYER = {
    field = "air_kills_player"
    headerTooltip = "lb_air_kills_player"
    hideInAdditionalTooltipIfZero = true
  }

  AIR_KILLS_BOT = {
    field = "air_kills_bot"
    headerTooltip = "lb_air_kills_bot"
    hideInAdditionalTooltipIfZero = true
  }

  AIR_KILLS_AI = {
    field = "air_kills_ai"
    headerTooltip = "lb_air_kills_ai"
    hideInAdditionalTooltipIfZero = true
  }

  GROUND_KILLS_PLAYER = {
    field = "ground_kills_player"
    headerTooltip = "lb_ground_kills_player"
    hideInAdditionalTooltipIfZero = true
  }

  GROUND_KILLS_BOT = {
    field = "ground_kills_bot"
    headerTooltip = "lb_ground_kills_bot"
    hideInAdditionalTooltipIfZero = true
  }

  GROUND_KILLS_AI = {
    field = "ground_kills_ai"
    headerTooltip = "lb_ground_kills_ai"
    hideInAdditionalTooltipIfZero = true
  }

  NAVAL_KILLS_PLAYER = {
    field = "naval_kills_player"
    headerTooltip = "lb_naval_kills_player"
    hideInAdditionalTooltipIfZero = true
  }

  NAVAL_KILLS_BOT = {
    field = "naval_kills_bot"
    headerTooltip = "lb_naval_kills_bot"
    hideInAdditionalTooltipIfZero = true
  }

  NAVAL_KILLS_AI = {
    field = "naval_kills_ai"
    headerTooltip = "lb_naval_kills_ai"
    hideInAdditionalTooltipIfZero = true
  }

  AIR_SPAWN = {
    field = "air_spawn"
    headerTooltip = "lb_air_spawn"
    hideInAdditionalTooltipIfZero = true
  }

  GROUND_SPAWN = {
    field = "ground_spawn"
    headerTooltip = "lb_ground_spawn"
    hideInAdditionalTooltipIfZero = true
  }

  NAVAL_SPAWN = {
    field = "naval_spawn"
    headerTooltip = "lb_naval_spawn"
    hideInAdditionalTooltipIfZero = true
  }

  AIR_DEATH = {
    field = "air_death"
    headerTooltip = "lb_air_death"
    hideInAdditionalTooltipIfZero = true
  }

  GROUND_DEATH = {
    field = "ground_death"
    headerTooltip = "lb_ground_death"
    hideInAdditionalTooltipIfZero = true
  }

  NAVAL_DEATH = {
    field = "naval_death"
    headerTooltip = "lb_naval_death"
    hideInAdditionalTooltipIfZero = true
  }

  AVERAGE_ACTIVE_KILLS_BY_SPAWN = {
    lbDataType = lbDataType.FLOAT
    field = "average_active_kills_by_spawn"
    headerImage = "average_active_kills_by_spawn"
    headerTooltip = "average_active_kills_by_spawn"
    additionalTooltipCategoryes = [
      "AIR_KILLS_PLAYER",
      "AIR_KILLS_BOT",
      "GROUND_KILLS_PLAYER",
      "GROUND_KILLS_BOT",
      "NAVAL_KILLS_PLAYER",
      "NAVAL_KILLS_BOT",
      "AIR_SPAWN",
      "GROUND_SPAWN",
      "NAVAL_SPAWN",
      "AIR_DEATH",
      "GROUND_DEATH",
      "NAVAL_DEATH"
    ]
    modesMask = LB_MODE.AIR | LB_MODE.TANK | LB_MODE.SHIP | LB_MODE.HELICOPTER
  }

  AVERAGE_SCRIPT_KILLS_BY_SPAWN = {
    lbDataType = lbDataType.FLOAT
    field = "average_script_kills_by_spawn"
    headerImage = "average_script_kills_by_spawn"
    headerTooltip = "average_script_kills_by_spawn"
    additionalTooltipCategoryes = [
      "AIR_KILLS_AI",
      "GROUND_KILLS_AI",
      "NAVAL_KILLS_AI",
      "AIR_SPAWN",
      "GROUND_SPAWN",
      "NAVAL_SPAWN",
      "AIR_DEATH",
      "GROUND_DEATH",
      "NAVAL_DEATH"
    ]
    modesMask = LB_MODE.AIR | LB_MODE.TANK | LB_MODE.SHIP | LB_MODE.HELICOPTER
  }

  /*CLAN DUELS*/
  CLANDUELS_CLAN_ELO = {
    field = "clanRating"
    lbDataType = lbDataType.NUM,
    headerImage = "elo_rating"
    headerTooltip = "clan_elo"

    showFieldFilter = [] // not encountered in event leaderboards
  }

  /*EVENTS*/
  EVENTS_PERSONAL_ELO = {
    field = "rating"
    lbDataType = lbDataType.NUM,
    headerImage = "elo_rating"
    headerTooltip = "personal_elo"

    isSortDefaultFilter = true

   showFieldFilter = [
      GAME_EVENT_TYPE.TM_NONE_RACE,
      GAME_EVENT_TYPE.TM_ELO_PERSONAL,
      GAME_EVENT_TYPE.TM_ELO_GROUP,
      GAME_EVENT_TYPE.TM_DOUBLE_ELIMINATION
    ]
  }

  WW_EVENTS_PERSONAL_ELO = {
    field = "rating"
    lbDataType = lbDataType.NUM,
    headerImage = "elo_rating_worldwar"
    headerTooltip = "personal_elo"
    wwModesMask = ~WW_LB_MODE.WW_COUNTRIES

    isSortDefaultFilter = true

    showFieldFilter = [
      GAME_EVENT_TYPE.TM_NONE_RACE,
      GAME_EVENT_TYPE.TM_ELO_PERSONAL,
      GAME_EVENT_TYPE.TM_ELO_GROUP,
      GAME_EVENT_TYPE.TM_DOUBLE_ELIMINATION
    ]
  }

  EVENTS_EACH_PLAYER_FASTLAP = {
    field = "fastlap"
    visualKey = "each_player_fastlap"
    lbDataType = lbDataType.TIME_MSEC
    inverse = true
    showFieldFilter = [GAME_EVENT_TYPE.TM_NONE_RACE]
  }

  EVENTS_EACH_PLAYER_VICTORIES = {
    field = "wins"
    visualKey = "each_player_victories"
  }

  EVENTS_EACH_PLAYER_SESSION = {
    field = "battles"
    visualKey = "each_player_session"
    showEventFilterFunc = @(event) !events.isGameTypeOfEvent(event, "gt_football")
  }

  EVENTS_AIR_KILLS = {
    field = "akills"
    visualKey = "air_kills"
  }

  EVENTS_GROUND_KILLS = {
    field = "gkills"
    visualKey = "ground_kills"
  }

  EVENTS_WP_TOTAL_GAINED = {
    field = "wpEarned"
    visualKey = "wp_total_gained"
    isSortDefaultFilter = true
    showFieldFilter = [GAME_EVENT_TYPE.TM_NONE]
    showEventFilterFunc = @(event) !(event?.mission_decl.isScoreTournament ?? false)
  }

  EVENT_STAT_TOTALKILLS = {
    field = "totalKills"
    visualKey = "air_ground_kills"
    hideInAdditionalTooltipIfZero = true
    additionalTooltipCategoryes = ["EVENTS_AIR_KILLS", "EVENTS_GROUND_KILLS"]
    showEventFilterFunc = @(event) !events.isGameTypeOfEvent(event, "gt_football")
  }

  EVENTS_SUPERIORITY_BATTLES_THRESHOLD = {
    field = "superiorityBattlesThreshold"
    visualKey = "lb_event_superiority_battles_threshold"
  }

  EVENTS_SUPERIORITY = {
    field = "superiority"
    visualKey = "average_relative_position"
    headerTooltip = "averageRelativePosition"
    lbDataType = lbDataType.PERCENT
    additionalTooltipCategoryes = ["EVENTS_SUPERIORITY_BATTLES_THRESHOLD"]
    isSortDefaultFilter = true
    showFieldFilter = [GAME_EVENT_TYPE.TM_NONE]
    showEventFilterFunc = function (event) {
      return isEventLastManStanding(event)
    }
  }

  EVENT_FOOTBALL_MATCHES = {
    field = "battles"
    visualKey = "matches"
    headerImage = "each_player_session"
    showEventFilterFunc = @(event) events.isGameTypeOfEvent(event, "gt_football")
  }

  EVENT_FOOTBALL_GOALS = {
    field = "ext1"
    visualKey = "footballGoals"
    headerImage = "football_goals"
    headerTooltip = "football/goals"
    showEventFilterFunc = @(event) events.isGameTypeOfEvent(event, "gt_football")
  }

  EVENT_FOOTBALL_ASSISTS = {
    field = "ext2"
    visualKey = "footballAssists"
    headerImage = "football_assists"
    headerTooltip = "football/assists"
    showEventFilterFunc = @(event) events.isGameTypeOfEvent(event, "gt_football")
  }

  EVENT_FOOTBALL_SAVES = {
    field = "ext3"
    visualKey = "footballSaves"
    headerImage = "football_saves"
    headerTooltip = "football/saves"
    showEventFilterFunc = @(event) events.isGameTypeOfEvent(event, "gt_football")
  }

  EVENT_FOOTBALL_TOTAL_ACTIONS = {
    field = "ext4"
    visualKey = "footballTotalActions"
    headerImage = "total_score"
    headerTooltip = "football/totalActions"
    showEventFilterFunc = @(event) events.isGameTypeOfEvent(event, "gt_football")
  }

  EVENT_SCORE = {
    field = "ext1"
    visualKey = "total_score"
    headerImage = "total_score"
    headerTooltip = "score"
    isSortDefaultFilter = true
    showEventFilterFunc = @(event) ((event?.leaderboardEventBestStat ?? "") == "ext1")
  }

  EVENT_SCORE_RATING = {
    field = "score_rating"
    visualKey = "total_score"
    headerImage = "total_score"
    headerTooltip = "personal_elo"
    isSortDefaultFilter = true
    showEventFilterFunc = @(event) ((event?.leaderboardEventBestStat ?? "") == "score_rating")
  }

  // for World War
  OPERATION_COUNT = {
    field = "operation_count"
    visualKey = "operation_count"
    headerImage = "each_player_session"
    wwModesMask = ~WW_LB_MODE.WW_USERS & ~WW_LB_MODE.WW_USERS_CLAN
  }

  OPERATION_WINRATE = {
    lbDataType = lbDataType.PERCENT
    field = "operation_winrate"
    visualKey = "operation_winrate"
    headerImage = "victories_battles"
    wwModesMask = ~WW_LB_MODE.WW_USERS & ~WW_LB_MODE.WW_USERS_CLAN
  }

  BATTLE_COUNT = {
    field = "battle_count"
    visualKey = "each_player_session"
    headerImage = "each_player_session"
  }

  BATTLE_WINRATE = {
    lbDataType = lbDataType.PERCENT
    field = "battle_winrate"
    visualKey = "victories_battles"
    headerImage = "victories_battles"
  }

  PLAYER_KILLS = {
    field = "playerKills"
    visualKey = "lb_kills_player"
    headerImage = "average_active_kills"
    additionalTooltipCategoryes = ["AIR_KILLS_PLAYER", "GROUND_KILLS_PLAYER", "NAVAL_KILLS_PLAYER"]
    wwModesMask = ~WW_LB_MODE.WW_CLANS_MANAGER
  }

  AI_KILLS = {
    field = "aiKills"
    visualKey = "lb_kills_ai"
    headerImage = "average_script_kills"
    additionalTooltipCategoryes = ["AIR_KILLS_AI", "GROUND_KILLS_AI", "NAVAL_KILLS_AI"]
    wwModesMask = ~WW_LB_MODE.WW_CLANS_MANAGER
  }

  AVG_PLACE = {
    field = "avg_place"
    visualKey = "averagePosition"
    headerImage = "average_position"
    wwModesMask = (WW_LB_MODE.WW_USERS | WW_LB_MODE.WW_USERS_CLAN) & ~WW_LB_MODE.WW_CLANS_MANAGER
    lbDataType = lbDataType.FLOAT
  }

  AVG_SCORE = {
    field = "avg_score"
    visualKey = "averageScore"
    headerImage = "average_score"
    wwModesMask = (WW_LB_MODE.WW_USERS | WW_LB_MODE.WW_USERS_CLAN) & ~WW_LB_MODE.WW_CLANS_MANAGER
  }

  UNIT_RANK = {
    field = "unit_rank"
    visualKey = "unitRank"
    headerImage = "unit_rank"
    wwModesMask = WW_LB_MODE.WW_USERS_CLAN
  }
}.map(mkCategory))

let eventsTableConfig = [
  lbCategoryTypes.EVENTS_PERSONAL_ELO
  lbCategoryTypes.EVENTS_SUPERIORITY
  lbCategoryTypes.EVENTS_EACH_PLAYER_FASTLAP
  lbCategoryTypes.EVENTS_EACH_PLAYER_VICTORIES
  lbCategoryTypes.EVENTS_EACH_PLAYER_SESSION
  lbCategoryTypes.EVENT_STAT_TOTALKILLS
  lbCategoryTypes.EVENTS_WP_TOTAL_GAINED
  lbCategoryTypes.CLANDUELS_CLAN_ELO
  lbCategoryTypes.EVENT_FOOTBALL_MATCHES
  lbCategoryTypes.EVENT_FOOTBALL_GOALS
  lbCategoryTypes.EVENT_FOOTBALL_ASSISTS
  lbCategoryTypes.EVENT_FOOTBALL_SAVES
  lbCategoryTypes.EVENT_FOOTBALL_TOTAL_ACTIONS
  lbCategoryTypes.EVENT_SCORE
  lbCategoryTypes.EVENT_SCORE_RATING
]

return {
  lbCategoryTypes
  getLbCategoryTypeById
  getLbCategoryTypeByField
  eventsTableConfig
}
