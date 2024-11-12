from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")
let { floor, sin, cos, PI } = require("math")
let { degToRad, radToDeg } = require("%sqstd/math_ex.nut")

let rwrSetting = require("%rGui/rwrSetting.nut")
let { rwrTargetsTriggers, rwrTargets, RwrNewTargetHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")

let { mpsToKnots, metrToFeet } = require("%rGui/planeIlses/ilsConstants.nut")
let { Speed, Mach, Altitude, Aoa, Overload, Tangage, Roll, CompassValue, FuelInternal } = require("%rGui/planeState/planeFlyState.nut")

let backGroundColor = Color(255, 255, 128, 255)
let color = Color(0, 0, 0, 255)
let iconColor = Color(200, 0, 0, 255)
let sectorColor = Color(195, 205, 195, 255)
let adiSkyColor = Color(200, 240, 240, 255)
let adiGroundColor = Color(240, 200, 150, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontSize = 10
}

function createBackground() {
  return {
    size = flex()
    color = backGroundColor
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = backGroundColor
    commands = [
      [VECTOR_RECTANGLE, -50, -70, 220.0, 220.0]
    ]
  }
}

function createTimeStr(time) {
  let h = floor(time / 3600.0)
  let m = floor((time - h * 3600.0) / 60.0)
  let s = floor(time - h * 3600.0 - m * 60.0)
  return format("%02d:%02d:%02d", h, m, s)
}

function createTimeValue(gridStyle) {
  return @() styleText.__merge({
    pos = [pw(100), 0],
    rendObj = ROBJ_TEXT,
    size = flex(),
    watch = CurrentTime,
    fontSize = gridStyle.fontScale * styleText.fontSize,
    text = createTimeStr(CurrentTime.get()),
    halign = ALIGN_RIGHT,
    valign = ALIGN_CENTER
  })
}

function createCompass(gridStyle) {
  let markAngleStep = 5.0
  let markAngle = PI * markAngleStep / 180.0
  let markDashCount = 360.0 / markAngleStep
  let indicatorRadius = 45
  let azimuthMarkLength = 2

  let commands = array(markDashCount).map(@(_, i) [
    VECTOR_LINE,
    50 + cos(i * markAngle) * (indicatorRadius - ((i % 2 == 0) ? 1.0 : 0.5) * azimuthMarkLength),
    50 + sin(i * markAngle) * (indicatorRadius - ((i % 2 == 0) ? 1.0 : 0.5) * azimuthMarkLength),
    50 + cos(i * markAngle) * indicatorRadius,
    50 + sin(i * markAngle) * indicatorRadius
  ])

  let textAngleStep = 30.0
  let textDashCount = 360.0 / textAngleStep
  local azimuthMarks = []
  for (local i = 0; i < textDashCount; ++i) {
    azimuthMarks.append({
      rendObj = ROBJ_TEXT
      pos = [0, ph(-0.5)],
      size = flex(),
      color = color,
      font = styleText.font,
      fontSize = gridStyle.fontScale * styleText.fontSize,
      text = (i * textAngleStep).tointeger(),
      halign = ALIGN_CENTER,
      transform = {
        rotate = i * textAngleStep,
        pivot = [0.5, 0.5 + 0.005 ]
      }
    })
  }

  return {
    size = [pw(100 * gridStyle.scale), ph(100 * gridStyle.scale)]
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale
    fillColor = backGroundColor
    commands = commands
    children = azimuthMarks
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -CompassValue.get()
      }
    }
  }
}

function createRwrGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)],
    size = [pw(100 * gridStyle.scale), ph(100 * gridStyle.scale)],
    children = [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS,
        color = color,
        lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_ELLIPSE, 0, 0, 25, 25],
          [VECTOR_LINE, 0, -50, 0, -25],
          [VECTOR_LINE, 0,  50, 0,  25],
          [VECTOR_LINE, -50, 0, -25, 0],
          [VECTOR_LINE,  50, 0,  25, 0],
          [VECTOR_LINE, 0, 0, 4, 10, -4, 10, 0, 0, 0, -5]
        ]
      },
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS,
        color = backGroundColor,
        lineWidth = baseLineWidth * 90,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 65.0, 65.0]
        ]
      }
    ]
  }
}

