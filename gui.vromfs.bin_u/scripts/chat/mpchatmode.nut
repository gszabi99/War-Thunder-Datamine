local enums = ::require("sqStdlibs/helpers/enums.nut")
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
  id = ::CHAT_MODE_ALL
  name = ""
  sortOrder = mpChatModeSort.ALL
  textColor = ""

  getNameText = function() { return ::loc("chat/" + name) }
  getDescText = function() { return ::loc("chat/" + name + "/desc") }
  isEnabled   = function() { return false }
}

enums.addTypesByGlobalName("g_mp_chat_mode", {
  ALL = {
    id = ::CHAT_MODE_ALL
    name = "all"
    sortOrder = mpChatModeSort.ALL
    textColor = "@chatTextAllColor"

    isEnabled = function() { return true }
  }

  TEAM = {
    id = ::CHAT_MODE_TEAM
    name = "team"
    sortOrder = mpChatModeSort.TEAM
    textColor = "@chatTextTeamColor"

    isEnabled = function() { return !::isPlayerDedicatedSpectator() && ::is_mode_with_teams() }
  }

  SQUAD = {
    id = ::CHAT_MODE_SQUAD
    name = "squad"
    sortOrder = mpChatModeSort.SQUAD
    textColor = "@chatTextSquadColor"

    isEnabled = function() { return ::g_squad_manager.isInSquad(true) && !::isPlayerDedicatedSpectator() }
  }

  PRIVATE = { //dosnt work atm, but still exist in enum
    id = ::CHAT_MODE_PRIVATE
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

g_mp_chat_mode.getModeById <- function getModeById(modeId)
{
  return enums.getCachedType("id", modeId, cache.byId, this, ALL)
}


g_mp_chat_mode.getModeNameText <- function getModeNameText(modeId)
{
  return getModeById(modeId).getNameText()
}


// To pass color name to daRg.
// daRg can't use text color constants
g_mp_chat_mode.getModeColorName <- function getModeColorName(modeId)
{
  local colorName = getModeById(modeId).textColor
  if (colorName.len())
    colorName = colorName.slice(1) //slice '@'
  return colorName
}


g_mp_chat_mode.getNextMode <- function getNextMode(modeId)
{
  local isCurFound = false
  local newMode = null
  foreach(mode in types)
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

g_mp_chat_mode.getTextAvailableMode <- function getTextAvailableMode()
{
  return ::g_string.implode(
    ::u.map(types.filter(@(mode) mode.isEnabled()),
      @(mode) mode.getNameText()),
    ::loc("ui/slash"))
}

g_mp_chat_mode.getChatHint <- function getChatHint()
{
  local hasIME = ::is_ps4_or_xbox || ::is_platform_android || ::is_steam_big_picture()
  return ::loc("chat/help/modeSwitch",
    { modeSwitchShortcuts = "{{ID_TOGGLE_CHAT_MODE}}"
      modeList = getTextAvailableMode()
    })
    + (hasIME ? ""
      : ::loc("ui/comma")
      + ::loc("chat/help/send", { sendShortcuts = "{{INPUT_BUTTON KEY_ENTER}}" }))
}

::cross_call_api.mp_chat_mode <- ::g_mp_chat_mode
