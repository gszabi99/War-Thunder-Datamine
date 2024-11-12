from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked

let string = require("string")
let { compassWrap, generateCompassMarkSU145 } = require("ilsCompasses.nut")
let { IlsColor, IlsLineScale, BombCCIPMode, RocketMode, BombingMode, TvvMark,
 CannonMode, TargetPosValid, TargetPos, IlsPosSize, TimeBeforeBombRelease } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet } = require("ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { lowerSolutionCue } = require("commonElements.nut")
let { floor, abs, sin, round, atan2, PI } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { degToRad } = require("%sqstd/math_ex.nut")
let { GuidanceLockState, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { Speed, BarAltitude, Mach, Aoa, Overload, Tangage, Roll, MaxOverload } = require("%rGui/planeState/planeFlyState.nut")
let { CurWeaponName, ShellCnt, GunBullets0, GunBullets1 } = require("%rGui/planeState/planeWeaponState.nut")
let { get_local_unixtime, unixtime_to_local_timetbl } = require("dagor.time")
let { rwrTargetsTriggers, rwrTargets } = require("%rGui/twsState.nut")
let { settings } = require("%rGui/planeRwrs/rwrAri23333Components.nut")

let SpeedValue = Computed(@() round(Speed.value * mpsToKnots).tointeger())
let speed = @() {
  watch = [IlsColor, SpeedValue]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(12), ph(40)]
  color = IlsColor.value
  fontSize = 60
  font = Fonts.hud
  text = SpeedValue.value.tointeger()
}

let HeiHundreds = Computed(@() (BarAltitude.value * metrToFeet / 1000).tointeger())
let HeiDozens = Computed(@() (BarAltitude.value * metrToFeet % 1000.0 / 10.0).tointeger())
let barAlt = {
  pos = [pw(75), ph(40)]
  size = [pw(10), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  children = [
    @() {
      watch = [HeiHundreds, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 60
      font = Fonts.hud
      text = HeiHundreds.value.tostring()
    },
    @() {
      watch = [HeiDozens, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 45
      font = Fonts.hud
      text = string.format("%02d0", HeiDozens.value)
    }
  ]
}

let MachValue = Computed(@() (floor(Mach.value * 100.0)).tointeger())
let mach = @() {
  watch = [MachValue, IlsColor]
  pos = [pw(8), ph(80)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 45
  font = Fonts.hud
  text = string.format("M %.2f", MachValue.value * 0.01)
}

let SUMAoaMarkH = Computed(@() cvt(Aoa.value, -5, 25, 100, 0).tointeger())
let SUMAoa = @() {
  watch = [SUMAoaMarkH, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(3), ph(35)]
  pos = [pw(15), ph(45)]
  color = IlsColor.value
  lineWidth = baseLineWidth * 3 * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 16.6, 0, 16.6],
    [VECTOR_LINE, 0, 33.3, 0, 33.3],
    [VECTOR_LINE, 0, 50, 0, 50],
    [VECTOR_LINE, 0, 66.6, 0, 66.6],
    [VECTOR_LINE, 0, 83.3, 0, 83.3],
    [VECTOR_WIDTH, baseLineWidth * IlsLineScale.value],
    [VECTOR_LINE, 5, SUMAoaMarkH.value, 100, SUMAoaMarkH.value - 5],
    [VECTOR_LINE, 5, SUMAoaMarkH.value, 100, SUMAoaMarkH.value + 5],
    (SUMAoaMarkH.value < 79.3 || SUMAoaMarkH.value > 87.3 ? [VECTOR_LINE, 80, 83.3, 80, SUMAoaMarkH.value + (Aoa.value > 0 ? 4 : -4)] : [])
  ]
}

let OverloadWatch = Computed(@() (floor(Overload.value * 10)).tointeger())
let overload = @() {
  watch = [OverloadWatch, IlsColor]
  size = flex()
  pos = [pw(8), ph(85)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 45
  font = Fonts.hud
  text = string.format("G %.1f", OverloadWatch.value / 10.0)
}

let MaxOverloadWatch = Computed(@() (floor(MaxOverload.value * 10)).tointeger())
let IsShowOverload = Computed(@() MaxOverloadWatch.value >= 45)
let maxOverload = @() {
  watch = [IsShowOverload]
  size = flex()
  children = IsShowOverload.value ? [
    @() {
      watch = [MaxOverloadWatch, IlsColor]
      size = flex()
      pos = [pw(8), ph(90)]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 45
      font = Fonts.hud
      text = string.format("MAX G %.1f", MaxOverloadWatch.value / 10.0)
    }
  ] : null
}

let localTime = @() {
  watch = BombingMode
  size = flex()
  children = !BombingMode.value ? [
    @() {
      watch = IlsColor
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(80), ph(90)]
      color = IlsColor.value
      fontSize = 45
      font = Fonts.hud
      text = "11:22:33"
      behavior = Behaviors.RtPropUpdate
      function update() {
        let time = unixtime_to_local_timetbl(get_local_unixtime())
        return {
          text = string.format("%02d:%02d:%02d", time.hour, time.min, time.sec)
        }
      }
    }
  ] : null
}

function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }

  return {
    size = [width * 0.6, height * 0.5]
    pos = [width * 0.2, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value) * 0.05]
        rotate = -Roll.value
        pivot = [0.5, (90.0 - Tangage.value) * 0.1]
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
    color = IlsColor.value
    fontSize = 45
    font = Fonts.hud
    text = abs(num).tostring()
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  let lineAngle = degToRad(min(20, newNum))
  return {
    size = [pw(60), ph(50)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        padding = [0, 10]
        commands = [
          [VECTOR_LINE, 30, 5, 30, 0],
          [VECTOR_LINE, -20, 0, 30, 0],
          [VECTOR_LINE, 70, 5, 70, 0],
          [VECTOR_LINE, 120, 0, 70, 0]
        ]
        children = [angleTxt(-5, true, 1, pw(-20)), angleTxt(-5, false, 1, pw(20))]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, 0, 10 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 30 : 5, sin(lineAngle) * (num > 0 ? 30 : 5)],
          (num < 0 ? [VECTOR_LINE, 10, sin(lineAngle) * 10, 17, sin(lineAngle) * 17] : []),
          (num < 0 ? [VECTOR_LINE, 23, sin(lineAngle) * 23, 30, sin(lineAngle) * 30] : []),
          [VECTOR_LINE, 100, 10 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 70 : 95, sin(lineAngle) * (num > 0 ? 30 : 5)],
          (num < 0 ? [VECTOR_LINE, 90, sin(lineAngle) * 10, 83, sin(lineAngle) * 17] : []),
          (num < 0 ? [VECTOR_LINE, 77, sin(lineAngle) * 23, 70, sin(lineAngle) * 30] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, 1, pw(-15)), angleTxt(newNum, false, 1, pw(15))] : null
      }
    ]
  }
}

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let GunMode = Computed(@() !BombCCIPMode.value && !RocketMode.value && !BombingMode.value && !isAAMMode.value && GunBullets0.value >= 0)
let HasGndReticle = Computed(@() (GunMode.value && GunBullets0.value > 0) || RocketMode.value || BombCCIPMode.value)
let groundReticle = @() {
  watch = [HasGndReticle, TargetPosValid]
  size = flex()
  children = HasGndReticle.value && TargetPosValid ? [
    @() {
      watch = [RocketMode, CannonMode, BombCCIPMode, IlsColor]
      size = [pw(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_LINE, BombCCIPMode.value ? 30 : 60, 0, 100, 0],
        [VECTOR_LINE, BombCCIPMode.value ? -30 : -60, 0, -100, 0],
        (!RocketMode.value && !BombCCIPMode.value && !CannonMode.value ? [VECTOR_LINE, 0, 60, 0, 100] : []),
        (GunMode.value ? [VECTOR_ELLIPSE, 0, 0, 60, 60] : []),
        (RocketMode.value ? [VECTOR_LINE, 0, 60, 0, 80] : []),
        (RocketMode.value ? [VECTOR_LINE, 0, -60, 0, -80] : []),
        (RocketMode.value ? [VECTOR_LINE, 42.4, 42.4, 56.5, 56.5] : []),
        (RocketMode.value ? [VECTOR_LINE, -42.4, -42.4, -56.5, -56.5] : []),
        (RocketMode.value ? [VECTOR_LINE, 42.4, -42.4, 56.5, -56.5] : []),
        (RocketMode.value ? [VECTOR_LINE, -42.4, 42.4, -56.5, 56.5] : []),
        (BombCCIPMode.value ? [VECTOR_LINE, 0, 30, 0, 100] : []),
        (BombCCIPMode.value ? [VECTOR_LINE, 0, -30, 0, -100] : []),
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0], TargetPos.value[1]]
        }
      }
    }
  ] : null
}

