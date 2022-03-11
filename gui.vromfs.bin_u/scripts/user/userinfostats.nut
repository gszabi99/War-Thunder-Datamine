local time = require("scripts/time.nut")
local avatars = require("scripts/user/avatars.nut")
local { hasAllFeatures } = require("scripts/user/features.nut")
local { eachParam, eachBlock } = require("std/datablock.nut")
local { shopCountriesList } = require("scripts/shop/shopCountriesList.nut")

local statsFm = ["fighter", "bomber", "assault"]
local statsTanks = ["tank", "tank_destroyer", "heavy_tank", "SPAA"]
local statsShips = [
  "torpedo_boat"
  "gun_boat"
  "torpedo_gun_boat"
  "submarine_chaser"
  "destroyer"
  "naval_ferry_barge"
  "cruiser"
]
local statsHelicopters = ["helicopter"]
statsFm.extend(statsHelicopters)
statsFm.extend(statsTanks)
statsFm.extend(statsShips)
local statsConfig = [
  {
    name = "mainmenu/titleVersus"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = "pvp_played"  //!! mode incoming by ::get_player_public_stats
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = "pvp_played"
  }
  {
    id = "respawns"
    name = "stats/flights"
    mode = "pvp_played"
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = "pvp_played"
    separateRowsByFm = true
    timeFormat = true
  }
  {
    id = "air_kills"
    name = "stats/kills_air"
    mode = "pvp_played"
  }
  {
    id = "ground_kills"
    name = "stats/kills_ground"
    mode = "pvp_played"
  }
  {
    id = "naval_kills"
    name = "stats/kills_naval"
    mode = "pvp_played"
    reqFeature = ["Ships"]
  }

  {
    name = "mainmenu/btnSkirmish"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = "skirmish_played"
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = "skirmish_played"
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = "skirmish_played"
    timeFormat = true
  }

  {
    name = "mainmenu/btnPvE"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = ["dynamic_played", "builder_played", "single_played"] //"campaign_played"
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = ["dynamic_played", "builder_played", "single_played"]
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = ["dynamic_played", "builder_played", "single_played"]
    timeFormat = true
  }
]

local defaultSummaryItem = {
  id = ""
  name = ""
  mode = null
  fm = null
  header = false
  separateRowsByFm = false
  timeFormat = false
  reqFeature = null
}
foreach(idx, stat in statsConfig)
  foreach(param, value in defaultSummaryItem)
    if (!(param in stat))
      statsConfig[idx][param] <- value

local function getAirsStatsFromBlk(blk) {
  local res = {}
  eachBlock(blk, function(diffBlk, diffName) {

    local diffData = {}
    eachBlock(diffBlk, function(typeBlk, typeName) {

      local typeData = []
      eachBlock(typeBlk, function(airBlk, airName) {

        local airData = { name = airName }
        foreach(stat in ::air_stats_list)
        {
          if ("reqFeature" in stat && !hasAllFeatures(stat.reqFeature))
            continue

          if ("countFunc" in stat)
            airData[stat.id] <- stat.countFunc(airBlk)
          else
            airData[stat.id] <- airBlk?[stat.id] ?? 0
        }
        typeData.append(airData)
      })
      if (typeData.len() > 0)
        diffData[typeName] <- typeData
    })
    if (diffData.len() > 0)
      res[diffName] <- diffData
  })
  return res
}

local function buildProfileSummaryRowData(config, summary, diffCode, textId = "")
{
  local row = [{ id = textId, text = "#" + config.name, tdalign = "left" }]
  local modeList = (typeof config.mode == "array") ? config.mode : [config.mode]
  local diff = ::g_difficulty.getDifficultyByDiffCode(diffCode)
  if (diff == ::g_difficulty.UNKNOWN)
    return

  local value = 0
  foreach(mode in modeList)
  {
    local sumData = summary?[mode]?[diff.name]
    if (!sumData)
      continue

    if (config.fm == null)
    {
      if (config.id in sumData)
        value += sumData[config.id]
      else
        for (local i = 0; i < statsFm.len(); i++)
          if ((statsFm[i] in sumData) && (config.id in sumData[statsFm[i]]))
            value += sumData[statsFm[i]][config.id]
    } else
      if ((config.fm in sumData) && (config.id in sumData[config.fm]))
        value += sumData[config.fm][config.id]
  }
  local s = config.timeFormat? time.hoursToString(time.secondsToHours(value), false) : value
  local tooltip = diff.getLocName()
  row.append({text = s.tostring(), tooltip = tooltip})
  return buildTableRowNoPad("", row)
}

