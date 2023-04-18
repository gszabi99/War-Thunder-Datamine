//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
enum PRESENCE_SORT {
  UNKNOWN
  OFFLINE
  ONLINE
  IN_QUEUE
  IN_GAME
  SQUAD_OFFLINE
  SQUAD_NOT_READY
  SQUAD_READY
  SQUAD_LEADER
}

::g_contact_presence <- {
  types = []
  template = {
    presenceName = "" //filled automatically with addTypesByGlobalName
    sortOrder = PRESENCE_SORT.UNKNOWN
    iconName = ""
    iconColor = "white"
    textColor = ""
    iconTransparency = 180

    getTooltip = @() "status/" + this.presenceName
    getText = @(locParams = {}) colorize(this.textColor, loc(this.getTooltip(), locParams))
    getIcon = @() "#ui/gameuiskin#" + this.iconName
    getIconColor = @() ::get_main_gui_scene().getConstantValue(this.iconColor) || ""
  }
}

enums.addTypesByGlobalName("g_contact_presence", {
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
},
@() this.presenceName = this.typeName.tolower(),
"typeName")