let BombMode = Computed(@() BombCCIPMode.value || BombingMode.value)
let AamIsReady = Computed(@() GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
let shellName = @() {
  watch = [IlsColor, CurWeaponName, RocketMode, CannonMode, isAAMMode, BombCCIPMode, BombingMode, AamIsReady, HasGndReticle]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(90), ph(BombMode.value ? 65 : 80)]
  color = IlsColor.value
  fontSize = 45
  font = Fonts.hud
  text = BombCCIPMode.value ? "CCIP" :
   (BombingMode.value ? "AUTO" :
    (RocketMode.value ? "RKT" :
     (CannonMode.value ? "GUN" :
      (isAAMMode.value ? loc_checked(string.format("%s/su_145", CurWeaponName.value)) :
      (HasGndReticle.value ? "GUN" : "")))))
}

let aamReadyLabel = @() {
  watch = [IlsColor, AamIsReady]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(97), ph(80)]
  color = IlsColor.value
  fontSize = 45
  font = Fonts.hud
  text = AamIsReady.value ? "U" : ""
}

let shellCount = @() {
  watch = [IlsColor, ShellCnt, GunMode, BombMode, isAAMMode, RocketMode, GunBullets0, GunBullets1]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(80)]
  color = IlsColor.value
  fontSize = 45
  font = Fonts.hud
  text = BombMode.value ? "" : (GunMode.value ? string.format("%03d", max(0, GunBullets0.value) + max(0, GunBullets1.value)) : (isAAMMode.value || RocketMode.value ? ShellCnt.value.tointeger() : ""))
}

