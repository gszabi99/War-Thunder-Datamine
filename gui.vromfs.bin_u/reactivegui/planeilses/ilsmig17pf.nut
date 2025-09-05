from "%rGui/globals/ui_library.nut" import *

let { IlsColor, RadarTargetPosValid, RadarTargetPos } = require("%rGui/planeState/planeToolsState.nut")
let { HorizonY, HorizonX, Roll } = require("%rGui/planeState/planeFlyState.nut")

let horizontLine = @() {
  watch = IlsColor
  rendObj = ROBJ_SOLID
  pos = [pw(-50), 0]
  size = static [pw(200), ph(0.7)]
  color = IlsColor.get()
}

let horizont = {
  size = flex()
  children = [horizontLine]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [HorizonX.get(), HorizonY.get()]
      rotate = -Roll.get()
      pivot = [0, 0]
    }
  }
}

let target = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = static [pw(1.2), ph(1.2)]
  color = IlsColor.get()
  fillColor = IlsColor.get()
  commands = [[VECTOR_ELLIPSE, 0, 0, 100, 100]]
}

let targetWrap = @()
{
  watch = RadarTargetPosValid
  size = flex()
  children = [(RadarTargetPosValid.get() ? target : null)]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = RadarTargetPos
    }
  }
}

function mig17pf(width, height) {
  return {
    size = [width, height]
    children = [
      horizont,
      targetWrap
    ]
  }
}

return mig17pf