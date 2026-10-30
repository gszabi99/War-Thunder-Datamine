from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/wheelmenu/wheelmenu.nut" import wheelMenuHandler
from "%scripts/wheelmenu/multifuncMenuTools.nut" import openMfm, getMfmSectionTitle, getMfmHandler
from "controls" import emulateShortcut, isXInputDevice
from "eventbus" import eventbus_subscribe, eventbus_send
from "scriptRespondent" import registerRespondent
from "%scripts/dagui_library.nut" import *

let cfg = require("%scripts/wheelmenu/multifuncmenuCfg.nut")



register_gui_handler("multifuncMenuHandler", class (wheelMenuHandler) {
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
    if (this.mfmDescription == null) { 
      this.showScene(false)
      return
    }
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
      for (local i = 0; i < this.path.len(); i++)
        this.mfmDescription[this.path[i]]?.onExit()
      this.path.clear()
      this.showScene(false)
      eventbus_send("onMultifuncMenuClosed")
    }
  }
})



eventbus_subscribe("on_multifunc_menu_request", function on_multifunc_menu_request(evt) {
  let isShow = evt.show
  if (isShow) {
    let curSection = evt?.curSection
    return openMfm(cfg, curSection)
  }
  getMfmHandler()?.quit()
})


function onMultifuncMenuItemSelected(btnIdx, isDown) {
  getMfmHandler()?.onShortcutSelectCallback(btnIdx, isDown)
  return true
}

registerRespondent("onMultifuncMenuItemSelectedNative", onMultifuncMenuItemSelected)

eventbus_subscribe("on_multifunc_menu_activate_item", function on_multifunc_menu_activate_item(...) {
  getMfmHandler()?.onActivateItemCallback()
})
