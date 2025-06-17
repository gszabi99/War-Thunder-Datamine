from "%rGui/globals/ui_library.nut" import *

let { IlsColor, TargetPosValid, TargetPos, IlsLineScale, TimeBeforeBombRelease,
       BombingMode, RadarTargetDist } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth } = require("ilsConstants.nut")
let { cos, sin, PI, acos, asin } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { Roll } = require("%rGui/planeState/planeFlyState.nut")
let { DistanceMax, AamLaunchZoneDistMin, AamLaunchZoneDistMax, AamLaunchZoneDist, Azimuth, Elevation }= require("%rGui/radarState.nut")
let { GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { AVQ7CCRP } = require("ilsAVQ7.nut")

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
  size = const [pw(20), ph(20)]
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
  size = const [pw(17), ph(17)]
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

let ccrpVisible = Computed(@() BombingMode.value && TimeBeforeBombRelease.get() > 0.0)
function LCOSS(width, height, hasCCRP) {
  return @() {
    watch = ccrpVisible
    size = [width, height]
    children = [
      LCOSSCrosshair,
      LCOSSRollMark,
      LCOSSRadarRange,
      (hasCCRP && ccrpVisible.get() ? AVQ7CCRP(width, height) : null)
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.get() ? (BombingMode.get() ? [0, 0] : [TargetPos.get()[0] - width * 0.5, TargetPos.get()[1] - height * 0.5]) : [0, 0]
      }
    }
  }
}

let ASG23MainReticle = @(){
  watch = IlsColor
  size = ph(20)
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value * 1.5
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 60, 60],
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
    [VECTOR_LINE, 52, 0, 75, 0],
    [VECTOR_LINE, -52, 0, -75, 0],
    [VECTOR_LINE, 0, -52, 0, -60],
    [VECTOR_LINE, 0, -100, 0, -120],
    [VECTOR_LINE, -100, 0, -120, 0],
    [VECTOR_LINE, -86.6, 50, -104, 60],
    [VECTOR_LINE, -50, 86.6, -60, 104],
    [VECTOR_LINE, -38.27, 92.39, -42.1, 101.63],
    [VECTOR_LINE, -26, 96.6, -31, 115.9],
    [VECTOR_LINE, -13, 99.14, -14.36, 109.06],
    [VECTOR_LINE, 0, 100, 0, 120],
    [VECTOR_LINE, 13, 99.14, 14.36, 109.06],
    [VECTOR_LINE, 26, 96.6, 31, 115.9],
    [VECTOR_LINE, 38.27, 92.39, 42.1, 101.63],
    [VECTOR_LINE, 50, 86.6, 60, 104],
    [VECTOR_LINE, 86.6, 50, 104, 60],
    [VECTOR_LINE, 100, 0, 120, 0],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value * 3.0],
    [VECTOR_LINE, 0, 0, 0, 0]
  ]
  children = [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_POLY, -4, -75, 0, -79, 4, -75],
        [VECTOR_POLY, -71, 0, -75, -4, -79, 0],
        [VECTOR_POLY, 71, 0, 75, -4, 79, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = -Roll.value
          pivot = [0, 0]
        }
      }
    }
  ]
}

