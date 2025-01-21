from "%rGui/globals/ui_library.nut" import *

let math = require("math")
let { rwrTargetsTriggers, rwrTargetsPresenceTriggers, rwrTrackingTargetAgeMin, rwrLaunchingTargetAgeMin, mlwsTargetsTriggers, mlwsTargets, mlwsTargetsAgeMin, lwsTargetsTriggers, lwsTargets, rwrTargets, lwsTargetsAgeMin, rwrTargetsPresence, IsMlwsLwsHudVisible, MlwsLwsSignalHoldTimeInv, RwrSignalHoldTimeInv, RwrNewTargetHoldTimeInv, IsRwrHudVisible, LastTargetAge, CurrentTime } = require("twsState.nut")
let rwrSetting = require("rwrSetting.nut")
let { MlwsLwsForMfd, MfdFontScale, RwrForMfd } = require("airState.nut");
let DataBlock = require("DataBlock")
let { IPoint3 } = require("dagor.math")
let { BlkFileName, MfdRwrColor } = require("%rGui/planeState/planeToolsState.nut")
let { hudFontHgt, isColorOrWhite, fontOutlineFxFactor, greenColor, fontOutlineColor } = require("style/airHudStyle.nut")
let { CompassValue } = require("compassState.nut")

let backgroundColor = Color(0, 0, 0, 50)
const RADAR_LINES_OPACITY = 0.42

let indicatorRadius = 70.0
let trackRadarsRadius = 0.04
let azimuthMarkLength = 50 * 3 * trackRadarsRadius
let scaleLineWidth = hdpx(LINE_WIDTH)
let targetLineWidth = hdpx(1)
let sectorLineWidth = hdpx(30)
let targetStateBorder = hdpx(3)

let txtStatePadding = [hdpx(9), hdpx(4), hdpx(6), hdpx(4)]

