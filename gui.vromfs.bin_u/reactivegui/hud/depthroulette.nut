import "%rGui/hudUnitType.nut" as hudUnitType
import "DataBlock" as DataBlock
from "%rGui/shipState.nut" import depthLevel, waterDist, wishDist,
  bottomDist, periscopeCanBeEnabled, periscopeDepthCtrl, maxControlDepth
from "%rGui/shellState.nut" import isAimCamera
from "%rGui/planeState/planeToolsState.nut" import BlkFileName
from "%rGui/hudState.nut" import tacticalMapStates, unitType, isUnitAlive
from "%rGui/options/optionsMeasureUnits.nut" import isInitializedMeasureUnits, measureUnitsNames
from "%rGui/globalState.nut" import isInFlight
from "math" import floor, ceil, round
from "blkLoad" import tryLoadBlk
from "dagor.math" import Point4
from "dagor.workcycle" import clearTimer, resetTimeout
from "%rGui/globals/ui_library.nut" import *

let { hudLogBgColor } = require("%rGui/style/colors.nut").hud


const SMALL_GAP = hdpx(4)
const MEDIUM_GAP = hdpx(8)
const BIG_GAP = hdpx(16)

const WATER_SURFACE_DEPTH = 1.0
const DEF_MAX_DEPTH = 40.0
const VISIBLE_DEPTH = 70.0
const EDGE_MARGIN_DEPTH = 10.0
const SCALE_END_MARGIN_DEPTH = 10.0
const TICK_STEP = 5
const LABEL_STEP = 10
const KEEL_WARN_DIST = 10
const GREEN_DEPTH_COLOR = 0xFF00FF00
const WARN_COLOR = 0xFFFF9900
const ALERT_COLOR = 0xFFC91917
const BASE_COLOR = 0xFFDDDDDD
const ANIM_HIDE_WISH_DEPTH = "hide_wish_depth_anim"
const ANIM_SHOW_WISH_DEPTH = "show_wish_depth_anim"
const markerSize = sh(1.)
const rouletteIconSize = hdpxi(18)
const shVertSpeedHeight = sh(21)
const windowPad = hdpxi(22)
const labelHeight = hdpx(20)
const windowWidth = sh(1.) + hdpx(5) + 1.5 * sh(1) + hdpx(4) + hdpx(30) + hdpxi(16)


let depthLevels = Watched([])
let verticalMoveDir = Watched(0.0)
let isOnWishDepth = Watched(false)
let isWishDepthVisible = Watched(false)
local cachedDepth = 0
let lastDepth = Watched(0.0)

let levelsMaxDepth = Computed(@() depthLevels.get().reduce(@(res, level) max(res, level.depth), -1.0))

let scaleEndDepth = Computed(@() maxControlDepth.get() > 0 ? maxControlDepth.get().tofloat()
  : levelsMaxDepth.get() > 0 ? ceil(levelsMaxDepth.get() / LABEL_STEP) * LABEL_STEP + SCALE_END_MARGIN_DEPTH
  : DEF_MAX_DEPTH)
let visibleDepth = Computed(@() min(VISIBLE_DEPTH, scaleEndDepth.get()))
let pxPerMeter = Computed(@() shVertSpeedHeight / visibleDepth.get())

let scrollDepth = Computed(function() {
  let visible = visibleDepth.get()
  let cur = waterDist.get()
  let wish = max(wishDist.get(), 0.0)
  let lo = min(cur, wish)
  let hi = max(cur, wish)
  let top = hi - lo <= visible - 2 * EDGE_MARGIN_DEPTH ? (lo + hi - visible) * 0.5
    : wish > cur ? wish + EDGE_MARGIN_DEPTH - visible
    : wish - EDGE_MARGIN_DEPTH
  return clamp(round(top), 0.0, max(0.0, scaleEndDepth.get() - visible))
})

let underKeelDist = Computed(@() bottomDist.get() < 0 ? -1
  : max(0, (bottomDist.get() - waterDist.get()).tointeger()))

let isOnWaterSurface = Computed(
  @(prev) prev == FRP_INITIAL
    ? false
    : (wishDist.get() == 0 && prev) || (wishDist.get() == 0 && waterDist.get() <= WATER_SURFACE_DEPTH)
)

let isWishDepthReached = Computed(@() isOnWishDepth.get()
  || ((lastDepth.get() - wishDist.get() <= 0) && waterDist.get() >= wishDist.get())
  || ((lastDepth.get() - wishDist.get() > 0) && waterDist.get() <= wishDist.get()))

isWishDepthReached.subscribe(@(val) val ? isOnWishDepth.set(true) : null)

