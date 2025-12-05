from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs

let { mkFrameIncrementObservable } = require("%rGui/globals/ec_to_watched.nut")

let selfHealMedkitsDefValue = 0
let { selfHealMedkits, selfHealMedkitsSetValue } = mkFrameIncrementObservable(selfHealMedkitsDefValue, "selfHealMedkits")

ecs.register_es("total_medkits_ui",{
  [["onChange", "onInit"]] = @(_, _eid, comp) selfHealMedkitsSetValue(comp.total_kits__selfHeal),
  onDestroy = @(...) selfHealMedkitsSetValue(selfHealMedkitsDefValue)
}, {
  comps_track=[["total_kits__selfHeal", ecs.TYPE_INT]],
  comps_rq=["watchedByPlr"]
})

return { selfHealMedkits }
