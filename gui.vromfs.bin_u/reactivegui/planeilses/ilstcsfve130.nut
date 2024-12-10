from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked

let string = require("string")
let { compassWrap, generateCompassMarkVE130 } = require("ilsCompasses.nut")
let { flyDirection } = require("commonElements.nut")
let { IlsColor, IlsLineScale, CannonMode, TargetPosValid, TargetPos, BombingMode,
  DistToTarget, RocketMode, BombCCIPMode, RadarTargetPosValid, RadarTargetPos,
   RadarTargetDistRate, RadarTargetDist } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, metrToNavMile } = require("ilsConstants.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { Speed, Mach, BarAltitude, Altitude, Overload, Tangage, Roll,
  Accel, Aoa } = require("%rGui/planeState/planeFlyState.nut")
let { floor, round, abs } = require("%sqstd/math.nut")
let { cvt } = require("dagor.math")
let { CurWeaponName, GunBullets0, GunBullets1, BulletImpactPoints, BulletImpactLineEnable } = require("%rGui/planeState/planeWeaponState.nut")
let { GuidanceLockState, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")
let { AamTimeOfFlightMax, IsAamLaunchZoneVisible, AamLaunchZoneDistMinVal, AamLaunchZoneDistMaxVal } = require("%rGui/radarState.nut")
let { get_local_unixtime, unixtime_to_local_timetbl } = require("dagor.time")

let SpeedValue = Computed(@() round(Speed.value * mpsToKnots).tointeger())
let speed = @() {
  watch = [IlsColor, SpeedValue]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(12), ph(10)]
  color = IlsColor.value
  fontSize = 60
  font = Fonts.mirage_ils
  text = SpeedValue.value.tointeger()
}

let MachValue = Computed(@() (floor(Mach.value * 100.0)).tointeger())
let mach = @() {
  watch = [MachValue, IlsColor]
  pos = [pw(13), ph(16)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 45
  font = Fonts.mirage_ils
  text = string.format("%.2f", MachValue.value * 0.01)
}

let HeiHundreds = Computed(@() (BarAltitude.value * metrToFeet / 100).tointeger())
let HeiDozens = Computed(@() (BarAltitude.value * metrToFeet % 100.0 / 10).tointeger())
let barAlt = {
  pos = [pw(75), ph(10)]
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
      font = Fonts.mirage_ils
      text = HeiHundreds.value.tostring()
    },
    @() {
      watch = [HeiDozens, IlsColor]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      fontSize = 45
      font = Fonts.mirage_ils
      text = string.format("%d0", HeiDozens.value)
    }
  ]
}

let AltValue = Computed(@() clamp(Altitude.value * metrToFeet, -1.0, 5001.0).tointeger())
let altitude = @() {
  watch = [AltValue, IlsColor]
  pos = [pw(70), ph(16)]
  size = [pw(20), SIZE_TO_CONTENT]
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 45
  font = Fonts.mirage_ils
  text = AltValue.value < 5000 ? string.format("%d H", AltValue.value) : "***** H"
}

let localTime = @() {
  watch = IlsColor
  rendObj = ROBJ_TEXT
  size = [pw(20), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  pos = [pw(40), ph(97)]
  color = IlsColor.get()
  fontSize = 40
  font = Fonts.mirage_ils
  text = "11:22:33"
  behavior = Behaviors.RtPropUpdate
  function update() {
    let time = unixtime_to_local_timetbl(get_local_unixtime())
    return {
      text = string.format("%02d:%02d:%02d", time.hour, time.min, time.sec)
    }
  }
}

let OverloadWatch = Computed(@() (floor(Overload.value * 10)).tointeger())
let overload = @() {
  watch = [OverloadWatch, IlsColor]
  size = flex()
  pos = [pw(10), ph(55)]
  rendObj = ROBJ_TEXT
  color = IlsColor.value
  fontSize = 45
  font = Fonts.mirage_ils
  text = string.format("G  %.1f", OverloadWatch.value / 10.0)
}

let aoaWatched = Computed(@() (Aoa.get() * 10.0).tointeger())
let aoa = @() {
  size = [pw(5), pw(10)]
  flow = FLOW_HORIZONTAL
  halign = ALIGN_LEFT
  valign = ALIGN_BOTTOM
  pos = [pw(10), ph(55)]
  children = [
    @(){
      watch = [IlsColor]
      rendObj = ROBJ_TEXT
      size = [50  , SIZE_TO_CONTENT]
      color = IlsColor.get()
      fontSize = 55
      font = Fonts.mirage_ils
      text = "α"
    }
    @(){
      watch = [aoaWatched, IlsColor]
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      color = IlsColor.get()
      fontSize = 45
      font = Fonts.mirage_ils
      text = string.format((aoaWatched.get() >= 0) ? " %.1f" : "%.1f", aoaWatched.get() * 0.1)
    }
  ]
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
    font = Fonts.mirage_ils
    text = string.format(num == -5 ? "-05" : "%02d", num)
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
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
          [VECTOR_LINE, -100, 0, 200, 0]
        ]
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
          [VECTOR_LINE, 0, 5 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 30 : 5, 0],
          (num < 0 ? [VECTOR_LINE, 10, 0, 17, 0] : []),
          (num < 0 ? [VECTOR_LINE, 23, 0, 30, 0] : []),
          [VECTOR_LINE, 100, 5 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 70 : 95, 0],
          (num < 0 ? [VECTOR_LINE, 90, 0, 83, 0] : []),
          (num < 0 ? [VECTOR_LINE, 77, 0, 70, 0] : [])
        ]
        children = newNum <= 90 && newNum % 10 == 0 ? [angleTxt(newNum, true, 1, pw(-25)), angleTxt(newNum, false, 1, pw(25))] : null
      }
    ]
  }
}