let needShowWishDepth = Computed(@() !isWishDepthReached.get()
  && isInFlight.get() && verticalMoveDir.get() != 0
  && unitType.get() == "shipEx" && !isOnWaterSurface.get()
)

let styleLine = {
  color = BASE_COLOR
  fillColor = 0
  lineWidth = hdpx(LINE_WIDTH)
}

let styleShipHudText = {
  rendObj = ROBJ_TEXT
  color = BASE_COLOR
  font = Fonts.small_text_hud
  fontFxColor = 0x00000050
  fontFxFactor = 16
  fontFx = FFT_GLOW
}

let styleScaleText = styleShipHudText.__merge({ font = Fonts.very_tiny_text_hud })

function hideWishDepth() {
  if (needShowWishDepth.get())
    return
  isWishDepthVisible.set(false)
  anim_start(ANIM_HIDE_WISH_DEPTH)
}

function startWishDepthAnim(val) {
  if (!val) {
    anim_request_stop(ANIM_SHOW_WISH_DEPTH)
    resetTimeout(2, hideWishDepth)
  } else {
    anim_request_stop(ANIM_HIDE_WISH_DEPTH)
    anim_start(ANIM_SHOW_WISH_DEPTH)
    clearTimer(hideWishDepth)
    isWishDepthVisible.set(true)
  }
}

needShowWishDepth.subscribe(startWishDepthAnim)

let getDirectionValue = @(val) val == 0 ? 0 : val < 0 ? -1 : 1

function onUpdateWaterDist(newDepth) {
  verticalMoveDir.set(getDirectionValue(cachedDepth - newDepth))
  lastDepth.set(cachedDepth)
  cachedDepth = newDepth
}

wishDist.subscribe(@(_val) isOnWishDepth.set(false))

function getDepthColor(depth) {
  let green = depth < 2 ? 255 : 0
  let blue =  depth < 1 ? 255 : 0
  return Color(255, green, blue, 255)
}


let currentDepthColor = Computed(@() getDepthColor(depthLevel.get()))

let depthText = @() styleShipHudText.__merge({
  watch = [currentDepthColor, waterDist]
  color = currentDepthColor.get()
  text = floor(waterDist.get()).tostring()
})

let depthMeasureText = @() styleShipHudText.__merge({
  watch = [isInitializedMeasureUnits, measureUnitsNames, currentDepthColor]
  margin = const [0, 0, hdpx(3), 0]
  color = currentDepthColor.get()
  text = isInitializedMeasureUnits.get() ? loc(measureUnitsNames.get().alt) : ""
  font = Fonts.tiny_text_hud
})

let depthLevelCmp = {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  margin = const [0, BIG_GAP, 0, 0]
  children = [
    depthText
    depthMeasureText
  ]
}


function arrowsIndicator() {
  const arrowSize = [hdpxi(8), hdpxi(4)]
  const arrowsCount = 5
  const height = arrowSize[1] * arrowsCount
  const fullBlinkTime = 1.0
  let direction = verticalMoveDir.get()

  let children = []
  for (local i = 0; i < arrowsCount; i++) {
    let startOpacity = i / arrowsCount.tofloat()
    let firstDelay = startOpacity * fullBlinkTime
    children.append({
      rendObj = ROBJ_IMAGE
      size = const [arrowSize[0], arrowSize[1]]
      pos = [0, arrowSize[1] * (direction > 0 ? (arrowsCount - i - 1) :  i)]
      transform = direction > 0 ? const { rotate = 180 } : null
      animations = [
        { prop = AnimProp.opacity, from = startOpacity, to = 1.0, play = true, duration = firstDelay },
        { prop = AnimProp.opacity, from = 1.0, to = 0.0, loop = true, play = true, easing = CosineFull,
          duration = fullBlinkTime, delay = firstDelay }
      ]
      color = direction < 0 ? 0xff00ff00 : 0xffff0000
      image = Picture($"ui/gameuiskin#depth_arrow.svg:{arrowSize[0]}:{arrowSize[1]}:P")
    })
  }

  return {
    watch = verticalMoveDir
    margin = const [0, hdpx(7), hdpx(7), 0]
    size = const [arrowSize[0], height]
    children
  }
}

let wishDepthText = @() styleShipHudText.__merge(
  {
    watch = [currentDepthColor, wishDist]
    color = currentDepthColor.get()
    halign = ALIGN_RIGHT
    text = floor(max(wishDist.get(), 0)).tostring()
  }
)


