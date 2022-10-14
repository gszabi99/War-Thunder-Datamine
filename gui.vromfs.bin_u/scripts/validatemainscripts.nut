from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

getroottable().__update(require("math"), require("string"), require("iostream"), require("io"))

//Load main scripts
require("%scripts/main.nut")

log("::load_scripts_after_login()")
::load_scripts_after_login_once()


//validate exist common files for base handlers
local blk = ::DataBlock()
foreach(name, hClass in ::gui_handlers)
{
  if (!("sceneBlkName" in hClass) || !("sceneTplName" in hClass))
    ::dagor.fatal("handlerClass not instance of BaseGuiHandler: ::gui_handlers." + name)

  if (hClass.sceneBlkName && !blk.tryLoad(hClass.sceneBlkName))
    //fatal only for old codegen version without support dblk::ReadFlag::ROBUST on datablock creation from script
    ::dagor.fatal("Failed to load " + hClass.sceneBlkName + " for ::gui_handlers." + name)

  local tplName = hClass.sceneTplName
  if (tplName)
    if (!::dd_file_exist(tplName + ".tpl"))
      ::dagor.fatal("Failed to load " + tplName + ".tpl for ::gui_handlers." + name)
    else
      ::handyman.renderCached(tplName, {}) //validate template tokens
}