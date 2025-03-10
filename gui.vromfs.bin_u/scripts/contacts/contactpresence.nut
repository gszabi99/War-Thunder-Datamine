from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadMemberState

let { addTypes } = require("%sqStdLibs/helpers/enums.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { is_in_my_clan } = require("%scripts/clans/clanState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

enum PRESENCE_SORT {
  UNKNOWN
  OFFLINE
  STEAM_ONLINE
  ONLINE
  IN_QUEUE
  IN_GAME
  SQUAD_OFFLINE
  SQUAD_NOT_READY
  SQUAD_READY
  SQUAD_LEADER
}

let contactPresence = {
  types = []
  template = {
    presenceName = "" 
    sortOrder = PRESENCE_SORT.UNKNOWN
    iconName = ""
    iconColor = "white"
    textColor = ""
    iconTransparency = 180

    getTooltip = @() $"status/{this.presenceName}"
    getText = @(locParams = {}) colorize(this.textColor, loc(this.getTooltip(), locParams))
    getIcon = @() $"#ui/gameuiskin#{this.iconName}"
    getIconColor = @() get_main_gui_scene().getConstantValue(this.iconColor) || ""

    getTextInTooltip = @()
      colorize(this.getColorInTooltip(), loc(this?.locInTooltip ?? this.getTooltip()))
    getColorInTooltip = @() this?.colorInTooltip
      ?? (this.textColor != "" ? this.textColor : this.getIconColor())
  }
}

addTypes(contactPresence, {
  UNKNOWN = {
    sortOrder = PRESENCE_SORT.UNKNOWN
    iconName = "player_unknown"
    iconColor = "contactUnknownColor"
  }

  OFFLINE = {
    sortOrder = PRESENCE_SORT.OFFLINE
    iconName = "player_offline"
    iconColor = "contactOfflineColor"
  }

  ONLINE = {
    sortOrder = PRESENCE_SORT.ONLINE
    iconName = "player_online"
    iconColor = "contactOnlineColor"
    colorInTooltip = "@contactTooltipOnlineColor"
  }

  IN_QUEUE = {
    sortOrder = PRESENCE_SORT.IN_QUEUE
    iconName = "player_in_queue"
    locInTooltip = "status/in_queue_short"
    colorInTooltip = "@contactTooltipOnlineColor"
  }

  IN_GAME = {
    sortOrder = PRESENCE_SORT.IN_GAME
    iconName = "player_in_game.svg"
    locInTooltip = "status/in_game_short"
    colorInTooltip = "@contactTooltipOnlineColor"
  }

  SQUAD_OFFLINE = {
    sortOrder = PRESENCE_SORT.SQUAD_OFFLINE
    iconName = "squad_not_ready"
    iconColor = "contactOfflineColor"
  }

  SQUAD_NOT_READY = {
    sortOrder = PRESENCE_SORT.SQUAD_NOT_READY
    iconName = "squad_not_ready"
    textColor = "@userlogColoredText"
    colorInTooltip = "@commonTextColor"
  }

  SQUAD_READY = {
    sortOrder = PRESENCE_SORT.SQUAD_READY
    iconName = "squad_ready"
    textColor = "@userlogColoredText"
    colorInTooltip = "@white"
  }

  SQUAD_LEADER = {
    sortOrder = PRESENCE_SORT.SQUAD_LEADER
    iconName = "squad_leader"
    textColor = "@userlogColoredText"
  }

  STEAM_ONLINE = {
    sortOrder = PRESENCE_SORT.STEAM_ONLINE
    iconName = "player_online"
    iconColor = "contactOfflineColor"
  }
}, @() this.presenceName = this.typeName.tolower(), "typeName")

function getOnlinePresence(contact) {
  local presence = contactPresence.UNKNOWN

  if (contact.online)
    presence = contactPresence.ONLINE
  else if (!contact.unknown)
    presence = contactPresence.OFFLINE

  if (contact.forceOffline)
    presence = contactPresence.OFFLINE
  else if (contact.online && contact.gameStatus) {
    if (contact.gameStatus == "in_queue")
      presence = contactPresence.IN_QUEUE
    else
      presence = contactPresence.IN_GAME
  }
  else if (!contact.online && contact.isSteamOnline)
    presence = contactPresence.STEAM_ONLINE

  return presence
}

function getSquadPresence(squadStatus) {
  if (squadStatus == squadMemberState.NOT_IN_SQUAD)
    return null

  local presence = null
  if (squadStatus == squadMemberState.SQUAD_LEADER)
    presence = contactPresence.SQUAD_LEADER
  else if (squadStatus == squadMemberState.SQUAD_MEMBER_READY)
    presence = contactPresence.SQUAD_READY
  else if (squadStatus == squadMemberState.SQUAD_MEMBER_OFFLINE)
    presence = contactPresence.SQUAD_OFFLINE
  else
    presence = contactPresence.SQUAD_NOT_READY

  return presence
}

function updateContactPresence(contact) {
  let { uid } = contact
  let squadStatus = g_squad_manager.getPlayerStatusInMySquad(uid)
  let onlinePresence = getOnlinePresence(contact)
  let squadPresence = getSquadPresence(squadStatus)
  let presence = onlinePresence == contactPresence.IN_GAME || onlinePresence == contactPresence.IN_QUEUE
    ? onlinePresence
    : squadPresence ?? onlinePresence

  contact.presence = presence
  contact.onlinePresence = onlinePresence
  contact.squadPresence = squadPresence

  if (squadStatus != squadMemberState.NOT_IN_SQUAD || is_in_my_clan(null, uid))
    broadcastEvent("ChatUpdatePresence", { contact })
}

return {
  contactPresence
  updateContactPresence
}