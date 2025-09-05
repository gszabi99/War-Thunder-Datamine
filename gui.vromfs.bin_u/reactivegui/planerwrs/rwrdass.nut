from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")
let { sin, cos, abs, floor } = require("math")
let { degToRad, radToDeg } = require("%sqstd/math_ex.nut")

let rwrSetting = require("%rGui/rwrSetting.nut")
let { rwrTargetsTriggers, rwrTargets, rwrTargetsOrder, RwrSignalHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")

let { Speed, CompassValue, Altitude } = require("%rGui/planeState/planeFlyState.nut")
let { FlaresCount, ChaffsCount } = require("%rGui/airState.nut")
let { RadarTargetDist } = require("%rGui/planeState/planeToolsState.nut")

let { IsRadarVisible, IsRadarEmitting, ScanAzimuthMin, ScanAzimuthMax, ScanElevationMin, ScanElevationMax,
  Azimuth, Elevation, AzimuthMin, AzimuthMax, ElevationMin, ElevationMax } = require("%rGui/radarState.nut")

let { mpsToKnots, metrToFeet, metrToNavMile} = require("%rGui/planeIlses/ilsConstants.nut")

let backGroundColor = Color(0, 0, 0, 255)
let gridColor = Color(0, 0, 255, 255)
let gridColorInner = Color(0, 255, 0, 255)
let radarScanSectorColor = Color(255, 255, 255, 255)
let iconColor = Color(255, 0, 0, 255)
let iconBorderColor = Color(255, 255, 255, 255)
let textColor = Color(255, 255, 255, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = textColor
  fillColor = backGroundColor
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontSize = 10
  lineWidth = baseLineWidth
}

let gridFontVarSizeMult = 2.0
let gridFontSizeMult = gridFontVarSizeMult * 0.75

function createRwrGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)],
    size = flex(),
    children = [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS,
        color = gridColor,
        lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE, 0, 0,  60,  60],
          [VECTOR_ELLIPSE, 0, 0, 100, 100]
        ]
      },
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS,
        color = gridColorInner,
        lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 20, 20]
        ]
      }
    ]
  }
}