let AccelPos = Computed(@() (48.5 - cvt(Accel.value, 10, -10, 10, -10)).tointeger())
let acceleration = @() {
  watch = [IlsColor, AccelPos]
  pos = [pw(35), ph(AccelPos.value)]
  size = [pw(30), ph(3)]
  color = IlsColor.value
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = [
    [VECTOR_LINE, 0, 0, 10, 50],
    [VECTOR_LINE, 0, 100, 10, 50],
    [VECTOR_LINE, 100, 100, 90, 50],
    [VECTOR_LINE, 100, 0, 90, 50]
  ]
}

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value)
let ccipDistF = Computed(@() CCIPMode.value ? cvt(clamp(DistToTarget.value * 0.01, 0, 24), 0, 24, -90, 270).tointeger() : 269)
let gunAimMark = @() {
  watch = TargetPosValid
  size = flex()
  children = TargetPosValid.value ?
    @() {
      watch = [IlsColor, ccipDistF]
      size = [pw(8), ph(8)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_LINE, 0, 0, 0, 0],
        [VECTOR_LINE, -120, 0, -100, 0],
        [VECTOR_LINE, 120, 0, 100, 0],
        [VECTOR_LINE, 0, -120, 0, -100],
        [VECTOR_LINE, 0, 120, 0, 100],
        (DistToTarget.value < 10000 || !CCIPMode.value ? [VECTOR_SECTOR, 0, 0, 100, 100, -90, ccipDistF.value] : [])
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [TargetPos.value[0], TargetPos.value[1]]
        }
      }
    }
  : null
}

let bombMark = @() {
  watch = [TargetPosValid]
  size = flex()
  children = TargetPosValid.value ?
  @() {
    watch = IlsColor
    size = [pw(5), ph(2)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, -30, -100, 30, -100],
      [VECTOR_LINE, -30, 100, 30, 100],
      [VECTOR_LINE, -40, 0, -30, -100],
      [VECTOR_LINE, -40, 0, -30, 100],
      [VECTOR_LINE, 40, 0, 30, -100],
      [VECTOR_LINE, 40, 0, 30, 100],
      [VECTOR_LINE, -100, 0, -40, 0],
      [VECTOR_LINE, 100, 0, 40, 0]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.value[0], TargetPos.value[1]]
      }
    }
  } : null
}

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let shellName = @() {
  watch = [IlsColor, CurWeaponName, RocketMode, CannonMode, isAAMMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(50)]
  color = IlsColor.value
  fontSize = 45
  font = Fonts.mirage_ils
  text = RocketMode.value ? "RK" : (CannonMode.value ? "CAS" : (isAAMMode.value ? loc_checked(CurWeaponName.value) :  "CAN"))
}

function bombImpactLine(width, height) {
  return @() {
    watch = TargetPosValid
    size = flex()
    children = TargetPosValid.value ? [
      @() {
        watch = [IlsColor, TargetPos]
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
        color = IlsColor.value
        commands = [
          [VECTOR_LINE, 50, 50, TargetPos.value[0] / width * 100.0, TargetPos.value[1] / height * 100.0]
        ]
      }
    ] : null
  }
}

function groundReticles(width, height) {
  return @() {
    watch = [CCIPMode, BombCCIPMode]
    size = flex()
    children = CCIPMode.value ?
      [
        gunAimMark
      ] :
      [
        flyDirection(width, height, true),
        acceleration,
        (BombCCIPMode.value ? bombMark : null),
        (BombCCIPMode.value ? bombImpactLine(width, height) : null),
        (!isAAMMode.value ? gunAimMark : null)
      ]
  }
}

