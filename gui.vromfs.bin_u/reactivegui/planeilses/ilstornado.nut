from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { Aoa, ClimbSpeed, Altitude, Speed, Tangage, Roll, CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { baseLineWidth, mpsToFpm, metrToFeet, mpsToKnots, metrToNavMile } = require("%rGui/planeIlses/ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { IlsColor, IlsLineScale, TargetPos, RocketMode, CannonMode, BombCCIPMode, BombingMode,
  TargetPosValid, DistToTarget, RadarTargetDist, TimeBeforeBombRelease, TvvMark, RadarTargetDistRate,
  RadarTargetPosValid, RadarTargetPos, AirCannonMode } = require("%rGui/planeState/planeToolsState.nut")
let { cvt } = require("dagor.math")
let string = require("string")
let { SUMAltitude } = require("%rGui/planeIlses/commonElements.nut")
let { AdlPoint, CurWeaponName, ShellCnt, BulletImpactPoints, BulletImpactLineEnable } = require("%rGui/planeState/planeWeaponState.nut")
let { sin, cos, round } = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { AamLaunchZoneDistMax, AamLaunchZoneDistMin, AamLaunchZoneDist, AamLaunchZoneDistDgftMax,
 AamLaunchZoneDistDgftMin, IsAamLaunchZoneVisible, LockZoneIlsWatched, IsLockZoneIlsVisible,
 IsRadarEmitting } = require("%rGui/radarState.nut")

let SUMAoaMarkH = Computed(@() cvt(Aoa.get(), 0, 25, 100, 0).tointeger())
let SUMAoa = @() {
  watch = [SUMAoaMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = static [pw(3), ph(30)]
  pos = [pw(15), ph(30)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * 2 * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -60, 20, -60, 20],
    [VECTOR_LINE, 0, 20, 0, 20],
    [VECTOR_LINE, 0, 40, 0, 40],
    [VECTOR_LINE, -60, 60, -60, 60],
    [VECTOR_LINE, 0, 60, 0, 60],
    [VECTOR_LINE, 0, 80, 0, 80],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get()],
    [VECTOR_LINE, 5, SUMAoaMarkH.get(), 100, SUMAoaMarkH.get() - 5],
    [VECTOR_LINE, 5, SUMAoaMarkH.get(), 100, SUMAoaMarkH.get() + 5],
    (SUMAoaMarkH.get() < 96 ? [VECTOR_LINE, 80, 100, 80, SUMAoaMarkH.get() + (Aoa.get() > 0 ? 4 : -4)] : []),
    [VECTOR_LINE, 0, 100, 80, 100],
  ]
}

let SUMVSMarkH = Computed(@() cvt(ClimbSpeed.get() * mpsToFpm, 2000, -3000, -33, 133).tointeger())
let SUMVerticalSpeed = @() {
  watch = [SUMVSMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = static [pw(3), ph(40)]
  pos = [pw(85), ph(30)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * 2 * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 0, 0, 0, 0],
    [VECTOR_LINE, -60, 0, -60, 0],
    [VECTOR_LINE, 0, 16, 0, 16],
    [VECTOR_LINE, 0, 34, 0, 34],
    [VECTOR_LINE, 0, 52, 0, 52],
    [VECTOR_LINE, 0, 68, 0, 68],
    [VECTOR_LINE, -60, 68, -60, 68],
    [VECTOR_LINE, 0, 84, 0, 84],
    [VECTOR_LINE, 0, 100, 0, 100],
    [VECTOR_LINE, -60, 100, -60, 100],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.get()],
    [VECTOR_LINE, 0, 34, 100, 34],
    [VECTOR_LINE, 5, SUMVSMarkH.get(), 100, SUMVSMarkH.get() - 5],
    [VECTOR_LINE, 5, SUMVSMarkH.get(), 100, SUMVSMarkH.get() + 5],
    (SUMVSMarkH.get() < 30 || SUMVSMarkH.get() > 38 ? [VECTOR_LINE, 80, 34, 80, SUMVSMarkH.get() + (ClimbSpeed.get() > 0.0 ? 4 : -4)] : [])
  ]
}

let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())

