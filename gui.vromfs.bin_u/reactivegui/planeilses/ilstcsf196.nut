let {IlsColor, TargetPosValid, TargetPos, IlsLineScale,
       RocketMode, CannonMode, BombCCIPMode} = require("%rGui/planeState/planeToolsState.nut")
let {Roll, Tangage} = require("%rGui/planeState/planeFlyState.nut");
let {baseLineWidth} = require("ilsConstants.nut")
let {compassWrap, generateCompassTCSFMark} = require("ilsCompasses.nut")

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)
let tcsfAimMark = @() {
  watch = [TargetPosValid, CCIPMode]
  size = flex()
  children = TargetPosValid.value ? (
    !CCIPMode.value ?
    @() {
      watch = IlsColor
      size = [pw(13), ph(13)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_POLY, 0, -100, -2, -92.5, 0, -85, 2, -92.5],
        [VECTOR_POLY, 0, 100, -2, 92.5, 0, 85, 2, 92.5],
        [VECTOR_POLY, -85.5, -50, -80, -44.75, -72.5, -42.5, -78, -47.75],
        [VECTOR_POLY, 85.5, -50, 80, -44.75, 72.5, -42.5, 78, -47.75],
        [VECTOR_POLY, 85.5, 50, 80, 44.75, 72.5, 42.5, 78, 47.75],
        [VECTOR_POLY, -85.5, 50, -80, 44.75, -72.5, 42.5, -78, 47.75],
        [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value * 3.0],
        [VECTOR_LINE, 0, 0, 0, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0], TargetPos.value[1]]
        }
      }
    } :
    @() {
      watch = IlsColor
      size = [baseLineWidth * IlsLineScale.value * 3, baseLineWidth * IlsLineScale.value * 3]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0] - baseLineWidth * IlsLineScale.value * 1.5, TargetPos.value[1] - baseLineWidth * IlsLineScale.value * 1.5]
        }
      }
    })
  : null
}

let tcsfAirSymbol = @() {
  watch = IlsColor
  size = flex()
  color = IlsColor.value
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value * 1.5
  commands = [
    [VECTOR_LINE, 42, 50, 48, 50],
    [VECTOR_LINE, 52, 50, 58, 50],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value * 1.2],
    [VECTOR_LINE, 50, 49, 50, 47],
    [VECTOR_LINE, 50, 11, 50, 13]
  ]
}

let function tcsfHorizont(height) {
  return @() {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = Color(10, 202, 10, 250)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, 10, 50, 30, 50],
      [VECTOR_LINE, 15, 51, 25, 51],
      [VECTOR_LINE, 17.5, 52, 22.5, 52],
      [VECTOR_LINE, 40, 50, 60, 50],
      [VECTOR_LINE, 70, 50, 90, 50],
      [VECTOR_LINE, 75, 51, 85, 51],
      [VECTOR_LINE, 77.5, 52, 82.5, 52]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, height * 0.5 * clamp(Tangage.value  * 0.2, -0.9, 0.9)]
        rotate = -Roll.value
        pivot=[0.5, 0.5 -  0.5 * clamp(Tangage.value  * 0.2, -0.9, 0.9)]
      }
    }
  }
}

let function TCSF196(width, height) {
  return {
    size = [width, height]
    children = [
      tcsfAirSymbol,
      tcsfHorizont(height),
      compassWrap(width, height, -0.1, generateCompassTCSFMark, 0.4, 2.0, true),
      tcsfAimMark
    ]
  }
}

return TCSF196