from "%scripts/squads/squadState.nut" import isInSquad
from "%sqstd/platform.nut" import is_android, isSony, isXbox
from "%scripts/user/matchingFeature.nut" import hasBattleChatModeAll, hasBattleChatModeTeam, hasBattleChatModeSquad
from "%scripts/matchingRooms/sessionLobbyMembersInfo.nut" import isPlayerDedicatedSpectator
from "%sqStdLibs/helpers/enums.nut" import enumsAddTypes, getCachedType
from "chat" import CHAT_MODE_ALL, CHAT_MODE_TEAM, CHAT_MODE_SQUAD, CHAT_MODE_PRIVATE
from "%scripts/dagui_natives.nut" import is_steam_big_picture
from "%scripts/dagui_library.nut" import *
from "%appGlobals/missions/missionStateShared.nut" import isModeWithTeams
from "%scripts/chat/chatStates.nut" import hasChatCharPermission

enum mpChatModeSort {
  TEAM
  SQUAD
  ALL
  PRIVATE
}

let g_mp_chat_mode = {
  types = []
  cache = {
    byId = {}
  }
}

g_mp_chat_mode.template <- {
  id = CHAT_MODE_ALL
  name = ""
  sortOrder = mpChatModeSort.ALL
  textColor = ""

  getNameText = function() { return loc($"chat/{this.name}") }
  getDescText = function() { return loc($"chat/{this.name}/desc") }
  isEnabled   = function() { return false }
}

enumsAddTypes(g_mp_chat_mode, {
  ALL = {
    id = CHAT_MODE_ALL
    name = "all"
    sortOrder = mpChatModeSort.ALL
    textColor = "@chatTextAllColor"

    isEnabled = @() hasBattleChatModeAll.get() && hasChatCharPermission.get()
  }

  TEAM = {
    id = CHAT_MODE_TEAM
    name = "team"
    sortOrder = mpChatModeSort.TEAM
    textColor = "@chatTextTeamColor"

    isEnabled = @() hasBattleChatModeTeam.get() && !isPlayerDedicatedSpectator()
      && isModeWithTeams() && hasChatCharPermission.get()
  }

  SQUAD = {
    id = CHAT_MODE_SQUAD
    name = "squad"
    sortOrder = mpChatModeSort.SQUAD
    textColor = "@chatTextSquadColor"

    isEnabled = @() hasBattleChatModeSquad.get() && isInSquad(true)
      && !isPlayerDedicatedSpectator() && hasChatCharPermission.get()
  }

  PRIVATE = { 
    id = CHAT_MODE_PRIVATE
    name = "private"
    sortOrder = mpChatModeSort.PRIVATE
    textColor = "@chatTextPrivateColor"

    isEnabled = function() { return false }
  }
})

g_mp_chat_mode.types.sortby(@(a) a.sortOrder)

g_mp_chat_mode.getModeById <- function getModeById(modeId) {
  return getCachedType("id", modeId, this.cache.byId, this, this.ALL)
}


g_mp_chat_mode.getNextMode <- function getNextMode(modeId) {
  local isCurFound = false
  local newMode = null
  foreach (mode in this.types) {
    if (modeId == mode.id) {
      isCurFound = true
      continue
    }

    if (!mode.isEnabled())
      continue

    if (isCurFound)
      return mode.id
    if (newMode == null)
      newMode = mode.id
  }

  return newMode
}

g_mp_chat_mode.getTextAvailableMode <- function getTextAvailableMode() {
  let availableModes = this.types.filter(@(mode) mode.isEnabled())
  if (availableModes.len() <= 1)
    return ""
  return loc("ui/slash").join(availableModes.map(@(mode) mode.getNameText()), true)
}

g_mp_chat_mode.getChatHint <- function getChatHint() {
  let hasIME = isSony || isXbox || is_android || is_steam_big_picture()
  let chatHelpText = hasIME ? "" : loc("chat/help/send", { sendShortcuts = "{{INPUT_BUTTON KEY_ENTER}}" })
  local availableModeText = this.getTextAvailableMode()
  availableModeText = availableModeText != ""
    ? loc("chat/help/modeSwitch", {
        modeSwitchShortcuts = "{{ID_TOGGLE_CHAT_MODE}}"
        modeList = availableModeText
      })
    : ""
  return loc("ui/comma").join([availableModeText, chatHelpText], true)
}

return {g_mp_chat_mode}