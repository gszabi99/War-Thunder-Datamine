from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs


let isHumanAiming = Watched(false)
let isHumanHoldingBreath = Watched(false)
let isHumanHoldBreathAvailable = Watched(false)
let isHumanHoldBreathShowHint = Watched(false)


ecs.register_es("script_hold_breath_state_es",
  {
    [["onInit", "onChange"]] = function(_, _eid, comp) {
      let isAlive = comp["isAlive"]
      if (!isAlive) {
        isHumanAiming.set(false)
        isHumanHoldingBreath.set(false)
        isHumanHoldBreathAvailable.set(false)
        isHumanHoldBreathShowHint.set(false)
      }
      isHumanAiming.set(comp["human_net_phys__isAiming"])
      isHumanHoldingBreath.set(comp["human_net_phys__isHoldBreath"])
      isHumanHoldBreathAvailable.set(comp["human_hold_breath__isAvailable"])
      isHumanHoldBreathShowHint.set(comp["human_hold_breath__showHintUi"])
    }
    onDestroy = function() {
      isHumanAiming.set(false)
      isHumanHoldingBreath.set(false)
      isHumanHoldBreathAvailable.set(false)
      isHumanHoldBreathShowHint.set(false)
    }
  }
  {
    comps_track = [
      ["isAlive", ecs.TYPE_BOOL, true],
      ["human_net_phys__isAiming", ecs.TYPE_BOOL],
      ["human_net_phys__isHoldBreath", ecs.TYPE_BOOL],
      ["human_hold_breath__isAvailable", ecs.TYPE_BOOL],
      ["human_hold_breath__showHintUi", ecs.TYPE_BOOL]
    ]
    comps_rq = ["watchedByPlr"]
  }
)

return {
  isHumanAiming
  isHumanHoldingBreath
  isHumanHoldBreathAvailable
  isHumanHoldBreathShowHint
}