let styleText = {
  color = greenColor
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

enum centralMarkType {
  plane
  empty
  cross
  bigCross
}

let mfdRwrSettings = Computed(function() {
  let res = {
    textColor = MfdRwrColor.get()
    backgroundColor = Color(0, 0, 0, 255)
    lineColor = MfdRwrColor.get()
    circleCnt = -1
    angleMarkStep = 30.0
    hasCompass = false
    digitalCompass = false
    centralMark = centralMarkType.plane
  }

  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  let cockpitBlk = blk.getBlockByName("cockpit")
  if (!cockpitBlk)
    return res
  let mfdBlk = cockpitBlk.getBlockByName("multifunctionDisplays")
  if (!mfdBlk)
    return res
  for (local i = 0; i < mfdBlk.blockCount(); ++i) {
    let displayBlk = mfdBlk.getBlock(i)
    for (local j = 0; j < displayBlk.blockCount(); ++j) {
      let pageBlk = displayBlk.getBlock(j)
      let typeStr = pageBlk.getStr("type", "")
      if (typeStr != "rwr")
        continue
      let textC = pageBlk.getIPoint3("textColor", IPoint3(-1, -1, -1))
      let lineC = pageBlk.getIPoint3("lineColor", IPoint3(-1, -1, -1))
      let backC = pageBlk.getIPoint3("backgroundColor", IPoint3(0, 0, 0))
      return {
        textColor = textC.x < 0 ? MfdRwrColor.get() : Color(textC.x, textC.y, textC.z, 255)
        lineColor = lineC.x < 0 ? MfdRwrColor.get() : Color(lineC.x, lineC.y, lineC.z, 255)
        backgroundColor = Color(backC.x, backC.y, backC.z, 255)
        circleCnt = pageBlk.getInt("circleCnt", -1)
        angleMarkStep = pageBlk.getReal("angleMarkStep", 30)
        hasCompass = pageBlk.getBool("hasCompass", false)
        digitalCompass = pageBlk.getBool("digitalCompass", false)
        centralMark = centralMarkType?[pageBlk.getStr("centralMark", "plane")] ?? centralMarkType.plane
      }
    }
  }
  return res
})

let targetsCommonOpacity = Computed(@() max(0.0, 1.0 - min(LastTargetAge.value * min(RwrSignalHoldTimeInv.value, MlwsLwsSignalHoldTimeInv.value), 1.0)))

function centeredIcon(colorWatched, centralCircleSizeMult) {
  return {
    size = flex()
    children = [
      @() {
        watch = [targetsCommonOpacity, colorWatched]
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        fillColor = 0
        color = colorWatched.value
        opacity = targetsCommonOpacity.value
        lineWidth = scaleLineWidth
        commands = [
          [VECTOR_ELLIPSE, 50, 50, indicatorRadius * 0.1 * centralCircleSizeMult, indicatorRadius * 0.1 * centralCircleSizeMult]
        ]
      },
      @() {
        watch = colorWatched
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = scaleLineWidth
        fillColor = 0
        color = colorWatched.value
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        size = [pw(10 * centralCircleSizeMult), ph(10 * centralCircleSizeMult)]
        pos = [0, 0]
        opacity = RADAR_LINES_OPACITY
        commands = [
          [VECTOR_LINE, 10, 50, 90, 50],
          [VECTOR_LINE, 50, 10, 50, 90]
        ]
      }
    ]
  }
}

let aircraftVectorImageCommands = (function() {
  let tailW = 25
  let tailH = 10
  let tailOffset1 = 10
  let tailOffset2 = 5
  let tailOffset3 = 25
  let fuselageWHalf = 10
  let wingOffset1 = 45
  let wingOffset2 = 30
  let wingW = 32
  let wingH = 18
  let wingOffset3 = 30
  let noseOffset = 5

  return [
    [VECTOR_POLY,
      // tail left
      50, 100 - tailOffset1,
      50 - tailW, 100 - tailOffset2,
      50 - tailW, 100 - tailOffset2 - tailH,
      50 - fuselageWHalf, 100 - tailOffset3,
      // wing left
      50 - fuselageWHalf, 100 - wingOffset1,
      50 - fuselageWHalf - wingW, 100 - wingOffset2,
      50 - fuselageWHalf - wingW, 100 - wingOffset2 - wingH,
      50 - fuselageWHalf, wingOffset3,
      // nose
      50, noseOffset,
      // wing rigth
      50 + fuselageWHalf, wingOffset3,
      50 + fuselageWHalf + wingW, 100 - wingOffset2 - wingH,
      50 + fuselageWHalf + wingW, 100 - wingOffset2,
      50 + fuselageWHalf, 100 - wingOffset1,
      // tail right
      50 + fuselageWHalf, 100 - tailOffset3,
      50 + tailW, 100 - tailOffset2 - tailH,
      50 + tailW, 100 - tailOffset2
    ]
  ]
}())


function centeredAircraftIcon(colorWatched, centralCircleSizeMult) {
  let lineWidth = hdpx(2)
  let aircraftIcon = @() {
    watch = colorWatched
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth
    fillColor = 0
    color = colorWatched.value
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    size = [pw(10 * centralCircleSizeMult), ph(10 * centralCircleSizeMult)]
    opacity = RADAR_LINES_OPACITY
    commands = aircraftVectorImageCommands
  }

  return {
    size = flex()
    children = [
      @() {
        watch = [targetsCommonOpacity, colorWatched]
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        fillColor = 0
        color = colorWatched.value
        opacity = targetsCommonOpacity.value
        lineWidth = scaleLineWidth
        commands = [
          [VECTOR_ELLIPSE, 50, 50, indicatorRadius * 0.1 * centralCircleSizeMult, indicatorRadius * 0.1 * centralCircleSizeMult]
        ]
      },
      aircraftIcon
    ]
  }
}

let targetsOpacityMult = Computed(@() math.floor((math.sin(CurrentTime.value * 10.0) + 0.5)))
let targetsOpacity = Computed(@() max(0.0, 1.0 - min(LastTargetAge.value * MlwsLwsSignalHoldTimeInv.value, 1.0)) * targetsOpacityMult.value)

let createCircle = @(colorWatched, backGroundColorEnabled, scale = 1.0, isForTank = false, circleCnt = -1) function() {
  local circles = [[VECTOR_ELLIPSE, 50, 50, indicatorRadius * scale, indicatorRadius * scale]]
  if (circleCnt > 1) {
    let step = indicatorRadius / circleCnt
    for (local i = 1; i < circleCnt; ++i) {
      circles.append([VECTOR_ELLIPSE, 50, 50, step * i * scale, step * i * scale])
    }
  }
  return {
    watch = [targetsOpacity, colorWatched]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = scaleLineWidth
    fillColor = backGroundColorEnabled ? backgroundColor : 0
    color = colorWatched.value
    opacity = !isForTank ? 1.0 : targetsOpacity.value
    size = flex()
    commands = circles
  }
}

function createAzimuthMark(colorWatch, scale = 1.0, isForTank = false, angleStep = 30, circles = -1) {
  let angle = math.PI * angleStep / 180.0
  let dashCount = 360.0 / angleStep
  let circleCnt = max(circles, 1)
  let step = indicatorRadius / circleCnt * scale
  let azimuthMarksCommands = array(dashCount * circleCnt).map(@(_, i) [
    VECTOR_LINE,
    50 + math.cos(i * angle) * (step * (i / dashCount + 1).tointeger() - azimuthMarkLength),
    50 + math.sin(i * angle) * (step * (i / dashCount + 1).tointeger() - azimuthMarkLength),
    50 + math.cos(i * angle) * step * (i / dashCount + 1).tointeger(),
    50 + math.sin(i * angle) * step * (i / dashCount + 1).tointeger(),
  ])

  return @() {
    watch = [targetsOpacity, colorWatch]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = targetLineWidth
    fillColor = 0
    size = flex()
    color = colorWatch.value
    opacity = !isForTank ? RADAR_LINES_OPACITY : targetsOpacity.value * RADAR_LINES_OPACITY
    commands = azimuthMarksCommands
  }
}

let twsBackground = @(colorWatched, isForTank = false) function() {

  let res = { watch = [IsMlwsLwsHudVisible, MlwsLwsForMfd] }

  if (!IsMlwsLwsHudVisible.value && !MlwsLwsForMfd.value)
    return res

  return res.__update({
    size = flex()
    children = [
      createCircle(colorWatched, true, 1, isForTank, -1),
      createAzimuthMark(colorWatched, 1, isForTank)
    ]
  })
}

let rwrBackground = @(colorWatched, scale, forMfd) function() {

  let res = { watch = [IsRwrHudVisible, IsMlwsLwsHudVisible] }

  if (!IsRwrHudVisible.value && !RwrForMfd.value)
    return res

  return res.__update({
    size = [pw(75), ph(75)]
    pos = [pw(12.5), ph(12.5)]
    children = [
      createCircle(colorWatched, !IsMlwsLwsHudVisible.value, scale, false, forMfd ? mfdRwrSettings.get().circleCnt : -1)
      createAzimuthMark(colorWatched, scale, false, forMfd ? mfdRwrSettings.get().angleMarkStep : 30.0, forMfd ? mfdRwrSettings.get().circleCnt : -1)
    ]
  })
}

let rocketVector =
  [
    //right stab
    [VECTOR_LINE, -15, -40, -15, -30],
    [VECTOR_LINE, -15, -40, -5, -35],
    [VECTOR_LINE, -15, -30, -5, -25],
    //left stab
    [VECTOR_LINE, 15, -40, 15, -30],
    [VECTOR_LINE, 15, -40, 5, -35],
    [VECTOR_LINE, 15, -30, 5, -25],
    //right stab 2
    [VECTOR_LINE, -15, 0, -15, 10],
    [VECTOR_LINE, -15, 0, -5, 5],
    [VECTOR_LINE, -15, 10, -5, 15],
    //left stab 2
    [VECTOR_LINE, 15, 0, 15, 10],
    [VECTOR_LINE, 15, 0, 5, 5],
    [VECTOR_LINE, 15, 10, 5, 15],
    //rocket tank
    [VECTOR_LINE, -5, -25, -5, 0],
    [VECTOR_LINE, 5, -25, 5, 0],
    [VECTOR_LINE, -5, -35, 5, -35],
    //rocket tank 2
    [VECTOR_LINE, -5, 15, -5, 30],
    [VECTOR_LINE, 5, 15, 5, 30],
    //warhead
    [VECTOR_LINE, -5, 30, 0, 40],
    [VECTOR_LINE, 5, 30, 0, 40]
  ]

const sectorOpacityMult = 0.25

function createMlwsTarget(index, colorWatch) {
  let target = mlwsTargets[index]
  let targetOpacity = Computed(@() max(0.0, 1.0 - min(target.age * MlwsLwsSignalHoldTimeInv.value, 1.0)) * targetsOpacityMult.value)
  let targetComponent = @() {
    watch = [targetOpacity, colorWatch]
    color = isColorOrWhite(colorWatch.value)
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [pw(100), ph(100)]
    size = [pw(50), ph(50)]
    lineWidth = targetLineWidth
    fillColor = 0
    opacity = targetOpacity.value
    transform = {
      pivot = [0.0, 0.0]
      rotate = 135 //toward center
    }
    commands = rocketVector
    children = target.enemy ? null
      : {
          color = isColorOrWhite(colorWatch.value)
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = targetLineWidth
          fillColor = backgroundColor
          opacity = targetOpacity.value
          size = flex()
          commands = [[VECTOR_ELLIPSE, 0, 0, 45, 45]]
        }
  }

  local sector = null
  if (target.sector > 2.0) {
    sector = @() {
      watch = [targetOpacity, colorWatch]
      color = isColorOrWhite(colorWatch.value)
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(100), ph(100)]
      lineWidth = sectorLineWidth
      fillColor = 0
      opacity = targetOpacity.value * sectorOpacityMult
      commands = [
        [VECTOR_SECTOR, 0, 0, 143, 143, 45 - target.sector, 45 + target.sector]
      ]
    }
  }

  return {
    size = flex()
    pos = [pw(50), ph(50)]
    transform = {
      pivot = [0.0, 0.0]
      rotate = math.atan2(target.y, target.x) * (180.0 / math.PI) - 45
    }
    children = [
      targetComponent,
      sector
    ]
  }
}