let SpeedWatch = Computed(@() round(Speed.get() * mpsToKnots).tointeger())
let speed = @() {
  watch = [Speed, IlsColor]
  rendObj = ROBJ_TEXT
  size = SIZE_TO_CONTENT
  pos = [pw(25), ph(25)]
  color = IlsColor.get()
  fontSize = 40
  font = Fonts.hud
  text = SpeedWatch.get().tostring()
}

let mainReticle = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = static [pw(2), ph(2)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, -100, 0, -40, 0],
    [VECTOR_LINE, 0, -100, 0, -40],
    [VECTOR_LINE, 100, 0, 40, 0],
    [VECTOR_LINE, 0, 100, 0, 40]
  ]
}

let CcipReticleSector = Computed(@() cvt(DistToTarget.get(), 0.0, 4000.0, -90.0, 269.0).tointeger())
let adlMarker = @() {
  watch = [BombingMode, TargetPosValid]
  size = flex()
  children = TargetPosValid.get() ? [
    mainReticle,
    (CCIPMode.get() ? @() {
      watch = [CcipReticleSector, IlsColor]
      size = pw(5)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_SECTOR, 0, 0, 95, 95, -90, CcipReticleSector.get()],
        [VECTOR_LINE, 0, -95, 0, -115],
        [VECTOR_LINE, 95 * cos(degToRad(CcipReticleSector.get())), 95 * sin(degToRad(CcipReticleSector.get())),
         115 * cos(degToRad(CcipReticleSector.get())), 115 * sin(degToRad(CcipReticleSector.get()))]
      ]
    } : null)
  ] : null
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = CCIPMode.get() || BombingMode.get() ? TargetPos.get() : [AdlPoint[0], AdlPoint[1]]
    }
  }
}

function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = i * step

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.5, height * 0.5]
    pos = [width * 0.2, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * 0.06]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.12]
      }
    }
  }
}

function angleTxt(num, isLeft, invVPlace = 1, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.get()
    fontSize = 35
    font = Fonts.hud
    text = string.format("%d", num)
  }
}

function generatePitchLine(num) {
  let newNum = num <= 0 ? num : (num - 5)
  return {
    size = static [pw(80), ph(60)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, -10, 0, 25, 0],
          [VECTOR_LINE, 75, 0, 110, 0]
        ]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = static [10, 0]
        commands = [
          [VECTOR_LINE, 21, 4, 21, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 21 : 3, 0],
          (num < 0 ? [VECTOR_LINE, 6, 0, 9, 0] : []),
          (num < 0 ? [VECTOR_LINE, 12, 0, 15, 0] : []),
          (num < 0 ? [VECTOR_LINE, 18, 0, 21, 0] : []),
          [VECTOR_LINE, 79, 4, 79, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 79 : 97, 0],
          (num < 0 ? [VECTOR_LINE, 94, 0, 91, 0] : []),
          (num < 0 ? [VECTOR_LINE, 88, 0, 85, 0] : []),
          (num < 0 ? [VECTOR_LINE, 82, 0, 79, 0] : [])
        ]
        children = newNum <= 90 && newNum != 0 ? [angleTxt(newNum, false, -1, 0)] : null
      }
    ]
  }
}

let ReticleSector = Computed(@() cvt(RadarTargetDist.get(), 0.0, 4000.0, -90.0, 269.0).tointeger())
let TargetByRadar = Computed(@() RadarTargetDist.get() >= 0.0)
let gunReticle = @() {
  watch = [TargetByRadar, CCIPMode, BombingMode]
  size = flex()
  children = CCIPMode.get() || BombingMode.get() ? null : (TargetByRadar.get() ? [
    @() {
      watch = [ReticleSector, IlsColor]
      size = pw(5)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_SECTOR, 0, 0, 95, 95, -90, ReticleSector.get()],
        [VECTOR_LINE, -80, 0, -20, 0],
        [VECTOR_LINE, 80, 0, 20, 0],
        [VECTOR_LINE, 0, 80, 0, 20],
        [VECTOR_LINE, 0, -80, 0, -20],
        [VECTOR_LINE, 0, -115, 0, -95]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = TargetPos.get()
        }
      }
    }
  ] : [
    @() {
      watch = IlsColor
      size = pw(5)
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 35, 35],
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_LINE, -100, 0, -35, 0],
        [VECTOR_LINE, 100, 0, 35, 0],
        [VECTOR_LINE, 0, -100, 0, -35],
        [VECTOR_LINE, 0, 100, 0, 35]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = TargetPos.get()
        }
      }
    }
  ])
}

