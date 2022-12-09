from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this
let ww_leaderboard = require("ww_leaderboard")
let { getClansInfoByClanIds } = require("%scripts/clans/clansListShortInfo.nut")
let { round } = require("math")

let modes = [
  {
    mode  = "ww_users"
    appId = "1134"
    mask  = WW_LB_MODE.WW_USERS
    field = ::g_lb_category.WW_EVENTS_PERSONAL_ELO.field
    isInLeaderboardModes = true
    hasDaysData = true
    rewardsTableName = "user_leaderboards"
    needShowConsoleFilter = true
  },
  {
    mode  = "ww_users_manager"
    appId = "1134"
    isInLeaderboardModes = true
    hasDaysData = true
    rewardsTableName = "user_leaderboards"
    needShowConsoleFilter = true
    needAddClanInfo = true
  },
  {
    mode  = "ww_clans"
    appId = "1135"
    mask  = WW_LB_MODE.WW_CLANS
    field = ::g_lb_category.WW_EVENTS_PERSONAL_ELO.field
    isInLeaderboardModes = true
    hasDaysData = false
    rewardsTableName = "clan_leaderboards"
  },
  {
    mode  = "ww_countries"
    appId = "1136"
    mask  = WW_LB_MODE.WW_COUNTRIES
    field = ::g_lb_category.OPERATION_COUNT.field
    isInLeaderboardModes = true
    hasDaysData = false
    needFeature = "WorldWarCountryLeaderboard"
  },
  {
    mode  = "ww_users_clan"
    appId = "1134"
    hasDaysData = false
  }]

let function getModeByName(mName)
{
  return ::u.search(modes, @(m) m.mode == mName
    && (!m?.needFeature || hasFeature(m.needFeature)))
}

/*
dataParams = {
  gameMode = "ww_users" + "__nordwind_wwmap"
  table    = day && day > 0 ? "day" + day : "season"
  start    = 1  // start position lb request
  count    = 0  // count of records
  category = ::g_lb_category.WW_EVENTS_PERSONAL_ELO.field // sort field parametr
  platformFilter = "" //"ps4" for ps4 only players
}
headersParams = {
  userId = -1 //optional parameter. Equal to user id for user leaderboard and clan id for clan leaderboard
} */
let function requestWwLeaderboardData(modeName, dataParams, cb, headersParams = {})
{
  let mode = getModeByName(modeName)
  if (!mode)
    return

  let requestData = {
    add_token = true
    action = ("userId" in headersParams) ? "ano_get_leaderboard_json" : "cln_get_leaderboard_json" //Need use ano_get_leaderboard_json for request with userId

    headers = {
      appid  = mode.appId
      format = "json"    // TODO: remove me after leaderboard update
    }.__update(headersParams)

    data = {
      valueType   = LEADERBOARD_VALUE_TOTAL
      resolveNick = true
    }.__update(dataParams)
  }

  ww_leaderboard.request(requestData, cb)
}

let function requestWwLeaderboardModes(modeName, cb)
{
  if (!::g_login.isLoggedIn())
    return

  let mode = getModeByName(modeName)
  if (!mode)
    return

  let requestData = {
    add_token = true
    headers = { appid = mode.appId }
    action = "cmn_get_global_leaderboard_modes_json"
  }

  ww_leaderboard.request(requestData, cb)
}

let function getSeasonDay(days)
{
  if (!days)
    return 0

  local seasonDay = 0
  foreach (dayId in days)
    if (dayId.slice(0, 3) == "day")
    {
      let dayNumberText = dayId.slice(3)
      if (::g_string.isStringInteger(dayNumberText))
        seasonDay = max(seasonDay, dayNumberText.tointeger())
    }

  return seasonDay
}

let wwLeaderboardValueFactors = {
  rating = 0.0001
  operation_winrate = 0.0001
  battle_winrate = 0.0001
  avg_place = 0.0001
  avg_score = 0.0001
}
let wwLeaderboardKeyCorrection = {
  idx = "pos"
  playerAKills = "air_kills_player"
  playerGKills = "ground_kills_player"
  playerNKills = "naval_kills_player"
  aiAKills = "air_kills_ai"
  aiGKills = "ground_kills_ai"
  aiNKills = "naval_kills_ai"
}

let function convertWwLeaderboardData(result, applyLocalisationToName = false)
{
  let list = []
  foreach (rowId, rowData in result)
  {
    if (type(rowData) != "table")
      continue

    let lbData = {
      name = applyLocalisationToName ? loc(rowId) : rowId
    }
    foreach (columnId, columnData in rowData)
    {
      let key = wwLeaderboardKeyCorrection?[columnId] ?? columnId
      if (key in lbData && ::u.isEmpty(columnData))
        continue

      let valueFactor = wwLeaderboardValueFactors?[columnId]
      local value = type(columnData) == "table"
        ? columnData?.value_total
        : columnId == "name" && applyLocalisationToName
            ? loc(columnData)
            : columnData
      if (valueFactor)
        value = value * valueFactor

      lbData[key] <- value
    }
    list.append(lbData)
  }
  list.sort(@(a, b) a.pos < 0 <=> b.pos < 0 || a.pos <=> b.pos)

  return { rows = list }
}

let function addClanInfoIfNeedAndConvert(modeName, result, applyLocalisationToName = false) {
  let lbRows = convertWwLeaderboardData(result, applyLocalisationToName)
  let mode = getModeByName(modeName)
  if (!(mode?.needAddClanInfo ?? false))
    return lbRows

  let clanInfoList = getClansInfoByClanIds(lbRows.rows.map(@(row) row?.clanId ?? ""))
  lbRows.rows.map(@(row) row.__update({
    needAddClanTag = true
    clanTag = clanInfoList?[row?.clanId ?? ""].tag ?? ""
  }))

  return lbRows
}

let function isUsersLeaderboard(lbModeData) {
  return lbModeData.appId == "1134"
}

let function updateClanByWWLBAndDo(clanInfo, afterUpdate)
{
  if(!::g_world_war.isWWSeasonActive())
    return afterUpdate(clanInfo)

  requestWwLeaderboardData("ww_clans",
    {
      gameMode = "ww_clans"
      table    = "season"
      start    = null
      count    = 0
      category = ::g_lb_category.WW_EVENTS_PERSONAL_ELO.field
    },
    function (response){
      let lbData = response?[clanInfo.tag]
      if(lbData)
      {
        let idx = lbData?.idx
        let rating = lbData?.rating?.value_total
        if(rating != null)
          clanInfo.rating <- round(rating / 10000.0).tointeger()
        if(idx != null)
          clanInfo.place <- idx + 1
      }
      clanInfo.hasLBData <- lbData != null && clanInfo.canShowActivity()
      afterUpdate(clanInfo)
    }, {userId =  clanInfo.id})
}

return {
  modes = modes
  getSeasonDay = getSeasonDay
  getDayIdByNumber = @(number) "day" + number
  getModeByName = getModeByName
  requestWwLeaderboardData = requestWwLeaderboardData
  requestWwLeaderboardModes = requestWwLeaderboardModes
  convertWwLeaderboardData = convertWwLeaderboardData
  isUsersLeaderboard = isUsersLeaderboard
  updateClanByWWLBAndDo = updateClanByWWLBAndDo
  addClanInfoIfNeedAndConvert = addClanInfoIfNeedAndConvert
}
