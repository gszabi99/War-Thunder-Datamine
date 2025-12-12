from "%rGui/globals/ui_library.nut" import *

let { stamina, showStamina }  = require("%rGui/hud/state/stamina_es.nut")
let { staminaColor } = require("%rGui/style/colors.nut")
let { heroStateWidth } = require("%rGui/hud/humanSquad/humanConst.nut")
let { ticketHudBlurPanel } = require("%rGui/components/blurPanel.nut")

let staminaHeight = hdpxi(6)

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
        size = [ pw(clamp(stamina.get()-1, 0, 100)), flex() ] 
        fillColor = staminaColor
        hplace = ALIGN_RIGHT
      }
    ]
  }
}

return mkStamina