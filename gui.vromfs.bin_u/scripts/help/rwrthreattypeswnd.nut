from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
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

local RwrThreatTypesWnd = class (BaseGuiHandlerWT) {
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

register_gui_handler("RwrThreatTypesWnd", RwrThreatTypesWnd)

eventbus_subscribe("help.openRwrThreatTypesWnd",
  @(_) handlersManager.loadHandler(RwrThreatTypesWnd, {}))
