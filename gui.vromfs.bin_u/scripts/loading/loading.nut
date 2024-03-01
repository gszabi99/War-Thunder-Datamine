from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loading_is_finished, loading_press_apply, loading_get_briefing } = require("loading")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setHelpTextOnLoading, setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { eventbus_subscribe } = require("eventbus")

eventbus_subscribe("gui_start_loading", function gui_start_loading(payload) {
  let isMissionLoading = payload?["showBriefing"] ?? false
  let briefing = loading_get_briefing()
  if (::g_login.isLoggedIn() && isMissionLoading && (briefing.blockCount() > 0)) {
    log("briefing loaded, place =", briefing.getStr("place_loc", ""))
    handlersManager.loadHandler(gui_handlers.LoadingBrief, { briefing })
  }
  else if (::g_login.isLoggedIn())
    handlersManager.loadHandler(gui_handlers.LoadingHangarHandler, { isEnteringMission = isMissionLoading })
  else
    handlersManager.loadHandler(gui_handlers.LoadingHandler)

  showTitleLogo()
})

gui_handlers.LoadingHandler <- class (BaseGuiHandler) {
  sceneBlkName = "%gui/loading/loading.blk"
  sceneNavBlkName = "%gui/loading/loadingNav.blk"

  function initScreen() {
    animBgLoad()
    setVersionText()
    setHelpTextOnLoading(this.scene.findObject("help_text"))

    let updObj = this.scene.findObject("cutscene_update")
    if (checkObj(updObj))
      updObj.setUserData(this)
  }

  function onUpdate(_obj, _dt) {
    if (loading_is_finished())
      loading_press_apply()
  }
}