let cmdsLwsTargetTank = freeze([
  [VECTOR_LINE, 15, 0, 0, 50],
  [VECTOR_LINE, -15, 0, 0, 50],
  [VECTOR_LINE, 15, 0, -15, 0],
])

let cmdsLwsTargetNonTank = freeze([
  [VECTOR_LINE, 0, -25, 0, 5],
  [VECTOR_LINE, 0, 13, 0, 27],
  [VECTOR_LINE, 5, 13, 11, 22],
  [VECTOR_LINE, -5, 13, -11, 22],
  [VECTOR_LINE, -6, 10, -15, 10],
  [VECTOR_LINE, 6, 10, 15, 10]
])

let lswTargetTransform = {
  pivot = [0.0, 0.0]
  rotate = 135.0 //toward center
}

function createLwsTarget(index, colorWatched, isForTank = false) {
  let target = lwsTargets[index]
  let targetOpacity = Computed(@() max(0.0, 1.0 - min(target.age * MlwsLwsSignalHoldTimeInv.value, 1.0)) * targetsOpacityMult.value)
  let targetComponent = @() {
    watch = [targetOpacity, colorWatched]
    color = isColorOrWhite(colorWatched.value)
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = targetLineWidth
    fillColor = 0
    opacity = targetOpacity.value
    size = [pw(50), ph(50)]
    pos = [pw(100), ph(100)]
    commands = isForTank ? cmdsLwsTargetTank : cmdsLwsTargetNonTank

    transform = lswTargetTransform

    children = target.enemy ? null
      : {
          color = isColorOrWhite(colorWatched.value)
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = targetLineWidth
          fillColor = backgroundColor
          opacity = targetOpacity.value
          size = flex()
          commands = [[VECTOR_ELLIPSE, 0, 0, 45, 45]]
        }
  }

  local sector = null
  if (target.sector > 2.0) {
    sector = @() {
      watch = [targetOpacity, colorWatched]
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(100), ph(100)]
      lineWidth = sectorLineWidth
      fillColor = 0
      opacity = targetOpacity.value * sectorOpacityMult
      commands = [
        [VECTOR_SECTOR, 0, 0, 143, 143, -90 - target.sector, -90 + target.sector]
      ]
      transform = lswTargetTransform
    }
  }

  return {
    size = flex()
    pos = [pw(50), ph(50)]
    transform = {
      pivot = [0.0, 0.0]
      rotate = math.atan2(target.y, target.x) * (180.0 / math.PI) - 45
    }
    children = [
      targetComponent,
      sector
    ]
  }
}

