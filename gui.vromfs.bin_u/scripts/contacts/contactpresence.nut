from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadMemberState

let { addTypes } = require("%sqStdLibs/helpers/enums.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")

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
    presenceName = "" // filled automatically with addTypes
    sortOrder = PRESENCE_SORT.UNKNOWN
    iconName = ""
    iconColor = "white"
    textColor = ""
    iconTransparency = 180

    getTooltip = @() $"status/{this.presenceName}"
    getText = @(locParams = {}) colorize(this.textColor, loc(this.getTooltip(), locParams))
    getIcon = @() $"#ui/gameuiskin#{this.iconName}"
    getIconColor = @() get_main_gui_scene().getConstantValue(this.iconColor) || ""
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
  }

  IN_QUEUE = {
    sortOrder = PRESENCE_SORT.IN_QUEUE
    iconName = "player_in_queue"
  }

  IN_GAME = {
    sortOrder = PRESENCE_SORT.IN_GAME
    iconName = "player_in_game.svg"
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
  }

  SQUAD_READY = {
    sortOrder = PRESENCE_SORT.SQUAD_READY
    iconName = "squad_ready"
    textColor = "@userlogColoredText"
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

function updateContactPresence(contact) {
  let { uid } = contact
  local presence = contactPresence.UNKNOWN
  if (contact.online)
    presence = contactPresence.ONLINE
  else if (!contact.unknown)
    presence = contactPresence.OFFLINE

  let squadStatus = g_squad_manager.getPlayerStatusInMySquad(uid)
  if (squadStatus == squadMemberState.NOT_IN_SQUAD) {
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
  }
  else if (squadStatus == squadMemberState.SQUAD_LEADER)
    presence = contactPresence.SQUAD_LEADER
  else if (squadStatus == squadMemberState.SQUAD_MEMBER_READY)
    presence = contactPresence.SQUAD_READY
  else if (squadStatus == squadMemberState.SQUAD_MEMBER_OFFLINE)
    presence = contactPresence.SQUAD_OFFLINE
  else
    presence = contactPresence.SQUAD_NOT_READY

  contact.presence = presence

  if (squadStatus != squadMemberState.NOT_IN_SQUAD || ::is_in_my_clan(null, uid))
    ::chatUpdatePresence(contact)
}

return {
  contactPresence
  updateContactPresence
}