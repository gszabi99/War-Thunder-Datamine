from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let string = require("string")
let { floor } = require("math")
let activeOrder = require("activeOrder.nut")
let shipStateModule = require("shipStateModule.nut")
let hudLogs = require("hudLogs.nut")
let { depthLevel, waterDist, wishDist, buoyancyEx, periscopeDepthCtrl } = require("shipState.nut")
let fireControl = require("submarineFireControl.nut")

let { isAimCamera, GimbalX, GimbalY, GimbalSize, altitude, isActiveSensor,
  remainingDist, isOperated, isTrackingTarget, wireLoseTime, isWireConnected,
  IsGimbalVisible, TrackerSize, TrackerX, TrackerY, IsTrackerVisible } = require("shellState.nut")
let voiceChat = require("chat/voiceChat.nut")
let { safeAreaSizeHud } = require("style/screenState.nut")
let shipObstacleRf = require("shipObstacleRangefinder.nut")

let styleLine = {
  color = Color(255, 255, 255, 255)
  fillColor = Color(0, 0, 0, 0)
  opacity = 0.5
  lineWidth = hdpx(LINE_WIDTH)
}
let styleShipHudText = {
  rendObj = ROBJ_TEXT
  color = Color(255, 255, 255, 255)
  font = Fonts.medium_text_hud
  fontFxColor = Color(0, 0, 0, 80)
  fontFxFactor = 16
  fontFx = FFT_GLOW
}

function getDepthColor(depth) {
  let green = depth < 2 ? 255 : 0
  let blue =  depth < 1 ? 255 : 0
  return Color(255, green, blue, 255)
}


let shVertSpeedScaleWidth = sh(1)
let shVertSpeedHeight = sh(20)

function depthLevelCmp() {
  return styleShipHudText.__merge({
    color = getDepthColor(depthLevel.value)
    watch = [depthLevel, waterDist]
    halign = ALIGN_RIGHT
    text = floor(waterDist.value).tostring()
  })
}
function wishDistCmp() {
  return styleShipHudText.__merge({
    watch = [depthLevel, wishDist]
    color = getDepthColor(depthLevel.value)
    halign = ALIGN_LEFT
    text = floor(max(wishDist.value, 0)).tostring()
  })
}

function buoyancyExCmp() {
  let height = sh(1.)
  return styleLine.__merge({
    pos = [-shVertSpeedScaleWidth, -height * 0.5]
    transform = {
      translate = [0, shVertSpeedHeight * 0.01 * clamp(50 - buoyancyEx.value * 50.0, 0, 100)]
    }
    watch = [depthLevel, buoyancyEx]
    size = [height, height]
    color = getDepthColor(depthLevel.value)
    rendObj = ROBJ_VECTOR_CANVAS
    commands = [
      [VECTOR_LINE, 0, 0, 100, 50, 0, 100, 0, 0],
    ]
  })
}
function depthLevelLineCmp() {
  return styleLine.__merge({
    watch = depthLevel
    size = [shVertSpeedScaleWidth, shVertSpeedHeight]
    color = getDepthColor(depthLevel.value)
    rendObj = ROBJ_VECTOR_CANVAS
    halign = ALIGN_RIGHT
    commands = [
      [VECTOR_LINE, 0, 0, 100, 0],
      [VECTOR_LINE, 0, 12.5, 50, 12.5],
      [VECTOR_LINE, 0, 25, 50, 25],
      [VECTOR_LINE, 0, 37.5, 50, 37.5],
      [VECTOR_LINE, 0, 50, 100, 50],
      [VECTOR_LINE, 0, 62.5, 50, 62.5],
      [VECTOR_LINE, 0, 75, 50, 75],
      [VECTOR_LINE, 0, 87.5, 50, 87.5],
      [VECTOR_LINE, 0, 100, 100, 100],
    ]
  })
}

let periscopeIndVisible = Computed(@() wishDist.value.tointeger() == periscopeDepthCtrl.value)
let periscopeDepthInd = @(){
  watch = periscopeIndVisible
  size = SIZE_TO_CONTENT
  children = periscopeIndVisible.value ? [
    @() {
      size = [hdpx(62), hdpx(39)]
      rendObj = ROBJ_IMAGE
      color = Color(255, 255, 255, 255)
      image = Picture($"ui/gameuiskin#hud_periscope.svg:{hdpx(62)}:{hdpx(39)}")
    }] : null
}

