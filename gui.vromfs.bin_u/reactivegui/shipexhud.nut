local {floor} = require("math")
local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local {depthLevel, waterDist, wishDist, buoyancyEx} = require("shipState.nut")
local {isAimCamera, GimbalX, GimbalY, GimbalSize, altitude, isActiveSensor,
  remainingDist, isOperated, isTrackingTarget, wireLoseTime, isWireConnected,
  IsGimbalVisible, TrackerSize, TrackerX, TrackerY, IsTrackerVisible} = require("shellState.nut")
local voiceChat = require("chat/voiceChat.nut")
local {safeAreaSizeHud} = require("style/screenState.nut")

local styleLine = {
  color = Color(255, 255, 255, 255)
  fillColor = Color(0, 0, 0, 0)
  opacity = 0.5
  lineWidth = LINE_WIDTH + 1
}
local styleShipHudText = {
  rendObj = ROBJ_DTEXT
  color = Color(255, 255, 255, 255)
  font = Fonts.medium_text_hud
  fontFxColor = Color(0, 0, 0, 80)
  fontFxFactor = 16
  fontFx = FFT_GLOW
}

local function getDepthColor(depth){
  local green = depth < 2 ? 255 : 0
  local blue =  depth < 1 ? 255 : 0
  return Color(255, green, blue, 255)
}


local shVertSpeedScaleWidth = sh(1)
local shVertSpeedHeight = sh(20)

local function depthLevelCmp(){
  return styleShipHudText.__merge({
    color = getDepthColor(depthLevel.value)
    watch = [depthLevel, waterDist]
    halign = ALIGN_RIGHT
    text = floor(waterDist.value).tostring()
  })
}
local function wishDistCmp(){
  return styleShipHudText.__merge({
    watch = [depthLevel, wishDist]
    color = getDepthColor(depthLevel.value)
    halign = ALIGN_LEFT
    text = floor(::max(wishDist.value, 0)).tostring()
  })
}

local function buoyancyExCmp(){
  local height = sh(1.)
  return styleLine.__merge({
    pos = [-shVertSpeedScaleWidth, -height*0.5]
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
local function depthLevelLineCmp(){
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
local childrenShVerSpeed = [
  depthLevelCmp
  { size = [shVertSpeedScaleWidth*3, shVertSpeedScaleWidth] }
  { children = [depthLevelLineCmp, buoyancyExCmp] }
  wishDistCmp
]

local function ShipVertSpeed() {
  return {
    watch = isAimCamera
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = hdpx(15)
    children = !isAimCamera.value ? childrenShVerSpeed : null
  }
}

local shellAimGimbal = function(line_style, color_func) {
  local circle = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    color = color_func()
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, GimbalSize.value, GimbalSize.value]
    ]
  })

  return @(){
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

local shellAimTracker = function(line_style, color_func) {
  local circle = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    color = color_func()
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, TrackerSize.value * 0.33, TrackerSize.value * 0.33]
    ]
  })

  return @(){
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
local function mkShellComp(watches, textCtor){
  return @() styleShipHudText.__merge({
    watch = watches
    text = textCtor()
  })
}

local shellAltitude = {
  flow = FLOW_HORIZONTAL
  children = [
    styleShipHudText.__merge({text = $"{::loc("hud/depth")} "})
    mkShellComp(altitude,
        @() ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(max(0, -altitude.value), false))
  ]
}

local shellChildren = [
  shellAltitude
  mkShellComp(remainingDist, @() remainingDist.value <= 0.0 ? "" :
          ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(remainingDist.value))
  mkShellComp([isOperated, isTrackingTarget],
              @() isOperated.value ? ::loc("hud/shell_operated") :
              ::string.format("%s: %s", ::loc("hud/shell_homing"), isTrackingTarget.value ? ::loc("hud/shell_tracking") : ::loc("hud/shell_searching")))
  mkShellComp(isActiveSensor, @() isActiveSensor.value ? ::loc("activeSonar") : ::loc("passiveSonar"))
  mkShellComp([wireLoseTime, isWireConnected],
              @() isWireConnected.value ?
               (wireLoseTime.value > 0.0 ?
                  ::string.format("%s: %d", ::loc("hud/wireMayBeLost"), floor(wireLoseTime.value + 0.5)) : "") :
              ::loc("hud/wireIsLost"))
]

local function ShipShellState() {
  return {
    watch = isAimCamera
    flow = FLOW_VERTICAL
    children = isAimCamera.value ? shellChildren : null
  }
}

local shellAimColor = Color(255, 255, 255, 250)
local getColor = @() shellAimColor

local styleShellAim = {
  color = shellAimColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * 2.0
}

local shellAimChildren = [
  shellAimGimbal(styleShellAim, getColor)
  shellAimTracker(styleShellAim, getColor)
]

local function ShipShellAimState() {
  return {
    watch = isAimCamera
    children = isAimCamera.value ? shellAimChildren : null
  }
}

local shipHud = @(){
  watch = safeAreaSizeHud
  size = [SIZE_TO_CONTENT, flex()]
  margin = safeAreaSizeHud.value.borders
  padding = [0, 0, hdpx(32) + ::fpx(6), 0]
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = ::scrn_tgt(0.005)
  children = [
    voiceChat
    activeOrder
    hudLogs
    shipStateModule
  ]
}

local sensorsHud = {
  pos = [sw(60), 0]
  size = flex()
  valign = ALIGN_CENTER
  children = [
    ShipVertSpeed
    ShipShellState
  ]
}

local aimHud = {
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
    sensorsHud
    aimHud
  ]
}