from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

import "%globalScripts/ecs.nut" as ecs
let { enableDedicLogerr, subscribeDedicLogerr } = require("%globalScripts/debugTools/subscribeDedicLogerr.nut")
let { setTimeout } = require("dagor.workcycle")
let { DBGLEVEL } = require("dagor.system")

subscribeDedicLogerr(function(text) {
  logerr($"[DEDICATED]: {text}")
})

let can_receive_dedic_logerr = DBGLEVEL > 0

ecs.register_es("debug_dedic_logerrs_es",
  {
    [["onInit"]] = function(_eid, _comp) {
      if (can_receive_dedic_logerr && ::is_multiplayer()) //this global function is only one reason to this module be in dagui VM
        setTimeout(1.0, @() enableDedicLogerr(true)) //without timeout this event can reach dedicated before it create m_player entity
    },
  },
  {
    comps_ro = [["server_load_stat__frameCnt", ecs.TYPE_INT]]
  })
