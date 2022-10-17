let {IlsColor, TargetPosValid, TargetPos, IlsLineScale, DistToTarget, AimLockPos, AimLockValid} = require("%rGui/planeState/planeToolsState.nut")
let {baseLineWidth} = require("ilsConstants.nut")
let {cvt} = require("dagor.math")
let {Roll} = require("%rGui/planeState/planeFlyState.nut");

let ASP17crosshair = @() {
  watch = IlsColor
  size = [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -10, 0, -60, 0],
    [VECTOR_LINE, 0, -10, 0, -60],
    [VECTOR_LINE, 10, 0, 60, 0],
    [VECTOR_LINE, 0, 10, 0, 60],
  ]
}

let ASP17Roll = @() {
  watch = IlsColor
  size = [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  fillColor = IlsColor.value
  behavior = Behaviors.RtPropUpdate
  commands = [
    [VECTOR_POLY, -2, -70, 0, -77, 2, -70]
  ]
  update = @() {
    transform = {
      rotate = clamp(Roll.value, -30, 30).tointeger()
      pivot = [0, 0]
    }
  }
}

let DistToTargetWatch = Computed(@() cvt(DistToTarget.value, 450, 3000, -90, 15).tointeger())
let ASP17Distances = @() {
  watch = [IlsColor, DistToTargetWatch]
  size = [pw(20), ph(20)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_SECTOR, 0, 0, 93, 93, -80, max(-80, min(DistToTargetWatch.value, -3))],
    [VECTOR_SECTOR, 0, 0, 90, 90, -90, DistToTargetWatch.value],
    [VECTOR_WIDTH, baseLineWidth * 1.5 * IlsLineScale.value],
    [VECTOR_LINE, 0, -90, 0, -82], //0
    (DistToTargetWatch.value > -30 ? [VECTOR_LINE, 78, -45, 71, -41] : []),  //60
    (DistToTargetWatch.value > -60 ? [VECTOR_LINE, 45, -78, 41, -71] : []), //30
    (DistToTargetWatch.value > 0 ? [VECTOR_LINE, 82, 0, 90, 0] : []), //90
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
    (DistToTargetWatch.value >= 15 ? [VECTOR_LINE, 82.1, 22, 86.9, 23.3] : []),  //105
    (DistToTargetWatch.value > -15 ? [VECTOR_LINE, 82.1, -22, 86.9, -23.3] : []),  //75
    (DistToTargetWatch.value > -37.5 ? [VECTOR_LINE, 67.4, -51.7, 71.4, -54.8] : []),  //52,5
    (DistToTargetWatch.value > -45 ? [VECTOR_LINE, 60.1, -60.1, 63.6, -63.6] : []),  //45
    (DistToTargetWatch.value > -52.5 ? [VECTOR_LINE, 51.7, -67.4, 54.8, -71.4] : []),  //37.5
    (DistToTargetWatch.value > -67.5 ? [VECTOR_LINE, 32.5, -78.5, 34.4, -83.2] : []),  //22.5
    (DistToTargetWatch.value > -75 ? [VECTOR_LINE, 22, -82.1, 23.3, -86.9] : []),  //15
    (DistToTargetWatch.value > -82.5 ? [VECTOR_LINE, 11, -84.3, 11.7, -89.2] : [])  //7.5
  ]
}

let function ASP17(width, height) {
  return {
    size = [width, height]
    children = [
      ASP17Distances,
      ASP17crosshair,
      ASP17Roll
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.value ? [TargetPos.value[0] - width * 0.5, TargetPos.value[1] - height * 0.5] :
         (AimLockValid.value ? [AimLockPos[0] - width * 0.5, AimLockPos[1] - height * 0.5] : [0, 0])
      }
    }
  }
}

return ASP17