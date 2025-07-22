from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")

let g_ww_log_type = {
  types = []
  cache = {
    byName = {}
  }
  template = {
    category  = -1
    iconImage = ""
    iconColor = ""
  }
}


enumsAddTypes(g_ww_log_type, {
    [WW_LOG_TYPES.UNKNOWN] = {
    },

    [WW_LOG_TYPES.OPERATION_CREATED] = {
      category  = WW_LOG_CATEGORIES.SYSTEM
      iconImage = WW_LOG_ICONS.SYSTEM
      iconColor = WW_LOG_COLORS.SYSTEM
      categoryName = "system"
    },

    [WW_LOG_TYPES.OPERATION_STARTED] = {
      category  = WW_LOG_CATEGORIES.SYSTEM
      iconImage = WW_LOG_ICONS.SYSTEM
      iconColor = WW_LOG_COLORS.SYSTEM
      categoryName = "system"
    },

    [WW_LOG_TYPES.OPERATION_FINISHED] = {
      category  = WW_LOG_CATEGORIES.SYSTEM
      iconImage = WW_LOG_ICONS.SYSTEM
      iconColor = WW_LOG_COLORS.SYSTEM
      categoryName = "system"
    },

    [WW_LOG_TYPES.OBJECTIVE_COMPLETED] = {
      category  = WW_LOG_CATEGORIES.SYSTEM
      iconImage = WW_LOG_ICONS.SYSTEM
      iconColor = WW_LOG_COLORS.SYSTEM
      categoryName = "system"
    },

    [WW_LOG_TYPES.BATTLE_STARTED] = {
      category  = WW_LOG_CATEGORIES.EXISTING_BATTLES
      iconImage = WW_LOG_ICONS.EXISTING_BATTLES
      iconColor = WW_LOG_COLORS.EXISTING_BATTLES
      categoryName = "existing_battles"
    },

    [WW_LOG_TYPES.BATTLE_JOIN] = {
      category  = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      iconImage = WW_LOG_ICONS.ARMY_ACTIVITY
      iconColor = WW_LOG_COLORS.ARMY_ACTIVITY
      categoryName = "army_activity"
    },

    [WW_LOG_TYPES.BATTLE_FINISHED] = {
      category  = WW_LOG_CATEGORIES.FINISHED_BATTLES
      iconImage = WW_LOG_ICONS.FINISHED_BATTLES
      iconColor = WW_LOG_COLORS.FINISHED_BATTLES
      categoryName = "finished_battles"
    },

    [WW_LOG_TYPES.ZONE_CAPTURED] = {
      category  = WW_LOG_CATEGORIES.ZONE_CAPTURE
      iconImage = WW_LOG_ICONS.ZONE_CAPTURE
      iconColor = WW_LOG_COLORS.ZONE_CAPTURE
      categoryName = "zone_capture"
    },

    [WW_LOG_TYPES.ARMY_RETREAT] = {
      category  = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      iconImage = WW_LOG_ICONS.ARMY_ACTIVITY
      iconColor = WW_LOG_COLORS.ARMY_ACTIVITY
      categoryName = "army_activity"
    },

    [WW_LOG_TYPES.ARMY_DIED] = {
      category  = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      iconImage = WW_LOG_ICONS.ARMY_ACTIVITY
      iconColor = WW_LOG_COLORS.ARMY_ACTIVITY
      categoryName = "army_activity"
    },

    [WW_LOG_TYPES.ARMY_FLYOUT] = {
      category  = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      iconImage = WW_LOG_ICONS.ARMY_ACTIVITY
      iconColor = WW_LOG_COLORS.ARMY_ACTIVITY
      categoryName = "army_activity"
    },

    [WW_LOG_TYPES.ARMY_LAND_ON_AIRFIELD] = {
      category  = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      iconImage = WW_LOG_ICONS.ARMY_ACTIVITY
      iconColor = WW_LOG_COLORS.ARMY_ACTIVITY
      categoryName = "army_activity"
    },

    [WW_LOG_TYPES.ARTILLERY_STRIKE_DAMAGE] = {
      category  = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      iconImage = WW_LOG_ICONS.ARMY_ACTIVITY
      iconColor = WW_LOG_COLORS.ARMY_ACTIVITY
      categoryName = "army_activity"
    },

    [WW_LOG_TYPES.REINFORCEMENT] = {
      category  = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      iconImage = WW_LOG_ICONS.ARMY_ACTIVITY
      iconColor = WW_LOG_COLORS.ARMY_ACTIVITY
      categoryName = "army_activity"
    }
}, null, "name")

g_ww_log_type.getLogTypeByName <- function getLogTypeByName(logName) {
  return enumsGetCachedType(
    "name",
    logName,
    this.cache.byName,
    this,
    this.UNKNOWN
  )
}

return {
  g_ww_log_type
}