from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs


let isBipodEnabled = Watched(false)
let isBipodAdsFocused = Watched(false)


ecs.register_es("script_bipod_state_es",
  {
    [["onInit", "onChange"]] = function(_, _eid, comp) {
      isBipodEnabled.set(comp["bipod__enabled"])
      isBipodAdsFocused.set(comp["bipod__adsFocused"])
    }
    onDestroy = function() {
      isBipodEnabled.set(false)
      isBipodAdsFocused.set(false)
    }
  }
  {
    comps_track = [
      ["bipod__enabled", ecs.TYPE_BOOL, false],
      ["bipod__adsFocused", ecs.TYPE_BOOL, false]
    ]
    comps_rq = ["watchedByPlr"]
    comps_no = ["isReplayObserved"]
  }
)

return {
  isBipodEnabled
  isBipodAdsFocused
}
