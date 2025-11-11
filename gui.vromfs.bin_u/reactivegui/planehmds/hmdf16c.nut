from "%rGui/globals/ui_library.nut" import *
let { floor, round, atan2, PI } = require("%sqstd/math.nut")
let { Speed, BarAltitude, Overload, CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKnots, metrToFeet, metrToNavMile, mpsToKmh } = require("%rGui/planeIlses/ilsConstants.nut")
let { hudFontHgt } = require("%rGui/style/airHudStyle.nut")
let string = require("string")
let { IsTwsActivated, rwrTargetsTriggers, rwrTargets } = require("%rGui/twsState.nut")
let { settings } = require("%rGui/planeRwrs/rwrAnAlr56Components.nut")
let { HmdYaw, RadarTargetPosValid, RadarTargetDistRate } = require("%rGui/planeState/planeToolsState.nut")
let { TrackerVisible, TrackerX, TrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { TATargetVisible } = require("%rGui/airState.nut")
let { TargetX, TargetY } = require("%rGui/hud/targetTrackerState.nut")
let { isInVr } = require("%rGui/style/screenState.nut")
let { DistanceMax, AamLaunchZoneDistMax, AamLaunchZoneDistMin, AamLaunchZoneDistDgftMin, AamLaunchZoneDistDgftMax,
 AamLaunchZoneDist } = require("%rGui/radarState.nut")

let baseLineWidth = floor(LINE_WIDTH + 0.5)
let baseColor = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)

let crosshair = {
  pos = [pw(50), ph(50)]
  size = ph(2)
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 20, 0, 100, 0],
    [VECTOR_LINE, -20, 0, -100, 0],
    [VECTOR_LINE, 0, 20, 0, 100],
    [VECTOR_LINE, 0, -20, 0, -100]
  ]
}

let SpeedValue = Computed(@() round(Speed.get() * mpsToKnots).tointeger())
let SpeedValueM = Computed(@() round(Speed.get() * mpsToKmh).tointeger())
let speedVal = @(is_metric) function() {
  let valWatch = is_metric ? SpeedValueM : SpeedValue
  return {
    size = const [pw(3.5), ph(2.3)]
    pos = [pw(38), ph(49)]
    halign = ALIGN_RIGHT
    children = [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_RECTANGLE, 0, 0, 100, 100]
        ]
      },
      @() {
        watch = valWatch
        size = SIZE_TO_CONTENT
        padding = const [0, 5]
        rendObj = ROBJ_TEXT
        color = baseColor
        fontSize = hudFontHgt * 1.2
        text = valWatch.get().tostring()
      }
    ]
  }
}

let BarAltitudeValue = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let BarAltitudeValueM = Computed(@() BarAltitude.get().tointeger())
let AltVal = @(is_metric) function() {
  let valWatch = is_metric ? BarAltitudeValueM : BarAltitudeValue
  return {
    size = const [pw(5), ph(2.3)]
    pos = [pw(60), ph(49)]
    halign = ALIGN_RIGHT
    children = [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_RECTANGLE, 0, 0, 100, 100]
        ]
      },
      @() {
        watch = valWatch
        size = SIZE_TO_CONTENT
        padding = const [0, 5]
        rendObj = ROBJ_TEXT
        color = baseColor
        fontSize = hudFontHgt * 1.2
        text = valWatch.get() < 1000 ? string.format(",%03d", valWatch.get() % 1000) : string.format("%d,%03d", valWatch.get() / 1000, valWatch.get() % 1000)
      }
    ]
  }
}

let armLabel = {
  size = flex()
  pos = [pw(41), ph(55)]
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = hudFontHgt * 1.2
  text = "ARM"
}

let OverloadWatch = Computed(@() (floor(Overload.get() * 10)).tointeger())
let overload = @() {
  watch = OverloadWatch
  size = flex()
  pos = [pw(41), ph(45)]
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = hudFontHgt * 1.2
  text = string.format("%.1f", OverloadWatch.get() / 10.0)
}

let rwr = @() {
  watch = IsTwsActivated
  size = ph(7)
  pos = [pw(38), ph(35)]
  children = IsTwsActivated.get() ? [
    @() {
      watch = rwrTargetsTriggers
      size = flex()
      children = [
        {
          rendObj = ROBJ_VECTOR_CANVAS
          color = baseColor
          size = flex()
          lineWidth = baseLineWidth
          fillColor = Color(0, 0, 0, 0)
          commands = [
            [VECTOR_SECTOR, 50, 50, 35, 35, 10, 350]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              rotate = HmdYaw.get() - 90.0
            }
          }
        }
        {
          rendObj = ROBJ_TEXT
          size = flex()
          color = baseColor
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          fontSize = hudFontHgt * 1.2
          text = rwrTargets.len() == 0 ? settings.get().unknownText
            : settings.get().directionGroups?[rwrTargets[0].groupId].text ?? settings.get().unknownText
        }
        {
          size = flex()
          rendObj = ROBJ_VECTOR_CANVAS
          color = baseColor
          lineWidth = baseLineWidth
          fillColor = Color(0,0,0,0)
          commands = [
            [VECTOR_POLY, 42.5, 7.5, 50, 0, 58.5, 7.55, 50, 15]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              pivot = [0.5, 0.5]
              rotate = rwrTargets.len() == 0 ? 90
                : (atan2(rwrTargets[0].y, rwrTargets[0].x) * (180.0 / PI) + 90)
            }
          }
        }
      ]
    }
  ] : null
}

