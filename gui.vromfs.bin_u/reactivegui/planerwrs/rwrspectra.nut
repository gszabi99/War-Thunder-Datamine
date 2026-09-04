import "%rGui/rwrSetting.nut" as rwrSetting
from "%rGui/twsState.nut" import rwrTargetsTriggers, RwrSignalHoldTimeInv, CurrentTime
from "%rGui/planeState/planeFlyState.nut" import CompassValue
from "%rGui/airState.nut" import FlaresCount, ChaffsCount
from "%rGui/planeIlses/ilsConstants.nut" import metrToNavMile
from "string" import format
from "math" import sin, cos, PI
from "%rGui/globals/ui_library.nut" import *

let { rwrTargets, rwrTargetsOrder } = require("%rGui/twsState.nut")



const backGroundColor = Color(0, 0, 0, 255)
const white = Color(255, 255, 255, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = white
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontSize = 10
}

function createCompass(gridStyle) {
  const markAngleStep = 10.0
  const markAngle = PI * markAngleStep / 180.0
  let markDashCount = (360.0 / markAngleStep).tointeger()
  let dotCommands = array(markDashCount / 3 * 2).map(
    @(_, i) [ VECTOR_ELLIPSE, 50 + cos(((i / 2) * 3 + 1 + (i % 2)) * markAngle) * 100, 50 + sin(((i / 2) * 3 + 1 + (i % 2)) * markAngle) * 100, 1, 1 ] )
  let dots = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX,
    color = white,
    lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale
    fillColor = white
    commands = dotCommands
  }

  local childrens = []
  childrens.append(dots)

  const textAngleStep = 30.0
  const textMarkAngle = PI * textAngleStep / 180.0
  const textDashCount = 360.0 / textAngleStep
  const compassFontSizeMult = 2.0
  for (local i = 0; i < textDashCount; ++i) {
    let degrees = (i * textAngleStep).tointeger()
    local txt = ""
    if (degrees == 0)
      txt = "N"
    else if (degrees == 90)
      txt = "E"
    else if (degrees == 180)
      txt = "S"
    else if (degrees == 270)
      txt = "W"
    else
      txt = format("%02d", degrees * 0.1)

    childrens.append({
      rendObj = ROBJ_TEXT
      pos = [pw(sin(i * textMarkAngle) * 100), ph(-cos(i * textMarkAngle) * 100)],
      size = FLEX,
      color = white,
      font = styleText.font,
      fontSize = gridStyle.fontScale * styleText.fontSize * compassFontSizeMult,
      text = txt,
      halign = ALIGN_CENTER,
      valign = ALIGN_CENTER,
      transform = {
        rotate = i * textAngleStep
      }
    })
  }

  let gapCommands = array(markDashCount).map(@(_, i) [ VECTOR_ELLIPSE, 50 + cos(i * markAngle) * 100, 50 + sin(i * markAngle) * 100, (i % 3 == 0) ? 7 : 2, (i % 3 == 0) ? 7 : 2 ] )
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX,
    color = backGroundColor,
    lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale
    fillColor = backGroundColor
    commands = gapCommands
    children = childrens
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -CompassValue.get()
      }
    }
  }
}

function createRwrGrid(gridStyle) {
  const blue = Color(0, 128, 255, 255)
  let gridLineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale
  return {
    pos = const [pw(50), ph(50)],
    size = FLEX,
    children = [
      {
        size = FLEX
        rendObj = ROBJ_VECTOR_CANVAS,
        color = white,
        lineWidth = gridLineWidth,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 100, 100],
          [VECTOR_LINE,  10,  10,  20,  20],
          [VECTOR_LINE,  10, -10,  20, -20],
          [VECTOR_LINE, -10,  10, -20,  20],
          [VECTOR_LINE, -10, -10, -20, -20]
        ]
      },
      {
        size = FLEX
        rendObj = ROBJ_VECTOR_CANVAS,
        color = blue,
        lineWidth = gridLineWidth,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_ELLIPSE, 0, 0, 120, 120]
        ]
      }
    ]
  }
}

function calcRwrTargetRadius(target) {
  return 0.1 + target.rangeRel * 0.9
}