let cmdsRwrTarget = [
  [VECTOR_SECTOR, -0, -0, 35, 25, -230, 230],
  [VECTOR_SECTOR, -0, -0, 45, 35, -240, 240],
  [VECTOR_SECTOR, -0, -0, 55, 45, -250, 250]
]

let rwrTargetTransform = {
  pivot = [0.0, 0.0]
  rotate = 45.0
}

function createRwrTarget(target, colorWatched, fontSizeMult, centralCircleSizeMult, forMfd) {
//  let target = rwrTargets[index]

  if (!target.valid)
    return @() { }

  let targetRange = 0.3 + target.rangeRel * 0.7

  let targetOpacityRwr = Computed(@() max(0.0, 1.0 - min(target.age * RwrSignalHoldTimeInv.value, 1.0)) *
    (target.launch && ((CurrentTime.value * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0) *
    (target.show ? 1.0 : 0.2))
  let priorityTargetWidth = target.priority ? 2 : 1
  let priorityTargetOpacity = priorityTargetWidth
  let priorityTargetLineWidth = hdpx(priorityTargetWidth)

  local targetComponent = null
  local targetType = null
  if (target.groupId != null)
    targetType = @()
      styleText.__merge({
        watch = [colorWatched, MfdFontScale]
        rendObj = ROBJ_TEXT
        pos = [pw(target.x * 100.0 * targetRange), ph(target.y * 100.0 * targetRange)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = forMfd ? (fontSizeMult * (MfdFontScale.value > 0.0 ? MfdFontScale.value : 1.0) * hudFontHgt) : hudFontHgt
        text = target.groupId >= 0 && target.groupId < rwrSetting.value.direction.len() ? rwrSetting.value.direction[target.groupId].text : "?"
        color = forMfd ? mfdRwrSettings.get().textColor : isColorOrWhite(colorWatched.value)
      })
  else
    targetComponent = @() {
      watch = colorWatched
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = priorityTargetLineWidth
      fillColor = 0
      size = [pw(50), ph(50)]
      pos = [pw(85 * targetRange), ph(85 * targetRange)]
      commands = cmdsRwrTarget
      transform = rwrTargetTransform
      children = target.enemy ? null
        : {
            color = isColorOrWhite(colorWatched.value)
            rendObj = ROBJ_VECTOR_CANVAS
            lineWidth = priorityTargetLineWidth
            size = flex()
            commands = [[VECTOR_LINE, -20, -40, -20, 40]]
          }
      }

  local trackLine = null
  if (target.track || target.launch) {
    let nearRadius = -175
    let farRadius = target.groupId != null ? nearRadius + 90 * target.rangeRel : nearRadius + 110 * target.rangeRel
    let dashLength = hdpx(5)
    let spaceLength = hdpx(3)
    trackLine = @() {
      watch = colorWatched
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(50), ph(50)]
      pos = [pw(100), ph(100)]
      lineWidth = priorityTargetLineWidth
      commands = [
        [VECTOR_LINE_DASHED, nearRadius, nearRadius, farRadius, farRadius, dashLength, spaceLength]
      ]
    }
  }

  local sector = null
  if (target.sector > 2.0) {
    let lineWidth = hdpx(35)
    sector = @() {
      watch = [targetOpacityRwr, colorWatched]
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(100), ph(100)]
      lineWidth
      fillColor = 0
      opacity = targetOpacityRwr.value * priorityTargetOpacity
      commands = [
        [VECTOR_SECTOR, 0, 0, 100 * targetRange, 100 * targetRange, -target.sector, target.sector]
      ]
      transform = rwrTargetTransform
    }
  }

  local newTarget = null
  local age0 = target.age0
  let age0Rel = age0 * RwrNewTargetHoldTimeInv.value
  if (RwrNewTargetHoldTimeInv.value < 10.0 && age0Rel < 1.0) {
    let newTargetRadius = 20.0 / targetRange
    newTarget = @() {
      watch = colorWatched
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = priorityTargetLineWidth
      fillColor = 0
      size = [pw(100 * targetRange), ph(100 * targetRange)]
      commands = [ [VECTOR_ELLIPSE, 100.0, 0.0, newTargetRadius, newTargetRadius] ]
      transform = rwrTargetTransform
    }
  }

  local iffMark = null
  if (targetType != null && !target.enemy) {
    iffMark = @() {
      watch = colorWatched
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = priorityTargetLineWidth
      fillColor = 0
      size = flex()
      pos = [pw(target.x * 100.0 * targetRange), ph(target.y * 100.0 * targetRange)]
      commands = [[VECTOR_LINE, 40, 35, 60, 35]]
    }
  }

  local elevationMark = null
  if (target.priority) {
    if (target.elev > 0.1)
      elevationMark = @() {
        watch = targetOpacityRwr
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = colorWatched.value
        fillColor = 0
        opacity = targetOpacityRwr.value
        lineWidth = scaleLineWidth * 4
        commands = [
          [VECTOR_SECTOR, 50, 50, indicatorRadius * 0.2 * centralCircleSizeMult, indicatorRadius * 0.2 * centralCircleSizeMult, 180, 360]
        ]
      }
    else if (target.elev < -0.1)
      elevationMark = @() {
        watch = targetOpacityRwr
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = colorWatched.value
        fillColor = 0
        opacity = targetOpacityRwr.value
        lineWidth = scaleLineWidth * 4
        commands = [
          [VECTOR_SECTOR, 50, 50, indicatorRadius * 0.2 * centralCircleSizeMult, indicatorRadius * 0.2 * centralCircleSizeMult, 0, 180]
        ]
      }
  }

  return @() {
    watch = targetOpacityRwr
    size = flex()
    opacity = targetOpacityRwr.value
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        transform = {
          pivot = [0.0, 0.0]
          rotate = math.atan2(target.y, target.x) * (180.0 / math.PI) - 45.0
        }
        children = [
          trackLine,
          sector,
          targetComponent,
          newTarget
        ]
      },
      targetType,
      iffMark,
      elevationMark
    ]
  }
}