let AltThousandAngle = Computed(@() (Altitude.get() * metrToFeet % 1000 / 2.7777 - 90.0).tointeger())
let altCircle = @(){
  watch = IlsColor
  size = pw(16)
  pos = [pw(58.5), ph(18.5)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.get() * 2
  commands = [
    [VECTOR_LINE, 50, 0, 50, 0],
    [VECTOR_LINE, 50, 100, 50, 100],
    [VECTOR_LINE, 20.6, 9.5, 20.6, 9.5],
    [VECTOR_LINE, 2.4, 34.5, 2.4, 34.5],
    [VECTOR_LINE, 2.4, 65.5, 2.4, 65.5],
    [VECTOR_LINE, 20.6, 90.5, 20.6, 90.5],
    [VECTOR_LINE, 80.6, 90.5, 80.6, 90.5],
    [VECTOR_LINE, 97.6, 65.5, 97.6, 65.5],
    [VECTOR_LINE, 97.6, 34.5, 97.6, 34.5],
    [VECTOR_LINE, 80.6, 9.5, 80.6, 9.5]
  ]
  children = @() {
    watch = [AltThousandAngle, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = static [pw(50), ph(50)]
    pos = [pw(50), ph(50)]
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get() * 1.5
    commands = [
      [VECTOR_LINE, 80 * cos(degToRad(AltThousandAngle.get())), 80 * sin(degToRad(AltThousandAngle.get())),
        50 * cos(degToRad(AltThousandAngle.get())), 50 * sin(degToRad(AltThousandAngle.get()))]
    ]
  }
}

let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let ReticleSectorAam = Computed(@() cvt(RadarTargetDist.get(), 0.0, 10000.0, -90.0, 269.0).tointeger())
let aamReticle = @() {
  watch = [isAAMMode, IlsTrackerVisible]
  size = static [pw(8), ph(8)]
  children = isAAMMode.get() && IlsTrackerVisible.get() ? [
    @() {
      watch = [TargetByRadar, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, -70, 0, 0, -70],
        [VECTOR_LINE, 0, -70, 70, 0],
        [VECTOR_LINE, 70, 0, 0, 70],
        [VECTOR_LINE, 0, 70, -70, 0],
        [VECTOR_LINE, -30, 0, TargetByRadar.get() ? -100 : -70, 0],
        [VECTOR_LINE, 30, 0, TargetByRadar.get() ? 100 : 70, 0],
        [VECTOR_LINE, 0, -30, 0, TargetByRadar.get() ? -100 : -70],
        [VECTOR_LINE, 0, 30, 0, TargetByRadar.get() ? 100 : 70]
      ]
      children = TargetByRadar.get() ? [
        @() {
          watch = ReticleSectorAam
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.get()
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.get()
          commands = [
            [VECTOR_SECTOR, 0, 0, 100, 100, -90, ReticleSectorAam.get()],
            [VECTOR_LINE, 0, -100, 0, -120],
            [VECTOR_LINE, 100 * cos(degToRad(ReticleSectorAam.get())), 100 * sin(degToRad(ReticleSectorAam.get())),
            120 * cos(degToRad(ReticleSectorAam.get())), 120 * sin(degToRad(ReticleSectorAam.get()))]
          ]
        }
      ] : null
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.get(), IlsTrackerY.get()]
        }
      }
    }
  ] : null
}

let ccrpTimeAngle = Computed(@() cvt(TimeBeforeBombRelease.get(), 0.0, 60.0, -90.0, 269.0).tointeger())
let ccrp = @() {
  watch = BombingMode
  size = flex()
  children = BombingMode.get() ? [
    @() {
      watch = IlsColor
      rendObj = ROBJ_VECTOR_CANVAS
      size = static [pw(5), ph(5)]
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 30, 30],
        [VECTOR_LINE, -100, 0, -30, 0],
        [VECTOR_LINE, 30, 0, 100, 0]
      ]
    },
    @() {
      watch = IlsColor
      rendObj = ROBJ_SOLID
      size = [baseLineWidth * IlsLineScale.get(), ph(100)]
      color = IlsColor.get()
      pos = [-baseLineWidth * IlsLineScale.get() * 0.5, 0]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = -Roll.get()
          pivot = [0, 0]
        }
      }
    },
    @() {
      watch = [ccrpTimeAngle, IlsColor]
      size = static [pw(7), ph(7)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, -90, ccrpTimeAngle.get()],
        [VECTOR_LINE, 0, -100, 0, -120],
        [VECTOR_LINE, 100 * cos(degToRad(ccrpTimeAngle.get())), 100 * sin(degToRad(ccrpTimeAngle.get())),
          120 * cos(degToRad(ccrpTimeAngle.get())), 120 * sin(degToRad(ccrpTimeAngle.get()))]
      ]
    }
  ] : null
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [TvvMark[0], TvvMark[1]]
    }
  }
}

