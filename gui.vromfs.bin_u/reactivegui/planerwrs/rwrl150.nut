from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")
let { sin, cos, PI } = require("math")

let rwrSetting = require("%rGui/rwrSetting.nut")
let { rwrTargetsTriggers, rwrTargets, CurrentTime } = require("%rGui/twsState.nut")

let { CompassValue } = require("%rGui/planeState/planeFlyState.nut")

let backGroundColor = Color(0, 0, 0, 255)
let color = Color(10, 202, 10, 255)
let iconColor = Color(230, 0, 0, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontSize = 10
}

function createCompass(gridStyle) {
  let compassFontSizeMult = 2.0

  let markAngleStep = 10.0
  let markAngle = PI * markAngleStep / 180.0
  let markDashCount = 360.0 / markAngleStep
  let azimuthMarkLength = 4

  let commands = array(markDashCount).map(@(_, i) [
    VECTOR_LINE,
    50 + cos(i * markAngle) * (100 + azimuthMarkLength),
    50 + sin(i * markAngle) * (100 + azimuthMarkLength),
    50 + cos(i * markAngle) * 100,
    50 + sin(i * markAngle) * 100
  ])

  let textAngleStep = 30.0
  let textMarkAngle = PI * textAngleStep / 180.0
  let textDashCount = 360.0 / textAngleStep
  local azimuthMarks = []
  for (local i = 0; i < textDashCount; ++i) {
    azimuthMarks.append({
      rendObj = ROBJ_TEXT
      pos = [pw(sin(i * textMarkAngle) * 110), ph(-cos(i * textMarkAngle) * 110)],
      size = flex(),
      color = color,
      font = styleText.font,
      fontSize = gridStyle.fontScale * styleText.fontSize * compassFontSizeMult,
      text = (i * textAngleStep * 0.1).tointeger(),
      halign = ALIGN_CENTER,
      valign = ALIGN_CENTER,
      behavior = Behaviors.RtPropUpdate,
      update = @() {
        transform = {
          rotate = CompassValue.get()
        }
      }
    })
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS,
    size = flex(),
    color = color,
    lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
    fillColor = backGroundColor,
    commands = commands,
    children = azimuthMarks,
    behavior = Behaviors.RtPropUpdate,
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
    size = flex(),
    children = [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS,
        color = color,
        lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE,  0,    0,  33,  33],
          [VECTOR_ELLIPSE,  0,    0,  67,  67],
          [VECTOR_ELLIPSE,  0,    0, 100, 100],
          [VECTOR_LINE,     0, -100,   0, 100],
          [VECTOR_LINE,  -100,    0, 100,   0]
        ]
      }
    ]
  }
}

function createRwrGridMarks(gridStyle, settings) {
  let gridFontSizeMult = 2.0
  return {
    size = flex(),
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [ph(30), ph(10)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settings.rangeMax * 0.001 * 0.333)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [ph(64), ph(20)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settings.rangeMax * 0.001 * 0.667)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [ph(95), ph(30)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settings.rangeMax * 0.001 * 1.0)
      })
    ]
  }
}

function calcRwrTargetRadius(target) {
  return 0.1 + target.rangeRel * 0.9
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
      [ VECTOR_LINE,
        (pos[0] - 0.5 * sizeMult) * 100.0,
        (pos[1] - 0.5 * sizeMult) * 100.0,
        (pos[0] + 0.5 * sizeMult) * 100.0,
        (pos[1] - 0.5 * sizeMult) * 100.0 ],
      [ VECTOR_LINE,
        pos[0] * 100.0,
        (pos[1] - 0.50 * sizeMult) * 100.0,
        pos[0] * 100.0,
        (pos[1] - 0.75 * sizeMult) * 100.0 ]
    ]
  else if ( targetType == ThreatType.SAM ||
            targetType == ThreatType.AAA ||
            targetType == null)
    return [
      [ VECTOR_LINE,
        (pos[0] - 0.5 * sizeMult) * 100.0,
        (pos[1] + 0.5 * sizeMult) * 100.0,
        (pos[0] + 0.5 * sizeMult) * 100.0,
        (pos[1] + 0.5 * sizeMult) * 100.0 ],
      [ VECTOR_LINE,
        pos[0] * 100.0,
        (pos[1] + 0.50 * sizeMult) * 100.0,
        pos[0] * 100.0,
        (pos[1] + 0.75 * sizeMult) * 100.0 ]
    ]
  else if (targetType == ThreatType.MSL)
    return [
      [ VECTOR_LINE,
        (pos[0] - 0.25 * sizeMult) * 100.0,
        (pos[1] - 0.50 * sizeMult) * 100.0,
        (pos[0] + 0.25 * sizeMult) * 100.0,
        (pos[1] - 0.50 * sizeMult) * 100.0 ] ]
  else
    return null
}

