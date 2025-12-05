from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs

let { watchedTable2TableOfWatched } = require("%sqstd/frp.nut")
let { mkFrameIncrementObservable } = require("%rGui/globals/ec_to_watched.nut")

let defValue = freeze({
  stamina = null
  scaleStamina = 0
  staminaCanAim = true
  staminaUseFlask = false
})

let { staminaState, staminaStateSetValue } = mkFrameIncrementObservable(defValue, "staminaState")
let { stamina, scaleStamina, staminaCanAim, staminaUseFlask
} = watchedTable2TableOfWatched(staminaState)

ecs.register_es("hud_stamina_state_es",
  {
    [["onInit","onChange"]] = function(_, _eid, comp){
      let staminaComp = comp.view_stamina
      staminaStateSetValue({
        stamina = staminaComp
        staminaCanAim = comp.human_weap__staminaCanAim
        scaleStamina = comp.entity_mods__staminaBoostMult
        staminaUseFlask = staminaComp < comp.ui__flaskUseTipMinStamina
      })
    },
    function onDestroy(){
      staminaStateSetValue(defValue)
    }
  },
  {
    comps_track = [
      ["view_stamina", ecs.TYPE_INT],
      ["entity_mods__staminaBoostMult", ecs.TYPE_FLOAT, 1.0],
      ["human_weap__staminaCanAim", ecs.TYPE_BOOL, true]
    ]
    comps_ro = [
      ["ui__flaskUseTipMinStamina", ecs.TYPE_FLOAT]
    ]
    comps_rq = ["watchedByPlr"]
  }
)

return {
  stamina
  scaleStamina
  staminaCanAim
  staminaUseFlask
  showStamina = Computed(@() stamina.get() != null)
}