function createRwrGridMarks(gridStyle, settings) {
  let gridFontSizeMult = 1.5
  return {
    size = flex(),
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [0, ph(22.5)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settings.rangeMax * 0.001 * 0.5)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [0, ph(47.5)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settings.rangeMax * 0.001)
      })
    ]
  }
}

function calcRwrTargetRadius(target) {
  return 0.0 + target.rangeRel * 1.0
}

let ThreatType = {
  AI = 0,
  SAM = 1,
  AAA = 2,
  MSL = 3
}

function makeRwrTargetIconCommands(pos, sizeMult, targetType) {
  if (targetType == ThreatType.AI)
    return [
      [ VECTOR_SECTOR,
        pos[0] * 50.0,
        pos[1] * 50.0,
        sizeMult * 0.5 * 50.0,
        sizeMult * 50.0,
        180, 360 ],
      [ VECTOR_LINE,
        (pos[0] - 0.5 * sizeMult) * 50.0,
        pos[1] * 50.0,
        (pos[0] + 0.5 * sizeMult) * 50.0,
        pos[1] * 50.0 ] ]
  else if (targetType == ThreatType.SAM)
    return [
      [ VECTOR_ELLIPSE,
        pos[0] * 50.0,
        pos[1] * 50.0,
        sizeMult * 0.5 * 50.0,
        sizeMult * 50.0 ] ]
  else if ( targetType == ThreatType.AAA ||
            targetType == null)
    return [
      [ VECTOR_SECTOR,
        pos[0] * 50.0,
        pos[1] * 50.0,
        sizeMult * 0.5 * 50.0,
        sizeMult * 50.0,
        0, 180 ],
      [ VECTOR_LINE,
        (pos[0] - 0.5 * sizeMult) * 50.0,
        pos[1] * 50.0,
        (pos[0] + 0.5 * sizeMult) * 50.0,
        pos[1] * 50.0 ] ]
  else if (targetType == ThreatType.MSL)
    return [
      [ VECTOR_ELLIPSE,
        pos[0] * 50.0,
        pos[1] * 50.0,
        sizeMult * 0.5 * 50.0,
        sizeMult * 0.5 * 50.0] ]
  else
    return null
}

function createRwrTarget(index, settings, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return null

  let directionGroup = settings.directionGroups?[target.groupId]
  let targetRadiusRel = calcRwrTargetRadius(target)

  let newTargetFontSizeMultRwr = Computed(@() (target.age0 * RwrNewTargetHoldTimeInv.get() < 1.0 && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 1.5 : 1.0))
  let targetType = @()
    styleText.__merge({
      watch = newTargetFontSizeMultRwr
      rendObj = ROBJ_TEXT
      pos = [pw(target.x * 50.0 * targetRadiusRel), ph(target.y * 50.0 * targetRadiusRel + 6)]
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      color = iconColor
      fontSize = objectStyle.fontScale * styleText.fontSize * newTargetFontSizeMultRwr.get()
      text = directionGroup != null ? directionGroup.text : settings.unknownText
    })

  let iconSizeMult = 0.075 * objectStyle.scale
  let attackOpacityRwr = Computed(@() ( (target.track || target.launch) && ((CurrentTime.get() * (target.launch ? 4.0 : 2.0)).tointeger() % 2) == 0 ? 0.0 : 1.0))
  let icon = @() {
    watch = attackOpacityRwr
    color = iconColor
    opacity = attackOpacityRwr.get()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
    fillColor = 0
    size = flex()
    commands = makeRwrTargetIconCommands([target.x * targetRadiusRel, target.y * targetRadiusRel], iconSizeMult, directionGroup?.type)
  }

  let killRadius = directionGroup != null && directionGroup?.lethalRangeRel != null ?
    @() {
      color = iconColor,
      rendObj = ROBJ_VECTOR_CANVAS,
      lineWidth = baseLineWidth * 2 * objectStyle.lineWidthScale,
      fillColor = 0,
      size = flex(),
      commands = [
        [ VECTOR_ELLIPSE,
          target.x * 50.0 * targetRadiusRel,
          target.y * 50.0 * targetRadiusRel,
          directionGroup.lethalRangeRel * 50.0,
          directionGroup.lethalRangeRel * 50.0] ]
    } : null

  return @() {
    size = flex()
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        children = [
          icon,
          killRadius
        ]
      },
      targetType
    ]
  }
}

