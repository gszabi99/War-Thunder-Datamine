from "%scripts/sqDagui/framework/baseGuiHandler.nut" import BaseGuiHandler
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let reminderGPModal = class (BaseGuiHandler) {
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/mainmenu/reminderGaijinPassModal.tpl"

  function getSceneTplView() {
    let passName = getCurCircuitOverride("passName", "Gaijin Pass")
    return {
      backgroundImg = "#ui/images/two_step_gp_banner_bg"
      passText = loc("mainmenu/2step/getPass", { passName })
      descText = loc("mainmenu/2step/getPass/reminder", { passName })
      whyNeedText = loc("mainmenu/2step/getPass/whyNeed", { passName })
      twoStepCodeAppURL = getCurCircuitOverride("twoStepCodeAppURL", loc("url/2step/codeApp"))
      signInTroublesURL = getCurCircuitOverride("signInTroublesURL", loc("url/2step/signInTroubles"))
    }
  }

  function onDontShowChange(obj) {
    saveLocalAccountSettings("skipped_msg/gaijinPassDontShowThisAgain", obj.getValue())
  }
}
register_gui_handler("reminderGPModal", reminderGPModal)

return freeze({
  open = @() handlersManager.loadHandler(reminderGPModal)
})
