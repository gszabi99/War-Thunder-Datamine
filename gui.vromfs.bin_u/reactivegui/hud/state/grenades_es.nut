from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs

let grenadesEids = Watched({})

let grenades = Computed(function(){
  let grenadesByType = {}
  let gEids = grenadesEids.get()
  foreach(gType in gEids) {
    grenadesByType[gType] <- (grenadesByType?[gType] ?? 0) + 1
  }
  return grenadesByType
})

ecs.register_es("inventory_grenades_ui_es",
  {
    [["onInit"]] = function trackGrenades(_, eid, comp) {
      let gType = comp.item__grenadeType
      let glType = comp.item__grenadeLikeType
      if (gType == "shell" && glType == null)
        return
      let grenadeType = gType ?? glType
      grenadesEids.mutate(@(v) v[eid] <- grenadeType)
    },
    onDestroy = function(_, eid, __) {
      if (eid in grenadesEids.get())
        grenadesEids.mutate(@(v) v.$rawdelete(eid))
    }
  },
  {
    comps_ro = [
      ["item__grenadeType", ecs.TYPE_STRING],
      ["item__grenadeLikeType", ecs.TYPE_STRING, null],
    ]
    comps_rq = ["watchedPlayerItem"]
  }
)

return {
  grenades
  grenadesEids
}