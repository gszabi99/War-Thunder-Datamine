from "%rGui/globals/ui_library.nut" import *

let math = require("math")
let { rwrTargetsTriggers, rwrTargetsPresenceTriggers, rwrTrackingTargetAgeMin, rwrLaunchingTargetAgeMin, mlwsTargetsTriggers, mlwsTargets, mlwsTargetsAgeMin, lwsTargetsTriggers, lwsTargets, rwrTargets, lwsTargetsAgeMin, rwrTargetsPresence, IsMlwsLwsHudVisible, MlwsLwsSignalHoldTimeInv, RwrSignalHoldTimeInv, RwrNewTargetHoldTimeInv, IsRwrHudVisible, LastTargetAge, CurrentTime } = require("twsState.nut")
let rwrSetting = require("rwrSetting.nut")
let { MlwsLwsForMfd, MfdFontScale, RwrForMfd } = require("airState.nut");
let { MfdRadarColor } = require("radarState.nut")
let DataBlock = require("DataBlock")
let { IPoint3 } = require("dagor.math")
let {BlkFileName} = require("%rGui/planeState/planeToolsState.nut")
let { hudFontHgt, isColorOrWhite, fontOutlineFxFactor, greenColor, fontOutlineColor } = require("style/airHudStyle.nut")

let backgroundColor = Color(0, 0, 0, 50)
const RADAR_LINES_OPACITY = 0.42

let indicatorRadius = 70.0
let trackRadarsRadius = 0.04
let azimuthMarkLength = 50 * 3 * trackRadarsRadius

let styleText = {
  color = greenColor
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

let styleLineBackground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH + 1.5)
}

let mfdRwrSettings = Computed(function() {
  let res = {
    textColor = MfdRadarColor.get()
    backgroundColor = Color(0, 0, 0, 255)
    lineColor = MfdRadarColor.get()
    hidePlane = false
    circleCnt = -1
    angleMarkStep = 30.0
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
        textColor = textC.x < 0 ? MfdRadarColor.get() : Color(textC.x, textC.y, textC.z, 255)
        lineColor = lineC.x < 0 ? MfdRadarColor.get() : Color(lineC.x, lineC.y, lineC.z, 255)
        backgroundColor = Color(backC.x, backC.y, backC.z, 255)
        hidePlane = pageBlk.getBool("hidePlaneSymbol", false)
        circleCnt = pageBlk.getInt("circleCnt", -1)
        angleMarkStep = pageBlk.getReal("angleMarkStep", 30)
      }
    }
  }
  return res
})