function createRwrTargetPresence(index, colorWatched) {
  let targetPresence = rwrTargetsPresence[index]

  let targetOpacityRwr = Computed(@() max(0.0, targetPresence.presents ? 1.0 - min(targetPresence.age * RwrSignalHoldTimeInv.value, 0.9) : 0.1))
  let prioritySizeMult = targetPresence.priority ? 2 : 1
  let priorityLineWidth = hdpx(2 * prioritySizeMult)

  local targetPresenceType = @()
    styleText.__merge({
      watch = [rwrSetting, colorWatched]
      rendObj = ROBJ_TEXT
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      text = index < rwrSetting.value.presence.len() ? rwrSetting.value.presence[index].text : ""
      color = isColorOrWhite(colorWatched.value)
    })
  local targetPresenceBorder = @() {
    watch = colorWatched
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = priorityLineWidth
    color = isColorOrWhite(colorWatched.value)
    fillColor = 0
    commands = [
      [VECTOR_RECTANGLE, 10, 30, 80, 40]
    ]
  }

  let colsMax = 3
  let row = index / colsMax
  let col = index - row * colsMax
  let cols = min(rwrTargetsPresence.len() - row * colsMax, colsMax)

  return @() {
    watch = [IsMlwsLwsHudVisible, targetOpacityRwr]
    pos = [pw((cols - 1) * -42.5 + col * 85), IsMlwsLwsHudVisible.value ? ph(200 + row * 50) : ph(150 + row * 50)]
    size = flex()
    opacity = targetOpacityRwr.value
    children = [
      targetPresenceType,
      targetPresenceBorder
    ]
  }
}

