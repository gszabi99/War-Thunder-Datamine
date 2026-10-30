from "%scripts/sqDagui/framework/baseGuiHandler.nut" import BaseGuiHandler
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/loading/animBg.nut" import animBgLoad
from "%appGlobals/login/loginState.nut" import hasLoginState
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let WaitForLoginWnd = class (BaseGuiHandler) {
  sceneBlkName = "%gui/login/waitForLoginWnd.blk"
  isInitialized = false
  isBgVisible = true

  function initScreen() {
    this.updateText()
    this.updateBg()
  }

  function updateText() {
    local text = ""
    if (!hasLoginState(LOGIN_STATE.MATCHING_CONNECTED))
      text = loc("yn1/connecting_msg")
    else if (!hasLoginState(LOGIN_STATE.CONFIGS_INITED))
      text = loc("loading")
    this.scene.findObject("msgText").setValue(text)
  }

  function updateVisibility() {
    let isVisible = this.isSceneActiveNoModals()
    this.scene.findObject("root-box").show(isVisible)
  }

  function updateBg() {
    let shouldBgVisible = !hasLoginState(LOGIN_STATE.HANGAR_LOADED)
    if (this.isBgVisible == shouldBgVisible && this.isInitialized)
      return

    this.isInitialized = true
    this.isBgVisible = shouldBgVisible
    showObjById("bg_picture_container", this.isBgVisible, this.scene)
    if (this.isBgVisible)
      animBgLoad("", this.scene.findObject("animated_bg_picture"))
  }

  function onEventLoginStateChanged(_p) {
    this.updateText()
    this.updateBg()
  }

  function onEventActiveHandlersChanged(_p) {
    this.updateVisibility()
  }
}
register_gui_handler("WaitForLoginWnd", WaitForLoginWnd)

return freeze({ WaitForLoginWnd })