let flyDirHide = Computed(@() HasGndReticle.value && abs(TargetPos.value[0] - IlsPosSize[2] * 0.5) < IlsPosSize[2] * 0.05 && abs(TargetPos.value[1] - IlsPosSize[3] * 0.5) < IlsPosSize[3] * 0.05)
function aamReticle(width, height) {
  return @() {
    watch = isAAMMode
    size = flex()
    children = isAAMMode.value ? [
      @() {
        watch = [IlsColor, AamIsReady]
        size = [pw(7), ph(7)]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        fillColor = Color(0, 0, 0, 0)
        lineWidth = IlsLineScale.value * baseLineWidth
        commands = [
          (AamIsReady.value ? [VECTOR_ELLIPSE, 0, 0, 100, 100] : [VECTOR_SECTOR, 0, 0, 100, 100, 7.5, 37.5]),
          (!AamIsReady.value ? [VECTOR_SECTOR, 0, 0, 100, 100, 52.5, 82.5] : []),
          (!AamIsReady.value ? [VECTOR_SECTOR, 0, 0, 100, 100, 97.5, 127.5] : []),
          (!AamIsReady.value ? [VECTOR_SECTOR, 0, 0, 100, 100, 142.5, 172.5] : []),
          (!AamIsReady.value ? [VECTOR_SECTOR, 0, 0, 100, 100, 187.5, 217.5] : []),
          (!AamIsReady.value ? [VECTOR_SECTOR, 0, 0, 100, 100, 232.5, 262.5] : []),
          (!AamIsReady.value ? [VECTOR_SECTOR, 0, 0, 100, 100, 277.5, 307.5] : []),
          (!AamIsReady.value ? [VECTOR_SECTOR, 0, 0, 100, 100, 322.5, 352.5] : [])
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [IlsTrackerX.value, IlsTrackerY.value]
          }
        }
      }
    ] :
    [
      @() {
        watch = flyDirHide
        size = flex()
        children = !flyDirHide.value ? @() {
          watch = IlsColor
          size = [pw(4), ph(4)]
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = IlsLineScale.value * baseLineWidth
          behavior = Behaviors.RtPropUpdate
          commands = [
            [VECTOR_ELLIPSE, 0, 0, 40, 40],
            [VECTOR_LINE, 0, -40, 0, -100],
            [VECTOR_LINE, -100, 0, -40, 0],
            [VECTOR_LINE, 100, 0, 40, 0]
          ]
          update = @() {
            transform = {
              translate = GunMode.value ? [TvvMark[0], TvvMark[1]] : [width * 0.5, height * 0.5]
            }
          }
        } : null
      }
    ]
  }
}

function bombImpactLine(width, height) {
  return @() {
    watch = BombCCIPMode
    size = flex()
    children = BombCCIPMode.value ? [
      @() {
        watch = [IlsColor, TargetPos]
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE_DASHED, 50, 50, TargetPos.value[0] / width * 100.0, TargetPos.value[1] / height * 100.0, width * 0.08, width * 0.02]
        ]
      }
    ] : null
  }
}

