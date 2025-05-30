from "%scripts/dagui_library.nut" import *
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getUserInfo } = require("%scripts/user/usersInfoManager.nut")
let { getRoomRankCalcMode, getBattleRatingParamByPlayerInfo, isMemberInMySquadById
} = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { get_mission_difficulty } = require("guiMission")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getSquadInfo } = require("%scripts/statistics/squadIcon.nut")
let { calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { format } = require("string")
let { getAvatarIconIdByUserInfo } = require("%scripts/user/avatars.nut")

let formatFloat = @(f) format("%.1f", f)
let sortUnits = @(u1, u2) u1.rating <=> u2.rating || u1.rankUnused <=> u2.rankUnused

function getUnitsRatingInfo(playerInfo) {
  let battleRatingInfo = getBattleRatingParamByPlayerInfo(playerInfo)
  if (!battleRatingInfo)
    return null

  let units = battleRatingInfo.units.map(function(u, idx) {
    let unit = getAircraftByName(u.unitName)
    return u.__merge({
      rank = formatFloat(u.rating)
      unit = u.unitName
      icon = getUnitClassIco(unit)
      even = idx % 2 == 0
      isWideIco = ["ships", "helicopters", "boats"].contains(unit.unitType.armyId)
    })
  }).sort(sortUnits)


  local brCalcHint = null
  let needShowBrCalcHint = units.len() > 1
  if (needShowBrCalcHint) {
    let rankCalcMode = getRoomRankCalcMode()
    if (rankCalcMode)
      brCalcHint = loc($"multiplayer/battleRatingCalcHint/{rankCalcMode}")
  }

  let squadInfo = getSquadInfo(battleRatingInfo.squad)
  let isInSquad = squadInfo ? !squadInfo.autoSquad : false

  return {
    units
    brCalcHint
    ratingTotal = formatFloat(calcBattleRatingFromRank(battleRatingInfo.rank))
    ratingCaption = isInSquad ? loc("debriefing/battleRating/squad")
      : loc("debriefing/battleRating/total")
  }
}

function getTooltipView(player, params) {
  let { playersInfo, isAlly, isDebriefing } = params
  let playerInfo = playersInfo?[player.userId] ?? playersInfo?[player.userId.tointeger()]
  let isUnitListVisible = isDebriefing
    || ((get_mission_difficulty() == g_difficulty.ARCADE.gameTypeName || isAlly)
      && !getCurMissionRules().isWorldWar)
  let unitsRatingInfo = isUnitListVisible ? getUnitsRatingInfo(playerInfo) : null
  let hints = []

  if (unitsRatingInfo?.brCalcHint)
    hints.append(unitsRatingInfo.brCalcHint)

  let isInHeroSquad = player?.isInHeroSquad || isMemberInMySquadById(player.userId.tointeger())
  let showAutoSquadHint = !player.isLocal && isInHeroSquad && !!playerInfo?.auto_squad
  if (showAutoSquadHint)
    hints.append(loc("squad/auto"))

  let userInfo = getUserInfo(player.userId)
  let title = player.title != "" && player.title != null
    ? loc($"title/{player.title}")
    : ""

  return {
    name = colorize("@white", utf8(getPlayerName(player.name)))
    clanTag = hasFeature("Clans") && player?.clanTag
      ? colorize("@white", player.clanTag)
      : null
    title = colorize("@white", title)

    icon = userInfo?.pilotIcon
      ? $"#ui/images/avatars/{getAvatarIconIdByUserInfo(userInfo)}.avif"
      : null
    hasAvatarFrame = (userInfo?.frame ?? "") != ""
    frame = userInfo?.frame

    headerBackground = (userInfo?.background ?? "") != ""
      ? userInfo.background
      : "profile_header_default"

    hasBattleOrSquadTxt = false
    hasUnitList = (unitsRatingInfo?.units.len() ?? 0) > 0

    unitList = unitsRatingInfo?.units
    ratingCaption = unitsRatingInfo?.ratingCaption
    ratingTotal  = unitsRatingInfo?.ratingTotal
    isTotalRatingRowEven = !!unitsRatingInfo && unitsRatingInfo.units.len() % 2 != 0

    hint = "\n\n".join(hints, true)
  }
}

addTooltipTypes({
  MP_STAT_PLAYER = {
    isCustomTooltipFill = true

    fillTooltip = function(obj, handler, player, params) {
      if (!obj?.isValid())
        return false

      let view = getTooltipView(player, params)
      let blk = handyman.renderCached("%gui/playerTooltip.tpl", view)
      let guiScene = obj.getScene()
      guiScene.replaceContentFromText(obj, blk, blk.len(), handler)
      obj.type="smallPadding"
      return true
    }
  }
})