function createRwrTarget(index, settingsIn, objectStyle) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return null

  let directionGroup = settingsIn.directionGroups?[target.groupId]
  let targetRadiusRel = calcRwrTargetRadius(target)

  let iconSizeMult = 0.2 * objectStyle.scale
  const iconColor = Color(230, 20, 20, 255)

  const targetTypeFontSizeMult = 2.0
  local targetTypeText = styleText.__merge({
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    color = iconColor
    fontSize = objectStyle.fontScale * styleText.fontSize * targetTypeFontSizeMult
    text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    padding = 2
  })
  let targetTypeTextSize = calc_comp_size(targetTypeText)
  local targetType = @() {
    rendObj = ROBJ_SOLID
    color = backGroundColor
    pos = [pw(target.x * 100.0 * targetRadiusRel - 0.125 * targetTypeTextSize[0]), ph(target.y * 100.0 * targetRadiusRel - 0.125 * targetTypeTextSize[1])]
    children = targetTypeText
  }

  let iconCommands = [
    [ VECTOR_POLY,
      target.x * targetRadiusRel * 100.0,
      target.y * targetRadiusRel * 100.0 - 0.5 * iconSizeMult * 100.0,
      target.x * targetRadiusRel * 100.0 - 0.5 * iconSizeMult * 100.0,
      target.y * targetRadiusRel * 100.0,
      target.x * targetRadiusRel * 100.0,
      target.y * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 100.0,
      target.x * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 100.0,
      target.y * targetRadiusRel * 100.0 ]
  ]

  let iconBackground = @() {
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX
    color = backGroundColor
    fillColor = backGroundColor
    lineWidth = baseLineWidth * (4 + 6) * objectStyle.lineWidthScale
    commands = iconCommands
  }

  const iconBorderColor = white
  let iconLineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale

  let ageOpacity = Computed(@() (target.age * RwrSignalHoldTimeInv.get() < 0.25 ? 1.0 : 0.1))
  let icon = @() {
    watch = ageOpacity
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX
    color = iconColor
    opacity = ageOpacity.get()
    fillColor = 0
    lineWidth = iconLineWidth
    commands = iconCommands
  }

  let launchMarkSize = [0.075 * iconSizeMult, 0.15 * iconSizeMult]
  let trackMarkSize = launchMarkSize[1]
  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  let attack = target.track || target.launch ? @() {
    watch = [ageOpacity, attackOpacityRwr]
    opacity = ageOpacity.get() * attackOpacityRwr.get()
    size = FLEX
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = iconLineWidth
        color = iconBorderColor
        fillColor = iconBorderColor
        size = FLEX
        commands = target.launch ? [
          [ VECTOR_RECTANGLE,
            target.x * targetRadiusRel * 100.0 - 0.5 * (iconSizeMult + launchMarkSize[0]) * 100.0,
            target.y * targetRadiusRel * 100.0 - 0.5 * launchMarkSize[1] * 100.0,
            launchMarkSize[0] * 100.0, launchMarkSize[1] * 100.0 ],
          [ VECTOR_RECTANGLE,
            target.x * targetRadiusRel * 100.0 + 0.5 * (iconSizeMult - launchMarkSize[0]) * 100.0,
            target.y * targetRadiusRel * 100.0 - 0.5 * launchMarkSize[1] * 100.0,
            launchMarkSize[0] * 100.0, launchMarkSize[1] * 100.0 ],
          [ VECTOR_RECTANGLE,
            target.x * targetRadiusRel * 100.0 - 0.5 * launchMarkSize[1] * 100.0,
            target.y * targetRadiusRel * 100.0 - 0.5 * (iconSizeMult + launchMarkSize[0]) * 100.0,
            launchMarkSize[1] * 100.0, launchMarkSize[0] * 100.0 ],
          [ VECTOR_RECTANGLE,
            target.x * targetRadiusRel * 100.0 - 0.5 * launchMarkSize[1] * 100.0,
            target.y * targetRadiusRel * 100.0 + 0.5 * (iconSizeMult - launchMarkSize[0]) * 100.0,
            launchMarkSize[1] * 100.0, launchMarkSize[0] * 100.0  ]
        ] :
        [
          [ VECTOR_LINE,
            target.x * targetRadiusRel * 100.0 - 0.5 * (iconSizeMult - trackMarkSize) * 100.0,
            target.y * targetRadiusRel * 100.0 - 0.5 * trackMarkSize * 100.0,
            target.x * targetRadiusRel * 100.0 - 0.5 * (iconSizeMult - trackMarkSize) * 100.0,
            target.y * targetRadiusRel * 100.0 + 0.5 * trackMarkSize * 100.0 ],
          [ VECTOR_LINE,
            target.x * targetRadiusRel * 100.0 + 0.5 * (iconSizeMult - trackMarkSize) * 100.0,
            target.y * targetRadiusRel * 100.0 - 0.5 * trackMarkSize * 100.0,
            target.x * targetRadiusRel * 100.0 + 0.5 * (iconSizeMult - trackMarkSize) * 100.0,
            target.y * targetRadiusRel * 100.0 + 0.5 * trackMarkSize * 100.0 ]
        ]
      },
      {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = iconLineWidth
        color = iconColor
        fillColor = 0
        size = FLEX
        commands = [
          target.launch ? [ VECTOR_LINE, 0.0, 0.0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0 ] :
            [ VECTOR_LINE_DASHED, 0.0, 0.0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0, 5, 10 ]
        ]
      }
    ]
  } : null

  return @() {
    pos = const [pw(50), ph(50)],
    size = FLEX,
    children = [
      iconBackground,
      targetType,
      icon,
      attack
    ]
  }
}

