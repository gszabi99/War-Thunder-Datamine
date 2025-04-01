from "%scripts/dagui_library.nut" import *
import "%globalScripts/ecs.nut" as ecs
from "%scripts/utils_sa.nut" import is_multiplayer

let { enableDedicLogerr, subscribeDedicLogerr } = require("%globalScripts/debugTools/subscribeDedicLogerr.nut")
let { resetTimeout } = require("dagor.workcycle")
let { DBGLEVEL } = require("dagor.system")

subscribeDedicLogerr(function(text) {
  logerr($"[DEDICATED]: {text}")
})

let can_receive_dedic_logerr = DBGLEVEL > 0
let setEnableDedicLogger = @() enableDedicLogerr(true)
ecs.register_es("debug_dedic_logerrs_es",
  {
    [["onInit"]] = function(_eid, _comp) {
      if (can_receive_dedic_logerr && is_multiplayer()) 
        resetTimeout(1.0, setEnableDedicLogger) 
    },
  },
  {
    comps_rq=["server_load_stat__load"]
  })
