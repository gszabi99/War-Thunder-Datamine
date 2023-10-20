//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")

return [
//-------------------------------------------------------
  {
    id = "ID_COMMON_INTERFACE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FLIGHTMENU_SETUP"
    checkAssign = false
  }
  {
    id = "ID_CONTINUE_SETUP"
    checkAssign = false
  }
  {
    id = "ID_SKIP_CUTSCENE"
    checkAssign = false
  }
  {
    id = "ID_GAME_PAUSE"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_HIDE_HUD"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_COLLAPSE_ACTION_BAR"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHOW_MOUSE_CURSOR"
    checkAssign = false
    showFunc = @() hasFeature("EnableMouse")
    condition = @() is_platform_pc || isPlatformSony || isPlatformXboxOne
  }
  {
    id = "ID_SCREENSHOT"
    checkAssign = false
    condition = @() is_platform_pc // See AcesApp::makeScreenshot()
    needShowInHelp = true
  }
  {
    id = "ID_SCREENSHOT_WO_HUD"
    checkAssign = false
    condition = @() is_platform_pc // See AcesApp::makeScreenshot()
    needShowInHelp = true
  }
  {
    id = "decal_move_x"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "decal_move_y"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "decal_rotate"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
  {
    id = "decal_scale"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
  }
]