let wishDepthComps = @() {
  watch = isWishDepthVisible
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  margin = const [0, MEDIUM_GAP, 0, 0]
  padding = const [SMALL_GAP, MEDIUM_GAP]
  rendObj = ROBJ_SOLID
  color = hudLogBgColor
  children = [
    arrowsIndicator
    wishDepthText
    depthMeasureText
  ]
  opacity = isWishDepthVisible.get() ? 1 : 0
  animations = [
    { prop = AnimProp.opacity, from = 1, to = 0, duration = 1, easing = InOutCubic, trigger = ANIM_HIDE_WISH_DEPTH }
    { prop = AnimProp.opacity, from = 0, to = 1, duration = 1, easing = InOutCubic, trigger = ANIM_SHOW_WISH_DEPTH }
  ]
}

let wishMarkerMaxDepth = Computed(@() maxControlDepth.get() > 0
  ? min(maxControlDepth.get(), scaleEndDepth.get())
  : scaleEndDepth.get())

let wishDepthMarker = @() {
  watch = [wishDist, wishMarkerMaxDepth, pxPerMeter]
  pos = [0, clamp(wishDist.get(), 0.0, wishMarkerMaxDepth.get()) * pxPerMeter.get() - markerSize * 0.5]
  size = const [markerSize, markerSize]
  rendObj = ROBJ_VECTOR_CANVAS
  color = GREEN_DEPTH_COLOR
  fillColor = GREEN_DEPTH_COLOR
  lineWidth = 0
  commands = const [
    [VECTOR_POLY, 0, 0, 100, 50, 0, 100, 0, 0],
  ]
}

function waterDistMarker() {
  let top = scrollDepth.get()
  let bottom = top + visibleDepth.get()
  let depth = waterDist.get()
  let commands = depth < top ? const [[VECTOR_POLY, 0, 100, 50, 0, 100, 100]]
    : depth > bottom ? const [[VECTOR_POLY, 0, 0, 100, 0, 50, 100]]
    : const [[VECTOR_POLY, 0, 0, 100, 50, 0, 100, 0, 0]]
  return {
    watch = [waterDist, scrollDepth, visibleDepth, pxPerMeter]
    pos = const [0, -markerSize * 0.5]
    transform = {
      translate = [0, clamp(depth, top, bottom) * pxPerMeter.get()]
    }
    size = const [markerSize, markerSize]
    color = 0xFFFFFF
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = 0xFFFFFF
    lineWidth = 0
    commands
  }
}


function scaleTicks() {
  let endDepth = scaleEndDepth.get()
  let commands = []
  for (local depth = 0; depth <= endDepth; depth += TICK_STEP) {
    let posY = 100.0 * depth / endDepth
    if (depth % LABEL_STEP == 0) {
      if (depth == endDepth)
        commands.append([ VECTOR_COLOR, ALERT_COLOR ])
      else if (depth == endDepth - LABEL_STEP)
        commands.append([ VECTOR_COLOR, WARN_COLOR ])

      commands.append([ VECTOR_LINE, 25, posY, 32, posY ])
      commands.append([ VECTOR_LINE, 68, posY, 75, posY ])
    }
  }

  return styleLine.__merge({
    watch = [scaleEndDepth, periscopeDepthCtrl]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = hdpx(2)
    commands
  })
}


let mkScaleLabel = @(depth, px, color) {
  pos = [0, depth * px - labelHeight * 0.5]
  size = const [flex(), labelHeight]
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  children = styleScaleText.__merge({ text = depth.tointeger().tostring(), color })
}


function scaleLabels() {
  let endDepth = scaleEndDepth.get()
  let px = pxPerMeter.get()

  let children = []
  for (local depth = LABEL_STEP * 2; depth <= endDepth; depth += LABEL_STEP) {
    let labelColor = depth == endDepth ? ALERT_COLOR
      : depth == endDepth - LABEL_STEP ? WARN_COLOR
      : BASE_COLOR
    children.append(mkScaleLabel(depth, px, labelColor))
  }

  return {
    watch = [scaleEndDepth, pxPerMeter]
    size = flex()
    children
  }
}


let mkLineComp = @(color, pwFactor = 100) {
  size = [pw(pwFactor), hdpxi(2)]
  rendObj = ROBJ_SOLID
  color
}


function periscopeDepthInd() {
  let watch = [ periscopeDepthCtrl, periscopeCanBeEnabled, pxPerMeter ]
  return periscopeDepthCtrl.get() <= 0
    ? { watch }
    : {
        watch
        pos = [0, periscopeDepthCtrl.get() * pxPerMeter.get() - rouletteIconSize + hdpxi(2)]
        size = const [flex(), rouletteIconSize]
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = [
          {
            size = const [rouletteIconSize, rouletteIconSize]
            rendObj = ROBJ_IMAGE
            color = periscopeCanBeEnabled.get() ? GREEN_DEPTH_COLOR : BASE_COLOR
            image = Picture($"ui/gameuiskin#ic_periscope.svg:{rouletteIconSize}:{rouletteIconSize}")
          }
          mkLineComp(GREEN_DEPTH_COLOR, 50)
        ]
      }
}

