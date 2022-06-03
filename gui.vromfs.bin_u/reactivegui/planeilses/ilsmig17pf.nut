let {IlsColor, RadarTargetPosValid, RadarTargetPos} = require("%rGui/planeState/planeToolsState.nut")
let {HorizonY, Roll} = require("%rGui/planeState/planeFlyState.nut")

let horizontLine = @(){
  watch = IlsColor
  rendObj = ROBJ_SOLID
  pos = [pw(-50), 0]
  size = [pw(200), ph(2)]
  color = IlsColor.value
}

let horizont = {
  size = flex()
  children = [horizontLine]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [0, HorizonY.value]
      rotate = -Roll.value
      pivot = [0.5, 0]
    }
  }
}

let target = @(){
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(2), ph(2)]
  color = IlsColor.value
  fillColor = IlsColor.value
  commands = [[VECTOR_ELLIPSE, 0, 0, 100, 100]]
}

let targetWrap = @()
{
  watch = RadarTargetPosValid
  size = flex()
  children = [(RadarTargetPosValid.value ? target : null)]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = RadarTargetPos
    }
  }
}

let function mig17pf(width, height) {
  return {
    size = [width, height]
    children = [
      horizont,
      targetWrap
    ]
  }
}

return mig17pf