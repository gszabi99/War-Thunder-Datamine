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
      if (can_receive_dedic_logerr && is_multiplayer()) //this global function is only one reason to this module be in dagui VM
        resetTimeout(1.0, setEnableDedicLogger) //without timeout this event can reach dedicated before it create m_player entity
    },
  },
  {
    comps_ro = [["server_load_stat__frameCnt", ecs.TYPE_INT]]
  })
