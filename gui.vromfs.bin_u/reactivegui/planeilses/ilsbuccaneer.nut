from "%rGui/globals/ui_library.nut" import *

let { IlsColor, TargetPosValid, TargetPos, IlsLineScale, TimeBeforeBombRelease,
       BombingMode } = require("%rGui/planeState/planeToolsState.nut")
let { Tas, Roll } = require("%rGui/planeState/planeFlyState.nut");
let { mpsToKnots, baseLineWidth } = require("%rGui/planeIlses/ilsConstants.nut")
let { cvt } = require("dagor.math")

let buccaneerSpdVal = Computed(@() cvt(Tas.get() * mpsToKnots, 300, 600, 0, 100).tointeger())
let buccaneerSpeed = @() {
  watch = [buccaneerSpdVal, IlsColor]
  size = static [pw(20), ph(5)]
  pos = [pw(40), ph(85)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * 1.5 * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 33, 0, 33, 0],
    [VECTOR_LINE, 66, 0, 66, 0],
    [VECTOR_LINE, 100, 0, 100, 0],
    [VECTOR_LINE, buccaneerSpdVal.get(), 50, buccaneerSpdVal.get(), 100]
  ]
}

let DistToTargetBuc = Computed(@() cvt(TimeBeforeBombRelease.get(), 0, 10.0, -90, 250).tointeger())
let BucDistMarkVis = Computed(@() TargetPosValid.get() && BombingMode.get())
let buccaneerCCRP = @() {
  watch = [BucDistMarkVis, DistToTargetBuc, IlsColor]
  size = pw(20)
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * 1.5 * IlsLineScale.get()
  commands = BucDistMarkVis.get() ? [
    [VECTOR_SECTOR, 0, 0, 80, 80, -90, DistToTargetBuc.get()],
    [VECTOR_SECTOR, 0, 0, 30, 30, 50, 130],
    (TimeBeforeBombRelease.get() < 3.0 ? [VECTOR_SECTOR, 0, 0, 30, 30, -130, -50] : [])
  ] : []
}

function buccaneerAimMark(_width, _height) {
  return {
    size = flex()
    children = [
      @() {
        watch = IlsColor
        size = static [pw(20), ph(20)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * 1.5 * IlsLineScale.get()
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
      @() {
        watch = IlsColor
        size = static [pw(30), ph(30)]
        pos = [pw(50), ph(50)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * 1.5 * IlsLineScale.get()
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_LINE, -100, 0, -80, 0],
          [VECTOR_LINE, 100, 0, 80, 0]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = -Roll.get()
            pivot = [0, 0]
          }
        }
      },
      buccaneerCCRP,
      @() {
        watch = IlsColor
        size = ph(1.2)
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        fillColor = IlsColor.get()
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = TargetPosValid.get() ? [TargetPos.get()[0], TargetPos.get()[1]] : [-10, -10]
          }
        }
      }
    ]
  }
}

function buccaneerHUD(width, height) {
  return {
    size = [width, height]
    children = [
      buccaneerAimMark(width, height),
      buccaneerSpeed
    ]
  }
}

return buccaneerHUD