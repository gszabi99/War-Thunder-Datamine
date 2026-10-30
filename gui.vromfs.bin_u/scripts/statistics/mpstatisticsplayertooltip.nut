from "%scripts/events/eventsManager.nut" import events
from "%scripts/utils/genericTooltipTypes.nut" import addTooltipTypes
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/user/usersInfoManager.nut" import getUserInfo
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import getRoomRankCalcMode, getBattleRatingParamByPlayerInfo, isMemberInMySquadById
from "%scripts/matchingRooms/sessionLobbyState.nut" import getSessionLobbyPlayersInfo
from "%scripts/misCustomRules/missionCustomState.nut" import getCurMissionRules
from "%scripts/statistics/squadIcon.nut" import getSquadInfo
from "%scripts/unit/unitInfoTexts.nut" import getUnitClassIco
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/user/avatars.nut" import getAvatarIconIdByUserInfo
from "%scripts/debriefing/debriefingFull.nut" import getDebriefingResult
from "%scripts/user/profileStates.nut" import userIdStr, userName
from "%scripts/user/clanName.nut" import getMyClanTag
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentShopDifficulty
from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "mission" import get_mplayer_by_userid
from "matching.errors" import INVALID_SQUAD_ID
from "guiMission" import get_mission_difficulty
from "string" import format
from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *
from "%globalScripts/difficultyConsts.nut" import *
from "%scripts/user/profileAppearance.nut" import getProfileAvatarFrameCfg

let { g_difficulty } = require("%scripts/difficulty.nut")

let formatFloat = @(f) format("%.1f", f)
let sortUnits = @(u1, u2) u1.rating <=> u2.rating || u1.rankUnused <=> u2.rankUnused

function getUnitsRatingInfo(playerInfo, ediff) {
  let battleRatingInfo = getBattleRatingParamByPlayerInfo(playerInfo, ediff)
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

  let { squad = INVALID_SQUAD_ID, team = 0 } = playerInfo
  let squadInfo = getSquadInfo(team, squad)
  let isInSquad = squadInfo ? !squadInfo.autoSquad : false

  return {
    units
    brCalcHint
    ratingTotal = formatFloat(calcBattleRatingFromRank(battleRatingInfo.rank))
    ratingCaption = isInSquad ? loc("debriefing/battleRating/squad")
      : loc("debriefing/battleRating/total")
  }
}

function getPlayerInfoFromDebriefing(playerUserId) {
  let { playersInfo = null, mplayers_list = null, ediff = DIFFICULTY_ARCADE } = getDebriefingResult()
  return {
    player = mplayers_list?.findvalue(@(v) v.userId == playerUserId)
    playerInfo = playersInfo?[playerUserId] ?? playersInfo?[playerUserId.tointeger()]
    ediff
  }
}

function getPlayerInfo(playerUserId) {
  let userIdInt = playerUserId.tointeger()
  let playersInfo = getSessionLobbyPlayersInfo()

  return {
    player = get_mplayer_by_userid(userIdInt)
    playerInfo = playersInfo?[playerUserId] ?? playersInfo?[userIdInt]
    ediff = isInFlight() ? events.getCurBattleEdiff() : getCurrentShopDifficulty().diffCode
  }
}

function getTooltipView(playerUserId, params) {
  let { isAlly, isDebriefing } = params
  let { playerInfo, player, ediff } = isDebriefing ? getPlayerInfoFromDebriefing(playerUserId)
    : getPlayerInfo(playerUserId)
  if (player == null)
    return null

  let isUnitListVisible = isDebriefing
    || ((get_mission_difficulty() == g_difficulty.ARCADE.gameTypeName || isAlly)
      && !getCurMissionRules().isWorldWar)
  let unitsRatingInfo = isUnitListVisible ? getUnitsRatingInfo(playerInfo, ediff) : null
  let hints = []

  if (unitsRatingInfo?.brCalcHint)
    hints.append(unitsRatingInfo.brCalcHint)

  let isInHeroSquad = player?.isInHeroSquad || isMemberInMySquadById(playerUserId.tointeger())
  let showAutoSquadHint = !player.isLocal && isInHeroSquad && !!playerInfo?.auto_squad
  if (showAutoSquadHint)
    hints.append(loc("squad/auto"))

  let userInfo = getUserInfo(playerUserId)
  let title = player.title != "" && player.title != null
    ? loc($"title/{player.title}")
    : ""

  let isMe = userInfo?.uid == userIdStr.get()
    || userInfo?.name == userName.get()
  let { frame = "" } = userInfo
  let { frameImagePath, framesCount } = getProfileAvatarFrameCfg(frame)

  return {
    name = colorize("@white", utf8(getPlayerName(player.name)))
    clanTag = player?.clanTag
      ? isMe
        ? getMyClanTag()
        : colorize("@white", player.clanTag)
      : null
    title = colorize("@white", title)

    icon = userInfo?.pilotIcon
      ? $"#ui/images/avatars/{getAvatarIconIdByUserInfo(userInfo)}.avif"
      : null
    frameImagePath
    framesCount

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

    fillTooltip = function(obj, handler, playerUserId, params) {
      if (!obj?.isValid())
        return false

      let view = getTooltipView(playerUserId, params)
      if (view == null)
        return false
      let blk = handyman.renderCached("%gui/playerTooltip.tpl", view)
      let guiScene = obj.getScene()
      guiScene.replaceContentFromText(obj, blk, blk.len(), handler)
      obj.type="smallPadding"
      return true
    }
  }
})