let generateCompassMark = function(num, width) {
  return {
    size = [width * 0.15, ph(100)]
    flow = FLOW_VERTICAL
    children = [
      {
        size = [baseLineWidth * 0.8, baseLineWidth * (num % 10 == 0 ? 6 : 4)]
        rendObj = ROBJ_SOLID
        color = baseColor
        lineWidth = baseLineWidth
        hplace = ALIGN_CENTER
      }
      {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        hplace = ALIGN_CENTER
        fontSize = hudFontHgt * 1.2
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
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
  let getOffset = @() (360.0 + CompassValue.get() + HmdYaw.get()) * 0.03 * width
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
    size = [width * 0.2, height]
    pos = [width * 0.4, height * 0.65]
    clipChildren = true
    children = [
      compass(width * 0.2, generateFunc)
    ]
  }
}

let CompassInt = Computed(@() ((360.0 + CompassValue.get() + HmdYaw.get()) % 360.0).tointeger())
let compassVal = {
  size = const [pw(4), ph(3)]
  pos = [pw(48), ph(70)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_RECTANGLE, 0, 0, 100, 100]
  ]
  children = [
    @() {
      watch = CompassInt
      rendObj = ROBJ_TEXT
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = flex()
      color = baseColor
      lineWidth = baseLineWidth
      font = Fonts.hud
      fontSize = hudFontHgt * 1.4
      text = CompassInt.get().tostring()
    }
  ]
}

let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let AamCancel = Computed(@() TrackerX.get() < sw(37) || TrackerX.get() > sw(65) || TrackerY.get() < sh(35) || TrackerY.get() > sh(70))
function aamReticle(width, height) {
  return @() {
    watch = isAAMMode
    size = ph(1.2)
    children = isAAMMode.get() ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_POLY, -100, 0, 0, -100, 100, 0, 0, 100]
        ]
      }
      @(){
        watch = AamCancel
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        lineWidth = baseLineWidth
        commands = AamCancel.get() ? [
          [VECTOR_LINE, -100, -100, 100, 100],
          [VECTOR_LINE, -100, 100, 100, -100]
        ] : []
      }
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TrackerVisible.get() ? [clamp(TrackerX.get(), 0.37 * width, 0.63 * width), clamp(TrackerY.get(), 0.35 * height, 0.7 * height)] : [width * 0.5, height * 0.5]
      }
    }
  }
}

let AimLockLimited = Computed(@() TargetX.get() < sw(37) || TargetX.get() > sw(65) || TargetY.get() < sh(35) || TargetY.get() > sh(70))
function ccrpReticle(width, height) {
  return @() {
    watch = TATargetVisible
    size = ph(2)
    children = TATargetVisible.get() ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_RECTANGLE, -50, -50, 100, 100],
          [VECTOR_LINE, 0, 0, 0, 0]
        ]
      }
      @(){
        watch = AimLockLimited
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        lineWidth = baseLineWidth
        commands = AimLockLimited.get() ? [
          [VECTOR_LINE, -50, -50, 50, 50],
          [VECTOR_LINE, -50, 50, 50, -50]
        ] : []
      }
    ] : null
    animations = [
      { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "aim_lock_limit" }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TATargetVisible.get() ? [clamp(TargetX.get(), 0.37 * width, 0.63 * width), clamp(TargetY.get(), 0.35 * height, 0.7 * height)] : [width * 0.5, height * 0.5]
      }
    }
  }
}

