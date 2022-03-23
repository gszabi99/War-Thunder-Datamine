let { animBgLoad } = require("%scripts/loading/animBg.nut")

::gui_handlers.WaitForLoginWnd <- class extends ::BaseGuiHandler
{
  sceneBlkName = "%gui/login/waitForLoginWnd.blk"
  isInitialized = false
  isBgVisible = true

  function initScreen()
  {
    updateText()
    updateBg()
  }

  function updateText()
  {
    local text = ""
    if (!(::g_login.curState & LOGIN_STATE.MATCHING_CONNECTED))
      text = ::loc("yn1/connecting_msg")
    else if (!(::g_login.curState & LOGIN_STATE.CONFIGS_INITED))
      text = ::loc("loading")
    scene.findObject("msgText").setValue(text)
  }

  function updateVisibility()
  {
    let isVisible = isSceneActiveNoModals()
    scene.findObject("root-box").show(isVisible)
  }

  function updateBg()
  {
    let shouldBgVisible = !(::g_login.curState & LOGIN_STATE.HANGAR_LOADED)
    if (isBgVisible == shouldBgVisible && isInitialized)
      return

    isInitialized = true
    isBgVisible = shouldBgVisible
    ::showBtn("bg_picture_container", isBgVisible, scene)
    if (isBgVisible)
      animBgLoad("", scene.findObject("animated_bg_picture"))
  }

  function onEventLoginStateChanged(p)
  {
    updateText()
    updateBg()
  }

  function onEventHangarModelLoaded(params)
  {
    ::enableHangarControls(true)
  }

  function onEventActiveHandlersChanged(p)
  {
    updateVisibility()
  }
}