let IsLaunchZoneVisible = Computed(@() IsAamLaunchZoneVisible.get() && !BombingMode.get())
let currentMax = Computed(@() max(0.01, max(AamLaunchZoneDistMax.get(), AamLaunchZoneDist.get())))
let currentLaunchDistLen = Computed(@() (AamLaunchZoneDist.get() / currentMax.get() * 100.0).tointeger())
let minLaunchZonePos = Computed(@() (AamLaunchZoneDistMin.get() / currentMax.get() * 100.0).tointeger())
let maxLaunchZonePos = Computed(@() (AamLaunchZoneDistMax.get() / currentMax.get() * 20.0).tointeger())
let IsDgftZoneVisible = Computed(@() AamLaunchZoneDistDgftMax.get() > 0.0)
let maxLaunchDgftZonePos = Computed(@() (AamLaunchZoneDistDgftMax.get() / currentMax.get() * 20.0).tointeger())
let minLaunchDgftZonePos = Computed(@() (AamLaunchZoneDistDgftMin.get() / currentMax.get() * 20.0).tointeger())
let curTargetDist = Computed(@() (RadarTargetDist.get() * metrToNavMile * 10.0).tointeger())
let aamLaunchZone = @(){
  watch = IsLaunchZoneVisible
  size = flex()
  pos = [0, ph(40)]
  children = IsLaunchZoneVisible.get() ? [
    @(){
      watch = [currentLaunchDistLen, IlsColor]
      pos = [pw(70), 0]
      size = static [pw(2), ph(20)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, 100, 100, 100, 100 - currentLaunchDistLen.get() + 4],
        [VECTOR_LINE, 0, 100, 100, 100],
        [VECTOR_LINE, 0, 100 - currentLaunchDistLen.get(), 100, 100 - currentLaunchDistLen.get() - 4],
        [VECTOR_LINE, 0, 100 - currentLaunchDistLen.get(), 100, 100 - currentLaunchDistLen.get() + 4]
      ]
    }
    @(){
      watch = [minLaunchZonePos, IlsColor]
      pos = [pw(67), 0]
      size = static [pw(2), ph(20)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = [
        [VECTOR_LINE, 50, 0, 50, 100 - minLaunchZonePos.get()],
        [VECTOR_LINE, 0, 100 - minLaunchZonePos.get(), 100, 100 - minLaunchZonePos.get()],
      ]
    }
    @(){
      watch = [maxLaunchZonePos, IlsColor]
      size = [pw(1.5), baseLineWidth * IlsLineScale.get()]
      pos = [pw(68), ph(20 - maxLaunchZonePos.get())]
      rendObj = ROBJ_SOLID
      color = IlsColor.get()
    }
    @(){
      watch = IsDgftZoneVisible
      size = flex()
      children = IsDgftZoneVisible.get() ? [
        @(){
          watch = [maxLaunchDgftZonePos, IlsColor]
          size = [pw(1.5), baseLineWidth * IlsLineScale.get()]
          pos = [pw(66.5), ph(20 - maxLaunchDgftZonePos.get())]
          rendObj = ROBJ_SOLID
          color = IlsColor.get()
        }
        @(){
          watch = [minLaunchDgftZonePos, IlsColor]
          size = [pw(1.5), baseLineWidth * IlsLineScale.get()]
          pos = [pw(66.5), ph(20 - minLaunchDgftZonePos.get())]
          rendObj = ROBJ_SOLID
          color = IlsColor.get()
        }
      ] : null
    }
    @(){
      watch = [curTargetDist, currentLaunchDistLen, IlsColor]
      size = SIZE_TO_CONTENT
      pos = [pw(72.5), ph(19 - currentLaunchDistLen.get() * 0.2)]
      rendObj = ROBJ_TEXT
      color = Color(255, 0, 0)
      font = Fonts.hud
      fontSize = 30
      text = string.format("%.1f", curTargetDist.get() * 0.1)
    }
  ] : null
}