let directionGroups = [
  {
    text = "AI",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_ai",
    lethalRangeMax = 5000.0
  },
  {
    text = "ATK",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_attacker",
    lethalRangeMax = 8000.0
  },
  {
    text = "M21",
    type = ThreatType.AI,
    originalName = "M21"
    lethalRangeMax = 5000.0
  },
  {
    text = "M23",
    type = ThreatType.AI,
    originalName = "M23",
    lethalRangeMax = 40000.0
  },
  {
    text = "M29",
    type = ThreatType.AI,
    originalName = "M29",
    lethalRangeMax = 40000.0
  },
  {
    text = "S24",
    type = ThreatType.AI,
    originalName = "S24",
  },
  {
    text = "F4",
    type = ThreatType.AI,
    originalName = "F4",
    lethalRangeMax = 40000.0
  },
  {
    text = "F4E",
    type = ThreatType.AI,
    originalName = "F4E",
    lethalRangeMax = 40000.0
  },
  {
    text = "F4J",
    type = ThreatType.AI,
    originalName = "F4J",
    lethalRangeMax = 40000.0
  },
  {
    text = "F5",
    type = ThreatType.AI,
    originalName = "F5",
    lethalRangeMax = 5000.0
  },
  {
    text = "F14",
    type = ThreatType.AI,
    originalName = "F14",
    lethalRangeMax = 40000.0
  },
  {
    text = "F15",
    type = ThreatType.AI,
    originalName = "F15",
    lethalRangeMax = 40000.0
  },
  {
    text = "F16",
    type = ThreatType.AI,
    originalName = "F16",
    lethalRangeMax = 40000.0
  },
  {
    text = "F18",
    type = ThreatType.AI,
    originalName = "F18",
    lethalRangeMax = 40000.0
  },
  {
    text = "HRR",
    type = ThreatType.AI,
    originalName = "HRR",
    lethalRangeMax = 5000.0
  },
  {
    text = "BCR",
    type = ThreatType.AI,
    originalName = "BCR",
  },
  {
    text = "TRF",
    type = ThreatType.AI,
    originalName = "TRF",
    lethalRangeMax = 30000.0
  },
  {
    text = "M3",
    type = ThreatType.AI,
    originalName = "M3",
    lethalRangeMax = 20000.0
  },
  {
    text = "M5",
    type = ThreatType.AI,
    originalName = "M5",
    lethalRangeMax = 20000.0
  },
  {
    text = "MF1",
    type = ThreatType.AI,
    originalName = "MF1",
    lethalRangeMax = 30000.0
  },
  {
    text = "M20",
    type = ThreatType.AI,
    originalName = "M2K",
    lethalRangeMax = 40000.0
  },
  {
    text = "A32",
    type = ThreatType.AI,
    originalName = "A32",
    lethalRangeMax = 5000.0
  },
  {
    text = "J35",
    type = ThreatType.AI,
    originalName = "J35",
    lethalRangeMax = 5000.0
  },
  {
    text = "J37",
    type = ThreatType.AI,
    originalName = "J37",
    lethalRangeMax = 30000.0
  },
  {
    text = "J39",
    type = ThreatType.AI,
    originalName = "J39",
    lethalRangeMax = 40000.0
  },
  {
    text = "J17",
    type = ThreatType.AI,
    originalName = "J17",
    lethalRangeMax = 40000.0
  },
  //







  {
    text = "SA3",
    originalName = "S125",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "SA8",
    originalName = "93",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "SA15",
    originalName = "9K3",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "SA19",
    originalName = "2S6",
    type = ThreatType.SAM,
    lethalRangeMax = 8000.0
  },
  {
    text = "S1",
    originalName = "S1",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "AD",
    originalName = "ADS",
    lethalRangeMax = 8000.0
  },
  {
    text = "RLD",
    originalName = "RLD",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "CRT",
    originalName = "CRT",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "AR",
    originalName = "ASR",
    lethalRangeMax = 8000.0
  },
  {
    text = "AAA",
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AAA,
    lethalRangeMax = 4000.0
  },
  {
    text = "ZSU",
    originalName = "Z23",
    type = ThreatType.AAA,
    lethalRangeMax = 2500.0
  },
  {
    text = "ZSU",
    originalName = "Z37",
    type = ThreatType.AAA,
    lethalRangeMax = 3500.0
  },
  {
    text = "MSM",
    originalName = "MSM",
    type = ThreatType.AAA,
    lethalRangeMax = 3000.0
  },
  {
    text = "GPD",
    originalName = "GPD",
    type = ThreatType.AAA,
    lethalRangeMax = 3500.0
  },
  {
    text = "NVL",
    originalName = "hud/rwr_threat_naval",
    lethalRangeMax = 16000.0
  },
  {
    text = "MSL",
    originalName = "MSL",
    type = ThreatType.MSL,
  }
]

