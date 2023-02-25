//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { loading_is_finished, loading_press_apply } = require("loading")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { setHelpTextOnLoading, setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")

::gui_handlers.LoadingHangarHandler <- class extends ::gui_handlers.BaseGuiHandlerWT {
  sceneBlkName = "%gui/loading/loadingHangar.blk"
  sceneNavBlkName = "%gui/loading/loadingNav.blk"

  isEnteringMission = false // true on entering mission, false on quiting.

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