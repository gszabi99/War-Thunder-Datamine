
from "ecs" import INVALID_ENTITY_ID
let { debugTableData, toString } = require("%sqStdLibs/helpers/toString.nut")
let darg_library = require("%rGui/globals/darg_library.nut")
let { hdpx } = darg_library
require("%sqstd/regScriptDebugger.nut")(debugTableData)
require("console").setObjPrintFunc(debugTableData)

let notZero = @(basePx, resPx) resPx != 0 || basePx == 0 ? resPx
  : basePx > 0 ? 1
  : -1

let evenPx = @[pure](px) notZero(px, hdpx(px / 2.0).tointeger() * 2)


let fontsState = require("%rGui/style/fontsState.nut")
return {
  evenPx,
  debugTableData, toString
  str = @(...) "".join(vargv)
  fpx = fontsState.getSizePx,
  dp = fontsState.getSizeByDp,
  scrn_tgt = fontsState.getSizeByScrnTgt, 
  WtBhv = require("wt.behaviors"),
  LINE_WIDTH = 1.6,
  INVALID_ENTITY_ID,
  Layers = freeze({
    Default = 0
    Upper = 1
    Tooltip = 2
    Inspector = 3
  })
}.__merge(darg_library)