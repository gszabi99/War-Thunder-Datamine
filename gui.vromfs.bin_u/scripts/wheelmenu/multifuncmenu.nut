from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { openMfm, getMfmSectionTitle, getMfmHandler } = require("%scripts/wheelmenu/multifuncMenuTools.nut")
let cfg = require("%scripts/wheelmenu/multifuncmenuCfg.nut")
let { emulateShortcut, isXInputDevice } = require("controls")
let { eventbus_subscribe } = require("eventbus")

//--------------------------------------------------------------------------------------------------

gui_handlers.multifuncMenuHandler <- class (gui_handlers.wheelMenuHandler) {
  wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_IN_MULTIFUNC_MENU
                                 | CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
                                 | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS

  wndControlsAllowMaskWhenInactive = CtrlsInGui.CTRL_ALLOW_FULL

  mfmDescription = null
  curSectionId = null
  path = null

  function initScreen() {
    base.initScreen()

    this.path = this.path ?? []
    this.path.append(this.curSectionId)

    this.updateCaption()
  }

  function updateCaption() {
    let objCaption = this.scene.findObject("wheel_menu_category")
    let text = getMfmSectionTitle(this.mfmDescription[this.curSectionId])
    objCaption.setValue(colorize("hudGreenTextColor", text))
  }

  function toggleShortcut(shortcutId) {
    if (isXInputDevice())
      this.switchControlsAllowMask(this.wndControlsAllowMaskWhenInactive)

    emulateShortcut(shortcutId)

    if (isXInputDevice() && this.isActive)
      this.switchControlsAllowMask(this.wndControlsAllowMaskWhenActive)
  }

  function gotoPrevMenuOrQuit() {
    if (this.path.len() == 0)
      return

    let escapingSectionId = this.path.pop()
    this.mfmDescription[escapingSectionId]?.onExit()

    if (this.path.len() > 0)
      openMfm(this.mfmDescription, this.path.pop(), false)
    else
      this.quit()
  }

  function gotoSection(sectionId) {
    openMfm(this.mfmDescription, sectionId)
  }

  function quit() {
    if (this.isActive) {
      for (local i = 0; i < this.path.len() - 1; i++)
        this.mfmDescription[this.path[i]]?.onExit()
      this.path.clear()
      this.showScene(false)
    }
  }
}

//--------------------------------------------------------------------------------------------------

eventbus_subscribe("on_multifunc_menu_request", function on_multifunc_menu_request(evt) {
  let isShow = evt.show
  if (isShow)
    return openMfm(cfg)
  getMfmHandler()?.quit()
})

// Called from client
::on_multifunc_menu_item_selected <- function on_multifunc_menu_item_selected(btnIdx, isDown) {
  getMfmHandler()?.onShortcutSelectCallback(btnIdx, isDown)
  return true
}

eventbus_subscribe("on_multifunc_menu_activate_item", function on_multifunc_menu_activate_item(...) {
  getMfmHandler()?.onActivateItemCallback()
})