let radarDistKm = Computed(@() (RadarTargetDist.value / 100.0).tointeger())
let raderClosureSpeed = Computed(@() (RadarTargetDistRate.value * mpsToKnots * -1.0).tointeger())
let radarTargetDist = @() {
  watch = RadarTargetPosValid
  size = flex()
  children = RadarTargetPosValid.value ?
  [
    @() {
      watch = CCIPMode
      size = flex()
      children = [
        @() {
          watch = [IlsColor, radarDistKm]
          size = SIZE_TO_CONTENT
          rendObj = ROBJ_TEXT
          pos = [pw(72), ph(20)]
          color = IlsColor.value
          fontSize = 45
          font = Fonts.mirage_ils
          text = string.format("%.1fKM", RadarTargetDist.value / 1000.0)
        }
        !CCIPMode.value ? @() {
          watch = IlsColor
          size = [pw(12), ph(5)]
          pos = [pw(70), ph(55)]
          rendObj = ROBJ_VECTOR_CANVAS
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = IlsLineScale.value * baseLineWidth
          commands = [
            [VECTOR_RECTANGLE, 0, 0, 100, 100]
          ]
          children = [
            @() {
              watch = [IlsColor, raderClosureSpeed]
              size = flex()
              padding = [0, 5]
              rendObj = ROBJ_TEXT
              valign = ALIGN_CENTER
              color = IlsColor.value
              fontSize = 40
              font = Fonts.mirage_ils
              text = raderClosureSpeed.value.tostring()
              halign = ALIGN_RIGHT
            }
          ]
        } : null
      ]
    }
  ] : null
}

function targetMark(width, height) {
  return @() {
    watch = [IlsColor, RadarTargetPosValid]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(7), ph(7)]
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = RadarTargetPosValid.value ? [
      [VECTOR_LINE, -100, -100, 100, -100],
      [VECTOR_LINE, 100, -100, 100, 100],
      [VECTOR_LINE, 100, 100, -100, 100],
      [VECTOR_LINE, -100, 100, -100, -100]
    ] : null
    animations = [
      { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.5, loop = true, trigger = "radar_target_out_of_limit" }
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      let reticleLim = [0.42 * width, 0.42 * height]
      if (abs(RadarTargetPos[0] - 0.5 * width) > reticleLim[0] || abs(RadarTargetPos[1] - 0.5 * height) > reticleLim[1])
        anim_start("radar_target_out_of_limit")
      else
        anim_request_stop("radar_target_out_of_limit")
      let RadarTargetPosLim =  [
        0.5 * width + clamp(RadarTargetPos[0] - 0.5 * width, -reticleLim[0], reticleLim[0]),
        0.5 * height + clamp(RadarTargetPos[1] - 0.5 * height, -reticleLim[1], reticleLim[1])
      ]
      return {
        transform = {
          translate = RadarTargetPosLim
        }
      }
    }
  }
}

let AamIsReady = Computed(@() GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
let aamTargetMarker = @() {
  watch = [IlsColor, AamIsReady]
  size = [pw(10), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = IlsLineScale.value * baseLineWidth
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
    (AamIsReady.value ? [VECTOR_ELLIPSE, 0, 0, 90, 90] : [])
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [IlsTrackerX.value, IlsTrackerY.value]
    }
  }
}

let CalcFlightTime = Computed(@() AamLaunchZoneDistMaxVal.value == 0 ? 0
  : round(AamTimeOfFlightMax.value * (RadarTargetDist.value / AamLaunchZoneDistMaxVal.value)).tointeger())
let AamIsLocking = Computed(@() GuidanceLockState.value >= GuidanceLockResult.RESULT_LOCKING)
function AamReady(is_left) {
  return @() {
    watch = AamIsLocking
    size = flex()
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_TEXT
        pos = [is_left ? pw(35) : pw(62), ph(90)]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        fontSize = 45
        font = Fonts.mirage_ils
        text = is_left ? "G" : "D"
      },
      @() {
        watch = IsAamLaunchZoneVisible
        pos = [is_left ? pw(33.8) : pw(60.7), ph(85)]
        size = [pw(5), ph(5)]
        children = IsAamLaunchZoneVisible.value ? [
          @() {
            watch = [CalcFlightTime, IlsColor]
            rendObj = ROBJ_TEXT
            halign = ALIGN_CENTER
            size = flex()
            color = IlsColor.value
            fontSize = 45
            font = Fonts.mirage_ils
            text = CalcFlightTime.value.tostring()
          }
        ] : null
      },
      (AamIsLocking.value ?
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        pos = [is_left ? pw(33.8) : pw(60.7), ph(89.5)]
        size = [pw(5), ph(5)]
        color = IlsColor.value
        lineWidth = IlsLineScale.value * baseLineWidth
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_ELLIPSE, 50, 50, 50, 50]
        ]
      } : null)
    ]
  }
}


