from "%rGui/globals/ui_library.nut" import *

let { stamina, showStamina }  = require("%rGui/hud/state/stamina_es.nut")
let { staminaColor, barStyleBGColor, barStyleBorderColor, barStyleBackColor
} = require("%rGui/style/colors.nut")
let { healthBlockWidth, heroStateWidth, humanBarInnerPadding
} = require("%rGui/hud/humanSquad/humanConst.nut")
let { hudBlurPanel } = require("%rGui/components/blurPanel.nut")

let staminaBlockHeight = shHud(4)
let iconSize = shHud(2)
let staminaHeight = shHud(1)

function mkStamina() {
  if (!showStamina.get())
    return { watch = showStamina }

  return {
    watch = showStamina
    size = [ heroStateWidth, staminaBlockHeight ]
    children = [
      hudBlurPanel
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        children = [
          {
            size = [flex(), staminaHeight]
            margin = [0, 0, 0, evenPx(7)]
            rendObj = ROBJ_BOX
            borderColor = barStyleBorderColor
            fillColor = barStyleBGColor
            borderWidth = hdpxi(1)
            padding = humanBarInnerPadding
            vplace = ALIGN_CENTER
            children = [
              {
                size = flex()
                rendObj = ROBJ_BOX
                fillColor = barStyleBackColor
              }
              @() {
                watch = stamina
                rendObj = ROBJ_BOX
                size = [ pw(clamp(stamina.get()-1, 0, 100)), flex() ] 
                fillColor = staminaColor
                hplace = ALIGN_LEFT
              }
            ]
          }
          {
            size = [ healthBlockWidth, flex() ]
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = {
              size = [iconSize, iconSize]
              rendObj = ROBJ_IMAGE
              image = Picture($"ui/gameuiskin#icon_stamina.svg:{iconSize}:{iconSize}:P")
            }
          }
        ]
      }
    ]
  }
}

return mkStamina