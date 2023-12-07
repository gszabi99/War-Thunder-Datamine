from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let threatTypes = [
  {
    title = "common"
    list = [
      "pulse"
      "mprf"
      "hprf"
      "pd"
      "cw"
      "cw_pd"
      "tws"
      "ai"
      "ai_ro"
      "ai_high"
      "ai_track"
      "aaa"
      "aaa_ai"
      "aaa_low"
      "aaa_track"
      "air_defence"
      "sam_mid"
      "sam_low"
      "sam_high"
      "sam_track"
      "sam_launch"
    ]
  }
  {
    title = "specific"
    list = [
      "nike_hercules"
      "hawk"
      "sa_75"
      "s_75"
      "s_125"
    ]
  }
]

local RwrThreatTypesWnd = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/help/rwrThreatTypesWnd.tpl"

  function getSceneTplView() {
    let rows = []
    foreach (s in threatTypes) {
      let { title, list } = s
      rows
        .append({ title = loc($"controls/help/rwr/threat_types/{title}") })
        .extend(list.map(@(v) { name = loc($"hud/rwr_threat_{v}"), desc = loc($"hud/rwr_threat_{v}/desc") }))
    }
    return {
      rows
    }
  }
}

gui_handlers.RwrThreatTypesWnd <- RwrThreatTypesWnd

globalCallbacks.addTypes({
  openRwrThreatTypesWnd = {
    onCb = @(_obj, _params) handlersManager.loadHandler(gui_handlers.RwrThreatTypesWnd, {})
  }
})
