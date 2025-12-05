from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let string = require("string")
let { floor } = require("math")
let activeOrder = require("%rGui/activeOrder.nut")
let shipStateModule = require("%rGui/shipStateModule.nut")
let hudLogs = require("%rGui/hudLogs.nut")
let fireControl = require("%rGui/submarineFireControl.nut")
let { sonarComponent } = require("%rGui/shipHudComponents.nut")
let { isAimCamera, GimbalX, GimbalY, GimbalSize, altitude, isActiveSensor,
  remainingDist, isOperated, isTrackingTarget, wireLoseTime, isWireConnected,
  IsGimbalVisible, TrackerSize, TrackerX, TrackerY, IsTrackerVisible } = require("%rGui/shellState.nut")
let voiceChat = require("%rGui/chat/voiceChat.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let shipObstacleRf = require("%rGui/shipObstacleRangefinder.nut")
let { depthRoulette } = require("%rGui/hud/depthRoulette.nut")
let styleShipHudText = {
  rendObj = ROBJ_TEXT
  color = Color(255, 255, 255, 255)
  font = Fonts.medium_text_hud
  fontFxColor = Color(0, 0, 0, 80)
  fontFxFactor = 16
  fontFx = FFT_GLOW
}

let shellAimGimbal = function(line_style, color_func) {
  let circle = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = sh(14.0)
    color = color_func()
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, GimbalSize.get(), GimbalSize.get()]
    ]
  })

  return @() {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = SIZE_TO_CONTENT
    watch = [GimbalX, GimbalY, GimbalSize, IsGimbalVisible]
    transform = {
      translate = [GimbalX.get(), GimbalY.get()]
    }
    children = IsGimbalVisible.get() ? [circle] : null
  }
}

let shellAimTracker = function(line_style, color_func) {
  let circle = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = sh(14.0)
    color = color_func()
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, TrackerSize.get() * 0.33, TrackerSize.get() * 0.33]
    ]
  })

  return @() {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = SIZE_TO_CONTENT
    watch = [TrackerX, TrackerY, TrackerSize, IsTrackerVisible]
    transform = {
      translate = [TrackerX.get(), TrackerY.get()]
    }
    children = IsTrackerVisible.get() ? [circle] : null
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
        @() cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(max(0, -altitude.get()), false))
  ]
}

let shellChildren = [
  shellAltitude
  mkShellComp(remainingDist, @() remainingDist.get() <= 0.0 ? "" :
          cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(remainingDist.get()))
  mkShellComp([isOperated, isTrackingTarget],
              @() isOperated.get() ? loc("hud/shell_operated") :
              string.format("%s: %s", loc("hud/shell_homing"), isTrackingTarget.get() ? loc("hud/shell_tracking") : loc("hud/shell_searching")))
  mkShellComp(isActiveSensor, @() isActiveSensor.get() ? loc("activeSonar") : loc("passiveSonar"))
  mkShellComp([wireLoseTime, isWireConnected],
              @() isWireConnected.get() ?
               (wireLoseTime.get() > 0.0 ?
                  string.format("%s: %d", loc("hud/wireMayBeLost"), floor(wireLoseTime.get() + 0.5)) : "") :
              loc("hud/wireIsLost"))
]

function ShipShellState() {
  return {
    watch = isAimCamera
    pos = [sw(60), 0]
    flow = FLOW_VERTICAL
    children = isAimCamera.get() ? shellChildren : null
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
    children = isAimCamera.get() ? shellAimChildren : null
  }
}

let shipHud = @() {
  watch = safeAreaSizeHud
  size = FLEX_V
  margin = safeAreaSizeHud.get().borders
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

let aimHud = {
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = const [sw(100), sh(100)]
  children = [
    ShipShellAimState
  ]
}

return {
  size = flex()
  children = [
    shipHud
    fireControl
    depthRoulette
    ShipShellState
    sonarComponent
    aimHud
    shipObstacleRf
  ]
}