let settings = Computed(function() {
  let directionGroupOut = array(rwrSetting.get().direction.len())
  for (local i = 0; i < rwrSetting.get().direction.len(); ++i) {
    let direction = rwrSetting.get().direction[i]
    let directionGroupIndex = directionGroups.findindex(@(directionGroup) loc(directionGroup.originalName) == direction.text)
    if (directionGroupIndex != null) {
      let directionGroup = directionGroups[directionGroupIndex]
      directionGroupOut[i] = {
        text = directionGroup?.text
        type = directionGroup?.type
        lethalRangeRel = directionGroup?.lethalRangeMax != null ? (directionGroup.lethalRangeMax - rwrSetting.get().range.x) / (rwrSetting.get().range.y - rwrSetting.get().range.x) : null
      }
    }
  }
  return { directionGroups = directionGroupOut, rangeMax = rwrSetting.get().range.y, unknownText = "UNK" }
})

function rwrGridMarksComponent(gridStyle) {
  return @() {
    watch = settings
    size = flex()
    children = createRwrGridMarks(gridStyle, settings.get())
  }
}

function rwrTargetsComponent(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle))
  }
}

function makeScaleMarks(center, sector, numMarks, markRadius, markLength) {
  let markAngleStep = (sector[1] - sector[0]) / numMarks
  let markAngle = PI * markAngleStep / 180.0
  let angleFrom = degToRad(sector[0])
  let commands = array(numMarks).map(@(_, i) [
    VECTOR_LINE,
    center[0] + sin(angleFrom + i * markAngle) * (markRadius - markLength[i % 2 == 0 ? 0 : 1]),
    center[1] - cos(angleFrom + i * markAngle) * (markRadius - markLength[i % 2 == 0 ? 0 : 1]),
    center[0] + sin(angleFrom + i * markAngle) * markRadius,
    center[1] - cos(angleFrom + i * markAngle) * markRadius
  ])

  return commands
}

function makeScaleTextMarks(gridStyle, center, sector, numMarks, markRadius) {
  let textMarkAngleStep = (sector[1] - sector[0]) / numMarks
  let textMarkAngle = PI * textMarkAngleStep / 180.0
  let textMarks = []
  let angleFrom = degToRad(sector[0])
  for (local i = 0; i < numMarks; ++i) {
    textMarks.append(styleText.__merge({
      rendObj = ROBJ_TEXT
      pos = [
        pw( markRadius * sin(angleFrom + i * textMarkAngle) - center[0]),
        ph(-markRadius * cos(angleFrom + i * textMarkAngle) - center[1])
      ],
      size = flex()
      fontSize = gridStyle.fontScale * styleText.fontSize
      text = i.tointeger()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
    }))
  }
  return textMarks
}

let speedScaleInnerRadius = 30

function createSpeedScale(gridStyle) {
  let commands = makeScaleMarks([0, 0], [0, 360], 18, 100, [8, 4])
  commands.append([VECTOR_ELLIPSE, 0, 0, speedScaleInnerRadius, speedScaleInnerRadius], [VECTOR_ELLIPSE, 0, 0, 100, 100])

  local textMarks = makeScaleTextMarks(gridStyle, [50, 50], [0, 360], 9, 80)
  textMarks.append(styleText.__merge({
    rendObj = ROBJ_TEXT
    pos = [pw(0 - 50), ph(-speedScaleInnerRadius * 0.5 - 50)],
    size = flex()
    fontSize = gridStyle.fontScale * styleText.fontSize
    text = "M"
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
  }))

  return {
    pos = [pw(50), ph(50)],
    size = flex(),
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale
    fillColor = 0
    commands = commands
    children = textMarks
  }
}

let speedMaxInv = 1.0 / 900.0