let directionGroups = [
  {
    text = "FTR",
    originalName = "hud/rwr_threat_ai"
  },
  {
    text = "ATK",
    originalName = "hud/rwr_threat_attacker"
  },
  {
    text = "M21",
    originalName = "M21"
  },
  {
    text = "M23",
    originalName = "M23"
  },
  {
    text = "M29",
    originalName = "M29"
  },
  {
    text = "34",
    originalName = "S34"
  },
  {
    text = "30",
    originalName = "S30"
  },
  {
    text = "F4",
    originalName = "F4"
  },
  {
    text = "F5",
    originalName = "F5"
  },
  {
    text = "F14",
    originalName = "F14"
  },
  {
    text = "F15",
    originalName = "F15"
  },
  {
    text = "F16",
    originalName = "F16"
  },
  {
    text = "F18",
    originalName = "F18"
  },
  {
    text = "HRR",
    originalName = "HRR"
  },
  {
    text = "E2K",
    originalName = "E2K",
  },
  {
    text = "TRF",
    originalName = "TRF"
  },
  {
    text = "M20",
    originalName = "M2K"
  },
  {
    text = "RFL",
    originalName = "RFL"
  },
  {
    text = "J39",
    originalName = "J39"
  },
  {
    text = "J17",
    originalName = "J17"
  },
  





  {
    text = "SA3",
    originalName = "S125"
  },
  {
    text = "SA8",
    originalName = "93"
  },
  {
    text = "S15",
    originalName = "9K3"
  },
  {
    text = "RLD",
    originalName = "RLD"
  },
  {
    text = "CRT",
    originalName = "CRT"
  },
  {
    text = "S19",
    originalName = "2S6"
  },
  {
    text = "S22",
    originalName = "S1"
  },
  {
    text = "ADS",
    originalName = "ADS"
  },
  {
    text = "ASR",
    originalName = "ASR"
  },
  {
    text = "AAA",
    originalName = "hud/rwr_threat_aaa"
  },
  {
    text = "NVL",
    originalName = "hud/rwr_threat_naval"
  },
  {
    text = "MSL",
    originalName = "MSL"
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
  return { directionGroups = directionGroupOut, rangeMax = rwrSetting.get().range.y, unknownText = "INC" }
})

function rwrTargetsComponent(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = FLEX
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle))
  }
}

const addInfoLargeFontSizeMult = 3.0
const addInfoFontSizeMult = 2.0

function scope(scale, style) {
  return {
    size = [pw(scale * style.grid.scale), ph(scale * style.grid.scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      {
        pos = const [pw(7), ph(7)],
        size = const [pw(80), ph(80)],
        children = [
          {
            size = const [pw(100), ph(100)],
            children = [
              rwrTargetsComponent(style.object),
              createRwrGrid(style.grid)
            ]
          },
          createCompass(style.grid),

          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(-120), ph(90)]
            size = FLEX
            color = white
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * addInfoFontSizeMult
            text = "EM"
          }),
          @() styleText.__merge({
            watch = ChaffsCount
            rendObj = ROBJ_TEXT
            pos = const [pw(-100), ph(90)]
            size = FLEX
            color = white
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * addInfoFontSizeMult
            text = format("%d", ChaffsCount.get())
          }),
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(-120), ph(100)]
            size = FLEX
            color = white
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * addInfoFontSizeMult
            text = "IR"
          }),
          @() styleText.__merge({
            watch = FlaresCount
            rendObj = ROBJ_TEXT
            pos = const [pw(-100), ph(100)]
            size = FLEX
            color = white
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * addInfoFontSizeMult
            text = format("%d", FlaresCount.get())
          }),

          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(130), ph(-55)]
            color = white
            size = FLEX
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * addInfoFontSizeMult
            text = "+"
          }),
          @() styleText.__merge({
            watch = settings
            rendObj = ROBJ_TEXT
            pos = const [pw(130), ph(-40)]
            size = FLEX
            color = white
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * addInfoLargeFontSizeMult
            text = format("%d", settings.get().rangeMax * metrToNavMile)
          }),
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(130), ph(-25)]
            size = FLEX
            color = white
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * addInfoFontSizeMult
            text = "-"
          })
        ]
      }
    ]
  }
}

function tws(posWatched, sizeWatched, scale, style) {
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