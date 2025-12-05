from "%rGui/globals/ui_library.nut" import *

let { floor, fabs } = require("math")
let { depthLevel, waterDist, wishDist, periscopeCanBeEnabled } = require("%rGui/shipState.nut")
let { isAimCamera } = require("%rGui/shellState.nut")
let hudUnitType = require("%rGui/hudUnitType.nut")
let DataBlock = require("DataBlock")
let { BlkFileName } = require("%rGui/planeState/planeToolsState.nut")
let { Point4 } = require("dagor.math")
let { tacticalMapStates, unitType, isUnitAlive } = require("%rGui/hudState.nut")
let { isInitializedMeasureUnits, measureUnitsNames } = require("%rGui/options/optionsMeasureUnits.nut")
let { hudLogBgColor } = require("%rGui/style/colors.nut").hud
let { isInFlight } = require("%rGui/globalState.nut")

const greenDepthColor = 0x09d90b
const bigLineDepth = 10.0
const WATER_SURFACE_DEPTH = 1.0

let defMaxDepth = 70.0
let maxDepth = Watched(defMaxDepth)
let rouletteMaxDepth = Watched(defMaxDepth)
let periscopeDepth = Watched(0.0)
let verticalMoveDir = Watched(0.0)

let markerSize = sh(1.)
let rouletteIconSize = hdpx(16)
local lastDepth = 0

let shVertSpeedScaleWidth = sh(1)
let shVertSpeedHeight = sh(19)
let defSmallLineStep = sh(18) / 39.0

let isOnWaterSurface = Computed(
  @(prev) prev == FRP_INITIAL
    ? false
    : (wishDist.get() == 0 && prev) || (wishDist.get() == 0 && waterDist.get() <= WATER_SURFACE_DEPTH)
)

let arrowIndicatorIsVisible = Computed(
  @() isInFlight.get() && verticalMoveDir.get() != 0 && unitType.get() == "shipEx" && !isOnWaterSurface.get()
)

let styleLine = {
  color = 0xFFFFFFFF
  fillColor = 0
  lineWidth = hdpx(LINE_WIDTH)
}

let styleShipHudText = {
  rendObj = ROBJ_TEXT
  color = 0xFFFFFFFF
  font = Fonts.medium_text_hud
  fontFxColor = 0x00000050
  fontFxFactor = 16
  fontFx = FFT_GLOW
}

function onUpdateWaterDist(newDepth) {
  let verticalSpeed = lastDepth - newDepth
  let direction = verticalSpeed > 0
    ? 1
    : verticalSpeed < 0 ? -1 : 0

  verticalMoveDir.set(direction)
  lastDepth = newDepth
}

function getDepthColor(depth) {
  let green = depth < 2 ? 255 : 0
  let blue =  depth < 1 ? 255 : 0
  return Color(255, green, blue, 255)
}

let currentDepthColor = Computed(@() getDepthColor(depthLevel.get()))

function wishDepthText() {
  return styleShipHudText.__merge({
    watch = [currentDepthColor, wishDist]
    color = currentDepthColor.get()
    halign = ALIGN_RIGHT
    text = floor(max(wishDist.get(), 0)).tostring()
  })
}

function wishDepthMeasureText() {
  return styleShipHudText.__merge({
    watch = [isInitializedMeasureUnits, measureUnitsNames, currentDepthColor]
    color = currentDepthColor.get()
    text = isInitializedMeasureUnits.get() ? loc(measureUnitsNames.get().alt) : ""
    font = Fonts.small_text_hud
  })
}

let wishDepthComps = {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  padding = [0, hdpx(7), 0, 0]
  children = [wishDepthText, wishDepthMeasureText]
}

function depthText() {
  return styleShipHudText.__merge({
    watch = [currentDepthColor, waterDist]
    color = currentDepthColor.get()
    text = floor(waterDist.get()).tostring()
  })
}

