from "%scripts/utils/genericTooltipTypes.nut" import addTooltipTypes
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%appGlobals/missions/respawnCountModes.nut" import isRespawnAllowed
from "%scripts/user/usersInfoManager.nut" import getUserInfo
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/user/avatars.nut" import getAvatarIconIdByUserInfo
from "%scripts/user/profileAppearance.nut" import getProfileAvatarFrameCfg
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/matchingRooms/sessionLobbyMembersInfo.nut" import getRoomMemberInfo
from "%scripts/matchingRooms/sessionLobbyState.nut" import getSessionLobbyMaxRespawns, getSessionLobbyCurRoomEdiff, getRoomMembers
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%scripts/unit/unitInfoTexts.nut" import getUnitClassIco
from "%scripts/teams.nut" import g_team
from "%scripts/teamsConsts.nut" import Team
from "%scripts/contacts/playerStateTypes.nut" import g_player_state
from "string" import format
from "%scripts/dagui_library.nut" import *

function getPlayerUnitList(player) {
  if (isRespawnAllowed(getSessionLobbyMaxRespawns()) || player.selAirs.len() == 0)
    return []

  let unit = getAircraftByName(player.selAirs?[player.country] ?? "")
  if (unit == null)
    return []

  let roomEdiff = getSessionLobbyCurRoomEdiff()
  let ediff = roomEdiff != -1 ? roomEdiff : getCurrentGameModeEdiff()
  return [{
    unit = unit.name
    icon = getUnitClassIco(unit)
    rank = format("%.1f", unit.getBattleRating(ediff))
    isWideIco = unit.unitType.isWideUnitIco
  }]
}

function getTooltipView(userId) {
  let member = getRoomMembers().findvalue(@(m) m.userId.tostring() == userId)
  if (member == null)
    return null

  let player = getRoomMemberInfo(member)

  let userInfo = getUserInfo(userId)
  let { frameImagePath, framesCount } = getProfileAvatarFrameCfg(player.frame)
  let titleText = player.title != ""
    ? loc("ui/colon").concat(loc("title/title"), loc($"title/{player.title}"))
    : ""
  let stateText = g_player_state.getStateByPlayerInfo(player).getText(player)
  let unitList = getPlayerUnitList(player)
  let team = player.team == Team.A || player.team == Team.B
    ? g_team.getTeamByCode(player.team).cssLabel
    : null

  return {
    name = colorize("@white", getPlayerName(player.name))
    clanTag = player.clanTag != "" ? colorize("@white", player.clanTag) : null
    title = colorize("@white", titleText)
    team
    countryIcon = getCountryIcon(player.country)
    statusText = stateText != "" ? loc("ui/colon").concat(loc("multiplayer/state"), stateText) : null

    icon = $"#ui/images/avatars/{getAvatarIconIdByUserInfo(player)}.avif"
    frameImagePath
    framesCount
    headerBackground = (userInfo?.background ?? "") != ""
      ? userInfo.background
      : "profile_header_default"

    hasUnitList = unitList.len() > 0
    unitList
  }
}

addTooltipTypes({
  SESSION_LOBBY_PLAYER = {
    isCustomTooltipFill = true

    function fillTooltip(obj, handler, userId, _params) {
      if (!obj?.isValid())
        return false

      let view = getTooltipView(userId)
      if (view == null)
        return false
      let blk = handyman.renderCached("%gui/playerTooltip.tpl", view)
      obj.getScene().replaceContentFromText(obj, blk, blk.len(), handler)
      obj.type = "smallPadding"
      return true
    }
  }
})
