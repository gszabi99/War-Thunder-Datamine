from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { floor, round, atan2, PI } = require("%sqstd/math.nut")
let { Speed, BarAltitude, Overload, Mach, Aoa, CompassValue, Tas } = require("%rGui/planeState/planeFlyState.nut")
let { mpsToKnots, metrToFeet, metrToNavMile } = require("%rGui/planeIlses/ilsConstants.nut")
let { hudFontHgt } = require("%rGui/style/airHudStyle.nut")
let string = require("string")
let { HmdYaw, RadarTargetDist, CannonMode, RocketMode, BombingMode, BombCCIPMode } = require("%rGui/planeState/planeToolsState.nut")
let { TrackerVisible, TrackerX, TrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { TATargetVisible, AamTimeToHit, } = require("%rGui/airState.nut")
let { TargetX, TargetY } = require("%rGui/hud/targetTrackerState.nut")
let { isInVr } = require("%rGui/style/screenState.nut")
let { CurWeaponName, ShellCnt } = require("%rGui/planeState/planeWeaponState.nut")
let { AamLaunchZoneDistMax, AamLaunchZoneDistMin, AamLaunchZoneDistDgftMin, AamLaunchZoneDistDgftMax, AamLaunchZoneDist } = require("%rGui/radarState.nut")

let baseLineWidth    = floor(LINE_WIDTH + 0.5)
let baseColor        = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
let lockColor        = Color(255, 0, 0, 100)
let lightBlueColor   = Color(60, 200, 255, 15)                                   
let blueColor        = Color(10, 10, 255, 50)                                    

let textTemplate = {
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = hudFontHgt * 1.1
  font = Fonts.hud
}

let textTemplateLarge = clone textTemplate
textTemplateLarge.__update({ fontSize = hudFontHgt * 1.3 })

let boxedTemplate = {
  rendObj = ROBJ_FRAME
  color = baseColor
  borderWidth = baseLineWidth
  padding = const 5
}

let loc_wpn = function(key) {
  return loc_checked(key.replace("_default", ""))
}

let crosshair = {
  pos = [pw(49), ph(49)]
  size = ph(3)
  rendObj = ROBJ_VECTOR_CANVAS
  color = lockColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE_DASHED, 20, 0, 100, 0, 5, 5],
    [VECTOR_LINE_DASHED, 100, 0, 100, 80, 5, 5],
    [VECTOR_LINE_DASHED, 100, 80, 20, 80, 5, 5],
    [VECTOR_LINE_DASHED, 20, 80, 20, 0, 5, 5]
  ]
}

let IasValue = Computed(@() round(Speed.get() * mpsToKnots).tointeger())
let TasValue = Computed(@() round(Tas.get() * mpsToKnots).tointeger())