function depthMeasureText() {
  return styleShipHudText.__merge({
    watch = [isInitializedMeasureUnits, measureUnitsNames, currentDepthColor]
    color = currentDepthColor.get()
    text = isInitializedMeasureUnits.get() ? loc(measureUnitsNames.get().alt) : ""
    font = Fonts.small_text_hud
  })
}

function arrowsIndicator() {
  let arrowSize = [hdpxi(8), hdpxi(4)]
  let arrowsCount = 5
  let height = arrowSize[1] * arrowsCount
  let direction = verticalMoveDir.get()
  let fullBlinkTime = 1.0

  let children = []
  if (arrowIndicatorIsVisible.get()) {
    for (local i = 0; i < arrowsCount; i++) {
      let startOpacity = i / arrowsCount.tofloat()
      let firstDelay = startOpacity * fullBlinkTime
      children.append({
        rendObj = ROBJ_IMAGE
        size = [arrowSize[0], arrowSize[1]]
        pos = [0, arrowSize[1] * (direction > 0 ? (arrowsCount - i - 1) :  i)]
        transform = direction > 0 ? { rotate = 180 } : null
        animations = [
          { prop = AnimProp.opacity, from = startOpacity, to = 1.0, play = true, duration = firstDelay },
          { prop = AnimProp.opacity, from = 1.0, to = 0.0, loop = true, play = true, easing = CosineFull,
            duration = fullBlinkTime, delay = firstDelay }
        ]
        color = direction < 0 ? 0xff00ff00 : 0xffff0000
        image = Picture($"ui/gameuiskin#depth_arrow.svg:{arrowSize[0]}:{arrowSize[1]}:P")
      })
    }
  }

  return {
    watch = [verticalMoveDir, arrowIndicatorIsVisible]
    margin = [0, hdpx(7), hdpx(7), 0]
    size = [arrowSize[0], height]
    children
  }
}

function depthLevelCmp() {
  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    halign = ALIGN_RIGHT
    padding = [0, hdpx(7)]
    rendObj = ROBJ_SOLID
    color = hudLogBgColor
    children = [arrowsIndicator, depthText, depthMeasureText]
  }
}

function wishDepthMarker() {
  return {
    watch = [wishDist, rouletteMaxDepth]
    pos = [0, shVertSpeedHeight * ( wishDist.get() / rouletteMaxDepth.get() ) - markerSize * 0.5]
    size = [markerSize, markerSize]
    rendObj = ROBJ_VECTOR_CANVAS
    color = greenDepthColor
    fillColor = greenDepthColor
    lineWidth = 0
    commands = [
      [VECTOR_POLY, 0, 0, 100, 50, 0, 100, 0, 0],
    ]
  }
}

function waterDistMarker() {
  return {
    watch = [waterDist, maxDepth]
    pos = [0, -markerSize * 0.5]
    transform = {
      translate = [0, shVertSpeedHeight * (waterDist.get() / maxDepth.get())]
    }
    size = [markerSize, markerSize]
    color = 0xFFFFFF
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = 0xFFFFFF
    lineWidth = 0
    commands = [
      [VECTOR_POLY, 0, 0, 100, 50, 0, 100, 0, 0],
    ]
  }
}

let markersComps = {
  size = [markerSize, shVertSpeedHeight]
  margin = [0, hdpx(5), 0, 0]
  children = [waterDistMarker, wishDepthMarker]
}

function getDepthLine(depth, posY, minLineDepth, periscopeDepthVal) {
  if (depth == 0)
    return [VECTOR_LINE, 50, posY, 150, posY]

  if (depth % bigLineDepth < 0.1)
    return [VECTOR_LINE, 0, posY, 100, posY]

  if (fabs(depth - periscopeDepthVal) <= minLineDepth/2)
    return [VECTOR_LINE, 50, posY, 150, posY]

  return [VECTOR_LINE, 50, posY, 100, posY]
}

