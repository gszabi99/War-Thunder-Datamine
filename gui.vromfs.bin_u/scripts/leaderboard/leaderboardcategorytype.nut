local enums = ::require("sqStdlibs/helpers/enums.nut")
local { hasAllFeatures } = require("scripts/user/features.nut")

global enum LB_MODE
{
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

global enum WW_LB_MODE
{
  WW_USERS          = 0x00001
  WW_CLANS          = 0x00002
  WW_COUNTRIES      = 0x00004
  WW_CLANS_MANAGER  = 0x00010
  WW_USERS_CLAN     = 0x00020

  ALL               = 0xFFFFF
}


::lb_mode_name <- {
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

::ww_lb_mode_name <- {
  ww_users            = WW_LB_MODE.WW_USERS
  ww_clans            = WW_LB_MODE.WW_CLANS
  ww_countries        = WW_LB_MODE.WW_COUNTRIES
  ww_users_manager    = WW_LB_MODE.WW_CLANS_MANAGER
  ww_users_clan       = WW_LB_MODE.WW_USERS_CLAN
}


::get_lb_mode <- function get_lb_mode(name, isWwLeaderboard = false)
{
  if (!isWwLeaderboard && ::u.isEmpty(name))
    return 0

  if (::u.isEmpty(name))  //if not mode name then it events leaderboard and WW_LB_MODE need all
    return WW_LB_MODE.ALL

  local lbModeNames = isWwLeaderboard ? ::ww_lb_mode_name : ::lb_mode_name
  if (name in lbModeNames)
    return lbModeNames[name]

  ::dagor.logerr("Invalid leaderboard mode '" + name + "'")
  return 0
}


::g_lb_category <- {
  types = []
  cache = {
    byId = {}
    byField = {}
  }
}

g_lb_category.getTypeById <- function getTypeById(id)
{
  return enums.getCachedType("id", id, ::g_lb_category.cache.byId,
    ::g_lb_category, UNKNOWN)
}

g_lb_category.getTypeByField <- function getTypeByField(field)
{
  return enums.getCachedType("field", field, ::g_lb_category.cache.byField,
    ::g_lb_category, UNKNOWN)
}

g_lb_category._getAdditionalTooltipPart <- function _getAdditionalTooltipPart(row)
{
  if (!additionalTooltipCategoryes || !row)
    return ""

  local res = ""
  local additionalCategory = null

  foreach (categoryTypeName in additionalTooltipCategoryes)
  {
    additionalCategory = ::g_lb_category[categoryTypeName]
    if (!(additionalCategory.field in row))
    {
      continue
    }

    // check reqFeature
    if (!additionalCategory.isVisibleByFeature())
      continue

    local value = additionalCategory.type.getAdditionalTooltipPartValueText(
                    row[additionalCategory.field],
                    additionalCategory.hideInAdditionalTooltipIfZero)


    if (!value.len())
      continue

    local tooltipKey = additionalCategory.headerTooltip
    if (::g_string.startsWith(tooltipKey, "#"))
      tooltipKey = tooltipKey.slice(1)

    res += (res.len() ? "\n" : "") +
      ::loc(tooltipKey) + ::loc("ui/colon") + ::g_string.stripTags("" + value)
  }

  return res
}

::g_lb_category.template <- {
  id = ""//filled automatically by typeName [DEPRECATED]
  field = "" //field name from server response
  type = ::g_lb_data_type.NUM
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

  getAdditionalTooltipPart = ::g_lb_category._getAdditionalTooltipPart

  getItemCell = function(value, row = null, allowNegative = false, forceDataType = null)
  {
    local res = ::getLbItemCell(id, value, (forceDataType ? forceDataType : type), allowNegative)
    local additionalTooltipPart = getAdditionalTooltipPart(row)
    if (additionalTooltipPart != "")
      res.tooltip <- (("tooltip" in res) ? res.tooltip + "\n" : "") + additionalTooltipPart

    return res
  }

  isVisibleByFeature = function()
  {
    // check reqFeature
    return hasAllFeatures(reqFeature)
  }

  isVisibleByLbModeName = function(modeName)
  {
    // check modesMask
    return ((modesMask == LB_MODE.ALL) || ((::get_lb_mode(modeName) & modesMask) != 0)) &&
      ((wwModesMask == WW_LB_MODE.ALL) || ((::get_lb_mode(modeName, true) & wwModesMask) != 0))
  }

  isVisibleInEvent = function(event)
  {
    if (showFieldFilter && !::isInArray(::events.getEventTournamentMode(event), showFieldFilter))
      return false

    if (showEventFilterFunc && !showEventFilterFunc(event))
      return false

    return true
  }

  isDefaultSortRowInEvent = @(event) isSortDefaultFilter && isVisibleInEvent(event)
}


g_lb_category._typeConstructor <- function _typeConstructor ()
{
  headerImage = "#ui/gameuiskin#lb_" + (headerImage != "" ? headerImage : visualKey) + ".svg"
  headerTooltip = "#multiplayer/" + (headerTooltip != "" ? headerTooltip : visualKey)
}

enums.addTypesByGlobalName("g_lb_category", {
    UNKNOWN = {
    }

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
      visualKey = "total_score"
      headerTooltip = "score"
    }

    VICTORIES_BATTLES = {
      field = "victories_battles"
      visualKey = "victories_battles"
      type = ::g_lb_data_type.PERCENT
      additionalTooltipCategoryes = ["EACH_PLAYER_VICTORIES", "EACH_PLAYER_SESSION"]
    }

    AVERAGE_RELATIVE_POSITION = {
      field = "averageRelativePosition"
      visualKey = "average_relative_position"
      headerTooltip = "averageRelativePosition"
      type = ::g_lb_data_type.PERCENT
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
      reqFeature = ["Ships"]
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
      reqFeature = ["Ships"]
      hideInAdditionalTooltipIfZero = true
    }

    NAVAL_KILLS_BOT = {
      field = "naval_kills_bot"
      headerTooltip = "lb_naval_kills_bot"
      reqFeature = ["Ships"]
      hideInAdditionalTooltipIfZero = true
    }

    NAVAL_KILLS_AI = {
      field = "naval_kills_ai"
      headerTooltip = "lb_naval_kills_ai"
      reqFeature = ["Ships"]
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
      reqFeature = ["Ships"]
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
      reqFeature = ["Ships"]
    }

    AVERAGE_ACTIVE_KILLS_BY_SPAWN = {
      type = ::g_lb_data_type.FLOAT
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
      type = ::g_lb_data_type.FLOAT
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
      type = ::g_lb_data_type.NUM,
      headerImage = "elo_rating"
      headerTooltip = "clan_elo"

      showFieldFilter = [] // not encountered in event leaderboards
    }

    /*EVENTS*/
    EVENTS_PERSONAL_ELO = {
      field = "rating"
      type = ::g_lb_data_type.NUM,
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
      type = ::g_lb_data_type.NUM,
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
      type = ::g_lb_data_type.TIME_MSEC
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
      showEventFilterFunc = @(event) !::events.isGameTypeOfEvent(event, "gt_football")
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
    }

    EVENT_STAT_TOTALKILLS = {
      field = "totalKills"
      visualKey = "air_ground_kills"
      hideInAdditionalTooltipIfZero = true
      additionalTooltipCategoryes = ["EVENTS_AIR_KILLS", "EVENTS_GROUND_KILLS"]
      showEventFilterFunc = @(event) !::events.isGameTypeOfEvent(event, "gt_football")
    }

    EVENTS_SUPERIORITY_BATTLES_THRESHOLD = {
      field = "superiorityBattlesThreshold"
      visualKey = "lb_event_superiority_battles_threshold"
    }

    EVENTS_SUPERIORITY = {
      field = "superiority"
      visualKey = "average_relative_position"
      headerTooltip = "averageRelativePosition"
      type = ::g_lb_data_type.PERCENT
      additionalTooltipCategoryes = ["EVENTS_SUPERIORITY_BATTLES_THRESHOLD"]
      isSortDefaultFilter = true
      showFieldFilter = [GAME_EVENT_TYPE.TM_NONE]
      showEventFilterFunc = function (event) {
        return ::events.isEventLastManStanding(event)
      }
    }

    EVENT_FOOTBALL_MATCHES = {
      field = "battles"
      visualKey = "matches"
      headerImage = "each_player_session"
      showEventFilterFunc = @(event) ::events.isGameTypeOfEvent(event, "gt_football")
    }

    EVENT_FOOTBALL_GOALS = {
      field = "ext1"
      visualKey = "footballGoals"
      headerImage = "target_hits"
      headerTooltip = "football/goals"
      showEventFilterFunc = @(event) ::events.isGameTypeOfEvent(event, "gt_football")
    }

    EVENT_FOOTBALL_ASSISTS = {
      field = "ext2"
      visualKey = "footballAssists"
      headerImage = "total_score"
      headerTooltip = "football/assists"
      showEventFilterFunc = @(event) ::events.isGameTypeOfEvent(event, "gt_football")
    }

    // for World War
    OPERATION_COUNT = {
      field = "operation_count"
      visualKey = "operation_count"
      headerImage = "each_player_session"
      wwModesMask = ~WW_LB_MODE.WW_USERS & ~WW_LB_MODE.WW_USERS_CLAN
    }

    OPERATION_WINRATE = {
      type = ::g_lb_data_type.PERCENT
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
      type = ::g_lb_data_type.PERCENT
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
      type = ::g_lb_data_type.FLOAT
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
  },
::g_lb_category._typeConstructor, "id")