let targetsCommonOpacity = Computed(@() max(0.0, 1.0 - min(LastTargetAge.value * min(RwrSignalHoldTimeInv.value, MlwsLwsSignalHoldTimeInv.value), 1.0)))

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

  let aircraftIcon = @() styleLineBackground.__merge({
    watch = colorWatched
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(2)
    fillColor = Color(0, 0, 0, 0)
    color = colorWatched.value
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    size = [pw(33 * centralCircleSizeMult), ph(33 * centralCircleSizeMult)]
    pos = [0, 0]
    opacity = RADAR_LINES_OPACITY
    commands = aircraftVectorImageCommands
  })

  return {
    size = flex()
    children = [
      @() styleLineBackground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        fillColor = Color(0, 0, 0, 0)
        color = colorWatched.value
        opacity = targetsCommonOpacity.value
        watch = [targetsCommonOpacity, colorWatched]
        lineWidth = hdpx(LINE_WIDTH)
        commands = [
          [VECTOR_ELLIPSE, 50, 50, indicatorRadius * 0.25 * centralCircleSizeMult, indicatorRadius * 0.25 * centralCircleSizeMult]
        ]
      }),
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
  return styleLineBackground.__merge({
    watch = [targetsOpacity, colorWatched]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH)
    fillColor = backGroundColorEnabled ? backgroundColor : Color(0, 0, 0, 0)
    color = colorWatched.value
    opacity = !isForTank ? 1.0 : targetsOpacity.value
    size = flex()
    commands = circles
  })
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

  return @() styleLineBackground.__merge({
    watch = [targetsOpacity, colorWatch]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    size = flex()
    color = colorWatch.value
    opacity = !isForTank ? RADAR_LINES_OPACITY : targetsOpacity.value * RADAR_LINES_OPACITY
    commands = azimuthMarksCommands
  })
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
    pos = [pw(12), ph(12)]
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
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
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
          lineWidth = hdpx(1)
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
      pos = [pw(0), ph(0)]
      lineWidth = hdpx(30)
      fillColor = Color(0, 0, 0, 0)
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
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity.value
    size = [pw(50), ph(50)]
    pos = [pw(100), ph(100)]
    commands = isForTank ? cmdsLwsTargetTank : cmdsLwsTargetNonTank

    transform = lswTargetTransform

    children = target.enemy ? null
      : {
          color = isColorOrWhite(colorWatched.value)
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = hdpx(1)
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
      pos = [pw(0), ph(0)]
      lineWidth = hdpx(30)
      fillColor = Color(0, 0, 0, 0)
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

function createRwrTarget(index, colorWatched, fontSizeMult, forMfd) {
  let target = rwrTargets[index]

  if (!target.valid)
    return @() { }

  let targetRange = 0.6 + target.rangeRel * 0.4

  let targetOpacityRwr = Computed(@() max(0.0, 1.0 - min(target.age * RwrSignalHoldTimeInv.value, 1.0)) *
    (target.launch && ((CurrentTime.value * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0) *
    (target.show ? 1.0 : 0.2))

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
      watch = [colorWatched]
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1)
      fillColor = Color(0, 0, 0, 0)
      size = [pw(50), ph(50)]
      pos = [pw(85 * targetRange), ph(85 * targetRange)]
      commands = cmdsRwrTarget
      transform = rwrTargetTransform
      children = target.enemy ? null
        : {
            color = isColorOrWhite(colorWatched.value)
            rendObj = ROBJ_VECTOR_CANVAS
            lineWidth = hdpx(1)
            size = flex()
            commands = [[VECTOR_LINE, -20, -40, -20, 40]]
          }
      }

  local trackLine = null
  if (target.track || target.launch) {
    let nearRadius = -140
    let farRadius = target.groupId != null ? nearRadius + 50 * target.rangeRel : nearRadius + 70 * target.rangeRel
    trackLine = @() {
      watch = [colorWatched]
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(50), ph(50)]
      pos = [pw(100), ph(100)]
      lineWidth = hdpx(1)
      commands = [
        [VECTOR_LINE_DASHED, nearRadius, nearRadius, farRadius, farRadius, hdpx(5), hdpx(3)]
      ]
    }
  }

  local sector = null
  if (target.sector > 2.0) {
    sector = @() {
      watch = [targetOpacityRwr, colorWatched]
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(100), ph(100)]
      pos = [pw(0), ph(0)]
      lineWidth = hdpx(35)
      fillColor = Color(0, 0, 0, 0)
      opacity = targetOpacityRwr.value * sectorOpacityMult
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
      watch = [colorWatched]
      color = isColorOrWhite(colorWatched.value)
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1)
      fillColor = Color(0, 0, 0, 0)
      size = [pw(100 * targetRange), ph(100 * targetRange)]
      pos = [pw(0), ph(0)]
      commands = [ [VECTOR_ELLIPSE, 100.0, 0.0, newTargetRadius, newTargetRadius] ]
      transform = rwrTargetTransform
    }
  }

  return @() {
    watch = [targetOpacityRwr]
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
      targetType
    ]
  }
}