function createRwrTarget(index, settings, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return null

  let directionGroup = settings.directionGroups?[target.groupId]
  let targetRadiusRel = calcRwrTargetRadius(target)

  let targetSizeMult = target.priority ? 1.5 : 1.0

  let targetTypeFontSizeMult = 2.0
  let targetType = @()
    styleText.__merge({
      rendObj = ROBJ_TEXT
      pos = [pw(target.x * 100.0 * targetRadiusRel), ph(target.y * 100.0 * targetRadiusRel)]
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      color = iconColor
      fontSize = objectStyle.fontScale * styleText.fontSize * targetTypeFontSizeMult * targetSizeMult
      text = directionGroup != null ? directionGroup.text : settings.unknownText
    })

  let iconSizeMult = 0.15 * objectStyle.scale * targetSizeMult
  let iconCommands = makeRwrTargetIconCommands([target.x * targetRadiusRel, target.y * targetRadiusRel], iconSizeMult, directionGroup?.type)
  let attackBoxIconMult = iconSizeMult * 0.75
  if (target.track || target.launch)
    iconCommands.append(
      [ VECTOR_RECTANGLE,
        (target.x * targetRadiusRel - attackBoxIconMult) * 100.0,
        (target.y * targetRadiusRel - attackBoxIconMult) * 100.0,
        attackBoxIconMult * 2 * 100.0, attackBoxIconMult * 2 * 100.0])

  let launchOpacityRwr = Computed(@() target.launch && ((CurrentTime.get() * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0)
  let icon = @() {
    watch = launchOpacityRwr
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = iconColor
    opacity = launchOpacityRwr.get()
    fillColor = 0
    lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
    commands = iconCommands
  }

  return @() {
    size = flex()
    children = [
      {
        pos = [pw(50), ph(50)],
        size = flex(),
        children = [
          icon
        ]
      },
      targetType
    ]
  }
}

let directionGroups = [
  {
    text = "ИСТ",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_ai",
    lethalRangeMax = 5000.0
  },
  {
    text = "БМБ",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_attacker",
    lethalRangeMax = 5000.0
  },
  {
    text = "М21",
    type = ThreatType.AI,
    originalName = "M21"
    lethalRangeMax = 5000.0
  },
  {
    text = "М23",
    type = ThreatType.AI,
    originalName = "M23",
    lethalRangeMax = 40000.0
  },
  {
    text = "М29",
    type = ThreatType.AI,
    originalName = "M29",
    lethalRangeMax = 40000.0
  },
  {
    text = "С34",
    type = ThreatType.AI,
    originalName = "S34",
    lethalRangeMax = 40000.0
  },
  {
    text = "С24",
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
    text = "TRF",
    type = ThreatType.AI,
    originalName = "TRF",
    lethalRangeMax = 30000.0
  },
  {
    text = "M20",
    type = ThreatType.AI,
    originalName = "M2K",
    lethalRangeMax = 40000.0
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
    text = "125",
    originalName = "S125",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "ОСА",
    originalName = "93",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "ТОР",
    originalName = "9K3",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "2С6",
    originalName = "2S6",
    type = ThreatType.SAM,
    lethalRangeMax = 8000.0
  },
  {
    text = "С1",
    originalName = "S1",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "ADS",
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
    text = "ASR",
    originalName = "ASR",
    lethalRangeMax = 8000.0
  },
  {
    text = "ЗА",
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AAA,
    lethalRangeMax = 4000.0
  },
  {
    text = "КРБ",
    originalName = "hud/rwr_threat_naval",
    lethalRangeMax = 16000.0
  },
  {
    text = "РКТ",
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
  return { directionGroups = directionGroupOut, rangeMax = rwrSetting.get().range.y, unknownText = "Н/О" }
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

function scope(scale, style) {
  return {
    size = [pw(scale * style.grid.scale), ph(scale * style.grid.scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      {
        pos = [pw(7), ph(0)],
        size = [pw(90), ph(90)],
        children = [
          {
            size = [pw(100), ph(100)],
            children = [
              rwrTargetsComponent(style.object),
              createRwrGrid(style.grid),
              rwrGridMarksComponent(style.grid)
            ]
          },
          createCompass(style.grid)
        ]
      }
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