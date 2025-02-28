from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isXInputDevice } = require("controls")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { joystickGetCurSettings, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")

//--------------------------------------------------------------------------------------------------

gui_handlers.chooseVehicleMenuHandler <- class (gui_handlers.wheelMenuHandler) {
  wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_IN_UNLIM_CTRL_MENU
                                 | CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
                                 | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS

  wndControlsAllowMaskWhenInactive = CtrlsInGui.CTRL_ALLOW_FULL

  function initScreen() {
    this.callbackFunc = this.doApplyChoose
    base.initScreen()
    this.updateCaption()
  }

  function updateCaption() {
    let objCaption = this.scene.findObject("wheel_menu_category")
    objCaption.setValue(colorize("hudGreenTextColor", loc("HUD/CHOICE_OF_VEHICLE")))
  }

  function quit() {
    if (this.isActive)
      this.showScene(false)
  }

  function doApplyChoose(idx) {
    if (idx < 0 || (idx not in this.menu)) {
      this.quit()
      return
    }

    toggleShortcut(this.menu[idx].shortcutId)
  }
}

let getMenuHandler = @() handlersManager.findHandlerClassInScene(gui_handlers.chooseVehicleMenuHandler)

function makeMenuView(cfg) {
  let menu = cfg.map(function(item) {
    let { name, isEnabled, shortcutId } = item
    local color = isEnabled ? "hudGreenTextColor" : ""
    local shortcutText = ""
    if (is_platform_pc)
      shortcutText = ::get_shortcut_text({
        shortcuts = getShortcuts([ shortcutId ])
        shortcutId = 0
        cantBeEmpty = false
        strip_tags = true
        colored = isEnabled
      })

    return {
      shortcutId
      name = colorize(color, loc(name))
      shortcutText
      wheelmenuEnabled = isEnabled
    }
  })
  return menu
}


function openMenu(cfg) {
  let joyParams = joystickGetCurSettings()
  let params = {
    menu = makeMenuView(cfg)
    mouseEnabled = joyParams.useMouseForVoiceMessage || joyParams.useJoystickMouseForVoiceMessage
    axisEnabled  = true
    shouldShadeBackground = isXInputDevice()
  }

  let handler = getMenuHandler()
  if (handler)
    handler.reinitScreen(params)
  else
    handlersManager.loadHandler(gui_handlers.chooseVehicleMenuHandler, params)
}

//--------------------------------------------------------------------------------------------------

//choose vehicle menu config
/*let cfg = [
  {
    name = "germ_at_gun_pak38_1"
    isEnabled = true
    shortcutId = "ID_VOICE_MESSAGE_1"
  }
  {
    name = "germ_at_gun_pak38_2"
    isEnabled = false
    shortcutId = "ID_VOICE_MESSAGE_2"
  }
]*/

eventbus_subscribe("showChooseVehicleMenu", function(params) {
  if (params.isShow) {
    if ((params?.cfg ?? []).len() > 0)
      openMenu(params.cfg)
    return
  }
  getMenuHandler()?.quit()
})
