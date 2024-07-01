// configure scene when hosted in game
from "ecs" import INVALID_ENTITY_ID
let { debugTableData, toString } = require("%sqStdLibs/helpers/toString.nut")
let darg_library = require("darg_library.nut")
let { hdpx } = darg_library
require("%sqstd/regScriptDebugger.nut")(debugTableData)
require("console").setObjPrintFunc(debugTableData)

let notZero = @(basePx, resPx) resPx != 0 || basePx == 0 ? resPx
  : basePx > 0 ? 1
  : -1

let evenPx = @(px) notZero(px, hdpx(px / 2.0).tointeger() * 2)

/*scale px by font size*/
let fontsState = require("%rGui/style/fontsState.nut")
return {
  evenPx,
  debugTableData, toString
  str = @(...) "".join(vargv)
  fpx = fontsState.getSizePx,
  dp = fontsState.getSizeByDp,
  scrn_tgt = fontsState.getSizeByScrnTgt, //equal @scrn_tgt in gui
  WtBhv = require("wt.behaviors"),
  LINE_WIDTH = 1.6,
  INVALID_ENTITY_ID,
  Layers = freeze({
    Default = 0
    Tooltip = 1
    Inspector = 2
  })
}.__merge(darg_library)