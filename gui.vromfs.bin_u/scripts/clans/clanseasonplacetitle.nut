from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanConsts.nut" import CLAN_SEASON_NUM_IN_YEAR_SHIFT
from "%scripts/clans/clanState.nut" import is_in_clan
let { split_by_chars } = require("string")
let { unixtime_to_utc_timetbl } = require("dagor.time")
let { startsWith, slice } = require("%sqstd/string.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { getMyClanTag, getMyClanName } = require("%scripts/user/clanName.nut")

function getUpdatedClanInfo(unlockBlk) {
  local isMyClan = is_in_clan() && (unlockBlk?.clanId ?? "").tostring() == clan_get_my_clan_id()
  return {
    clanTag  = isMyClan ? getMyClanTag()  : unlockBlk?.clanTag
    clanName = isMyClan ? getMyClanName() : unlockBlk?.clanName
  }
}

function getSeasonName(blk) {
  local name = ""
  if (blk?.type == "worldWar")
    name = loc($"worldwar/season_name/{split_by_chars(blk.titles, "@")?[2] ?? ""}")
  else {
    let year = unixtime_to_utc_timetbl(blk?.seasonStartTimestamp ?? 0).year.tostring()
    let num  = get_roman_numeral(to_integer_safe(blk?.numInYear ?? 0)
      + CLAN_SEASON_NUM_IN_YEAR_SHIFT)
    name = loc("clan/battle_season/name", { year = year, num = num })
  }
  return name
}

class ClanSeasonTitle {
  clanTag = ""
  clanName = ""
  seasonName = ""
  seasonTime = 0
  difficultyName = ""


  constructor (...) {
    assert(false, "Error: attempt to instantiate ClanSeasonTitle intreface class.")
  }

  function getBattleTypeTitle() {
    let difficulty = g_difficulty.getDifficultyByEgdLowercaseName(this.difficultyName)
    return loc(difficulty.abbreviation)
  }

  function name() {}
  function desc() {}
  function iconStyle() {}
  function iconParams() {}
}

let class ClanSeasonPlaceTitle (ClanSeasonTitle) {
  place = ""
  seasonType = ""
  seasonTag = null
  seasonIdx = ""
  seasonTitle = ""

  constructor (
    v_seasonTime,
    v_seasonType,
    v_seasonTag,
    v_difficlutyName,
    v_place,
    v_seasonName,
    v_clanTag,
    v_clanName,
    v_seasonIdx,
    v_seasonTitle
  ) {
    this.seasonTime = v_seasonTime
    this.seasonType = v_seasonType
    this.seasonTag = v_seasonTag
    this.difficultyName = v_difficlutyName
    this.place = v_place
    this.seasonName = v_seasonName
    this.clanTag = v_clanTag
    this.clanName = v_clanName
    this.seasonIdx = v_seasonIdx
    this.seasonTitle = v_seasonTitle
  }

  function isWinner() {
    return startsWith(this.place, "place")
  }

  function getPlaceTitle() {
    if (this.isWinner())
      return loc($"clan/season_award/place/{this.place}")
    else
      return loc("clan/season_award/place/top", { top = slice(this.place, 3) })
  }

  function name() {
    let path = this.seasonType == "worldWar" ? "clan/season_award_ww/title" : "clan/season_award/title"
    return loc(
      path,
      {
        achievement = this.getPlaceTitle()
        battleType = this.getBattleTypeTitle()
        season = this.seasonName
      }
    )
  }

  function desc() {
    let placeTitleColored = colorize("activeTextColor", this.getPlaceTitle())
    let params = {
      place = placeTitleColored
      top = placeTitleColored
      squadron = colorize("activeTextColor", nbsp.concat(this.clanTag, this.clanName))
      season = colorize("activeTextColor", this.seasonName)
    }
    let winner = this.isWinner() ? "place" : "top"
    let path = this.seasonType == "worldWar" ? "clan/season_award_ww/desc/" : "clan/season_award/desc/"

    return loc("".concat(path, winner), this.seasonType == "worldWar"
      ? params
      : params.__merge({ battleType = colorize("activeTextColor", this.getBattleTypeTitle()) }))
  }

  function iconStyle() {
    return $"clan_medal_{this.place}_{this.difficultyName}"
  }

  function iconConfig() {
    if (this.seasonType != "worldWar" || !this.seasonTag)
      return null

    let bg_img = "clan_medal_ww_bg"
    let path = this.isWinner() ? this.place : "rating"
    let bin_img = $"clan_medal_ww_{this.seasonTag}_bin_{path}"
    local place_img =$"clan_medal_ww_{this.place}"
    return ";".join([bg_img, bin_img, place_img], true)
  }

  function iconParams() {
    return { season_title = { text = this.seasonName } }
  }
}

function createSeasonRewardFromClanReward(titleString, sIdx, season, clanData) {
  let titleParts = split_by_chars(titleString, "@")
  let place = titleParts?[0] ?? ""
  let difficultyName = titleParts?[1] ?? ""
  let sTag = titleParts?[2]
  return ClanSeasonPlaceTitle(
    season?.t,
    season?.type,
    sTag,
    difficultyName,
    place,
    getSeasonName(season),
    clanData.tag,
    clanData.name,
    sIdx,
    titleString
  )
}

function createSeasonRewardFromUnlockBlk(unlockBlk) {
  let idParts = split_by_chars(unlockBlk.id, "_")
  let info = getUpdatedClanInfo(unlockBlk)
  return ClanSeasonPlaceTitle(
    unlockBlk?.t,
    "",
    null,
    unlockBlk?.rewardForDiff,
    idParts[0],
    getSeasonName(unlockBlk),
    info.clanTag,
    info.clanName,
    "",
    ""
  )
}

return {
  createSeasonRewardFromClanReward
  createSeasonRewardFromUnlockBlk
}