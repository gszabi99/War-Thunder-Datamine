from "%scripts/dagui_natives.nut" import get_player_public_stats, get_cur_rank_info, clan_get_my_clan_name, clan_get_my_clan_id, clan_get_my_clan_tag, clan_get_my_clan_type, shop_get_free_exp
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import buildTableRowNoPad
from "%scripts/utils_sa.nut" import is_multiplayer

let { getNumUnlocked } = require("unlocks")
let { get_mp_session_info } = require("guiMission")
let { get_mp_local_team } = require("mission")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let DataBlock = require("DataBlock")
let { isDataBlock } = require("%sqstd/underscore.nut")
let { format } = require("string")
let time = require("%scripts/time.nut")
let avatars = require("%scripts/user/avatars.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { convertBlk, eachParam, eachBlock } = require("%sqstd/datablock.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { userName } = require("%scripts/user/profileStates.nut")
let { ranksPersist, expPerRank, getRankByExp, getPrestigeByRank
} = require("%scripts/ranks.nut")
let { isUnitEliteByStatus } = require("%scripts/unit/unitStatus.nut")
let { clanUserTable } = require("%scripts/contacts/contactsManager.nut")

let statsFm = ["fighter", "bomber", "assault"]
let statsTanks = ["tank", "tank_destroyer", "heavy_tank", "SPAA"]
let statsShips = [
  "torpedo_boat"
  "gun_boat"
  "torpedo_gun_boat"
  "submarine_chaser"
  "destroyer"
  "naval_ferry_barge"
  "cruiser"
]
let statsHelicopters = ["helicopter"]
statsFm.extend(statsHelicopters)
statsFm.extend(statsTanks)
statsFm.extend(statsShips)
let statsConfig = [
  {
    name = "mainmenu/titleVersus"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = "pvp_played"  //!! mode incoming by get_player_public_stats
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

let defaultSummaryItem = {
  id = ""
  name = ""
  mode = null
  fm = null
  header = false
  separateRowsByFm = false
  timeFormat = false
  reqFeature = null
}
foreach (idx, stat in statsConfig)
  foreach (param, value in defaultSummaryItem)
    if (!(param in stat))
      statsConfig[idx][param] <- value

let airStatsListConfig = [
  { id = "victories", icon = "lb_each_player_victories", text = "multiplayer/each_player_victories" },
  { id = "sessions", icon = "lb_each_player_session", text = "multiplayer/each_player_session"
    countFunc = function(statBlk) {
      local sessions = statBlk?.victories ?? 0
      sessions += statBlk?.defeats ?? 0
      return sessions
    }
  },
  { id = "victories_battles", type = lbDataType.PERCENT
    countFunc = function(statBlk) {
      let victories = statBlk?.victories ?? 0
      let sessions = victories + (statBlk?.defeats ?? 0)
      if (sessions > 0)
        return victories.tofloat() / sessions
      return 0
    }
  },
  "flyouts",
  "deaths",
  "air_kills",
  "ground_kills",
  { id = "naval_kills", icon = "lb_naval_kills", text = "multiplayer/naval_kills" },
  { id = "wp_total", icon = "lb_wp_total_gained", text = "multiplayer/wp_total_gained", ownProfileOnly = true },
  { id = "online_exp_total", icon = "lb_online_exp_gained_for_common", text = "multiplayer/online_exp_gained_for_common" },
]
foreach (idx, val in airStatsListConfig) {
  if (type(val) == "string")
    airStatsListConfig[idx] = { id = val }
  if ("type" not in airStatsListConfig[idx])
    airStatsListConfig[idx].type <- lbDataType.NUM
}

let currentUserProfile = {
  name = ""
  icon = "cardicon_default"
  pilotId = 0
  country = "country_ussr"
  balance = 0
  rank = 0
  prestige = 0
  rankProgress = 0 //0..100
  medals = 0
  aircrafts = 0
  gold = 0

  exp = -1
  exp_by_country = {}
  ranks = {}
}

function getPlayerRankByCountry(c = null, profileData = null) {
  if (!profileData)
    profileData = currentUserProfile
  if (c == null || c == "")
    return profileData.rank
  if (c in profileData.ranks)
    return profileData.ranks[c]
  return 0
}

let playerRankByCountries = {}
function updatePlayerRankByCountries() {
  foreach (c in shopCountriesList)
    playerRankByCountries[c] <- getPlayerRankByCountry(c)
}

function updatePlayerRankByCountry(country, rank) {
  playerRankByCountries[country] <- rank
}

function getPlayerExpByCountry(c = null, profileData = null) {
  if (!profileData)
    profileData = currentUserProfile
  if (c == null || c == "")
    return profileData.exp
  if (c in profileData.exp_by_country)
    return profileData.exp_by_country[c]
  return 0
}

function getCurExpTable(profileData) {
  local res = null
  let rank = getPlayerRankByCountry(null, profileData)
  let maxRank = ranksPersist.max_player_rank

  if (rank < maxRank) {
    let expTbl = expPerRank
    if (rank >= expTbl.len())
      return res

    let prev = (rank > 0) ? expTbl[rank - 1] : 0
    let next = expTbl[rank]
    let cur = getPlayerExpByCountry(null, profileData)
    res = {
      rank
      exp     = cur - prev
      rankExp = next - prev
    }
  }
  return res
}

function calcRankProgress(profileData) {
  let rankTbl = getCurExpTable(profileData)
  if (rankTbl)
    return (1000.0 * rankTbl.exp.tofloat() / rankTbl.rankExp.tofloat()).tointeger()
  return -1
}

function getAirsStatsFromBlk(blk) {
  let res = {}
  eachBlock(blk, function(diffBlk, diffName) {

    let diffData = {}
    eachBlock(diffBlk, function(typeBlk, typeName) {

      let typeData = []
      eachBlock(typeBlk, function(airBlk, airName) {

        let airData = { name = airName }
        foreach (stat in airStatsListConfig) {
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

function buildProfileSummaryRowData(config, summary, diffCode, textId = "") {
  let diff = g_difficulty.getDifficultyByDiffCode(diffCode)
  if (diff == g_difficulty.UNKNOWN)
    return null

  let modeList = (type(config.mode) == "array") ? config.mode : [config.mode]
  local value = 0
  foreach (mode in modeList) {
    let sumData = summary?[mode]?[diff.name]
    if (!sumData)
      continue

    if (config.fm == null) {
      if (config.id in sumData)
        value += sumData[config.id]
      else
        for (local i = 0; i < statsFm.len(); i++)
          if ((statsFm[i] in sumData) && (config.id in sumData[statsFm[i]]))
            value += sumData[statsFm[i]][config.id]
    }
    else if ((config.fm in sumData) && (config.id in sumData[config.fm]))
        value += sumData[config.fm][config.id]
  }

  if (config.fm != null && config.id == "timePlayed" && value < time.TIME_MINUTE_IN_SECONDS)
    return null

  let s = config.timeFormat
    ? time.hoursToString(time.secondsToHours(value), false)
    : value.tostring()

  let row = [
    { id = textId, text = $"#{config.name}", tdalign = "left",
      rawParam = "isTableStatsName:t='yes'", textType = "text" },
    { text = s, textType = "text", rawParam = "isTableStatsVal:t='yes'" }
  ]

  return buildTableRowNoPad("", row)
}

function checkAndToggleStatsBottomFade(sObj) {
  let statsHeight = sObj.getSize()[1]

  local statsContainerHeight = 0
  let statsContainer = this.scene.findObject("stats-container")
  if (!statsContainer?.isValid())
    return

  statsContainerHeight = statsContainer.getSize()[1]
  showObjById("stats_bottom_fade", statsHeight >= statsContainerHeight * 0.9, statsContainer)
}

function fillProfileSummary(sObj, summary, diff) {
  if (!checkObj(sObj))
    return

  let guiScene = sObj.getScene()
  local data = ""
  let textsToSet = {}
  foreach (idx, item in statsConfig) {
    if (!hasAllFeatures(item.reqFeature))
      continue

    if (item.header)
      data = "".concat(data, buildTableRowNoPad("", [{ text = $"#{item.name}", textType = "text"}], null,
        format("headerRow:t='%s'; ", idx ? "yes" : "first")))
    else if (item.separateRowsByFm)
      for (local i = 0; i < statsFm.len(); i++) {
        let rowId = $"row_{idx}_{i}"
        item.fm = statsFm[i]
        let row = buildProfileSummaryRowData(item, summary, diff, rowId)
        if (!row)
          continue

        data += row
        textsToSet[$"txt_{rowId}"] <- "".concat(loc(item.name), " (", loc($"mainmenu/type_{statsFm[i].tolower()}"), ")")
      }
    else {
      let row = buildProfileSummaryRowData(item, summary, diff)
      if (row)
        data += row
    }
  }

  guiScene.replaceContentFromText(sObj, data, data.len(), this)
  foreach (id, text in textsToSet)
    sObj.findObject(id).setValue(text)

  checkAndToggleStatsBottomFade(sObj)
}

function getCountryMedals(countryId, profileData = null) {
  let res = []
  let medalsList = profileData?.unlocks?.medal ?? []
  let unlocks = getUnlocksByTypeInBlkOrder("medal")
  foreach (cb in unlocks)
    if (cb?.country == countryId)
      if ((!profileData && isUnlockOpened(cb.id, UNLOCKABLE_MEDAL)) || (medalsList?[cb.id] ?? 0) > 0)
        res.append(cb.id)
  return res
}

function getPlayerStatsFromBlk(blk) {
  let player = {
    name = blk?.nick
    lastDay = blk?.lastDay
    registerDay = blk?.registerDay
    title = blk?.title ?? ""
    titles = (blk?.titles ?? DataBlock()) % "name"
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

    //stats & leaderboards
    summary = isDataBlock(blk?.summary) ? convertBlk(blk.summary) : {}
    userstat = blk?.userstat ? getAirsStatsFromBlk(blk.userstat) : {}
    leaderboard = isDataBlock(blk?.leaderboard) ? convertBlk(blk.leaderboard) : {}
  }

  if (blk?.userid != null)
    player.uid <- blk.userid

  player.rank = getRankByExp(player.exp)
  player.rankProgress = calcRankProgress(player)

  player.prestige = getPrestigeByRank(player.rank)

  //unlocks
  eachBlock(blk?.unlocks, function(uBlk, unlock) {
    let uType = uBlk?.type
    if (!uType)
      return

    if (!(uType in player.unlocks))
      player.unlocks[uType] <- {}
    player.unlocks[uType][unlock] <- uBlk?.stage ?? 1
  })

  foreach (_i, country in shopCountriesList) {
    let cData = {
      medalsCount = getCountryMedals(country, player).len()
      unitsCount = 0
      eliteUnitsCount = 0
    }
    if (blk?.aircrafts?[country]) {
      cData.unitsCount = blk.aircrafts[country].paramCount()
      eachParam(blk.aircrafts[country], function(unitEliteStatus) {
        if (isUnitEliteByStatus(unitEliteStatus))
          cData.eliteUnitsCount++
      })
    }
    player.countryStats[country] <- cData
  }

  return player
}

function getCurSessionCountry() {
  if (is_multiplayer()) {
    let sessionInfo = get_mp_session_info()
    let team = get_mp_local_team()
    if (team == 1)
      return sessionInfo.alliesCountry
    if (team == 2)
      return sessionInfo.axisCountry
  }
  return null
}

function getProfileInfo() {
  let info = get_cur_rank_info()

  currentUserProfile.name = info.name //is_online_available() ? info.name : "" ;
  if (userName.value != info.name && info.name != "")
    userName.set(info.name)

  currentUserProfile.balance = info.wp
  currentUserProfile.country = info.country || "country_0"
  currentUserProfile.aircrafts = info.aircrafts
  currentUserProfile.gold = info.gold
  currentUserProfile.pilotId = info.pilotId
  currentUserProfile.icon = avatars.getIconById(info.pilotId)
  currentUserProfile.medals = getNumUnlocked(UNLOCKABLE_MEDAL, true)
  //dagor.debug($"unlocked medals: {currentUserProfile.medals}")

  //Show the current country in the game when you select an outcast.
  if (currentUserProfile.country == "country_0") {
    let country = getCurSessionCountry()
    if (country && country != "")
      currentUserProfile.country = $"country_{country}"
  }
  if (currentUserProfile.country != "country_0")
    currentUserProfile.countryRank <- getPlayerRankByCountry(currentUserProfile.country)

  let isInClan = clan_get_my_clan_id() != "-1"
  currentUserProfile.clanTag <- isInClan ? clan_get_my_clan_tag() : ""
  currentUserProfile.clanName <- isInClan  ? clan_get_my_clan_name() : ""
  currentUserProfile.clanType <- isInClan  ? clan_get_my_clan_type() : ""
  clanUserTable.mutate(@(v) v[userName.get()] <- currentUserProfile.clanTag)

  currentUserProfile.exp <- info.exp
  currentUserProfile.free_exp <- shop_get_free_exp()
  currentUserProfile.rank <- getRankByExp(currentUserProfile.exp)
  currentUserProfile.prestige <- getPrestigeByRank(currentUserProfile.rank)
  currentUserProfile.rankProgress <- calcRankProgress(currentUserProfile)

  return currentUserProfile
}

return {
  fillProfileSummary
  getCountryMedals
  getPlayerStatsFromBlk
  airStatsListConfig
  getProfileInfo
  getPlayerRankByCountry
  getPlayerExpByCountry
  updatePlayerRankByCountry
  updatePlayerRankByCountries
  playerRankByCountries
  getCurExpTable
}
