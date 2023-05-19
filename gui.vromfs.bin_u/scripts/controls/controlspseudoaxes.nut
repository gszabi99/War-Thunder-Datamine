//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")

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
      let curUnitType = ::get_es_unit_type(getPlayerCurUnit())
      if (curUnitType == ES_UNIT_TYPE_TANK)
        return ["ID_TOGGLE_VIEW_GM"]
      else if (curUnitType == ES_UNIT_TYPE_SHIP || curUnitType == ES_UNIT_TYPE_BOAT)
        return ["ID_TOGGLE_VIEW_SHIP"]
      else
        return ["ID_TOGGLE_VIEW"]
    }
    isAssigned = function () {
      return ::g_shortcut_type.COMMON_SHORTCUT.isAssigned(this.translate()[0])
    }
  }

  PSEUDO_FIRE = {
    id = "pseudo_fire"
    translate = function() {
      let requiredControls = ::getRequiredControlsForUnit(
        getPlayerCurUnit(), ::getCurrentHelpersMode())

      let isMGunsAvailable = isInArray("ID_FIRE_MGUNS", requiredControls)
      let isCannonsAvailable = isInArray("ID_FIRE_CANNONS", requiredControls)

      if (isMGunsAvailable && !isCannonsAvailable)
        return ["ID_FIRE_MGUNS"]
      else if (!isMGunsAvailable && isCannonsAvailable)
        return ["ID_FIRE_CANNONS"]

      let shortcuts = ::get_shortcuts(["ID_FIRE_MGUNS", "ID_FIRE_CANNONS"])
      if (::is_shortcut_display_equal(shortcuts[0], shortcuts[1]))
        return ["ID_FIRE_MGUNS"]
      else
        return ["ID_FIRE_MGUNS", "ID_FIRE_CANNONS"]
    }
    isAssigned = function () {
      foreach (shortcut in this.translate())
        if (::g_shortcut_type.COMMON_SHORTCUT.isAssigned(shortcut))
          return true
      return false
    }
  }
})

let function isPseudoAxis(shortcutId) {
  foreach (pseudoAxis in pseudoAxesList.types)
    if (shortcutId == pseudoAxis.id)
      return true
  return false
}

let function getPseudoAxisById(shortcutId) {
  return u.search(pseudoAxesList.types, (@(item) item.id == shortcutId))
}

::g_shortcut_type.addType({
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