let speedData = @() {
  pos = [pw(38), ph(45)]
  size = [pw(5), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  halign = ALIGN_LEFT
  children = [
    @() boxedTemplate.__merge({
      halign = ALIGN_RIGHT
      children = [
        @() textTemplateLarge.__merge({
          watch = IasValue
          text = string.format("%4d", IasValue.get())
        })
      ]
    }),
    @() textTemplate.__merge({
      watch = TasValue
      margin = const [10, 0]
      text = string.format("TS%4d", TasValue.get())
    })
  ]
}

let BaroAltValue = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let baroAlt = @() boxedTemplate.__merge({
  pos = [pw(58), ph(45)]
  halign = ALIGN_RIGHT
  children = [
  @() textTemplateLarge.__merge({
    watch = BaroAltValue
    text = BaroAltValue.get() < 1000 ? string.format("  ,%03d", BaroAltValue.get() % 1000) : string.format("%2d,%03d", BaroAltValue.get() / 1000, BaroAltValue.get() % 1000)
  })
]})

let AGMasterMode =  Computed(@() CannonMode.get() || BombingMode.get() || BombCCIPMode.get() || RocketMode.get())
let weaponData = @() {
  pos = [pw(33), ph(68)]
  size = [pw(20), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    @() textTemplateLarge.__merge({
      watch = AGMasterMode
      color = lightBlueColor
      text = AGMasterMode.get() ? "A-G" : "A-A"
    }),
    @() textTemplateLarge.__merge({
      watch = [ShellCnt, CurWeaponName]
      color = lightBlueColor
      text = CurWeaponName.get() != "" && ShellCnt.get() > 0 ? string.format("%d ", ShellCnt.get()).concat(loc_wpn(string.format("%s/targo", CurWeaponName.get()))) : ""
    }),
    textTemplateLarge.__merge({
      color = lightBlueColor
      text = "ARM"
    })
  ]
}

let AoaValue = Computed(@() (floor(Aoa.get() * 10.0)).tointeger())
let MachValue = Computed(@() (floor(Mach.get() * 100.0)).tointeger())
let OverloadValue = Computed(@() (floor(Overload.get() * 10.0)).tointeger())
let airData = @() {
  pos = [pw(37), ph(60)]
  size = [pw(5), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    @() textTemplate.__merge({
      watch = AoaValue
      text = string.format("α% .1f", AoaValue.get() / 10.0)
    }),
    @() textTemplate.__merge({
      watch = MachValue
      text = string.format("M %.2f", MachValue.get() / 100.0)
    }),
    @() textTemplate.__merge({
      watch = OverloadValue
      text = string.format("G %.1f", OverloadValue.get() / 10.0)
    })
  ]
}

let generateCompassMark = @(num, width) {
  size = [width * 0.15, ph(100)]
  flow = FLOW_VERTICAL
  children = [
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = baseColor
      hplace = ALIGN_CENTER
      fontSize = hudFontHgt * 1.2
      text = num % 10 == 0 ? (num / 10).tostring() : ""
    },
    {
      size = [baseLineWidth * 0.8, baseLineWidth * (num % 10 == 0 ? 8 : 6)]
      margin = [baseLineWidth * (num % 10 == 0 ? 0 : 2), 0]
      rendObj = ROBJ_SOLID
      color = baseColor
      lineWidth = baseLineWidth
      hplace = ALIGN_CENTER
    }
  ]
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
  let size = [(width * 0.2).tointeger(), (height * 0.08).tointeger()]
  return {
    size = size
    pos = [width * 0.4, height * 0.35]
    clipChildren = true
    rendObj = ROBJ_MASK
    image = Picture($"ui/gameuiskin#hmd_targo_mask.svg:{size[0]}:{size[1]}:P")
    children = [
      compass(width * 0.2, generateFunc)
    ]
  }
}


let CompassIntValue = Computed(@() ((360.0 + CompassValue.get()) % 360.0).tointeger())
let compassValue = boxedTemplate.__merge({
  pos = [pw(0), ph(31)]
  halign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  children = [
    @() textTemplate.__merge({
      watch = CompassIntValue
      text = string.format("%03d", CompassIntValue.get())
    })
  ]
})

let HmdCompassIntValue = Computed(@() ((360.0 + CompassValue.get() + HmdYaw.get()) % 360.0).tointeger())
let hmdCompassValue = {
  pos = [pw(0), ph(39.5)]
  padding = const [hdpx(2), hdpx(20)]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = 0x00000000
  lineWidth = baseLineWidth
  children = [
    @() textTemplate.__merge({
      watch = HmdCompassIntValue
      text = string.format("%03d", HmdCompassIntValue.get())
    })
  ]
  commands = [
    [VECTOR_POLY, 0, 50, 20, 0, 80, 0, 100, 50, 80, 100, 20, 100],
    [VECTOR_LINE, 35, 0, 50, -50, 65, 0]
  ]
}