function createSpeedValueSectorCommands(valueAbs) {
  let valueRel = valueAbs * speedMaxInv
  let valueAngle = 2.0 * PI * valueRel
  let sectorRadius = (100 + speedScaleInnerRadius) * 0.5
  return [
    [ VECTOR_SECTOR, 0, 0, sectorRadius, sectorRadius, 0.0 - 90.0, radToDeg(valueAngle) - 90.0 ]
  ]
}

function createSpeedValueArrowCommands(valueAbs) {
  let valueRel = valueAbs * speedMaxInv
  let valueAngle = 2.0 * PI * valueRel
  return [
    [ VECTOR_LINE,
      0 + sin(valueAngle) * 100,
      0 - cos(valueAngle) * 100,
      0 + sin(valueAngle) * speedScaleInnerRadius,
      0 - cos(valueAngle) * speedScaleInnerRadius]
  ]
}

function createSpeedValues(gridStyle) {
  return @() {
    pos = [pw(50), ph(50)],
    size = flex(),
    children = [
      @() {
        size = flex(),
        watch = Speed,
        color = sectorColor,
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 45
        fillColor = 0
        commands = createSpeedValueSectorCommands(Speed.get() * mpsToKnots)
      },
      @() {
        size = flex(),
        watch = Speed,
        color = color
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 6 * gridStyle.lineWidthScale
        fillColor = 0
        commands = createSpeedValueArrowCommands(Speed.get() * mpsToKnots)
      },
      @() styleText.__merge({
        size = flex()
        watch = Mach,
        rendObj = ROBJ_TEXT
        pos = [pw(0 - 50), ph(speedScaleInnerRadius * 0.4 - 50)],
        fontSize = gridStyle.fontScale * styleText.fontSize
        text = format("%.2f", Mach.get())
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
      })
    ]
  }
}

function createAoaLoadFactorTable(gridStyle) {
  return {
    size = flex(),
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale
    fillColor = 0
    commands = [
      [VECTOR_RECTANGLE, 0, 0, 100, 100],
      [VECTOR_LINE, 0, 50, 100, 50]
    ]
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-40), ph(-20)],
        size = flex()
        fontSize = gridStyle.fontScale * styleText.fontSize
        text = "A"
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-40), ph(30)],
        size = flex()
        fontSize = gridStyle.fontScale * styleText.fontSize
        text = "G"
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
      })
    ]
  }
}

function createAoaLoadFactorValue(gridStyle) {
  let aoaLoadFactorFontScale = 1.2
  return @() {
    size = flex(),
    children = [
      @() styleText.__merge({
        rendObj = ROBJ_TEXT
        watch = Aoa,
        pos = [pw(45), ph(-20)],
        size = flex()
        fontSize = gridStyle.fontScale * styleText.fontSize * aoaLoadFactorFontScale
        text = format("%.f", Aoa.get())
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
      }),
      @() styleText.__merge({
        rendObj = ROBJ_TEXT
        watch = Overload,
        pos = [pw(45), ph(30)],
        size = flex()
        fontSize = gridStyle.fontScale * styleText.fontSize * aoaLoadFactorFontScale
        text = format("%.1f", Overload.get())
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
      })
    ]
  }
}

function createAltitudeScale(gridStyle) {
  let commands = makeScaleMarks([0, 0], [0, 360], 20, 100, [8, 4])
  commands.append([VECTOR_ELLIPSE, 0, 0, 100, 100])

  let textMarks = makeScaleTextMarks(gridStyle, [50, 50], [0, 360], 10, 80)

  return {
    pos = [pw(50), ph(50)],
    size = flex(),
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale
    fillColor = 0
    commands = commands
    children = textMarks
  }
}

let altitudeScaleInnerRadius = 60

function createAltitudeValueCommands(valueAbs) {
  let value1000Abs = valueAbs - floor(valueAbs * 0.001) * 1000.0
  let valueRel = value1000Abs * 0.001
  let valueAngle = 2.0 * PI * valueRel
  return [
    [ VECTOR_LINE,
      0 + sin(valueAngle) * 100,
      0 - cos(valueAngle) * 100,
      0 + sin(valueAngle) * altitudeScaleInnerRadius,
      0 - cos(valueAngle) * altitudeScaleInnerRadius]
  ]
}

function split_100000_1000(value) {
  return floor(value * 0.001)
}

function split_1000(value) {
  return value - floor(value * 0.001) * 1000.0
}

