import "DataBlock" as DataBlock
from "worldwar" import wwGetOperationId, wwIsOperationLoaded
from "console" import register_command
from "%scripts/dagui_library.nut" import *


let { refreshGlobalStatusData } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { charSimpleAction } = require("%scripts/tasker.nut")
let g_world_war = require("%scripts/worldWar/worldWarUtils.nut")

function ww_destroy_cur_operation() {
  if (!wwIsOperationLoaded())
    return dlog("No operation loaded!")

  let blk = DataBlock()
  blk.operationId = wwGetOperationId().tointeger()
  blk.status = 3 
  charSimpleAction("adm_ww_set_operation_status", blk, { showProgressBox = true },
    function() {
      dlog("success")
      g_world_war.stopWar()
      refreshGlobalStatusData(0)
    },
    function() { dlog("Do you have admin rights? ") }
  )
}

register_command(ww_destroy_cur_operation, "debug.ww_destroy_cur_operation")