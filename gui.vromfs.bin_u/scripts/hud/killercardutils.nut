from "%scripts/dagui_library.nut" import *
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getUnitTooltipImage, genUnitTooltipWeaponIcon
} = require("%scripts/unit/unitInfoTexts.nut")
let { get_local_mplayer, get_mplayer_by_id } = require("mission")
let { getCountryFlagForUnitTooltip } = require("%scripts/options/countryFlagsPreset.nut")
let { format } = require("string")
let { utf8Capitalize, cutPostfix } = require("%sqstd/string.nut")
let { getUnitRoleIconAndTypeCaption } = require("%scripts/unit/unitInfoRoles.nut")
let { getProjectileNameLoc, getProjectileIconLayers } = require("%scripts/weaponry/bulletsInfo.nut")
let { getAvatarIconIdByUserInfo } = require("%scripts/user/avatars.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")

function isKillerCardData(messageData) {
  let { isKill = false, playerId = -1, victimPlayerId = null, isDebugData = false } = messageData

  if (!isKill)
    return false

  let killer = get_mplayer_by_id(playerId)
  if ((!killer || killer?.isBot) && !isDebugData)
    return false

  if (get_local_mplayer().id != victimPlayerId)
    return false
  return true
}

function getKillerCardView(messageData, userInfo) {
  if (!isKillerCardData(messageData))
    return null
  let { playerId = -1, killerProjectileName = "", isDebugData = false,
    weaponEcsTemplateName = "" } = messageData
  let { aircraftName, name, clanTag = "", title = "", aircraft } = isDebugData ? messageData
    : get_mplayer_by_id(playerId)
  let unit = getAircraftByName(aircraftName)
  if (!unit)
    return null

  let showCustomItem = weaponEcsTemplateName != ""

  let unitImg = showCustomItem ? genUnitTooltipWeaponIcon(weaponEcsTemplateName)
    : getUnitTooltipImage(unit)

  let weaponEcsTemplateNameCutted = cutPostfix(weaponEcsTemplateName, "_gun", "")

  let rank = get_roman_numeral(unit.rank)
  let rankText = loc("ui/colon").concat(loc("sm_rank"), colorize("@white", rank))

  let battleRating = unit.getBattleRating(events.getCurBattleEdiff())
  let battleRatingText = loc("ui/colon")
    .concat(loc("shop/battle_rating"), colorize("@white", format("%.1f", battleRating)))
  let shellNameLoc = showCustomItem ? loc(weaponEcsTemplateNameCutted)
    : killerProjectileName != "" ? getProjectileNameLoc(killerProjectileName, true, unit)
    : ""

  let shellIconLayers = getProjectileIconLayers(killerProjectileName)

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

    name = utf8(getPlayerName(name))
    clanTag
    title = (userInfo?.title ?? "") != "" ? loc($"title/{title}") : ""

    unitImg
    countryFlagImg = getCountryFlagForUnitTooltip(unit.getOperatorCountry())
    unitName =  loc(aircraft)
    unitTypeText = getUnitRoleIconAndTypeCaption(unit)
    rankAndbattleRatingText = " ".concat(rankText, battleRatingText)
    hasShellInfo = shellNameLoc != ""
    shellNameLoc
    hasShellIcon = shellIconLayers.len() > 0
    shellIconLayers
    shellHeader = showCustomItem ? loc("hotkeys/ID_HUMAN_FIRE_HEADER") : loc("logs/ammunition")
  }
}

return {
  getKillerCardView
  isKillerCardData
}