let childrenShVerSpeed = [
  depthLevelCmp
  { size = [shVertSpeedScaleWidth * 3, shVertSpeedScaleWidth] }
  { children = [depthLevelLineCmp, buoyancyExCmp] }
  wishDistCmp
  periscopeDepthInd
]

function ShipVertSpeed() {
  return {
    watch = isAimCamera
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = hdpx(15)
    children = !isAimCamera.value ? childrenShVerSpeed : null
  }
}

let shellAimGimbal = function(line_style, color_func) {
  let circle = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    color = color_func()
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, GimbalSize.value, GimbalSize.value]
    ]
  })

  return @() {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = SIZE_TO_CONTENT
    watch = [GimbalX, GimbalY, GimbalSize, IsGimbalVisible]
    transform = {
      translate = [GimbalX.value, GimbalY.value]
    }
    children = IsGimbalVisible.value ? [circle] : null
  }
}

let shellAimTracker = function(line_style, color_func) {
  let circle = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    color = color_func()
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, TrackerSize.value * 0.33, TrackerSize.value * 0.33]
    ]
  })

  return @() {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = SIZE_TO_CONTENT
    watch = [TrackerX, TrackerY, TrackerSize, IsTrackerVisible]
    transform = {
      translate = [TrackerX.value, TrackerY.value]
    }
    children = IsTrackerVisible.value ? [circle] : null
  }
}
function mkShellComp(watches, textCtor) {
  return @() styleShipHudText.__merge({
    watch = watches
    text = textCtor()
  })
}

let shellAltitude = {
  flow = FLOW_HORIZONTAL
  children = [
    styleShipHudText.__merge({ text = $"{loc("hud/depth")} " })
    mkShellComp(altitude,
        @() cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(max(0, -altitude.value), false))
  ]
}

let shellChildren = [
  shellAltitude
  mkShellComp(remainingDist, @() remainingDist.value <= 0.0 ? "" :
          cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(remainingDist.value))
  mkShellComp([isOperated, isTrackingTarget],
              @() isOperated.value ? loc("hud/shell_operated") :
              string.format("%s: %s", loc("hud/shell_homing"), isTrackingTarget.value ? loc("hud/shell_tracking") : loc("hud/shell_searching")))
  mkShellComp(isActiveSensor, @() isActiveSensor.value ? loc("activeSonar") : loc("passiveSonar"))
  mkShellComp([wireLoseTime, isWireConnected],
              @() isWireConnected.value ?
               (wireLoseTime.value > 0.0 ?
                  string.format("%s: %d", loc("hud/wireMayBeLost"), floor(wireLoseTime.value + 0.5)) : "") :
              loc("hud/wireIsLost"))
]

function ShipShellState() {
  return {
    watch = isAimCamera
    flow = FLOW_VERTICAL
    children = isAimCamera.value ? shellChildren : null
  }
}

let shellAimColor = Color(255, 255, 255, 250)
let getColor = @() shellAimColor

let styleShellAim = {
  color = shellAimColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * 2.0
}

let shellAimChildren = [
  shellAimGimbal(styleShellAim, getColor)
  shellAimTracker(styleShellAim, getColor)
]

function ShipShellAimState() {
  return {
    watch = isAimCamera
    children = isAimCamera.value ? shellAimChildren : null
  }
}

let shipHud = @() {
  watch = safeAreaSizeHud
  size = [SIZE_TO_CONTENT, flex()]
  margin = safeAreaSizeHud.value.borders
  padding = [0, 0, hdpx(32) + fpx(6), 0]
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = scrn_tgt(0.005)
  children = [
    voiceChat
    activeOrder
    hudLogs
    shipStateModule
  ]
}

let sensorsHud = {
  pos = [sw(60), 0]
  size = flex()
  valign = ALIGN_CENTER
  children = [
    ShipVertSpeed
    ShipShellState
  ]
}

let aimHud = {
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = [sw(100), sh(100)]
  children = [
    ShipShellAimState
  ]
}

return {
  size = flex()
  children = [
    shipHud
    fireControl
    sensorsHud
    aimHud
    shipObstacleRf
  ]
}