function createAltitudeValue(gridStyle) {
  let altitude10000FontScale = 1.2
  return @() {
    pos = [pw(50), ph(50)],
    size = flex()
    watch = Altitude
    children = [
      {
        size = flex()
        color = color
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 6 * gridStyle.lineWidthScale
        fillColor = 0
        commands = createAltitudeValueCommands(Altitude.get() * metrToFeet)
      },
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-100), ph(-50)],
        size = flex()
        fontSize = gridStyle.fontScale * styleText.fontSize * altitude10000FontScale
        text = format("%.f", split_100000_1000(Altitude.get() * metrToFeet))
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [0, ph(-50)],
        size = flex()
        fontSize = gridStyle.fontScale * styleText.fontSize
        text = format("%03.f", split_1000(Altitude.get() * metrToFeet))
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
      })
    ]
  }
}

let fuelInnerRadius = 35

function createFuelScale(gridStyle) {
  let commands = makeScaleMarks([0, 0], [0, 360], 6, 100, [8, 4])
  commands.append([VECTOR_ELLIPSE, 0, 0, fuelInnerRadius, fuelInnerRadius], [VECTOR_ELLIPSE, 0, 0, 100, 100])

  return {
    pos = [pw(50), ph(50)],
    size = flex(),
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale
    fillColor = 0
    commands = commands
  }
}

function createFuelValueCommands(valueAbs) {
  let valueRel = valueAbs / 2340.0
  let valueAngle = 2.0 * PI * valueRel
  let sectorRadius = (100 + fuelInnerRadius) * 0.5
  return [
    [ VECTOR_SECTOR, 0, 0, sectorRadius, sectorRadius, 0.0 + 90.0, radToDeg(valueAngle) + 90.0 ]
  ]
}

function createFuelValue(gridStyle) {
  return @() {
    pos = [pw(50), ph(50)],
    size = flex()
    watch = FuelInternal
    children = [
      {
        size = flex()
        color = sectorColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 30
        fillColor = 0
        commands = createFuelValueCommands(FuelInternal.get())
      },
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(0 - 50), ph(0 - 50)],
        size = flex()
        fontSize = gridStyle.fontScale * styleText.fontSize
        text = format("%.0f", FuelInternal.get() * 0.1)
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
      })
    ]
  }
}

function createAdiValues(gridStyle) {
  let commands = makeScaleMarks([0, 0], [-90, 120], 6, 50, [-4, -4])
  commands.append([VECTOR_SECTOR, 0, 0, 50, 50, 180, 360])

  return {
    pos = [pw(50), ph(50)],
    size = flex(),
    clipChildren = true,
    children = [
      {
        pos = [pw(50), ph(50)],
        size = [pw(80), ph(80)],
        children = [
          {
            size = flex(),
            rendObj = ROBJ_VECTOR_CANVAS,
            color = adiGroundColor,
            fillColor = adiGroundColor,
            commands = [ [VECTOR_RECTANGLE, -100, 0, 200, 100] ]
          },
          {
            size = flex(),
            rendObj = ROBJ_VECTOR_CANVAS,
            color = backGroundColor,
            fillColor = backGroundColor,
            commands = [
              [VECTOR_POLY, -30,   10, -30 - 5, 20, -30  + 5, 20],
              [VECTOR_POLY,   0,   10,   0 - 5, 20,   0  + 5, 20],
              [VECTOR_POLY,  30,   10,  30 - 5, 20,  30  + 5, 20],
              [VECTOR_POLY, -20,   30, -20 - 5, 40, -20  + 5, 40],
              [VECTOR_POLY,   0,   30,   0 - 5, 40,   0  + 5, 40],
              [VECTOR_POLY,  20,   30,  20 - 5, 40,  20  + 5, 40]
            ]
          },
          {
            size = flex(),
            rendObj = ROBJ_VECTOR_CANVAS,
            color = adiSkyColor,
            fillColor = adiSkyColor,
            commands = [ [VECTOR_RECTANGLE, -100, -100, 200, 100] ]
          },
          {
            size = flex(),
            rendObj = ROBJ_VECTOR_CANVAS,
            color = color
            fillColor = 0,
            lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale,
            commands = array(21).map(@(_, i) [ VECTOR_LINE, -100, 10 * (i - 10), 100, 10 * (i - 10)])
          },
        ],
        transform = {
          translate = [0, 50.0 * Tangage.get() * 0.0111],
          rotate = -Roll.get()
          pivot = [0.0, 0.0]
        },
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [0, 50.0 * Tangage.get() * 0.0111],
            rotate = -Roll.get()
          }
        }
      },
      {
        pos = [pw(50), ph(50)],
        size = [pw(80), ph(80)],
        children = [
          {
            size = flex(),
            rendObj = ROBJ_VECTOR_CANVAS,
            color = backGroundColor,
            fillColor = 0,
            lineWidth = baseLineWidth * 60,
            commands = [ [VECTOR_ELLIPSE, 0, 0, 70, 70] ]
          },
          {
            size = flex(),
            rendObj = ROBJ_VECTOR_CANVAS,
            color = color,
            fillColor = 0,
            lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale,
            commands = commands
          }
        ],
        transform = {
          rotate = -Roll.get(),
          pivot = [0.0, 0.0]
        },
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            rotate = -Roll.get()
          }
        }
      }
    ]
  }
}

function createAdiGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)],
    size = flex(),
    children = [
      {
        size = flex(),
        color = color,
        fillColor = 0,
        rendObj = ROBJ_VECTOR_CANVAS,
        lineWidth = baseLineWidth * 4 * gridStyle.lineWidthScale,
        commands = [
          [VECTOR_LINE, 37, 50, 45, 50],
          [VECTOR_LINE, 55, 50, 63, 50],
          [VECTOR_LINE, 50, 45, 50, 37],
          [VECTOR_ELLIPSE, 50, 50, 5, 5],
          [VECTOR_POLY, 50, 10, 47, 20, 53, 20]
        ]
      },
    ]
  }
}

let obdFontScale = 1.2

function scope(scale, style) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createBackground(),
      {
        pos = [pw(-15), ph(-55)],
        size = [pw(130), ph(130)],
        children = [
          {
            pos = [pw(10), ph(10)],
            size = [pw(80), ph(80)],
            clipChildren = true,
            children = [
              rwrTargetsComponent(style.object),
              createRwrGrid(style.grid),
              rwrGridMarksComponent(style.grid)
            ]
          },
          createCompass(style.grid)
        ]
      },
      {
        pos = [pw(-75), ph(-100)],
        size = flex(),
        children = [
          createTimeValue(style.grid)
        ]
      },
      {
        pos = [pw(-12), ph(55)],
        size = [pw(60), ph(60)],
        children = [
          createAdiValues(style.grid),
          createAdiGrid(style.grid)
        ]
      },
      {
        pos = [pw(-10), ph(90)],
        size = [pw(20), ph(20)],
        children = [
          createSpeedValues(style.grid),
          createSpeedScale(style.grid)
        ]
      },
      {
        pos = [pw(-15), ph(125)],
        size = [pw(15), ph(10)],
        children = [
          createAoaLoadFactorValue(style.grid),
          createAoaLoadFactorTable(style.grid)
        ]
      },
      {
        pos = [pw(85), ph(90)],
        size = [pw(20), ph(20)],
        children = [
          createAltitudeValue(style.grid),
          createAltitudeScale(style.grid)
        ]
      },
      {
        pos = [pw(100), ph(125)],
        size = [pw(12), ph(12)],
        children = [
          createFuelValue(style.grid),
          createFuelScale(style.grid)
        ]
      },
      styleText.__merge({
        pos = [pw(125), ph(45)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "S\r\nT\r\nO\r\nR",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(125), ph(70)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "G\r\nM\r\nM",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(122), ph(92)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "R\r\nA\r\nL\r\nT",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(125), ph(95)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "A\r\nD",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(-27), ph(-47)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "E\r\nM\r\nG\r\nY",
        halign = ALIGN_LEFT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(-27), ph(45)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "S\r\nC\r\nA\r\nL",
        halign = ALIGN_LEFT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(-27), ph(68)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "C\r\nU\r\nR\r\nS",
        halign = ALIGN_LEFT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(-27), ph(91)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "M\r\nE\r\nN\r\nU",
        halign = ALIGN_LEFT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(-24), ph(93)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "D\r\nE\r\nF",
        halign = ALIGN_LEFT,
        valign = ALIGN_CENTER,
      }),
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, style)
  }
}

return tws