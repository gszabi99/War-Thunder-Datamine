require("scripts/worldWar/externalServices/worldWarTopMenuButtons.nut") //Independed Module. Need for init buttons configs

let enums = require("%sqStdLibs/helpers/enums.nut")
let buttonsList = require("%scripts/mainmenu/topMenuButtons.nut").buttonsListWatch.value

::g_ww_top_menu_left_side_sections <- {
  types = []
  cache = {
    byName = {}
  }

  template = ::g_top_menu_sections.template
  getSectionByName = ::g_top_menu_sections.getSectionByName
}

enums.addTypesByGlobalName("g_ww_top_menu_left_side_sections", [
  {
    name = "ww_menu"
    btnName = "ww_menu"
    getText = function(totalSections = 0) { return ::is_low_width_screen()? null : "#worldWar/menu" }
    getImage = function(totalSections = 0) { return ::is_low_width_screen()? "#ui/gameuiskin#btn_info.svg" : null }
    buttons = [
      [
        buttonsList.WW_MAIN_MENU
        buttonsList.WW_OPERATIONS
        buttonsList.LINE_SEPARATOR
        buttonsList.OPTIONS
        buttonsList.CONTROLS
        buttonsList.LINE_SEPARATOR
        buttonsList.WW_HANGAR
      ]
    ]
  }
  {
    name = "ww_map_filter"
    forceHoverWidth = "0.55@sf"
    getText = function(totalSections = 0) { return ::is_low_width_screen()? null : "#worldwar/mapFilters" }
    getImage = function(totalSections = 0) { return "#ui/gameuiskin#render_army_rad.png" }
    buttons = [
      [
        buttonsList.WW_FILTER_RENDER_ZONES
        buttonsList.WW_FILTER_RENDER_ARROWS
        buttonsList.WW_FILTER_RENDER_ARROWS_FOR_SELECTED
        buttonsList.WW_FILTER_RENDER_BATTLES
        buttonsList.WW_FILTER_RENDER_MAP_PICTURES
        buttonsList.WW_FILTER_RENDER_DEBUG
      ]
    ]
  }
])