let ASGRightScale = @() {
  watch = IlsColor
  size = const [pw(4), ph(32)]
  pos = [pw(25), ph(-16)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value * 1.5
  commands = [
    [VECTOR_LINE, 0, 0, 0, 47],
    [VECTOR_LINE, 0, 53, 0, 100],
    [VECTOR_LINE, 20, 50, 100, 50],
    [VECTOR_LINE, 0, 12.5, 90, 14],
    [VECTOR_LINE, 0, 25, 90, 26.5],
    [VECTOR_LINE, 0, 37.5, 90, 39],
    [VECTOR_LINE, 0, 62.5, 90, 61],
    [VECTOR_LINE, 0, 75, 90, 73.5],
    [VECTOR_LINE, 0, 87.5, 90, 86]
  ]
}

let ASGLeftScale = @() {
  watch = IlsColor
  size = const [pw(4), ph(32)]
  pos = [pw(-29), ph(-16)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value * 1.5
  commands = [
    [VECTOR_LINE, 100, 0, 100, 100],
    [VECTOR_LINE, 20, 50, 100, 50],
    [VECTOR_LINE, 100, 10, 0, 11.5],
    [VECTOR_LINE, 100, 20, 50, 21],
    [VECTOR_LINE, 100, 30, 0, 31.5],
    [VECTOR_LINE, 100, 40, 50, 41],
    [VECTOR_LINE, 100, 60, 50, 59],
    [VECTOR_LINE, 100, 70, 0, 68.5],
    [VECTOR_LINE, 100, 80, 50, 79],
    [VECTOR_LINE, 100, 90, 0, 88.5]
  ]
}

let RadarTargetValid = Computed(@() RadarTargetDist.value > 0.0)
let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let DistMarkAngle = Computed(@() 180 - (BombingMode.value && TimeBeforeBombRelease.value > 0.0 ? cvt(TimeBeforeBombRelease.value, 0, 30, 0, 270) : (DistanceMax.value <= 0.0 ? 0 :
 (isAAMMode.value && AamLaunchZoneDistMax.value > 0.0 ? cvt(AamLaunchZoneDist.value, AamLaunchZoneDistMin.value, 2.0 * AamLaunchZoneDistMax.value, 0, 270).tointeger() : (RadarTargetDist.value / (DistanceMax.value * 1000.0) * 270.0).tointeger()))))
let ASG23Distance = @() {
  watch = [RadarTargetValid, BombingMode]
  size = flex()
  children = RadarTargetValid.value || BombingMode.value ? [
    @() {
      watch = [IlsColor, DistMarkAngle]
      rendObj = ROBJ_VECTOR_CANVAS
      size = ph(18.7)
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value * 3
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, DistMarkAngle.value, 180],
        [VECTOR_LINE, 102 * cos(PI * DistMarkAngle.value / 180), 102 * sin(PI * DistMarkAngle.value / 180), 90 * cos(PI * DistMarkAngle.value / 180), 90 * sin(PI * DistMarkAngle.value / 180)]
      ]
    }
  ] : null
}

let CourseYawPos = Computed(@() (-100.0 + Azimuth.value * 200.0).tointeger())
let CoursePitchPos = Computed(@() (-100.0 + Elevation.value * 200.0).tointeger())
let ASG23Course = @() {
  watch = RadarTargetValid
  size = flex()
  children = RadarTargetValid.value ? [
    @(){
      watch = CourseYawPos
      size = ph(19)
      rendObj = ROBJ_VECTOR_CANVAS
      color = Color(80, 255, 10)
      lineWidth = baseLineWidth * IlsLineScale.value * 1.5
      commands = [
        [VECTOR_LINE_DASHED, CourseYawPos.value, 100 * sin(acos(CourseYawPos.value * 0.01)), CourseYawPos.value, -100 * sin(acos(CourseYawPos.value * 0.01)), 10, 25]
      ]
    }
    @(){
      watch = CoursePitchPos
      size = ph(19)
      rendObj = ROBJ_VECTOR_CANVAS
      color = Color(80, 255, 10)
      lineWidth = baseLineWidth * IlsLineScale.value * 1.5
      commands = [
        [VECTOR_LINE_DASHED, 100 * cos(asin(CoursePitchPos.value * 0.01)), CoursePitchPos.value, -100 * cos(asin(CoursePitchPos.value * 0.01)), CoursePitchPos.value, 10, 25]
      ]
    }
  ] : null
}

function ASG23(width, height) {
  return @() {
    size = [width, height]
    children = [
      ASG23MainReticle
      ASGRightScale
      ASGLeftScale
      ASG23Distance
      ASG23Course
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.value ? (BombingMode.value ? [0.5 * width, 0.5 * height] : TargetPos.value) : [0.5 * width, 0.5 * height]
      }
    }
  }
}

return {
  LCOSS
  ASG23
}