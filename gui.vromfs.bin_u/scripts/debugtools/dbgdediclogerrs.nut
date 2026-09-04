import "%globalScripts/ecs.nut" as ecs
from "%globalScripts/debugTools/subscribeDedicLogerr.nut" import enableDedicLogerr, subscribeDedicLogerr
from "dagor.workcycle" import resetTimeout
from "dagor.system" import DBGLEVEL
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

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