let isDGFTMode = Computed(@() isAAMMode.get() && RadarTargetPosValid.get())
let IsLaunchZoneVisible = Computed(@() isDGFTMode.get() && AamLaunchZoneDistMax.get() > 0.0)
let MaxDistLaunch = Computed(@() (DistanceMax.get() * 1000.0 * metrToNavMile).tointeger())
let MaxDistLaunchKm = Computed(@() DistanceMax.get().tointeger())
let MaxLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMax.get()) * 100.0).tointeger())
let MinLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMin.get()) * 100.0).tointeger())
let IsDgftLaunchZoneVisible = Computed(@() AamLaunchZoneDistDgftMax.get() > 0.0)
let MaxLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMax.get()) * 100.0).tointeger())
let MinLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMin.get()) * 100.0).tointeger())
let RadarClosureSpeed = Computed(@() (RadarTargetDistRate.get() * mpsToKnots * -1.0).tointeger())
let RadarClosureSpeedKmh = Computed(@() (RadarTargetDistRate.get() * mpsToKmh * -1.0).tointeger())
let launchZone = @(is_metric) function() {
  let radarClosureWatched = is_metric ? RadarClosureSpeedKmh : RadarClosureSpeed
  let maxDistWatched = is_metric ? MaxDistLaunchKm : MaxDistLaunch
  return {
    watch = IsLaunchZoneVisible
    size = const [pw(2), ph(15)]
    pos = [pw(60.1), ph(30)]
    children = IsLaunchZoneVisible.get() ? [
      @(){
        watch = AamLaunchZoneDist
        size = flex()
        pos = [pw(-100), ph((1.0 - AamLaunchZoneDist.get()) * 100.0)]
        flow = FLOW_HORIZONTAL
        halign = ALIGN_RIGHT
        children = [
          @(){
            watch = radarClosureWatched
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            color = baseColor
            fontSize = hudFontHgt * 1.1
            text = radarClosureWatched.get().tostring()
          },
          {
            rendObj = ROBJ_VECTOR_CANVAS
            size = const [pw(30), ph(7)]
            color = baseColor
            lineWidth = baseLineWidth
            commands = [
              [VECTOR_LINE, 0, 0, 100, 50],
              [VECTOR_LINE, 0, 100, 100, 50]
            ]
          }
        ]
      },
      {
        size = const [pw(25), flex()]
        flow = FLOW_VERTICAL
        children = [
          @(){
            watch = maxDistWatched
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            color = baseColor
            fontSize = hudFontHgt * 1.2
            text = maxDistWatched.get().tostring()
          },
          {
            size = flex()
            children = [
              {
                rendObj = ROBJ_SOLID
                color = baseColor
                size = [flex(), baseLineWidth]
              },
              {
                rendObj = ROBJ_SOLID
                color = baseColor
                size = [flex(), baseLineWidth]
                pos = [0, ph(100)]
              },
              @() {
                watch = [MaxLaunchPos, MinLaunchPos]
                rendObj = ROBJ_VECTOR_CANVAS
                size = flex()
                color = baseColor
                lineWidth = baseLineWidth
                commands = [
                  [VECTOR_LINE, 0, MaxLaunchPos.get(), 100, MaxLaunchPos.get()],
                  [VECTOR_LINE, 0, MinLaunchPos.get(), 100, MinLaunchPos.get()],
                  [VECTOR_LINE, 0, MaxLaunchPos.get(), 0, MinLaunchPos.get()]
                ]
              },
              @(){
                watch = IsDgftLaunchZoneVisible
                size = flex()
                children = IsDgftLaunchZoneVisible.get() ? [
                  @(){
                    watch = [MaxLaunchDgftPos, MinLaunchDgftPos]
                    rendObj = ROBJ_VECTOR_CANVAS
                    size = flex()
                    color = baseColor
                    lineWidth = baseLineWidth
                    commands = [
                      [VECTOR_LINE, 0, MaxLaunchDgftPos.get(), 100, MaxLaunchDgftPos.get()],
                      [VECTOR_LINE, 0, MinLaunchDgftPos.get(), 100, MinLaunchDgftPos.get()],
                      [VECTOR_LINE, 100, MaxLaunchDgftPos.get(), 100, MinLaunchDgftPos.get()]
                    ]
                  }
                ] : null
              }
            ]
          }
        ]
      }
    ] : null
  }
}

let isTargetDirVisible = Computed(@() TrackerVisible.get() ? AamCancel.get() :
 (TATargetVisible.get() ? AimLockLimited.get() : false))
function targetDir(width, height) {
  return @() {
    watch = isTargetDirVisible
    size = flex()
    children = isTargetDirVisible.get() ? {
      size = const [pw(4), ph(4)]
      pos = [pw(50), ph(50)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 100, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        let target = TrackerVisible.get() ? [TrackerX.get(), TrackerY.get()] : (TATargetVisible.get() ? [TargetX.get(), TargetY.get()] : [0, 0])
        return {
          transform = {
            rotate = atan2(height * -0.5 + target[1], width * -0.5 + target[0]) * (180.0 / PI)
            pivot = [0, 0]
          }
        }
      }
    } : null
  }
}

function hmd(width, height, is_metric) {
  return {
    size = [width, height]
    children = [
      crosshair
      speedVal(is_metric)
      AltVal(is_metric)
      armLabel
      overload
      rwr
      compassWrap(width, height, generateCompassMark)
      compassVal
      aamReticle(width, height)
      ccrpReticle(width, height)
      launchZone(is_metric)
      targetDir(width, height)
    ]
  }
}

return hmd