let mkTargetsStateBorder = @(colorWatched) @() {
  watch = colorWatched
  rendObj = ROBJ_BOX
  size = flex()
  borderWidth = targetStateBorder
  borderColor = isColorOrWhite(colorWatched.value)
}

function mlwsTargetsState(colorWatched) {
  let mlwsTargetsStateOpacity = Computed(@() max(0.0, 1.0 - mlwsTargetsAgeMin.value * MlwsLwsSignalHoldTimeInv.value) *
    (((CurrentTime.value * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  let targetsState = @()
    styleText.__merge({
      watch = colorWatched
      rendObj = ROBJ_TEXT
      padding = txtStatePadding
      text = loc("hud/mlws_missile")
      color = isColorOrWhite(colorWatched.value)
    })
  let targetsStateBorder = mkTargetsStateBorder(colorWatched)
  return @() {
    watch = [IsMlwsLwsHudVisible, mlwsTargetsStateOpacity]
    pos = [pw(100), IsMlwsLwsHudVisible.value ? ph(-165) : ph(-115)]
    hplace = ALIGN_CENTER
    opacity = mlwsTargetsStateOpacity.value
    children = mlwsTargetsStateOpacity.value > 0.01
      ? [ targetsState, targetsStateBorder ]
      : null
  }
}

function mlwsTargetsComponent(colorWatch) {

  return @() {
    watch = mlwsTargetsTriggers
    size = flex()
    children = mlwsTargets.filter(@(t) t != null).map(@(_, i) createMlwsTarget(i, colorWatch))
  }
}

function lwsTargetsState(colorWatched) {
  let lwsTargetsStateOpacity = Computed(@() max(0.0, 1.0 - lwsTargetsAgeMin.value * MlwsLwsSignalHoldTimeInv.value) *
    (((CurrentTime.value * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  let targetsState = @()
    styleText.__merge({
      watch = colorWatched
      rendObj = ROBJ_TEXT
      padding = txtStatePadding
      text = loc("hud/lws_laser")
      color = isColorOrWhite(colorWatched.value)
    })
  let targetsStateBorder = mkTargetsStateBorder(colorWatched)
  return @() {
    watch = [IsMlwsLwsHudVisible, lwsTargetsStateOpacity]
    pos = [pw(-100), IsMlwsLwsHudVisible.value ? ph(-165) : ph(-115)]
    hplace = ALIGN_CENTER
    opacity = lwsTargetsStateOpacity.value
    children = lwsTargetsStateOpacity.value > 0.01
      ? [ targetsState, targetsStateBorder ]
      : null
  }
}

function lwsTargetsComponent(colorWatched, isForTank = false) {

  return @() {
    watch = lwsTargetsTriggers
    size = flex()
    children = lwsTargets.filter(@(t) t != null).map(@(_, i) createLwsTarget(i, colorWatched, isForTank))
  }
}

function rwrTargetsState(colorWatched) {
  let rwrTargetsLaunch = Computed(@() rwrLaunchingTargetAgeMin.value * RwrSignalHoldTimeInv.value < 1.0 )
  let rwrTargetsStateOpacity = Computed(@() max(0.0, 1.0 - min(rwrTrackingTargetAgeMin.value, rwrLaunchingTargetAgeMin.value) * RwrSignalHoldTimeInv.value) *
    (rwrTargetsLaunch.value && ((CurrentTime.value * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0) )
  let targetsState = @()
    styleText.__merge({
      watch = [rwrTargetsLaunch, colorWatched]
      rendObj = ROBJ_TEXT
      padding = txtStatePadding
      text = rwrTargetsLaunch.value ? loc("hud/rwr_launch") : loc("hud/rwr_track")
      color = isColorOrWhite(colorWatched.value)
    })
  let targetsStateBorder = mkTargetsStateBorder(colorWatched)
  return @() {
    watch = [IsMlwsLwsHudVisible, rwrTargetsStateOpacity]
    pos = [pw(0), IsMlwsLwsHudVisible.value ? ph(-165) : ph(-115)]
    hplace = ALIGN_CENTER
    opacity = rwrTargetsStateOpacity.value
    children = rwrTargetsStateOpacity.value > 0.01
      ? [ targetsState, targetsStateBorder ]
      : []
  }
}

let rwrTargetsComponent = function(colorWatched, fontSizeMult, centralCircleSizeMult, forMfd) {
  return @() {
    watch = rwrTargetsTriggers
    size = flex()
    children = rwrTargets.map(@(target) createRwrTarget(target, colorWatched, fontSizeMult, centralCircleSizeMult, forMfd))
  }
}

let rwrTargetsPresenceComponent = function(colorWatched) {
  return @() {
    watch = rwrTargetsPresenceTriggers
    size = flex()
    children = rwrTargetsPresence.filter(@(t) t != null).map(@(_, i) createRwrTargetPresence(i, colorWatched))
  }
}

let compass = @(colorWatched, forMfd, scale, angleStep) function() {

  let res = { watch = mfdRwrSettings }

  if (!forMfd || !mfdRwrSettings.get().hasCompass)
    return res

  let angle = math.PI * angleStep / 180.0
  let dashCount = 360.0 / angleStep

  let commands = array(dashCount).map(@(_, i) [
    VECTOR_LINE,
    50 + math.cos(i * angle) * (indicatorRadius + azimuthMarkLength * 0.5),
    50 + math.sin(i * angle) * (indicatorRadius + azimuthMarkLength * 0.5),
    50 + math.cos(i * angle) * indicatorRadius,
    50 + math.sin(i * angle) * indicatorRadius,
  ])

  local azimuthMarks = []
  if (!mfdRwrSettings.get().digitalCompass) {
    azimuthMarks.append(
      {
        rendObj = ROBJ_TEXT
        pos = [pw(48), ph(125)]
        size = [pw(4), SIZE_TO_CONTENT]
        color = mfdRwrSettings.get().textColor
        font = Fonts.hud
        fontSize = 20 * scale
        text = "S"
        halign = ALIGN_CENTER
      }
      {
        rendObj = ROBJ_TEXT
        pos = [pw(48), ph(-32)]
        size = [pw(4), SIZE_TO_CONTENT]
        color = mfdRwrSettings.get().textColor
        font = Fonts.hud
        fontSize = 20 * scale
        text = "N"
        halign = ALIGN_CENTER
      }
      {
        rendObj = ROBJ_TEXT
        pos = [pw(-30), ph(46)]
        size = [SIZE_TO_CONTENT, ph(8)]
        color = mfdRwrSettings.get().textColor
        font = Fonts.hud
        fontSize = 20 * scale
        text = "W"
        valign = ALIGN_CENTER
      }
      {
        rendObj = ROBJ_TEXT
        pos = [pw(125), ph(46)]
        size = [SIZE_TO_CONTENT, ph(8)]
        color = mfdRwrSettings.get().textColor
        font = Fonts.hud
        fontSize = 20 * scale
        text = "E"
        valign = ALIGN_CENTER
      }
    )
  }
  else {
    for (local i = 0; i < dashCount; ++i) {
      azimuthMarks.append({
        rendObj = ROBJ_TEXT
        pos = [pw(40), ph(-33)]
        size = [pw(20), ph(100)]
        color = mfdRwrSettings.get().textColor
        font = Fonts.hud
        fontSize = 20 * scale
        text = (i * angleStep).tointeger()
        halign = ALIGN_CENTER
        transform = {
          rotate = i * angleStep
          pivot = [0.5, 0.5 + 0.33]
        }
      })
    }
  }

  return {
    watch = [mfdRwrSettings, colorWatched]
    size = [pw(75 * scale), ph(75 * scale)]
    pos = [pw(50 - 75 * scale * 0.5), ph(50 - 75 * scale * 0.5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = colorWatched.get()
    fillColor = 0
    lineWidth = 2
    commands
    children = azimuthMarks
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = CompassValue.value
      }
    }
  }
}

function centralCross(colorWatched, centralCircleSizeMult) {
  return @() {
    watch = colorWatched
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = 2
    fillColor = 0
    color = colorWatched.value
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    size = [pw(20 * centralCircleSizeMult), ph(20 * centralCircleSizeMult)]
    opacity = RADAR_LINES_OPACITY
    commands = [
      [VECTOR_LINE, 0, 50, 100, 50],
      [VECTOR_LINE, 50, 0, 50, 100]
    ]
  }
}

function centralBigCross(colorWatched, _centralCircleSizeMult) {
  return @() {
    watch = colorWatched
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = 2
    fillColor = 0
    color = colorWatched.value
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    size = flex()
    opacity = RADAR_LINES_OPACITY
    commands = [
      [VECTOR_LINE, 0, 50, 100, 50],
      [VECTOR_LINE, 50, 0, 50, 100]
    ]
  }
}

function getCentralMark(forMfd, centralMark) {
  if (!forMfd)
    return centeredIcon
  if (centralMark == centralMarkType.plane)
    return centeredAircraftIcon
  else if (centralMark == centralMarkType.empty)
    return null
  else if (centralMark == centralMarkType.cross)
    return centralCross
  else if (centralMark == centralMarkType.bigCross)
    return centralBigCross
  return centeredAircraftIcon
}

function scope(colorWatched, relativCircleRadius, scale, ratio, needDrawCentralIcon,
    needDrawBackground, fontSizeMult, needAdditionalLights, forMfd, centralCircleSizeMult) {
  let lineColor = forMfd ? Computed(@() mfdRwrSettings.get().lineColor) : colorWatched
  return @(){
    watch = mfdRwrSettings
    size = flex()
    children = [
      twsBackground(colorWatched, !needDrawCentralIcon),
      needDrawBackground ? rwrBackground(lineColor, scale, forMfd) : null,
      needDrawCentralIcon ? getCentralMark(forMfd, mfdRwrSettings.get().centralMark)?(colorWatched, centralCircleSizeMult) : null,
      compass(lineColor, forMfd, scale, mfdRwrSettings.get().angleMarkStep),
      {
        size = [pw(relativCircleRadius * scale * ratio), ph(relativCircleRadius * scale)]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        children = [
          needAdditionalLights ? mlwsTargetsState(lineColor) : null
          mlwsTargetsComponent(lineColor)
          needAdditionalLights ? lwsTargetsState(lineColor) : null
          lwsTargetsComponent(lineColor, !needDrawCentralIcon)
          needAdditionalLights ? rwrTargetsState(lineColor) : null
          rwrTargetsComponent(lineColor, fontSizeMult, centralCircleSizeMult, forMfd)
          needAdditionalLights ? rwrTargetsPresenceComponent(lineColor) : null
        ]
      }
    ]
  }
}

let tws = kwarg(function(colorWatched, posWatched, sizeWatched, relativCircleSize = 0, scale = 1.0,
    needDrawCentralIcon = true, needDrawBackground = true, fontSizeMult = 1.0,
    needAdditionalLights = true, forMfd = false, centralCircleSizeMult = 1.0) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.value
    pos = posWatched.value
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(colorWatched, relativCircleSize, scale, sizeWatched.value[0] > 0.0 ? sizeWatched.value[1] / sizeWatched.value[0] : 1.0,
     needDrawCentralIcon, needDrawBackground, fontSizeMult, needAdditionalLights, forMfd, centralCircleSizeMult)
  }
})

return {
  tws
  mfdRwrSettings
}