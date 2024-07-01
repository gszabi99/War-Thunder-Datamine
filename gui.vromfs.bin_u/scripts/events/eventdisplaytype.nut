from "%scripts/dagui_library.nut" import *

let { enumsAddTypes, enumsGetCachedType} = require("%sqStdLibs/helpers/enums.nut")

let eventsTypes = {
  //hidden event
  NONE = {
    name = "none"
  }

  /** (default) Event is visible only in events window. */
  REGULAR = {
    name = "regular"
    showInEventsWindow = true
  }

  /**
   * Event is hidden from events window but visible in gamercard drawer.
   * Can be selected with check box.
   */
  RANDOM_BATTLE = {
    name = "random_battle"
    showInGamercardDrawer = true
  }

  /**
   * Event is visible both in events window and in gamercard drawer.
   * Clicking on event's icon in drawer opens it event window.
   */
  FEATURED = {
    name = "featured"
    showInEventsWindow = true
    showInGamercardDrawer = true
  }

  /**
   * PVE battle
   */
  PVE_BATTLE = {
    name = "pve_battle"
    showInGamercardDrawer = true
  }
}

let g_event_display_type = {
  types = []
  cache = {
    byName = {}
  }
  template = {
    name = ""
    showInEventsWindow = false
    showInGamercardDrawer = false
    canBeSelectedInGcDrawer = @() this.showInGamercardDrawer && !this.showInEventsWindow
  }

  function getTypeByName(name) {
    return enumsGetCachedType("name", name, this.cache.byName,
      this, eventsTypes.REGULAR)
  }
}

enumsAddTypes(g_event_display_type, eventsTypes)

return {
  g_event_display_type
}