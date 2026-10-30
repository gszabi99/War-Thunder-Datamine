import "%sqStdLibs/helpers/u.nut" as u
import "%sqStdLibs/helpers/enums.nut" as enums
from "%scripts/unit/unitParams.nut" import getEsUnitType
from "%scripts/slotbar/playerCurUnit.nut" import getPlayerCurUnit
from "%scripts/controls/controlsCompatibility.nut" import getShortcuts
from "%scripts/controls/shortcutsUtils.nut" import isShortcutDisplayEqual
from "%scripts/controls/controlsUtils.nut" import getRequiredControlsForUnit
from "%scripts/controls/aircraftHelpers.nut" import getCurrentHelpersMode
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")

let pseudoAxesList = {
  template = {
    id = ""
    translate = function () { return [] }
    isAssigned = function () { return false }
  }
  types = []
}

enums.addTypes(pseudoAxesList, {
  TOGGLE_VIEW = {
    id = "pseudo_toggle_view"
    translate = function () {
      let curUnitType = getEsUnitType(getPlayerCurUnit())
      if (curUnitType == ES_UNIT_TYPE_TANK)
        return ["ID_TOGGLE_VIEW_GM"]
      else if (curUnitType == ES_UNIT_TYPE_SHIP || curUnitType == ES_UNIT_TYPE_BOAT)
        return ["ID_TOGGLE_VIEW_SHIP"]
      else
        return ["ID_TOGGLE_VIEW"]
    }
    isAssigned = function () {
      return g_shortcut_type.COMMON_SHORTCUT.isAssigned(this.translate()[0])
    }
  }

  PSEUDO_FIRE = {
    id = "pseudo_fire"
    translate = function() {
      let requiredControls = getRequiredControlsForUnit(
        getPlayerCurUnit(), getCurrentHelpersMode())

      let isMGunsAvailable = isInArray("ID_FIRE_MGUNS", requiredControls)
      let isCannonsAvailable = isInArray("ID_FIRE_CANNONS", requiredControls)

      if (isMGunsAvailable && !isCannonsAvailable)
        return ["ID_FIRE_MGUNS"]
      else if (!isMGunsAvailable && isCannonsAvailable)
        return ["ID_FIRE_CANNONS"]

      let shortcuts = getShortcuts(["ID_FIRE_MGUNS", "ID_FIRE_CANNONS"])
      if (isShortcutDisplayEqual(shortcuts[0], shortcuts[1]))
        return ["ID_FIRE_MGUNS"]
      else
        return ["ID_FIRE_MGUNS", "ID_FIRE_CANNONS"]
    }
    isAssigned = function () {
      foreach (shortcut in this.translate())
        if (g_shortcut_type.COMMON_SHORTCUT.isAssigned(shortcut))
          return true
      return false
    }
  }
})

function isPseudoAxis(shortcutId) {
  foreach (pseudoAxis in pseudoAxesList.types)
    if (shortcutId == pseudoAxis.id)
      return true
  return false
}

function getPseudoAxisById(shortcutId) {
  return u.search(pseudoAxesList.types, (@(item) item.id == shortcutId))
}

g_shortcut_type.addType({
  PSEUDO_AXIS = {
    isMe = @(shortcutId) isPseudoAxis(shortcutId)

    isAssigned = function (shortcutId, _preset = null) {
      let pseudoAxis = getPseudoAxisById(shortcutId)
      return pseudoAxis.isAssigned()
    }

    expand = function (shortcutId, _showKeyBoardShortcutsForMouseAim) {
      let pseudoAxis = getPseudoAxisById(shortcutId)
      return pseudoAxis.translate()
    }
  }
})
