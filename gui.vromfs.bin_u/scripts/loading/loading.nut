from "%appGlobals/login/loginState.nut" import isLoggedIn
from "loading" import loading_is_finished, loading_press_apply, loading_get_briefing
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%scripts/sqDagui/framework/baseGuiHandler.nut")
let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { LoadingHangarHandler } = require("%scripts/loading/loadingHangar.nut")
let { LoadingBrief } = require("%scripts/loading/loadingBrief.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setHelpTextOnLoading, setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")

eventbus_subscribe("gui_start_loading", function gui_start_loading(payload) {
  let isMissionLoading = payload?["showBriefing"] ?? false
  let briefing = loading_get_briefing()
  if (isLoggedIn.get() && isMissionLoading && (briefing.blockCount() > 0)) {
    log("briefing loaded, place =", briefing.getStr("place_loc", ""))
    handlersManager.loadHandler(LoadingBrief, { briefing })
  }
  else if (isLoggedIn.get())
    handlersManager.loadHandler(LoadingHangarHandler, { isEnteringMission = isMissionLoading })
  else
    handlersManager.loadHandler(get_gui_handler("LoadingHandler"))

  showTitleLogo()
})

let LoadingHandler = class (BaseGuiHandler) {
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
register_gui_handler("LoadingHandler", LoadingHandler)