let ccrpAimMark = @() {
  watch = BombingMode
  size = flex()
  children = BombingMode.value ? [
    {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(3), ph(3)]
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, -100, -100, 100, -100],
        [VECTOR_LINE, -100, -100, -100, 100],
        [VECTOR_LINE, 100, 100, -100, 100],
        [VECTOR_LINE, 100, 100, 100, -100],
        [VECTOR_LINE, -90, 0, -50, 0],
        [VECTOR_LINE, 90, 0, 50, 0],
        [VECTOR_LINE, 0, 90, 0, 50],
        [VECTOR_LINE, 0, -90, 0, -50]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0], TargetPos.value[1]]
        }
      }
    }
  ] : null
}

function ccrpBombLine(height) {
  return @() {
    watch = [BombingMode, TargetPosValid]
    size = flex()
    children = BombingMode.value && TargetPosValid.value ? [
      {
        size = flex()
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [TargetPos.value[0], 0]
          }
        }
        children = [
          lowerSolutionCue(height, -5),
          @() {
            watch = IlsColor
            rendObj = ROBJ_SOLID
            size = [baseLineWidth * IlsLineScale.value, flex()]
            color = IlsColor.value
          }
        ]
      }
    ] : null
  }
}

let TimeToRelease = Computed(@() TimeBeforeBombRelease.value < 100.0 ? round(TimeBeforeBombRelease.value * 10) : 999)
let timeToReleaseBomb = @() {
  watch = BombingMode
  pos = [pw(80), ph(90)]
  size = [pw(20), ph(5)]
  children = BombingMode.value ? [
    @() {
      watch = [TimeToRelease, IlsColor]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 45
      font = Fonts.hud
      text = string.format("%.1f SEC", TimeToRelease.value * 0.1)
      hplace = ALIGN_RIGHT
    }
  ] : null
}

function mkRwrTarget(target) {
  let targetComponent = @() {
    watch = [IlsColor, IlsLineScale]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    fillColor = Color(0, 0, 0, 0)
    size = [pw(25), ph(25)]
    pos = [pw(90), ph(90)]
    commands = [
      [VECTOR_ELLIPSE, 20, 20, 30, 30],
    ]
    children = {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = [pw(10), 0]
      color = IlsColor.value
      font = Fonts.hud
      fontSize = 40
      text = settings.get().directionGroups?[target.groupId].text ?? settings.get().unknownText
      transform = {
        pivot = [0.5, 0.5]
        rotate = -atan2(target.y, target.x) * (180.0 / PI) + 45
      }
    }
  }

  let trackLine = @() {
    watch = [IlsColor, IlsLineScale]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    size = flex()
    pos = [pw(100), ph(100)]
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      (target.track ? [VECTOR_LINE, -11, -11, -30, -30] : [VECTOR_LINE_DASHED, -11, -11, -30, -30, 20, 20])
    ]
  }

  return {
    size = [pw(35), ph(35)]
    pos = [pw(50), ph(50)]
    transform = {
      pivot = [0.0, 0.0]
      rotate = atan2(target.y, target.x) * (180.0 / PI) - 45
    }
    children = [
      targetComponent,
      trackLine,
    ]
  }
}

let rwrTargetsComponent = @() {
  watch = rwrTargetsTriggers
  size = flex()
  children = rwrTargets.filter(@(t) t != null && t.age < 2.0).map(@(t, _i) mkRwrTarget(t))
}

function SU145(width, height) {
  return {
    size = [width, height]
    children = [
      compassWrap(width, height, 0.2, generateCompassMarkSU145, 0.8, 5.0, false, 12),
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.value
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 50, 29, 49, 31],
          [VECTOR_LINE, 50, 29, 51, 31]
        ]
      },
      aamReticle(width, height),
      speed,
      barAlt,
      mach,
      SUMAoa,
      overload,
      maxOverload,
      pitch(width, height, generatePitchLine),
      groundReticle,
      shellName,
      shellCount,
      bombImpactLine(width, height),
      aamReadyLabel,
      ccrpAimMark,
      ccrpBombLine(height),
      timeToReleaseBomb,
      rwrTargetsComponent,
      localTime,
      @() {
        watch = GunMode
        size = flex()
        children = GunMode.value ? [
          @() {
            watch = IlsColor
            rendObj = ROBJ_VECTOR_CANVAS
            size = flex()
            color = IlsColor.value
            lineWidth = baseLineWidth * IlsLineScale.value
            commands = [
              [VECTOR_LINE, 50, 48, 50, 52],
              [VECTOR_LINE, 48, 50, 52, 50]
            ]
          }
        ] : null
      }
    ]
  }
}

return SU145