let isNearWaterSurface = Computed(@() waterDist.get() < 2)

let waterSurfaceInd = @() {
  watch = isNearWaterSurface
  pos = const [0, -rouletteIconSize - hdpxi(5)]
  size = const [flex(), rouletteIconSize]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    {
      size = const [rouletteIconSize, rouletteIconSize]
      rendObj = ROBJ_IMAGE
      color = isNearWaterSurface.get() ? GREEN_DEPTH_COLOR : BASE_COLOR
      image = Picture($"ui/gameuiskin#ic_water_surface.svg:{rouletteIconSize}:{rouletteIconSize}")
    }
    mkLineComp(GREEN_DEPTH_COLOR, 50)
  ]
}

let scrollTransitions = [{ prop = AnimProp.translate, duration = 0.3, easing = OutCubic }]

let scaleContent = @() {
  watch = [scrollDepth, scaleEndDepth, pxPerMeter]
  size = [windowWidth, scaleEndDepth.get() * pxPerMeter.get()]
  pos = const [0, windowPad]
  transform = {
    translate = [0, -scrollDepth.get() * pxPerMeter.get()]
  }
  transitions = scrollTransitions
  children = [
    scaleTicks
    scaleLabels
    waterSurfaceInd
    periscopeDepthInd
    wishDepthMarker
    waterDistMarker
  ]
}

let scaleWindow = {
  size = const [windowWidth, shVertSpeedHeight + 1.3 * windowPad]
  clipChildren = true
  children = scaleContent
}

let depthTextIndicators = {
  size = [0, SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  gap = hdpx(12)
  children = [
    depthLevelCmp
    wishDepthComps
  ]
}


let maxDepthComp = @() {
  watch = scaleEndDepth
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    mkLineComp(ALERT_COLOR, 80)
    styleScaleText.__merge({
      color = ALERT_COLOR
      text = loc("hud/submarine_max_depth", { depth = scaleEndDepth.get() })
    })
  ]
}


function underKeelText() {
  let watch = [underKeelDist, isInitializedMeasureUnits]
  let dist = underKeelDist.get()
  return dist < 0 || !isInitializedMeasureUnits.get()
    ? { watch }
    : styleScaleText.__merge({
        watch
        color = dist < KEEL_WARN_DIST ? WARN_COLOR : BASE_COLOR
        text = loc("hud/submarine_depth_under_keel", { depth = dist })
      })
}


let childrenShVerSpeed = [
  {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = [
      depthTextIndicators
      scaleWindow
    ]
  }
  {
    size = const [windowWidth, 0]
    flow = FLOW_VERTICAL
    gap = hdpxi(5)
    halign = ALIGN_CENTER
    children = [
      maxDepthComp
      underKeelText
    ]
  }
]


let depthIndicator = @() {
  watch = isAimCamera
  pos = const [pw(-100), hdpxi(10)]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = hdpxi(10)
  children = !isAimCamera.get() ? childrenShVerSpeed : null
}


let depthIndicatorContainer = @() {
  watch = tacticalMapStates
  pos = [tacticalMapStates.get().pos[0] - hdpx(16), tacticalMapStates.get().pos[1]]
  children = depthIndicator
}

function shipExSettingsUpd(blk_name) {
  if (!hudUnitType.isSubmarine())
    return

  depthLevels.set([])

  let blk = DataBlock()
  let fileName = $"gamedata/units/{blk_name}.blk"
  if (!tryLoadBlk(blk, fileName))
    return

  let blkMaxDepth = blk.getBlockByName("maxDepth")
  if (!blkMaxDepth)
    return

  let levels = []
  for (local i = 0; i < blkMaxDepth.paramCount(); i++) {
    let val = blkMaxDepth.getParamValue(i)
    if (val instanceof Point4)
      levels.append({ depth = val.x, killProb = val.y })
  }

  levels.sortby(@(a) a.depth)
  depthLevels.set(freeze(levels))
}


BlkFileName.subscribe(shipExSettingsUpd)
waterDist.subscribe(onUpdateWaterDist)

function onUnitAliveChange(isAlive) {
  if (isAlive) {
    lastDepth.set(waterDist.get())
    cachedDepth = waterDist.get()
  }
}

isUnitAlive.subscribe(onUnitAliveChange)

return freeze({
  depthRoulette = depthIndicatorContainer
})
