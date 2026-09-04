from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%scripts/sqDagui/framework/baseGuiHandler.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { saveLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")

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

return {
  open = @() handlersManager.loadHandler(reminderGPModal)
}
