from "%scripts/dagui_library.nut" import *

require("%scripts/worldWar/externalServices/worldWarTopMenuButtons.nut") //Independed Module. Need for init buttons configs

let { is_low_width_screen } = require("%scripts/baseGuiHandlerManagerWT.nut")
let enums = require("%sqStdLibs/helpers/enums.nut")
let buttonsList = require("%scripts/mainmenu/topMenuButtons.nut").buttonsListWatch.value
let { topMenuSectionsTemplate, getTopMenuSectionByName } = require("%scripts/mainmenu/topMenuSections.nut")

let wwTopMenuOperationMap = {
  types = []
  cache = {
    byName = {}
  }

  template = topMenuSectionsTemplate
  getSectionByName = getTopMenuSectionByName
}

enums.addTypes(wwTopMenuOperationMap, [
  {
    name = "ww_menu"
    btnName = "ww_menu"
    getText = @(_totalSections = 0) is_low_width_screen() ? null : "#worldWar/menu"
    getImage = @(_totalSections = 0) is_low_width_screen() ? "#ui/gameuiskin#menu.svg" : null
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

return wwTopMenuOperationMap
