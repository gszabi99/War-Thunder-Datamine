local networkState = require("networkState.nut")
local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local shipState = require("shipState.nut")
local shellState = require("shellState.nut")
local voiceChat = require("chat/voiceChat.nut")
local screenState = require("style/screenState.nut")

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
    color = getDepthColor(shipState.depthLevel.value)
    watch = [shipState.depthLevel, shipState.waterDist]
    halign = ALIGN_RIGHT
    text = ::math.floor(shipState.waterDist.value).tostring()
  })
}
local function wishDistCmp(){
  return styleShipHudText.__merge({
    watch = [shipState.depthLevel, shipState.wishDist]
    color = getDepthColor(shipState.depthLevel.value)
    halign = ALIGN_LEFT
    text = ::math.floor(::max(shipState.wishDist.value, 0)).tostring()
  })
}

local function buoyancyExCmp(){
  local height = sh(1.)
  return styleLine.__merge({
    pos = [-shVertSpeedScaleWidth, -height*0.5]
    transform = {
      translate = [0, shVertSpeedHeight * 0.01 * clamp(50 - shipState.buoyancyEx.value * 50.0, 0, 100)]
    }
    watch = [shipState.depthLevel, shipState.buoyancyEx]
    size = [height, height]
    color = getDepthColor(shipState.depthLevel.value)
    rendObj = ROBJ_VECTOR_CANVAS
    commands = [
      [VECTOR_LINE, 0, 0, 100, 50, 0, 100, 0, 0],
    ]
  })
}
local function depthLevelLineCmp(){
  return styleLine.__merge({
    watch = shipState.depthLevel
    size = [shVertSpeedScaleWidth, shVertSpeedHeight]
    color = getDepthColor(shipState.depthLevel.value)
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
    watch = shellState.isAimCamera
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = hdpx(15)
    children = !shellState.isAimCamera.value ? childrenShVerSpeed : null
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
    styleShipHudText.__merge({text = ::loc("hud/depth" + " ")})
    mkShellComp(shellState.altitude,
        @() ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(max(0, -shellState.altitude.value), false))
  ]
}

local shellAimChildren = [
  shellAltitude
  mkShellComp(shellState.remainingDist, @() shellState.remainingDist.value <= 0.0 ? "" :
          ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(shellState.remainingDist.value))
  mkShellComp(shellState.isOperated, @() shellState.isOperated.value ? ::loc("hud/shell_operated") : ::loc("hud/shell_homing"))
  mkShellComp(shellState.isActiveSensor, @() shellState.isActiveSensor.value ? ::loc("activeSonar") : ::loc("passiveSonar"))
]
local function ShipShellState() {
  return {
    watch = shellState.isAimCamera
    flow = FLOW_VERTICAL
    children = shellState.isAimCamera.value ? shellAimChildren : null
  }
}

local shipHud = @(){
  watch = networkState.isMultiplayer
  size = [SIZE_TO_CONTENT, flex()]
  margin = screenState.safeAreaSizeHud.value.borders
  padding = [0, 0, hdpx(32) + ::fpx(6), 0]
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = ::scrn_tgt(0.5)
  children = [
    voiceChat
    activeOrder
    networkState.isMultiplayer.value ? hudLogs : null
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

return {
  size = flex()
  children = [
    shipHud
    sensorsHud
  ]
}