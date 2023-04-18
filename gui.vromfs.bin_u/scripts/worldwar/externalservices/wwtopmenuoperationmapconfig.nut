//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

require("%scripts/worldWar/externalServices/worldWarTopMenuButtons.nut") //Independed Module. Need for init buttons configs

let enums = require("%sqStdLibs/helpers/enums.nut")
let buttonsList = require("%scripts/mainmenu/topMenuButtons.nut").buttonsListWatch.value

::g_ww_top_menu_operation_map <- {
  types = []
  cache = {
    byName = {}
  }

  template = ::g_top_menu_sections.template
  getSectionByName = ::g_top_menu_sections.getSectionByName
}

enums.addTypesByGlobalName("g_ww_top_menu_operation_map", [
  {
    name = "ww_menu"
    btnName = "ww_menu"
    getText = @(_totalSections = 0) ::is_low_width_screen() ? null : "#worldWar/menu"
    getImage = @(_totalSections = 0) ::is_low_width_screen() ? "#ui/gameuiskin#menu.svg" : null
    buttons = [
      [
        buttonsList.WW_LEADERBOARDS
        buttonsList.WW_ACHIEVEMENTS
        buttonsList.WW_VEHICLE_SET
        buttonsList.WW_SCENARIO_DESCR
        buttonsList.WW_OPERATION_LIST
        buttonsList.WW_WIKI
        buttonsList.LINE_SEPARATOR
        buttonsList.OPTIONS
        buttonsList.CONTROLS
        buttonsList.LINE_SEPARATOR
        buttonsList.WW_HANGAR
      ]
    ]
  }
])