//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { addTask } = require("%scripts/tasker.nut")

local callbackReturnFunc = null

::xbox_on_purchases_updated <- function() {
  if (!::is_online_available())
    return

  addTask(::update_entitlements_limited(),
                     {
                       showProgressBox = true
                       progressBoxText = loc("charServer/checking")
                     },
                     Callback(function() {
                       if (callbackReturnFunc) {
                         callbackReturnFunc()
                         callbackReturnFunc = null
                       }
                     }, this)
                    )
}

return function(cb) { callbackReturnFunc = cb }