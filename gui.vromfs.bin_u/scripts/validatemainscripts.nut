//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

//Load main scripts
let { file_exists } = require("dagor.fs")
require("%scripts/main.nut")

log("::load_scripts_after_login()")
::load_scripts_after_login_once()


//validate exist common files for base handlers
foreach (name, hClass in ::gui_handlers) {
  assert(("sceneBlkName" in hClass) && ("sceneTplName" in hClass),
       @() $"handlerClass not instance of BaseGuiHandler: ::gui_handlers.{name}")

  local tplName = hClass.sceneTplName
  if (tplName) {
    assert(file_exists(tplName), $"Failed to load sceneTplName {tplName} for ::gui_handlers.{name}")
    ::handyman.renderCached(tplName, {}) //validate template tokens
  }
}