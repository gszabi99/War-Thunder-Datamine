from "%rGui/hud/state/stamina_es.nut" import stamina, showStamina, isLowStamina
from "%rGui/style/colors.nut" import staminaColor
from "%rGui/hud/humanSquad/humanConst.nut" import heroStateWidth
from "%rGui/globals/ui_library.nut" import *

let { ticketHudBlurPanel } = require("%rGui/components/blurPanel.nut")

const staminaHeight = hdpxi(6)
const blinkAnimationId = "stamina_low_anim_id"
isLowStamina.subscribe(@(v) v ? anim_start(blinkAnimationId)
  : anim_request_stop(blinkAnimationId))

function mkStamina() {
  if (!showStamina.get())
    return { watch = showStamina }

  return {
    watch = showStamina
    size = [heroStateWidth, staminaHeight]
    children = [
      ticketHudBlurPanel
      @() {
        watch = stamina
        rendObj = ROBJ_BOX
        size = [ pw(clamp(stamina.get(), 0, 100)), FLEX ]
        fillColor = staminaColor
        hplace = ALIGN_RIGHT
        animations = [{
          trigger = blinkAnimationId
          prop = AnimProp.opacity, from = 1, to = 0.3, duration = 1.2,
          play = isLowStamina.get(), loop = true, easing = CosineFull
        }]
      }
    ]
  }
}

return mkStamina