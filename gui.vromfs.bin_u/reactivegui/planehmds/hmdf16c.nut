from "%rGui/globals/ui_library.nut" import *
let { floor, round, atan2, PI } = require("%sqstd/math.nut")
let { Speed, BarAltitude, Overload, CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKnots, metrToFeet, metrToNavMile } = require("%rGui/planeIlses/ilsConstants.nut")
let { hudFontHgt } = require("%rGui/style/airHudStyle.nut")
let string = require("string")
let { IsTwsActivated, rwrTargetsTriggers, rwrTargets } = require("%rGui/twsState.nut")
let rwrSetting = require("%rGui/rwrSetting.nut")
let { HmdYaw, RadarTargetPosValid, RadarTargetDistRate } = require("%rGui/planeState/planeToolsState.nut")
let { TrackerVisible, TrackerX, TrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("%rGui/guidanceConstants.nut")
let { TATargetVisible } = require("%rGui/airState.nut")
let { TargetX, TargetY } = require("%rGui/hud/targetTrackerState.nut")
let { isInVr } = require("%rGui/style/screenState.nut")
let { DistanceMax, AamLaunchZoneDistMax, AamLaunchZoneDistMin, AamLaunchZoneDistDgftMin, AamLaunchZoneDistDgftMax,
 AamLaunchZoneDist } = require("%rGui/radarState.nut")

let baseLineWidth = floor(LINE_WIDTH + 0.5)
let baseColor = isInVr ? Color(30, 255, 10, 255) : Color(30, 255, 10, 10)

let crosshair = {
  pos = [pw(50), ph(50)]
  size = [ph(2), ph(2)]
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

let SpeedValue = Computed(@() round(Speed.value * mpsToKnots).tointeger())
let speedVal = @() {
  size = [pw(3.5), ph(2.3)]
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
      watch = SpeedValue
      size = SIZE_TO_CONTENT
      padding = [0, 5]
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = hudFontHgt * 1.2
      text = SpeedValue.value.tostring()
    }
  ]
}

let BarAltitudeValue = Computed(@() (BarAltitude.value * metrToFeet).tointeger())
let AltVal = @() {
  size = [pw(5), ph(2.3)]
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
      watch = BarAltitudeValue
      size = SIZE_TO_CONTENT
      padding = [0, 5]
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = hudFontHgt * 1.2
      text = BarAltitudeValue.value < 1000 ? string.format(",%03d", BarAltitudeValue.value % 1000) : string.format("%d,%03d", BarAltitudeValue.value / 1000, BarAltitudeValue.value % 1000)
    }
  ]
}

let armLabel = {
  size = flex()
  pos = [pw(41), ph(55)]
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = hudFontHgt * 1.2
  text = "ARM"
}

let OverloadWatch = Computed(@() (floor(Overload.value * 10)).tointeger())
let overload = @() {
  watch = OverloadWatch
  size = flex()
  pos = [pw(41), ph(45)]
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = hudFontHgt * 1.2
  text = string.format("%.1f", OverloadWatch.value / 10.0)
}

let rwr = @() {
  watch = IsTwsActivated
  size = [ph(7), ph(7)]
  pos = [pw(38), ph(35)]
  children = IsTwsActivated.value ? [
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
              rotate = HmdYaw.value - 90.0
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
          text = rwrTargets[0].groupId >= 0 && rwrTargets[0].groupId < rwrSetting.value.direction.len() ? rwrSetting.value.direction[rwrTargets[0].groupId].text : "?"
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
              rotate = atan2(rwrTargets[0].y, rwrTargets[0].x) * (180.0 / PI) + 90
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

let function compass(width, generateFunc) {
  let children = []
  let step = 5.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num, width))
  }
  let getOffset = @() (360.0 + CompassValue.value + HmdYaw.value) * 0.03 * width
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

let function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.2, height]
    pos = [width * 0.4, height * 0.65]
    clipChildren = true
    children = [
      compass(width * 0.2, generateFunc)
    ]
  }
}

let CompassInt = Computed(@() ((360.0 + CompassValue.value + HmdYaw.value) % 360.0).tointeger())
let compassVal = {
  size = [pw(4), ph(3)]
  pos = [pw(48), ph(66)]
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
      text = CompassInt.value.tostring()
    }
  ]
}

let isAAMMode = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let AamCancel = Computed(@() TrackerX.value < sw(37) || TrackerX.value > sw(65) || TrackerY.value < sh(35) || TrackerY.value > sh(70))
let function aamReticle(width, height) {
  return @() {
    watch = isAAMMode
    size = [ph(1.2), ph(1.2)]
    children = isAAMMode.value ? [
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
        commands = AamCancel.value ? [
          [VECTOR_LINE, -100, -100, 100, 100],
          [VECTOR_LINE, -100, 100, 100, -100]
        ] : []
      }
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TrackerVisible.value ? [clamp(TrackerX.value, 0.37 * width, 0.63 * width), clamp(TrackerY.value, 0.35 * height, 0.7 * height)] : [width * 0.5, height * 0.5]
      }
    }
  }
}

