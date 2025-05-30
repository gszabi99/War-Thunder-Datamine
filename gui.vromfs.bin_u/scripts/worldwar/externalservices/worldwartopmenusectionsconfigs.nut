from "%scripts/dagui_library.nut" import *

require("%scripts/worldWar/externalServices/worldWarTopMenuButtons.nut") 

let { is_low_width_screen } = require("%scripts/options/safeAreaMenu.nut")
let enums = require("%sqStdLibs/helpers/enums.nut")
let buttonsList = require("%scripts/mainmenu/topMenuButtonsList.nut").get()
let { topMenuSectionsTemplate, getTopMenuSectionByName } = require("%scripts/mainmenu/topMenuSections.nut")

let wwTopMenuLeftSideSections = {
  types = []
  cache = {
    byName = {}
  }

  template = topMenuSectionsTemplate
  getSectionByName = getTopMenuSectionByName
}

enums.addTypes(wwTopMenuLeftSideSections, [
  {
    name = "ww_menu"
    btnName = "ww_menu"
    getText = function(_totalSections = 0) { return is_low_width_screen() ? null : "#worldWar/menu" }
    getImage = function(_totalSections = 0) { return is_low_width_screen() ? "#ui/gameuiskin#btn_info.svg" : null }
    buttons = [
      [
        buttonsList.WW_MAIN_MENU
        buttonsList.WW_OPERATIONS
        buttonsList.OPTIONS
        buttonsList.CONTROLS
        buttonsList.WW_HANGAR
      ]
    ]
  }
  {
    name = "ww_map_filter"
    forceHoverWidth = "0.55@sf"
    getText = function(_totalSections = 0) { return is_low_width_screen() ? null : "#worldwar/mapFilters" }
    getImage = function(_totalSections = 0) { return "#ui/gameuiskin#render_army_rad" }
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

return wwTopMenuLeftSideSections
