from "%scripts/sqDagui/framework/gui_handlers.nut" import each_gui_handler
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "dagor.fs" import file_exists
from "%scripts/dagui_library.nut" import *


require("%scripts/main.nut")

let { loadScriptsAfterLoginOnce } = require("%scripts/loadScriptsAfterLogin.nut")
log("loadScriptsAfterLoginOnce()")
loadScriptsAfterLoginOnce()


each_gui_handler(function(name, hClass) {
  assert(("sceneBlkName" in hClass) && ("sceneTplName" in hClass),
       @() $"handlerClass not instance of BaseGuiHandler: gui_handlers.{name}")

  local tplName = hClass.sceneTplName
  if (tplName) {
    assert(file_exists(tplName), $"Failed to load sceneTplName {tplName} for gui_handlers.{name}")
    handyman.renderCached(tplName, {}) 
  }
})