function roulette() {
  let bigLinesCount = rouletteMaxDepth.get().tofloat() / bigLineDepth
  let oneBigLineStep = shVertSpeedHeight / bigLinesCount
  let smallLinesCount = max(1, (oneBigLineStep / defSmallLineStep).tointeger())

  let linesTotal = rouletteMaxDepth.get() / (bigLineDepth / smallLinesCount)
  let oneLineDepth = rouletteMaxDepth.get() / linesTotal

  let canvasCommands = []
  for (local i = 0; i <= linesTotal; i++ ) {
    let posY = i / linesTotal * 100
    canvasCommands.append(getDepthLine(oneLineDepth * i, posY, oneLineDepth, periscopeDepth.get()))
  }

  return styleLine.__merge({
    watch = [rouletteMaxDepth, periscopeDepth]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [shVertSpeedScaleWidth, shVertSpeedHeight]
    lineWidth = hdpx(2)
    commands = canvasCommands
  })
}

let periscopeDepthInd = @(){
  watch = [periscopeDepth, periscopeCanBeEnabled, rouletteMaxDepth]
  size = [rouletteIconSize, rouletteIconSize]
  pos = [1.5 * shVertSpeedScaleWidth + hdpx(10), (periscopeDepth.get() / rouletteMaxDepth.get()) * shVertSpeedHeight - rouletteIconSize/2]
  rendObj = ROBJ_IMAGE
  color = periscopeCanBeEnabled.get() ? greenDepthColor : 0xFFFFFFFF
  image = Picture($"ui/gameuiskin#ic_periscope.svg:{rouletteIconSize}:{rouletteIconSize}")
}

let waterSurfaceInd = @(){
  watch = [waterDist]
  size = [rouletteIconSize, rouletteIconSize]
  pos = [1.5 * shVertSpeedScaleWidth + hdpx(10), -rouletteIconSize * 0.9]
  rendObj = ROBJ_IMAGE
  color = waterDist.get() < 2 ? greenDepthColor : 0xFFFFFFFF
  image = Picture($"ui/gameuiskin#ic_water_surface.svg:{rouletteIconSize}:{rouletteIconSize}")
}

let depthTextIndicators = {
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  gap = hdpx(12)
  margin = [0, hdpx(3), 0, 0]
  children = [
    wishDepthComps
    depthLevelCmp
  ]
}

let childrenShVerSpeed = [
  depthTextIndicators,
  markersComps,
  { children = [roulette, periscopeDepthInd, waterSurfaceInd] }
]

function depthIndicator() {
  return {
    pos = [pw(-100), 0]
    watch = isAimCamera
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    children = !isAimCamera.get() ? childrenShVerSpeed : null
  }
}

function depthIndicatorContainer() {
  return {
    watch = tacticalMapStates
    pos = [tacticalMapStates.get().pos[0] - hdpx(50), tacticalMapStates.get().pos[1]]
    children = depthIndicator
  }
}

function shipExSettingsUpd(blk_name) {
  if (!hudUnitType.isSubmarine()) {
    return
  }

  let blk = DataBlock()
  let fileName = $"gameData/units/{blk_name}.blk"
  if (!blk.tryLoad(fileName))
    return

  let blkMaxDepth = blk.getBlockByName("maxDepth")
  if (blkMaxDepth) {
    let killPoint = blkMaxDepth.getPoint4("kill", Point4(-1, -1, -1 , -1))
    maxDepth.set(killPoint.x)
    rouletteMaxDepth.set(0.0 + max(defMaxDepth, killPoint.x))
  }

  periscopeDepth.set(blk.getReal("periscopeDepth", 0))
}

BlkFileName.subscribe(shipExSettingsUpd)
waterDist.subscribe(onUpdateWaterDist)
isUnitAlive.subscribe(@(v) v ? @() lastDepth = waterDist.get() : null)

return {
  depthRoulette = depthIndicatorContainer
}