local function fillProfileSummary(sObj, summary, diff) {
  if (!::checkObj(sObj))
    return

  local guiScene = sObj.getScene()
  local data = ""
  local textsToSet = {}
  foreach(idx, item in statsConfig)
  {
    if (!hasAllFeatures(item.reqFeature))
      continue

    if (item.header)
      data += buildTableRowNoPad("", ["#" + item.name], null,
                  format("headerRow:t='%s'; ", idx? "yes" : "first"))
    else if (item.separateRowsByFm)
      for (local i = 0; i < statsFm.len(); i++)
      {
        if (::isInArray(statsFm[i], statsTanks) && !::has_feature("Tanks"))
          continue
        if (::isInArray(statsFm[i], statsShips) && !::has_feature("Ships"))
          continue

        local rowId = "row_" + idx + "_" + i
        item.fm = statsFm[i]
        data += buildProfileSummaryRowData(item, summary, diff, rowId)
        textsToSet["txt_" + rowId] <- ::loc(item.name) + " (" + ::loc("mainmenu/type_"+ statsFm[i].tolower()) +")"
      }
    else
      data += buildProfileSummaryRowData(item, summary, diff)
  }

  guiScene.replaceContentFromText(sObj, data, data.len(), this)
  foreach(id, text in textsToSet)
    sObj.findObject(id).setValue(text)
}

local function getCountryMedals(countryId, profileData = null)
{
  local res = []
  local medalsList = profileData?.unlocks?.medal ?? []
  local unlocks = ::g_unlocks.getUnlocksByTypeInBlkOrder("medal")
  foreach (cb in unlocks)
    if (cb?.country == countryId)
      if ((!profileData && ::is_unlocked_scripted(::UNLOCKABLE_MEDAL, cb.id)) || (medalsList?[cb.id] ?? 0) > 0)
        res.append(cb.id)
  return res
}

local function getPlayerStatsFromBlk(blk) {
  local player = {
    name = blk?.nick
    lastDay = blk?.lastDay
    registerDay = blk?.registerDay
    title = blk?.title ?? ""
    titles = (blk?.titles ?? ::DataBlock()) % "name"
    clanTag = blk?.clanTag ?? ""
    clanName = blk?.clanName ?? ""
    clanType = blk?.clanType ?? 0
    exp = blk?.exp ?? 0

    rank = 0
    rankProgress = 0
    prestige = 0

    unlocks = {}
    countryStats = {}

    icon = avatars.getIconById(blk?.icon)

    aircrafts = []
    crews = []

    //stats & leaderboards
    summary = blk?.summary? ::buildTableFromBlk(blk.summary) : {}
    userstat = blk?.userstat? getAirsStatsFromBlk(blk.userstat) : {}
    leaderboard = blk?.leaderboard? ::buildTableFromBlk(blk.leaderboard) : {}
  }

  if (blk?.userid != null)
    player.uid <- blk.userid

  player.rank = ::get_rank_by_exp(player.exp)
  player.rankProgress = ::calc_rank_progress(player)

  player.prestige = ::get_prestige_by_rank(player.rank)

  //unlocks
  eachBlock(blk?.unlocks, function(uBlk, unlock) {
    local uType = uBlk?.type
    if (!uType)
      return

    if (!(uType in player.unlocks))
      player.unlocks[uType] <- {}
    player.unlocks[uType][unlock] <- uBlk?.stage ?? 1
  })

  foreach(i, country in shopCountriesList)
  {
    local cData = {
      medalsCount = getCountryMedals(country, player).len()
      unitsCount = 0
      eliteUnitsCount = 0
    }
    if (blk?.aircrafts?[country])
    {
      cData.unitsCount = blk.aircrafts[country].paramCount()
      eachParam(blk.aircrafts[country], function(unitEliteStatus) {
        if (::isUnitEliteByStatus(unitEliteStatus))
          cData.eliteUnitsCount++
      })
    }
    player.countryStats[country] <- cData
  }

  //aircrafts list
  eachBlock(blk?.aircrafts, @(_, airName) player.aircrafts.append(airName))

  //same with ::g_crews_list.get()
  eachBlock(blk?.slots, function(crewBlk, country) {
    local countryData = { country, crews = [] }
    eachParam(crewBlk, @(_, aircraft) countryData.crews.append({ aircraft }))
    player.crews.append(countryData)
  })

  return player
}

return {
  statsTanks
  fillProfileSummary
  getCountryMedals
  getPlayerStatsFromBlk
}
