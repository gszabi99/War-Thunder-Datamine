from "%scripts/dagui_library.nut" import *

let { enumsAddTypes, enumsGetCachedType} = require("%sqStdLibs/helpers/enums.nut")

let eventsTypes = {
  
  NONE = {
    name = "none"
  }

  
  REGULAR = {
    name = "regular"
    showInEventsWindow = true
  }

  



  RANDOM_BATTLE = {
    name = "random_battle"
    showInGamercardDrawer = true
  }

  



  FEATURED = {
    name = "featured"
    showInEventsWindow = true
    showInGamercardDrawer = true
  }

  


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