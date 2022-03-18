let {IlsColor, TargetPosValid, TargetPos, IlsLineScale, TimeBeforeBombRelease,
       BombingMode, RadarTargetDist} = require("%rGui/planeState/planeToolsState.nut")
let {baseLineWidth} = require("ilsConstants.nut")
let {cos, sin, PI} = require("%sqstd/math.nut")
let {cvt} = require("dagor.math")
let {Roll} = require("%rGui/planeState/planeFlyState.nut")

let LCOSSRollMark = @() {
  watch = IlsColor
  size = flex()
  children = [
    {
      pos = [pw(46), pw(27)]
      size = [baseLineWidth * 4 * IlsLineScale.value, baseLineWidth * 4 * IlsLineScale.value]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(51), pw(27)]
      size = [baseLineWidth * 4 * IlsLineScale.value, baseLineWidth * 4 * IlsLineScale.value]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(26), pw(48.5)]
      size = [baseLineWidth * 4 * IlsLineScale.value, baseLineWidth * 4 * IlsLineScale.value]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    },
    {
      pos = [pw(71), pw(49)]
      size = [baseLineWidth * 4 * IlsLineScale.value, baseLineWidth * 4 * IlsLineScale.value]
      rendObj = ROBJ_SOLID
      color = IlsColor.value
    }
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      rotate = -Roll.value
    }
  }
}

let LCOSSCrosshair = @() {
  watch = IlsColor
  size = [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 90, 90],
    [VECTOR_SECTOR, 0, 0, 50, 50, -125, -55],
    [VECTOR_SECTOR, 0, 0, 50, 50, -35, 35],
    [VECTOR_SECTOR, 0, 0, 50, 50, 55, 125],
    [VECTOR_SECTOR, 0, 0, 50, 50, 145, 215],
    [VECTOR_WIDTH, baseLineWidth * 3 * IlsLineScale.value],
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, 92, 0, 97, 0],
    [VECTOR_LINE, -92, 0, -97, 0],
    [VECTOR_LINE, 0, -92, -0, -97]
  ]
}

let RadarDistAngle = Computed(@() PI * (BombingMode.value ? cvt(TimeBeforeBombRelease.value, 10.0, 0, -88, 90) :
  cvt(RadarTargetDist.value, 91.44, 1727.302, 90, -88)) / 180)
let LCOSSRadarRangeMark = @() {
  watch = [RadarDistAngle, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(17), ph(17)]
  pos = [pw(50), ph(50)]
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * 3 * IlsLineScale.value
  commands = [
    [VECTOR_SECTOR, 0, 0, 100, 100, RadarDistAngle.value * 180 / PI, 90],
    [VECTOR_LINE, 80 * cos(RadarDistAngle.value), 80 * sin(RadarDistAngle.value), 100 * cos(RadarDistAngle.value), 100 * sin(RadarDistAngle.value)]
  ]
}

let LCOSSRadarRangeVis =  Computed(@() RadarTargetDist.value > 0.0 || BombingMode.value)
let LCOSSRadarRange = @() {
  watch = LCOSSRadarRangeVis
  size = flex()
  children = LCOSSRadarRangeVis.value ? [LCOSSRadarRangeMark] : null
}

let function LCOSS(width, height) {
  return @() {
    watch = TargetPosValid
    size = [width, height]
    children = TargetPosValid.value ? [
      LCOSSCrosshair,
      LCOSSRollMark,
      LCOSSRadarRange
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = BombingMode.value ? [0, 0] : [TargetPos.value[0] - width * 0.5, TargetPos.value[1] - height * 0.5]
      }
    }
  }
}

return LCOSS