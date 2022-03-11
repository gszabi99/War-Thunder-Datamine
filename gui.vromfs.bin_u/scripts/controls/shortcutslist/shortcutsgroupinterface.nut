local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

return [
//-------------------------------------------------------
  {
    id = "ID_COMMON_INTERFACE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FLIGHTMENU_SETUP"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_CONTINUE_SETUP"
    checkGroup = ctrlGroups.NO_GROUP
    checkAssign = false
  }
  {
    id = "ID_SKIP_CUTSCENE"
    checkGroup = ctrlGroups.NO_GROUP
    checkAssign = false
  }
  {
    id = "ID_GAME_PAUSE"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_HIDE_HUD"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_SHOW_MOUSE_CURSOR"
    checkGroup = ctrlGroups.NO_GROUP
    checkAssign = false
    showFunc = @() ::has_feature("EnableMouse")
    condition = @() ::is_platform_pc || isPlatformSony || isPlatformXboxOne
  }
  {
    id = "ID_SCREENSHOT"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    condition = @() ::is_platform_pc // See AcesApp::makeScreenshot()
    needShowInHelp = true
  }
  {
    id = "ID_SCREENSHOT_WO_HUD"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    condition = @() ::is_platform_pc // See AcesApp::makeScreenshot()
    needShowInHelp = true
  }
  {
    id = "decal_move_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HANGAR
    checkAssign = false
  }
  {
    id = "decal_move_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HANGAR
    checkAssign = false
  }
]