function createRwrGridMarks(gridStyle, settings) {
  return {
    size = flex(),
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [ph(0), ph(90)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settings.rangeMax * 1.0 * metrToNavMile)
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

function createRwrTarget(index, settingsIn, objectStyle) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return null

  let directionGroup = settingsIn.directionGroups?[target.groupId]
  let targetRadiusRel = calcRwrTargetRadius(target)

  let iconSizeMult = 0.15 * objectStyle.scale

  let targetTypeFontSizeMult = 2.0
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
    pos = [pw(target.x * 100.0 * targetRadiusRel - 0.2 * targetTypeTextSize[0]), ph(target.y * 100.0 * targetRadiusRel - iconSizeMult * 100.0 - 0.2 * targetTypeTextSize[1])]
    children = targetTypeText
  }

  let background = {
    color = backGroundColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * (1 + 5) * objectStyle.lineWidthScale
    fillColor = backGroundColor
    size = flex()
    commands = [
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
  }

  let ageOpacity = Computed(@() (target.age * RwrSignalHoldTimeInv.get() < 0.25 ? 1.0 : 0.1))
  let icon = @() {
    watch = ageOpacity
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = iconColor
    opacity = ageOpacity.get()
    fillColor = iconColor
    lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
    commands = [
      [ VECTOR_POLY,
        target.x * targetRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0 - 0.5 * iconSizeMult * 80.0,
        target.x * targetRadiusRel * 100.0 - 0.5 * iconSizeMult * 80.0,
        target.y * targetRadiusRel * 100.0,
        target.x * targetRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 80.0,
        target.x * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 80.0,
        target.y * targetRadiusRel * 100.0 ]
    ]
  }

  let iconBorder = @() {
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = iconBorderColor
    fillColor = 0
    lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
    commands = [
      [ VECTOR_LINE,
        (target.x * targetRadiusRel - 0.2 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel - 0.3 * iconSizeMult) * 100.0,
        (target.x * targetRadiusRel) * 100.0,
        (target.y * targetRadiusRel - 0.5 * iconSizeMult) * 100.0,
        (target.x * targetRadiusRel + 0.2 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel - 0.3 * iconSizeMult) * 100.0 ],
      [ VECTOR_LINE,
        (target.x * targetRadiusRel + 0.3 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel - 0.2 * iconSizeMult) * 100.0,
        (target.x * targetRadiusRel + 0.5 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel) * 100.0,
        (target.x * targetRadiusRel + 0.3 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel + 0.2 * iconSizeMult) * 100.0 ],
      [ VECTOR_LINE,
        (target.x * targetRadiusRel - 0.2 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel + 0.3 * iconSizeMult) * 100.0,
        (target.x * targetRadiusRel) * 100.0,
        (target.y * targetRadiusRel + 0.5 * iconSizeMult) * 100.0,
        (target.x * targetRadiusRel + 0.2 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel + 0.3 * iconSizeMult) * 100.0 ],
      [ VECTOR_LINE,
        (target.x * targetRadiusRel - 0.3 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel - 0.2 * iconSizeMult) * 100.0,
        (target.x * targetRadiusRel - 0.5 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel) * 100.0,
        (target.x * targetRadiusRel - 0.3 * iconSizeMult) * 100.0,
        (target.y * targetRadiusRel + 0.2 * iconSizeMult) * 100.0 ]
    ]
  }

  let attack = target.track || target.launch ? @() {
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    color = iconBorderColor
    fillColor = 0
    lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
    commands = [
      [ VECTOR_LINE,
        target.x * targetRadiusRel * 100.0 - 0.3 * iconSizeMult * 100.0,
        target.y * targetRadiusRel * 100.0 + 0.8 * iconSizeMult * 100.0,
        target.x * targetRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 100.0,
        target.x * targetRadiusRel * 100.0 + 0.3 * iconSizeMult * 100.0,
        target.y * targetRadiusRel * 100.0 + 0.8 * iconSizeMult * 100.0 ]
    ]
  } : null

  let launchOpacityRwr = Computed(@() target.launch && ((CurrentTime.get() * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0)
  return @() {
    watch = launchOpacityRwr
    pos = [pw(50), ph(50)],
    size = flex(),
    opacity = launchOpacityRwr.get()
    children = [
      background,
      targetType,
      icon,
      iconBorder,
      attack
    ]
  }
}

let elevation5DegInRad = degToRad(5.0)

let AzimuthAbs = Computed(@() AzimuthMin.get() * (1.0 - Azimuth.get()) + AzimuthMax.get() * Azimuth.get() )

let ElevationRange = Computed(@() max(abs(ElevationMin.get()), abs(ElevationMax.get())))
let ElevationScale = Computed(@() ElevationRange.get() > 0.001 ? 1.0 / ElevationRange.get() : 0.0)
let ElevationAbs = Computed(@() ElevationMin.get() * (1.0 - Elevation.get()) + ElevationMax.get() * Elevation.get() )

function createRadarScanSector(gridStyle) {
  return @() {
    watch = [IsRadarVisible, IsRadarEmitting],
    size = flex(),
    children = IsRadarVisible.get() && IsRadarEmitting.get() ? [
      @() {
        rendObj = ROBJ_VECTOR_CANVAS,
        watch = [ElevationMin, ElevationMax, ElevationScale]
        pos = [pw(50), ph(50)],
        size = flex(),
        color = radarScanSectorColor,
        lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
        fillColor = 0,
        commands = [
          [VECTOR_LINE, 120, -ElevationMin.get() * ElevationScale.get() * 100, 120, -ElevationMax.get() * ElevationScale.get() * 100],
          [VECTOR_LINE, 112, 0, 120, 0],
          [VECTOR_LINE, 115,  elevation5DegInRad * ElevationScale.get() * 100, 120,  elevation5DegInRad * ElevationScale.get() * 100],
          [VECTOR_LINE, 115, -elevation5DegInRad * ElevationScale.get() * 100, 120, -elevation5DegInRad * ElevationScale.get() * 100]
        ]
      },
      @() {
        watch = RadarTargetDist
        size = flex()
        children = RadarTargetDist.get() > 0 ? [
          @() {
            rendObj = ROBJ_VECTOR_CANVAS,
            watch = [AzimuthAbs, ElevationAbs, ElevationScale]
            pos = [pw(50), ph(50)],
            size = flex(),
            color = radarScanSectorColor,
            lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
            fillColor = 0,
            commands = [
              [VECTOR_LINE, 0, 0, sin(AzimuthAbs.get()) * 100, -cos(AzimuthAbs.get()) * 100],
              [VECTOR_LINE, 120, -ElevationAbs.get() * ElevationScale.get() * 100.0, 122, -ElevationAbs.get() * ElevationScale.get() * 100.0]
            ]
          }
        ] :
        [
          @() {
            rendObj = ROBJ_VECTOR_CANVAS,
            watch = [ScanAzimuthMin, ScanAzimuthMax]
            pos = [pw(50), ph(50)],
            size = flex(),
            color = radarScanSectorColor,
            lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
            fillColor = 0,
            commands = [
              [VECTOR_LINE, 0, 0, sin(ScanAzimuthMin.get()) * 100, -cos(ScanAzimuthMin.get()) * 100],
              [VECTOR_LINE, 0, 0, sin(ScanAzimuthMax.get()) * 100, -cos(ScanAzimuthMax.get()) * 100],
              [VECTOR_SECTOR, 0, 0, 100, 100, radToDeg(ScanAzimuthMin.get()) - 90, radToDeg(ScanAzimuthMax.get()) - 90]
            ]
          },
          @() {
            rendObj = ROBJ_VECTOR_CANVAS,
            watch = [ScanElevationMin, ScanElevationMax, ElevationScale]
            pos = [pw(50), ph(50)],
            size = flex(),
            color = radarScanSectorColor,
            lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
            fillColor = radarScanSectorColor,
            commands = [
              [VECTOR_RECTANGLE,
                120, -ScanElevationMax.get() * ElevationScale.get() * 100.0,
                  2, (ScanElevationMax.get() - ScanElevationMin.get()) * ElevationScale.get() * 100.0]
            ]
          }
        ]
      }
    ] : null
  }
}

let directionGroups = [
  {
    text = "FTR",
    originalName = "hud/rwr_threat_ai",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "ATK",
    originalName = "hud/rwr_threat_attacker",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "FSB",
    originalName = "M21",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "FLG",
    originalName = "M23",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "FLN",
    originalName = "M29",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "FLB",
    type = ThreatType.AI,
    originalName = "S34",
    lethalRangeMax = 40000.0
  },
  {
    text = "FLH",
    type = ThreatType.AI,
    originalName = "S30",
    lethalRangeMax = 40000.0
  },
  {
    text = "F4",
    type = ThreatType.AI,
    originalName = "F4",
    lethalRangeMax = 40000.0
  },
  {
    text = "F5",
    originalName = "F5",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "F14",
    originalName = "F14",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "F15",
    originalName = "F15",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "F16",
    originalName = "F16",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "F18",
    originalName = "F18",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "HRR",
    originalName = "HRR",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "E2K",
    type = ThreatType.AI,
    originalName = "E2K",
    lethalRangeMax = 40000.0
  },
  {
    text = "TRF",
    originalName = "TRF",
    type = ThreatType.AI,
    lethalRangeMax = 30000.0
  },
  {
    text = "M20",
    originalName = "M2K",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "RFL",
    originalName = "RFL",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "J39",
    originalName = "J39",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "J17",
    originalName = "J17",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  







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
    text = "SA19",
    originalName = "2S6",
    type = ThreatType.SAM,
    lethalRangeMax = 8000.0
  },
  {
    text = "SA22",
    originalName = "S1",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "ADS",
    originalName = "ADS",
    type = ThreatType.SAM,
    lethalRangeMax = 8000.0
  },
  {
    text = "ASR",
    originalName = "ASR",
    type = ThreatType.SAM,
    lethalRangeMax = 8000.0
  },
  {
    text = "AAA",
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AAA,
    lethalRangeMax = 4000.0
  },
  {
    text = "SAM",
    originalName = "hud/rwr_threat_sam",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "NVL",
    originalName = "hud/rwr_threat_naval",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "MSL",
    originalName = "MSL",
    type = ThreatType.MSL
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
  return { directionGroups = directionGroupOut, rangeMax = rwrSetting.get().range.y, unknownText = "U" }
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
        size = static [pw(100), ph(100)],
        children = [
          {
            size = flex(),
            children = [
              rwrTargetsComponent(style.object),
              createRwrGrid(style.grid),
              rwrGridMarksComponent(style.grid)
            ]
          },
          @()
            styleText.__merge({
              watch = Speed
              rendObj = ROBJ_TEXT
              pos = [pw(-90), ph(-115)]
              size = flex()
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              fontSize = style.grid.fontScale * styleText.fontSize * gridFontVarSizeMult
              text = format("%.0f", Speed.get() * mpsToKnots)
            }),
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = [pw(-80), ph(-115)]
            size = flex()
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * gridFontSizeMult
            text = "KT"
          }),
          @()
            styleText.__merge({
              watch = CompassValue
              rendObj = ROBJ_TEXT
              pos = [pw(0), ph(-115)]
              size = flex()
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              fontSize = style.grid.fontScale * styleText.fontSize * gridFontVarSizeMult
              text = format("% 3.0f'", CompassValue.get() > 0.0 ? CompassValue.get() : 360.0 + CompassValue.get())
            }),
          @()
            styleText.__merge({
              watch = Altitude
              rendObj = ROBJ_TEXT
              pos = [pw(90), ph(-115)]
              size = flex()
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              fontSize = style.grid.fontScale * styleText.fontSize * gridFontVarSizeMult
              text = format("% 3.0f,%03.f", Altitude.get() * metrToFeet * 0.001, Altitude.get() * metrToFeet - floor(Altitude.get() * metrToFeet * 0.001) * 1000.0)
            }),
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = [pw(110), ph(-115)]
            size = flex()
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * gridFontSizeMult
            text = "FT"
          }),
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = [pw(-85), ph(110)]
            size = flex()
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * gridFontSizeMult
            text = "C"
          }),
          @()
            styleText.__merge({
              watch = ChaffsCount
              rendObj = ROBJ_TEXT
              pos = [pw(-75), ph(110)]
              size = flex()
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              fontSize = style.grid.fontScale * styleText.fontSize * gridFontVarSizeMult
              text = format("%d", ChaffsCount.get())
            }),
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = [pw(-85), ph(125)]
            size = flex()
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            fontSize = style.grid.fontScale * styleText.fontSize * gridFontSizeMult
            text = "F"
          }),
          @()
            styleText.__merge({
              watch = FlaresCount
              rendObj = ROBJ_TEXT
              pos = [pw(-75), ph(125)]
              size = flex()
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              fontSize = style.grid.fontScale * styleText.fontSize * gridFontVarSizeMult
              text = format("%d", FlaresCount.get())
            }),
          createRadarScanSector(style.grid)
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