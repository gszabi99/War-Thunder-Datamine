let {IlsColor, TargetPosValid, TargetPos, IlsLineScale, TimeBeforeBombRelease,
       BombingMode} = require("reactiveGui/planeState/planeToolsState.nut")
let {Speed, Roll} = require("reactiveGui/planeState/planeFlyState.nut");
let {mpsToKnots, baseLineWidth} = require("ilsConstants.nut")
let {cvt} = require("dagor.math")

let buccaneerSpdVal = Computed(@() cvt(Speed.value * mpsToKnots, 300, 600, 0, 100).tointeger())
let buccaneerSpeed = @() {
  watch = buccaneerSpdVal
  size = [pw(20), ph(5)]
  pos = [pw(40), ph(85)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * 1.5 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 33, 0, 33, 0],
    [VECTOR_LINE, 66, 0, 66, 0],
    [VECTOR_LINE, 100, 0, 100, 0],
    [VECTOR_LINE, buccaneerSpdVal.value, 50, buccaneerSpdVal.value, 100]
  ]
}

let DistToTargetBuc = Computed(@() cvt(TimeBeforeBombRelease.value, 0, 10.0, -90, 250).tointeger())
let BucDistMarkVis = Computed(@() TargetPosValid.value && BombingMode.value)
let buccaneerCCRP = @() {
  watch = [BucDistMarkVis, DistToTargetBuc]
  size = [pw(20), pw(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * 1.5 * IlsLineScale.value
  commands = BucDistMarkVis.value ? [
    [VECTOR_SECTOR, 0, 0, 80, 80, -90, DistToTargetBuc.value],
    [VECTOR_SECTOR, 0, 0, 30, 30, 50, 130],
    (TimeBeforeBombRelease.value < 3.0 ? [VECTOR_SECTOR, 0, 0, 30, 30, -130, -50] : [])
  ] : []
}

let function buccaneerAimMark(width, height) {
  return {
    size = flex()
    children = [
      {
        size = [pw(20), ph(20)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * 1.5 * IlsLineScale.value
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 15, 15],
          [VECTOR_LINE, -35, 0, -15, 0],
          [VECTOR_LINE, 15, 0, 35, 0],
          [VECTOR_LINE, 0, 80, 0, 90],
          [VECTOR_LINE, 0, -80, 0, -90],
          [VECTOR_LINE, -80, 0, -90, 0],
          [VECTOR_LINE, 80, 0, 90, 0]
        ]
      },
      {
        size = [pw(30), ph(30)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        lineWidth = baseLineWidth * 1.5 * IlsLineScale.value
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_LINE, -100, 0, -80, 0],
          [VECTOR_LINE, 100, 0, 80, 0]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = -Roll.value
            pivot = [0, 0]
          }
        }
      },
      buccaneerCCRP,
      {
        size = [ph(1.2), ph(1.2)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = IlsColor.value
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.value ? [TargetPos.value[0], TargetPos.value[1]] : [-10, -10]
          }
        }
      }
    ]
  }
}

let function buccaneerHUD(width, height) {
  return {
    size = [width, height]
    children = [
      buccaneerAimMark(width, height),
      buccaneerSpeed
    ]
  }
}

return buccaneerHUD