let curWeapon = @(){
  watch = [CurWeaponName, IlsColor, ShellCnt, isAAMMode]
  pos = [pw(72), ph(80)]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 30
  text = CurWeaponName.get() && CurWeaponName.get() != "" && isAAMMode.get() ? string.format("%d%s", ShellCnt.get(), loc_checked($"{CurWeaponName.get()}/tornado")) : "G"
}

let generateCompassMark = function(num, width) {
  return {
    size = [width * 0.15, ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @(){
        watch = IlsColor
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 30
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @(){
        watch = IlsColor
        size = [baseLineWidth, baseLineWidth]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * 1.5
        hplace = ALIGN_CENTER
        commands = [
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
      }
    ]
  }
}

function compass(width, generateFunc) {
  let children = []
  let step = 5.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, width))
  }
  let getOffset = @() (360.0 + CompassValue.get()) * 0.03 * width
  return {
    size = flex()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + 0.425 * width, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.3, height]
    pos = [width * 0.35, height * 0.15]
    clipChildren = true
    children = [
      compass(width * 0.3, generateFunc)
      @(){
        watch = IlsColor
        rendObj = ROBJ_SOLID
        size = [baseLineWidth, height * 0.03]
        color = IlsColor.get()
        pos = [width * 0.15 - baseLineWidth * 0.5, ph(4)]
      }
    ]
  }
}

let relVelMarkPos = Computed(@() cvt(-RadarTargetDistRate.get() * mpsToKnots, -20, 100, 0, 100).tointeger())
let targetRelVelScale = @(){
  watch = TargetByRadar
  size = flex()
  children = TargetByRadar.get() ? @(){
    watch = IlsColor
    rendObj = ROBJ_VECTOR_CANVAS
    size = static [pw(50), ph(3)]
    pos = [pw(25), ph(84)]
    color = IlsColor.get()
    lineWidth = baseLineWidth * 2.0
    commands = [
      [VECTOR_LINE, 0, 100, 0, 100],
      [VECTOR_LINE, 16.7, 100, 16.7, 100],
      [VECTOR_LINE, 33.3, 100, 33.3, 100],
      [VECTOR_LINE, 50, 100, 50, 100],
      [VECTOR_LINE, 66.7, 100, 66.7, 100],
      [VECTOR_LINE, 83.3, 100, 83.3, 100],
      [VECTOR_LINE, 100, 100, 100, 100]
    ]
    children = [
      @(){
        watch = [relVelMarkPos, IlsColor]
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.get()
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_LINE, 16.7, 100, 16.7, 20],
          (relVelMarkPos.get() > 18 ? [VECTOR_LINE, 16.7, 20, relVelMarkPos.get() - 2, 20] : []),
          (relVelMarkPos.get() < 15 ? [VECTOR_LINE, 16.7, 20, relVelMarkPos.get() + 2, 20] : []),
          [VECTOR_LINE, relVelMarkPos.get(), 100, relVelMarkPos.get() - 2, 0],
          [VECTOR_LINE, relVelMarkPos.get(), 100, relVelMarkPos.get() + 2, 0]
        ]
      }
      {
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        pos = [pw(-5), ph(150)]
        color = IlsColor.get()
        font = Fonts.hud
        fontSize = 30
        text = "-20"
      }
      {
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        pos = [pw(47), ph(150)]
        color = IlsColor.get()
        font = Fonts.hud
        fontSize = 30
        text = "40"
      }
      {
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        pos = [pw(80), ph(150)]
        color = IlsColor.get()
        font = Fonts.hud
        fontSize = 30
        text = "80"
      }
    ]
  } : null
}

