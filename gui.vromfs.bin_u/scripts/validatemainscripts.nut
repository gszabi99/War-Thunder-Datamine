from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

//Load main scripts
let { file_exists } = require("dagor.fs")
require("%scripts/main.nut")

log("::load_scripts_after_login()")
::load_scripts_after_login_once()


//validate exist common files for base handlers
foreach (name, hClass in gui_handlers) {
  if (name == "__dynamic_content__") continue
  assert(("sceneBlkName" in hClass) && ("sceneTplName" in hClass),
       @() $"handlerClass not instance of BaseGuiHandler: gui_handlers.{name}")

  local tplName = hClass.sceneTplName
  if (tplName) {
    assert(file_exists(tplName), $"Failed to load sceneTplName {tplName} for gui_handlers.{name}")
    handyman.renderCached(tplName, {}) //validate template tokens
  }
}