let isAAMMode = Computed(@() GuidanceLockState.get() != GuidanceLockResult.RESULT_STANDBY)
let AamCancel = Computed(@() TrackerX.get() < sw(37) || TrackerX.get() > sw(65) || TrackerY.get() < sh(35) || TrackerY.get() > sh(70))
function aamReticle(width, height) {
  return @() {
    watch = isAAMMode
    size = ph(1.2)
    children = isAAMMode.get() ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = lockColor
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_RECTANGLE, 0, 0, 100, 100]
        ]
      }
      @(){
        watch = AamCancel
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = lockColor
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

let IsLaunchZoneVisible = Computed(@() isAAMMode.get() && AamLaunchZoneDistMax.get() > 0.0)
let MaxLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMax.get()) * 100.0).tointeger())
let MinLaunchPos = Computed(@() ((1.0 - AamLaunchZoneDistMin.get()) * 100.0).tointeger())
let IsDgftLaunchZoneVisible = Computed(@() AamLaunchZoneDistDgftMax.get() > 0.0)
let MaxLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMax.get()) * 100.0).tointeger())
let MinLaunchDgftPos = Computed(@() ((1.0 - AamLaunchZoneDistDgftMin.get()) * 100.0).tointeger())
let launchZone = @() {
  watch = IsLaunchZoneVisible
  size = const [pw(2), ph(15)]
  pos = [pw(57), ph(52)]
  children = IsLaunchZoneVisible.get() ? [
    @() {
      watch = AamLaunchZoneDist
      size = flex()
      pos = [pw(-100), ph((1.0 - AamLaunchZoneDist.get()) * 100.0)]
      flow = FLOW_HORIZONTAL
      halign = ALIGN_RIGHT
      children = [
        {
          rendObj = ROBJ_VECTOR_CANVAS
          size = const [pw(30), ph(7)]
          lineWidth = baseLineWidth
          color = lightBlueColor
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
        {
          size = flex()
          children = [
            {
              rendObj = ROBJ_VECTOR_CANVAS
              size = flex()
              color = blueColor
              lineWidth = baseLineWidth
              commands = [
                [VECTOR_LINE, -100, 0, 100, 0],
                [VECTOR_LINE, -100, 100, 100, 100],
              ]
            },
            @() {
              watch = [MaxLaunchPos, MinLaunchPos]
              rendObj = ROBJ_VECTOR_CANVAS
              size = flex()
              color = blueColor
              lineWidth = baseLineWidth
              commands = [
                [VECTOR_LINE, -100, MaxLaunchPos.get(), 100, MaxLaunchPos.get()],
                [VECTOR_LINE, -100, MinLaunchPos.get(), 100, MinLaunchPos.get()],
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
                    [VECTOR_LINE, -50, MaxLaunchDgftPos.get(), 50, MaxLaunchDgftPos.get()],
                    [VECTOR_LINE, 50, MaxLaunchDgftPos.get(), 50, MinLaunchDgftPos.get()],
                    [VECTOR_LINE, 50, MinLaunchDgftPos.get(), -50, MinLaunchDgftPos.get()],
                    [VECTOR_LINE, -50, MinLaunchDgftPos.get(), -50, MaxLaunchDgftPos.get()]
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

let IsTargetDirVisible = Computed(@() TrackerVisible.get() ? AamCancel.get() :
 (TATargetVisible.get() ? AimLockLimited.get() : false))
function targetDir(width, height) {
  return @() {
    watch = IsTargetDirVisible
    size = flex()
    children = IsTargetDirVisible.get() ? {
      size = const [pw(4), ph(4)]
      pos = [pw(50), ph(50)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = lockColor
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

let HaveRadarTarget = Computed(@() RadarTargetDist.get() > 0)
let RadarTargetDistValue = Computed(@() (RadarTargetDist.get() * metrToNavMile * 10.0).tointeger())
let radarTargetData = @(){
  pos = const [pw(54), ph(68)]
  size = [pw(5), SIZE_TO_CONTENT]
  watch = HaveRadarTarget
  flow = FLOW_VERTICAL
  children = HaveRadarTarget.get() ? [
    @() textTemplate.__merge({
      watch = RadarTargetDistValue
      text = string.format("R %.1f NM", RadarTargetDistValue.get() * 0.1)
    })
    @() textTemplate.__merge({
      watch = AamTimeToHit
      text = AamTimeToHit.get() > 0.0 ? string.format("T %02d:%02d", floor(AamTimeToHit.get() / 60), AamTimeToHit.get() % 60) : ""
    })
   ] : null
}

let hmd = @(width, height) {
    size = [width, height]
    children = [
      crosshair
      speedData
      baroAlt
      airData
      weaponData
      compassWrap(width, height, generateCompassMark)
      compassValue
      hmdCompassValue
      aamReticle(width, height)
      ccrpReticle(width, height)
      launchZone
      targetDir(width, height)
      radarTargetData
    ]
}

return hmd