function radarTarget(width, height) {
  return @(){
    watch = [RadarTargetPosValid, isAAMMode, IlsColor]
    size = flex()
    children = RadarTargetPosValid.get() && !isAAMMode.get() ? {
      rendObj = ROBJ_VECTOR_CANVAS
      size = static [pw(3), ph(3)]
      color = IlsColor.get()
      lineWidth = baseLineWidth
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
      children = {
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        pos = [pw(120), -15]
        color = IlsColor.get()
        font = Fonts.hud
        fontSize = 30
        text = "L"
      }
      animations = [
        { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "radar_lock_limit" }
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        local target = RadarTargetPos
        let leftBorder = width * 0.08
        let rightBorder = width * 0.9
        let topBorder = height * 0.04
        let bottomBorder = height * 0.95
        if (target[0] < leftBorder || target[0] > rightBorder || target[1] < topBorder || target[1] > bottomBorder)
          anim_start("radar_lock_limit")
        else
          anim_request_stop("radar_lock_limit")
        target = [clamp(target[0], leftBorder, rightBorder), clamp(target[1], topBorder, bottomBorder)]
        return {
          transform = {
            translate = target
          }
        }
      }
    } : null
  }
}

function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints.get().len() - 2; ++i) {
    let point = BulletImpactPoints.get()[i]
    if (point.x == -1 && point.y == -1)
      continue
    commands.append([VECTOR_LINE, point.x, point.y, point.x, point.y])
  }
  return commands
}

let ccil = @(){
  watch = [AirCannonMode, BulletImpactLineEnable]
  size = flex()
  children = AirCannonMode.get() && BulletImpactLineEnable.get() ? @(){
    watch = [BulletImpactPoints, IlsColor]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get() * 2.0
    commands = getBulletImpactLineCommand()
  } : null
}

let lockZone = @(width, height) function() {
  if (!IsLockZoneIlsVisible.get())
    return { watch = [IsLockZoneIlsVisible, LockZoneIlsWatched] }

  let mw = 100 / width
  let mh = 100 / height
  let corner = IsRadarEmitting.get() ? 0.1 : 0.02

  let { x0, x1, x2, x3, y0, y1, y2, y3 } = LockZoneIlsWatched.get()
  let _x0 = (x0 + x1 + x2 + x3) * 0.25
  let _y0 = (y0 + y1 + y2 + y3) * 0.25

  let px0 = (x0 - _x0) * mw
  let py0 = (y0 - _y0) * mh
  let px1 = (x1 - _x0) * mw
  let py1 = (y1 - _y0) * mh
  let px2 = (x2 - _x0) * mw
  let py2 = (y2 - _y0) * mh
  let px3 = (x3 - _x0) * mw
  let py3 = (y3 - _y0) * mh

  let commands = [
    [ VECTOR_LINE, px0, py0, px0 + (px1 - px0) * corner, py0 + (py1 - py0) * corner ],
    [ VECTOR_LINE, px0, py0, px0 + (px3 - px0) * corner, py0 + (py3 - py0) * corner ],

    [ VECTOR_LINE, px1, py1, px1 + (px2 - px1) * corner, py1 + (py2 - py1) * corner ],
    [ VECTOR_LINE, px1, py1, px1 + (px0 - px1) * corner, py1 + (py0 - py1) * corner ],

    [ VECTOR_LINE, px2, py2, px2 + (px3 - px2) * corner, py2 + (py3 - py2) * corner ],
    [ VECTOR_LINE, px2, py2, px2 + (px1 - px2) * corner, py2 + (py1 - py2) * corner ],

    [ VECTOR_LINE, px3, py3, px3 + (px0 - px3) * corner, py3 + (py0 - py3) * corner ],
    [ VECTOR_LINE, px3, py3, px3 + (px2 - px3) * corner, py3 + (py2 - py3) * corner ]
  ]

  return {
    watch = [IsLockZoneIlsVisible, LockZoneIlsWatched, IlsColor, IlsLineScale]
    pos = [_x0, _y0 ]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    size = flex()
    commands
  }
}

function IlsTornado(width, height) {
  return {
    size = [width, height]
    children = [
      SUMAoa,
      SUMVerticalSpeed,
      SUMAltitude(40),
      speed,
      adlMarker,
      pitch(width, height, generatePitchLine),
      gunReticle,
      altCircle,
      aamReticle,
      ccrp,
      aamLaunchZone,
      compassWrap(width, height, generateCompassMark),
      curWeapon,
      targetRelVelScale,
      radarTarget(width, height),
      ccil,
      lockZone(width, height)
    ]
  }
}

return IlsTornado