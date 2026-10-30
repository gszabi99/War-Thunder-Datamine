from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs


let isBipodEnabled = Watched(false)
let isBipodAdsFocused = Watched(false)
let bipodAvailableMountPoints = Watched(0)


ecs.register_es("script_bipod_state_es",
  {
    [["onInit", "onChange"]] = function(_, _eid, comp) {
      isBipodEnabled.set(comp["bipod__enabled"])
      isBipodAdsFocused.set(comp["bipod__adsFocused"])
      bipodAvailableMountPoints.set(comp["bipod__availableMountPoints"])
    }
    onDestroy = function() {
      isBipodEnabled.set(false)
      isBipodAdsFocused.set(false)
      bipodAvailableMountPoints.set(0)
    }
  }
  {
    comps_track = [
      ["bipod__enabled", ecs.TYPE_BOOL, false],
      ["bipod__adsFocused", ecs.TYPE_BOOL, false],
      ["bipod__availableMountPoints", ecs.TYPE_INT, 0]
    ]
    comps_rq = ["watchedByPlr"]
    comps_no = ["isReplayObserved"]
  }
)

return freeze({
  isBipodEnabled
  isBipodAdsFocused
  bipodAvailableMountPoints
})
