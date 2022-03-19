// warning disable: -file:forbidden-function
local { refreshGlobalStatusData } = require("scripts/worldWar/operations/model/wwGlobalStatus.nut")

::dbg_ww_destroy_cur_operation <- function dbg_ww_destroy_cur_operation()
{
  if (!::ww_is_operation_loaded())
    return ::dlog("No operation loaded!")

  local blk = ::DataBlock()
  blk.operationId = ::ww_get_operation_id().tointeger()
  blk.status = 3 //ES_FAILED
  ::g_tasker.charSimpleAction("adm_ww_set_operation_status", blk, { showProgressBox = true },
    function() {
      ::dlog("success")
      ::g_world_war.stopWar()
      refreshGlobalStatusData(0)
    },
    function() { ::dlog("Do you have admin rights? ") }
  )
}