let AimLockLimited = Computed(@() TargetX.value < sw(37) || TargetX.value > sw(65) || TargetY.value < sh(35) || TargetY.value > sh(70))
let function ccrpReticle(width, height) {
  return @() {
    watch = TATargetVisible
    size = [ph(2), ph(2)]
    children = TATargetVisible.value ? [
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
        commands = AimLockLimited.value ? [
          [VECTOR_LINE, -50, -50, 50, 50],
          [VECTOR_LINE, -50, 50, 50, -50]
        ] : []
      }
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TATargetVisible.value ? [clamp(TargetX.value, 0.37 * width, 0.63 * width), clamp(TargetY.value, 0.35 * height, 0.7 * height)] : [width * 0.5, height * 0.5]
      }
    }
  }
}

let isDGFTMode = Computed(@() isAAMMode.value && RadarTargetPosValid.value)
let IsLaunchZoneVisible = Computed(@() isDGFTMode.value && AamLaunchZoneDistMax.value > 0.0)
let MaxDistLaunch = Computed(@() (DistanceMax.value * 1000.0 * metrToNavMile).tointeger())
let MaxLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMax.value) * 100.0).tointeger())
let MinLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMin.value) * 100.0).tointeger())
let IsDgftLaunchZoneVisible = Computed(@() AamLaunchZoneDistDgftMax.value > 0.0)
let MaxLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMax.value) * 100.0).tointeger())
let MinLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMin.value) * 100.0).tointeger())
let RadarClosureSpeed = Computed(@() (RadarTargetDistRate.value * mpsToKnots * -1.0).tointeger())
let launchZone = @() {
  watch = IsLaunchZoneVisible
  size = [pw(2), ph(15)]
  pos = [pw(60.1), ph(30)]
  children = IsLaunchZoneVisible.value ? [
    @(){
      watch = AamLaunchZoneDist
      size = flex()
      pos = [pw(-100), ph((1.0 - AamLaunchZoneDist.value) * 100.0)]
      flow = FLOW_HORIZONTAL
      halign = ALIGN_RIGHT
      children = [
        @(){
          watch = RadarClosureSpeed
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          color = baseColor
          fontSize = hudFontHgt * 1.1
          text = RadarClosureSpeed.value.tostring()
        },
        {
          rendObj = ROBJ_VECTOR_CANVAS
          size = [pw(30), ph(7)]
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
      size = [pw(25), flex()]
      flow = FLOW_VERTICAL
      children = [
        @(){
          watch = MaxDistLaunch
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          color = baseColor
          fontSize = hudFontHgt * 1.2
          text = MaxDistLaunch.value.tostring()
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
                [VECTOR_LINE, 0, MaxLaunchPos.value, 100, MaxLaunchPos.value],
                [VECTOR_LINE, 0, MinLaunchPos.value, 100, MinLaunchPos.value],
                [VECTOR_LINE, 0, MaxLaunchPos.value, 0, MinLaunchPos.value]
              ]
            },
            @(){
              watch = IsDgftLaunchZoneVisible
              size = flex()
              children = IsDgftLaunchZoneVisible.value ? [
                @(){
                  watch = [MaxLaunchDgftPos, MinLaunchDgftPos]
                  rendObj = ROBJ_VECTOR_CANVAS
                  size = flex()
                  color = baseColor
                  lineWidth = baseLineWidth
                  commands = [
                    [VECTOR_LINE, 0, MaxLaunchDgftPos.value, 100, MaxLaunchDgftPos.value],
                    [VECTOR_LINE, 0, MinLaunchDgftPos.value, 100, MinLaunchDgftPos.value],
                    [VECTOR_LINE, 100, MaxLaunchDgftPos.value, 100, MinLaunchDgftPos.value]
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

let isTargetDirVisible = Computed(@() TrackerVisible.value ? AamCancel.value :
 (TATargetVisible.value ? AimLockLimited.value : false))
let function targetDir(width, height) {
  return @() {
    watch = isTargetDirVisible
    size = flex()
    children = isTargetDirVisible.value ? {
      size = [pw(4), ph(4)]
      pos = [pw(50), ph(50)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_LINE, 0, 0, 100, 0]
      ]
      behavior = Behaviors.RtPropUpdate
      update = function() {
        let target = TrackerVisible.value ? [TrackerX.value, TrackerY.value] : (TATargetVisible.value ? [TargetX.value, TargetY.value] : [0, 0])
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

let function hmd(width, height) {
  return {
    size = [width, height]
    children = [
      crosshair
      speedVal
      AltVal
      armLabel
      overload
      rwr
      compassWrap(width, height, generateCompassMark)
      compassVal
      aamReticle(width, height)
      ccrpReticle(width, height)
      launchZone
      targetDir(width, height)
    ]
  }
}

return hmd