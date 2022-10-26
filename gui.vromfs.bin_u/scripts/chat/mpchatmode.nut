from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { hasBattleChatModeAll, hasBattleChatModeTeam, hasBattleChatModeSquad
} = require("%scripts/user/matchingFeature.nut")

enum mpChatModeSort {
  TEAM
  SQUAD
  ALL
  PRIVATE
}

::g_mp_chat_mode <- {
  types = []
  cache = {
    byId = {}
  }
}

::g_mp_chat_mode.template <- {
  id = CHAT_MODE_ALL
  name = ""
  sortOrder = mpChatModeSort.ALL
  textColor = ""

  getNameText = function() { return loc("chat/" + this.name) }
  getDescText = function() { return loc("chat/" + this.name + "/desc") }
  isEnabled   = function() { return false }
}

enums.addTypesByGlobalName("g_mp_chat_mode", {
  ALL = {
    id = CHAT_MODE_ALL
    name = "all"
    sortOrder = mpChatModeSort.ALL
    textColor = "@chatTextAllColor"

    isEnabled = @() hasBattleChatModeAll.value
  }

  TEAM = {
    id = CHAT_MODE_TEAM
    name = "team"
    sortOrder = mpChatModeSort.TEAM
    textColor = "@chatTextTeamColor"

    isEnabled = @() hasBattleChatModeTeam.value && !::isPlayerDedicatedSpectator()
      && ::is_mode_with_teams()
  }

  SQUAD = {
    id = CHAT_MODE_SQUAD
    name = "squad"
    sortOrder = mpChatModeSort.SQUAD
    textColor = "@chatTextSquadColor"

    isEnabled = @() hasBattleChatModeSquad.value && ::g_squad_manager.isInSquad(true)
      && !::isPlayerDedicatedSpectator()
  }

  PRIVATE = { //dosnt work atm, but still exist in enum
    id = CHAT_MODE_PRIVATE
    name = "private"
    sortOrder = mpChatModeSort.PRIVATE
    textColor = "@chatTextPrivateColor"

    isEnabled = function() { return false }
  }
})

::g_mp_chat_mode.types.sort(function(a, b) {
  if (a.sortOrder != b.sortOrder)
    return a.sortOrder < b.sortOrder ? -1 : 1
  return 0
})

::g_mp_chat_mode.getModeById <- function getModeById(modeId)
{
  return enums.getCachedType("id", modeId, this.cache.byId, this, this.ALL)
}


::g_mp_chat_mode.getModeNameText <- function getModeNameText(modeId)
{
  return this.getModeById(modeId).getNameText()
}


// To pass color name to daRg.
// daRg can't use text color constants
::g_mp_chat_mode.getModeColorName <- function getModeColorName(modeId)
{
  local colorName = this.getModeById(modeId).textColor
  if (colorName.len())
    colorName = colorName.slice(1) //slice '@'
  return colorName
}


::g_mp_chat_mode.getNextMode <- function getNextMode(modeId)
{
  local isCurFound = false
  local newMode = null
  foreach(mode in this.types)
  {
    if (modeId == mode.id)
    {
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

::g_mp_chat_mode.getTextAvailableMode <- function getTextAvailableMode()
{
  let availableModes = this.types.filter(@(mode) mode.isEnabled())
  if (availableModes.len() <= 1)
    return ""
  return loc("ui/slash").join(availableModes.map(@(mode) mode.getNameText()), true)
}

::g_mp_chat_mode.getChatHint <- function getChatHint()
{
  let hasIME = isPlatformSony || isPlatformXboxOne || is_platform_android || ::is_steam_big_picture()
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

::cross_call_api.mp_chat_mode <- ::g_mp_chat_mode
