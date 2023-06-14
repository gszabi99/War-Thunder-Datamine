//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { animBgLoad } = require("%scripts/loading/animBg.nut")

::gui_handlers.WaitForLoginWnd <- class extends ::BaseGuiHandler {
  sceneBlkName = "%gui/login/waitForLoginWnd.blk"
  isInitialized = false
  isBgVisible = true

  function initScreen() {
    this.updateText()
    this.updateBg()
  }

  function updateText() {
    local text = ""
    if (!(::g_login.curState & LOGIN_STATE.MATCHING_CONNECTED))
      text = loc("yn1/connecting_msg")
    else if (!(::g_login.curState & LOGIN_STATE.CONFIGS_INITED))
      text = loc("loading")
    this.scene.findObject("msgText").setValue(text)
  }

  function updateVisibility() {
    let isVisible = this.isSceneActiveNoModals()
    this.scene.findObject("root-box").show(isVisible)
  }

  function updateBg() {
    let shouldBgVisible = !(::g_login.curState & LOGIN_STATE.HANGAR_LOADED)
    if (this.isBgVisible == shouldBgVisible && this.isInitialized)
      return

    this.isInitialized = true
    this.isBgVisible = shouldBgVisible
    ::showBtn("bg_picture_container", this.isBgVisible, this.scene)
    if (this.isBgVisible)
      animBgLoad("", this.scene.findObject("animated_bg_picture"))
  }

  function onEventLoginStateChanged(_p) {
    this.updateText()
    this.updateBg()
  }

  function onEventHangarModelLoaded(_params) {
    ::enableHangarControls(true)
  }

  function onEventActiveHandlersChanged(_p) {
    this.updateVisibility()
  }
}
