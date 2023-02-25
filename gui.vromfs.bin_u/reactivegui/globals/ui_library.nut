// configure scene when hosted in game

let { debugTableData, toString } = require("%sqStdLibs/helpers/toString.nut")

require("%sqstd/regScriptDebugger.nut")(debugTableData)
require("console").setObjPrintFunc(debugTableData)

global enum Layers {
  Default
  Tooltip
  Inspector
}

global const LINE_WIDTH = 1.6
global const INVALID_ENTITY_ID = 0 //ecs.INVALID_ENTITY_ID
/*scale px by font size*/
let fontsState = require("%rGui/style/fontsState.nut")
return {
  debugTableData, toString
  str = @(...) "".join(vargv)
  fpx = fontsState.getSizePx,
  dp = fontsState.getSizeByDp,
  scrn_tgt = fontsState.getSizeByScrnTgt //equal @scrn_tgt in gui
}.__merge(require("darg_library.nut"))