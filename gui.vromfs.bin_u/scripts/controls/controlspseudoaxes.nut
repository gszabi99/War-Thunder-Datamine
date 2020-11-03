local enums = require("sqStdlibs/helpers/enums.nut")
::g_pseudo_axes_list <- {
  types = []
}

::g_pseudo_axes_list.template <- {
  id = ""
  translate = function () { return [] }
  isAssigned = function () { return false }
}

enums.addTypesByGlobalName("g_pseudo_axes_list", {
  TOGGLE_VIEW = {
    id = "pseudo_toggle_view"
    translate = function ()
    {
      local curUnitType = ::get_es_unit_type(::get_player_cur_unit())
      if (curUnitType == ::ES_UNIT_TYPE_TANK)
        return ["ID_TOGGLE_VIEW_GM"]
      else if (curUnitType == ::ES_UNIT_TYPE_SHIP || curUnitType == ::ES_UNIT_TYPE_BOAT)
        return ["ID_TOGGLE_VIEW_SHIP"]
      else
        return ["ID_TOGGLE_VIEW"]
    }
    isAssigned = function () {
      return ::g_shortcut_type.COMMON_SHORTCUT.isAssigned(translate()[0])
    }
  }

  PSEUDO_FIRE = {
    id = "pseudo_fire"
    translate = function()
    {
      local requiredControls = ::getRequiredControlsForUnit(
        ::get_player_cur_unit(), ::getCurrentHelpersMode())

      local isMGunsAvailable = ::isInArray("ID_FIRE_MGUNS", requiredControls)
      local isCannonsAvailable = ::isInArray("ID_FIRE_CANNONS", requiredControls)

      if (isMGunsAvailable && !isCannonsAvailable)
        return ["ID_FIRE_MGUNS"]
      else if (!isMGunsAvailable && isCannonsAvailable)
        return ["ID_FIRE_CANNONS"]

      local shortcuts = ::get_shortcuts(["ID_FIRE_MGUNS", "ID_FIRE_CANNONS"])
      if (::is_shortcut_display_equal(shortcuts[0], shortcuts[1]))
        return ["ID_FIRE_MGUNS"]
      else
        return ["ID_FIRE_MGUNS", "ID_FIRE_CANNONS"]
    }
    isAssigned = function ()
    {
      foreach (shortcut in translate())
        if (::g_shortcut_type.COMMON_SHORTCUT.isAssigned(shortcut))
          return true
      return false
    }
  }
})

g_pseudo_axes_list.isPseudoAxis <- function isPseudoAxis(shortcutId)
{
  foreach (pseudoAxis in types)
    if (shortcutId == pseudoAxis.id)
      return true
  return false
}

g_pseudo_axes_list.getPseudoAxisById <- function getPseudoAxisById(shortcutId)
{
  return ::u.search(types, (@(shortcutId) function (item) {
      return item.id == shortcutId
    })(shortcutId)
  )
}