function createRwrTargetPresence(index, colorWatched) {
  let targetPresence = rwrTargetsPresence[index]

  let targetOpacityRwr = Computed(@() max(0.0, targetPresence.presents ? 1.0 - min(targetPresence.age * RwrSignalHoldTimeInv.value, 0.9) : 0.1))

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
    watch = [colorWatched]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = hdpx(2)
    color = isColorOrWhite(colorWatched.value)
    fillColor = Color(0, 0, 0, 0)
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

function mlwsTargetsState(colorWatched) {
  let mlwsTargetsStateOpacity = Computed(@() max(0.0, 1.0 - mlwsTargetsAgeMin.value * MlwsLwsSignalHoldTimeInv.value) *
    (((CurrentTime.value * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local targetsState = @()
    styleText.__merge({
      watch = [colorWatched]
      rendObj = ROBJ_TEXT
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      text = loc("hud/mlws_missile")
      color = isColorOrWhite(colorWatched.value)
    })
  local targetsStateBorder = @() {
    watch = [colorWatched]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = hdpx(3)
    color = isColorOrWhite(colorWatched.value)
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_RECTANGLE, 10, 30, 80, 40]
    ]
  }
  return @() {
    watch = [IsMlwsLwsHudVisible, mlwsTargetsStateOpacity]
    pos = [pw(100), IsMlwsLwsHudVisible.value ? ph(-200) : ph(-150)]
    size = flex()
    opacity = mlwsTargetsStateOpacity.value
    children = mlwsTargetsStateOpacity.value > 0.01 ?
      [
        targetsState,
        targetsStateBorder
      ] : []
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
  local targetsState = @()
    styleText.__merge({
      watch = [colorWatched]
      rendObj = ROBJ_TEXT
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      text = loc("hud/lws_laser")
      color = isColorOrWhite(colorWatched.value)
    })
  local targetsStateBorder = @() {
    watch = [colorWatched]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = hdpx(3)
    color = isColorOrWhite(colorWatched.value)
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_RECTANGLE, 10, 30, 80, 40]
    ]
  }
  return @() {
    watch = [IsMlwsLwsHudVisible, lwsTargetsStateOpacity]
    pos = [pw(-100), IsMlwsLwsHudVisible.value ? ph(-200) : ph(-150)]
    size = flex()
    opacity = lwsTargetsStateOpacity.value
    children = lwsTargetsStateOpacity.value > 0.01 ?
      [
        targetsState,
        targetsStateBorder
      ] : []
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
  local targetsState = @()
    styleText.__merge({
      watch = [rwrTargetsLaunch, colorWatched]
      rendObj = ROBJ_TEXT
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      text = rwrTargetsLaunch.value ? loc("hud/rwr_launch") : loc("hud/rwr_track")
      color = isColorOrWhite(colorWatched.value)
    })
  local targetsStateBorder = @() {
    watch = [colorWatched]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = hdpx(2)
    color = isColorOrWhite(colorWatched.value)
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_RECTANGLE, 10, 30, 80, 40]
    ]
  }
  return @() {
    watch = [IsMlwsLwsHudVisible, rwrTargetsStateOpacity]
    pos = [pw(0), IsMlwsLwsHudVisible.value ? ph(-200) : ph(-150)]
    size = flex()
    opacity = rwrTargetsStateOpacity.value
    children = rwrTargetsStateOpacity.value > 0.01 ?
      [
        targetsState,
        targetsStateBorder
      ] : []
  }
}

let rwrTargetsComponent = function(colorWatched, fontSizeMult, forMfd) {
  return @() {
    watch = rwrTargetsTriggers
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, colorWatched, fontSizeMult, forMfd))
  }
}

let rwrTargetsPresenceComponent = function(colorWatched) {
  return @() {
    watch = [rwrTargetsPresenceTriggers]
    size = flex()
    children = rwrTargetsPresence.filter(@(t) t != null).map(@(_, i) createRwrTargetPresence(i, colorWatched))
  }
}

function scope(colorWatched, relativCircleRadius, scale, ratio, needDrawCentralIcon,
    needDrawBackground, fontSizeMult, needAdditionalLights, forMfd, centralCircleSizeMult) {
  let lineColor = forMfd ? Watched(mfdRwrSettings.get().lineColor) : colorWatched
  return {
    size = flex()
    children = [
      twsBackground(colorWatched, !needDrawCentralIcon),
      needDrawBackground ? rwrBackground(lineColor, scale, forMfd) : null,
      needDrawCentralIcon && (!forMfd || !mfdRwrSettings.get().hidePlane) ? centeredAircraftIcon(colorWatched, centralCircleSizeMult) : null,
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
          rwrTargetsComponent(lineColor, fontSizeMult, forMfd)
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