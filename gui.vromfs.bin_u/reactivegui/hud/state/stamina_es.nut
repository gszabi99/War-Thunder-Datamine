from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs

let { watchedTable2TableOfWatched } = require("%sqstd/frp.nut")
let { mkFrameIncrementObservable } = require("%rGui/globals/ec_to_watched.nut")

let defValue = freeze({
  stamina = null
  staminaCanAim = true
  breathShortnessStart = 0.0
})

let { staminaState, staminaStateSetValue } = mkFrameIncrementObservable(defValue, "staminaState")
let { stamina, staminaCanAim, breathShortnessStart
} = watchedTable2TableOfWatched(staminaState)

let breathStart = Computed(@() (1.0 - breathShortnessStart.get()) * 100)
let isLowStamina = keepref(Computed(@() stamina.get() <= breathStart.get()))

ecs.register_es("hud_stamina_state_es",
  {
    [["onInit","onChange"]] = function(_, _eid, comp){
      staminaStateSetValue({
        stamina = comp.view__staminaPercentage
        staminaCanAim = comp.human_weap__staminaCanAim
        breathShortnessStart = comp.human_breath_sound__breathShortnessStart
      })
    },
    function onDestroy(){
      staminaStateSetValue(defValue)
    }
  },
  {
    comps_track = [
      ["view__staminaPercentage", ecs.TYPE_INT],
      ["human_weap__staminaCanAim", ecs.TYPE_BOOL, true]
    ],
    comps_ro = [
      ["human_breath_sound__breathShortnessStart", ecs.TYPE_FLOAT, 1.0]
    ]
    comps_rq = ["watchedByPlr"]
  }
)

return {
  stamina
  staminaCanAim
  showStamina = Computed(@() stamina.get() != null)
  isLowStamina
}