function targetDistScale(height) {
  let MinDistPos = Computed(@() (clamp(1.0 - AamLaunchZoneDistMinVal.value / 40000.0, 0.0, 1.0) * height * 0.3).tointeger())
  let MaxDistPos = Computed(@() (clamp(1.0 - AamLaunchZoneDistMaxVal.value / 40000.0, 0.0, 1.0) * height * 0.3).tointeger())
  let CurDistPos = Computed(@() (clamp(1.0 - RadarTargetDist.value / 40000.0, 0.0, 1.0) * height * 0.3).tointeger())
  let curDist = Computed(@() round(RadarTargetDist.value * metrToNavMile))
  return @() {
    watch = IsAamLaunchZoneVisible
    size = [pw(10), ph(30)]
    pos = [pw(80), ph(60)]
    children = IsAamLaunchZoneVisible.value ? [
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        size = flex()
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 50, 0, 50, 100],
          [VECTOR_LINE, 50, 0, 70, 0],
          [VECTOR_LINE, 50, 100, 70, 100]
        ]
      },
      @() {
        watch = [MinDistPos, IlsColor]
        rendObj = ROBJ_SOLID
        pos = [pw(30), MinDistPos.value]
        size = [pw(20), baseLineWidth * IlsLineScale.value]
        color = IlsColor.value
      }
      ,
      @() {
        watch = [MaxDistPos, IlsColor]
        rendObj = ROBJ_SOLID
        pos = [pw(30), MaxDistPos.value]
        size = [pw(20), baseLineWidth * IlsLineScale.value]
        color = IlsColor.value
      },
      @() {
        watch = [CurDistPos, IlsColor]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.value
        size = [pw(45), ph(5)]
        pos = [pw(55), CurDistPos.value]
        lineWidth = baseLineWidth * IlsLineScale.value
        commands = [
          [VECTOR_LINE, 0, 0, 30, 100],
          [VECTOR_LINE, 0, 0, 30, -100]
        ]
        children = [
          @() {
            watch = curDist
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            pos = [pw(50), ph(-100)]
            color = IlsColor.value
            fontSize = 30
            font = Fonts.mirage_ils
            text = curDist.value.tostring()
          }
        ]
      }
    ] : null
  }
}

function aamInfo(height) {
  return @() {
    watch = isAAMMode
    size = flex()
    children = isAAMMode.value ?
    [
      aamTargetMarker,
      AamReady(true),
      AamReady(false),
      targetDistScale(height)
    ] : null
  }
}

function gunBulletsCnt(is_left, watch_var) {
  return {
    size = flex()
    hplace = ALIGN_CENTER
    children = [
      @() {
        watch = [IlsColor, watch_var]
        rendObj = ROBJ_TEXT
        pos = [is_left ? pw(32.5) : pw(-32.5), ph(90)]
        halign = is_left ? ALIGN_LEFT : ALIGN_RIGHT
        size = flex()
        color = IlsColor.value
        fontSize = 45
        font = Fonts.mirage_ils
        text = watch_var.value.tostring()
      }
    ]
  }
}

let GunMode = Computed(@() !BombCCIPMode.value && !RocketMode.value && !BombingMode.value && !isAAMMode.value)
let gunBullets = @() {
  watch = GunMode
  size = flex()
  children = GunMode.value ?
  [
    (GunBullets0.value >= 0 ? gunBulletsCnt(true, GunBullets0) : null),
    (GunBullets1.value >= 0 ? gunBulletsCnt(false, GunBullets1) : null)
  ] : null
}
function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints.value.len() - 2; ++i) {
    let point1 = BulletImpactPoints.value[i]
    let point2 = BulletImpactPoints.value[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  return commands
}

let bulletsImpactLine = @() {
  watch = [GunMode, CannonMode, BulletImpactLineEnable]
  size = flex()
  children = BulletImpactLineEnable.value && GunMode.value && !CannonMode.value ? [
    @() {
      watch = [BulletImpactPoints, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = getBulletImpactLineCommand()
    }
  ] : null
}

function TCSFVE130(width, height) {
  return {
    size = [width, height]
    children = [
      groundReticles(width, height),
      @() {
        watch = IlsColor
        pos = [pw(50), ph(17)]
        size = [baseLineWidth * IlsLineScale.value, baseLineWidth * 5]
        rendObj = ROBJ_SOLID
        color = IlsColor.value
      },
      compassWrap(width, height, 0.1, generateCompassMarkVE130, 0.8, 5.0, false, 15),
      speed,
      mach,
      barAlt,
      altitude,
      overload,
      shellName,
      pitch(width, height, generatePitchLine),
      targetMark(width, height),
      radarTargetDist,
      aamInfo(height),
      gunBullets,
      bulletsImpactLine,
      localTime,
      aoa
    ]
  }
}

return TCSFVE130