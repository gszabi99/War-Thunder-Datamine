//checked for plus_string
from "%scripts/dagui_library.nut" import *

// warning disable: -file:forbidden-function
let { refreshGlobalStatusData } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let DataBlock  = require("DataBlock")
let { wwGetOperationId, wwIsOperationLoaded } = require("worldwar")

::dbg_ww_destroy_cur_operation <- function dbg_ww_destroy_cur_operation() {
  if (!wwIsOperationLoaded())
    return dlog("No operation loaded!")

  let blk = DataBlock()
  blk.operationId = wwGetOperationId().tointeger()
  blk.status = 3 //ES_FAILED
  ::g_tasker.charSimpleAction("adm_ww_set_operation_status", blk, { showProgressBox = true },
    function() {
      dlog("success")
      ::g_world_war.stopWar()
      refreshGlobalStatusData(0)
    },
    function() { dlog("Do you have admin rights? ") }
  )
}
