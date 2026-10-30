from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/loading/animBg.nut" import animBgLoad
from "%scripts/viewUtils/objectTextUpdate.nut" import setHelpTextOnLoading, setVersionText
from "loading" import loading_is_finished, loading_press_apply
from "%scripts/dagui_library.nut" import *

let LoadingHangarHandler = class (BaseGuiHandlerWT) {
  sceneBlkName = "%gui/loading/loadingHangar.blk"
  sceneNavBlkName = "%gui/loading/loadingNav.blk"

  isEnteringMission = false 

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
register_gui_handler("LoadingHangarHandler", LoadingHangarHandler)

return freeze({ LoadingHangarHandler })
