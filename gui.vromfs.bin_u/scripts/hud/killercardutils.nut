from "%scripts/dagui_library.nut" import *
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { get_local_mplayer, get_mplayer_by_id } = require("mission")
let { getCountryFlagForUnitTooltip } = require("%scripts/options/countryFlagsPreset.nut")
let { format } = require("string")
let { utf8Capitalize } = require("%sqstd/string.nut")
let { getUnitRoleIconAndTypeCaption } = require("%scripts/unit/unitInfoRoles.nut")
let { get_mission_mode } = require("%appGlobals/ranks_common_shared.nut")
let { getProjectileNameLoc } = require("%scripts/weaponry/bulletsInfo.nut")
let { getAvatarIconIdByUserInfo } = require("%scripts/user/avatars.nut")

function isNeedUpdateKillerCardByUserInfo(oldUserInfo, newUserInfo) {
  return newUserInfo?.pilotIcon != oldUserInfo?.pilotIcon
    || newUserInfo?.background != oldUserInfo?.background
    || newUserInfo?.frame != oldUserInfo?.frame
    || newUserInfo?.title != oldUserInfo?.title
}

function isKillerCardData(messageData) {
  let { isKill = false, playerId = -1, victimPlayerId = null } = messageData

  if (!isKill)
    return false

  let killer = get_mplayer_by_id(playerId)
  if (!killer || killer?.isBot)
    return false

  if (get_local_mplayer().id != victimPlayerId)
    return false
  return true
}

function getKillerCardView(messageData, userInfo) {
  if (!isKillerCardData(messageData))
    return null
  let { playerId = -1, killerProjectileName = "" } = messageData
  let killer = get_mplayer_by_id(playerId)
  let unit = getAircraftByName(killer.aircraftName)
  if (!unit)
    return null

  let rank = get_roman_numeral(unit.rank)
  let rankText = loc("ui/colon").concat(loc("sm_rank"), colorize("@white", rank))
  let battleRating = unit.getBattleRating(get_mission_mode())
  let battleRatingText = loc("ui/colon")
    .concat(loc("shop/battle_rating"), colorize("@white", format("%.1f", battleRating)))
  let shellNameLoc = killerProjectileName != "" ? getProjectileNameLoc(killerProjectileName, true) : ""
  let hasShellText = shellNameLoc != ""

  return {
    cardCaption = "".concat(utf8Capitalize(loc("NET_UNIT_KILLED_BY_PLAYER")), loc("ui/colon"))

    pilotIcon = userInfo?.pilotIcon
      ? $"#ui/images/avatars/{getAvatarIconIdByUserInfo(userInfo)}.avif"
      : null
    hasAvatarFrame = (userInfo?.frame ?? "") != ""
    frame = userInfo?.frame
    headerBackground = (userInfo?.background ?? "") != ""
      ? userInfo.background
      : "profile_header_default"

    name = killer.name
    clanTag = killer.clanTag
    title = (userInfo?.title ?? "") != "" ? loc($"title/{killer.title}") : ""

    unitImg = getUnitTooltipImage(unit)
    countryFlagImg = getCountryFlagForUnitTooltip(unit.getOperatorCountry())
    unitName =  loc(killer.aircraft)
    unitTypeText = getUnitRoleIconAndTypeCaption(unit)
    rankAndbattleRatingText = " ".concat(rankText, battleRatingText)
    shellText =  hasShellText
      ? loc("ui/colon").concat(loc("logs/ammunition"), colorize("@white", shellNameLoc))
      : ""
    hasShellText
  }
}

return {
  getKillerCardView
  isKillerCardData
  isNeedUpdateKillerCardByUserInfo
}