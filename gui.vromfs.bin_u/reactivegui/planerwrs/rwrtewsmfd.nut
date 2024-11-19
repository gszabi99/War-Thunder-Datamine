from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")
let { sin, cos, PI } = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let { rwrTargetsTriggers, rwrTargets, RwrNewTargetHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")

let { CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { FlaresCount, ChaffsCount } = require("%rGui/airState.nut")

let {ThreatType, settings} = require("rwrAnAlr56ThreatsLibrary.nut")
let { color, baseLineWidth, styleText, calcRwrTargetRadius, rwrPriorityTargetComponent } = require("rwrAnAlr56Components.nut")

function createOuterGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)]
    size = flex()
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = color
    commands = [
      [ VECTOR_POLY,   -5, -100,    5, -100,   0, -95 ],
      [ VECTOR_POLY,   -5,  100,    5,  100,   0,  95 ],
      [ VECTOR_POLY, -100,   -5, -100,    5, -95,   0 ],
      [ VECTOR_POLY,  100,   -5,  100,    5,  95,   0 ]
    ]
  }
}

let gridFontSizeMult = 0.5

function createCompass(gridStyle) {
  let compassColor = Color(5, 100, 5, 250)

  let markAngleStep = 5.0
  let markAngle = PI * markAngleStep / 180.0
  let markDashCount = 360.0 / markAngleStep
  let azimuthMarkLength = 4

  let commands = array(markDashCount).map(@(_, i) [
    VECTOR_LINE,
    50 + cos(i * markAngle) * (100 - ((i % 2 == 0) ? 1.0 : 0.5) * azimuthMarkLength),
    50 + sin(i * markAngle) * (100 - ((i % 2 == 0) ? 1.0 : 0.5) * azimuthMarkLength),
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
      pos = [pw(sin(i * textMarkAngle) * 100), ph(-cos(i * textMarkAngle) * 100)],
      size = flex(),
      color = compassColor,
      font = styleText.font,
      fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult,
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
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex(),
    color = compassColor,
    lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
    fillColor = 0,
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

function makeInnerGridCommands() {
  let commands = [
    [VECTOR_LINE, -10,   0, -5,  0],
    [VECTOR_LINE,   5,   0, 10,  0],
    [VECTOR_LINE,   0, -10,  0, -5],
    [VECTOR_LINE,   0,   5,  0, 10] ]
  for (local az = 0.0; az < 360.0; az += 30)
    commands.append([VECTOR_ELLIPSE, sin(degToRad(az)) * 100.0, cos(degToRad(az)) * 100.0, 1, 1])
  return commands
}

let innerGridCommands = makeInnerGridCommands()

function createInnerGrid(gridStyle) {
  return {
    rendObj = ROBJ_VECTOR_CANVAS,
    pos = [pw(50), ph(50)],
    size = flex(),
    color = color,
    lineWidth = baseLineWidth * gridStyle.lineWidthScale,
    fillColor = color,
    commands = innerGridCommands
  }
}

let iconRadiusBaseRel = 0.2

function createRwrTarget(index, settingsIn, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settingsIn.directionGroups.len() ? settingsIn.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)

  let newTargetFontSizeMultRwr = Computed(@() (target.age0 * RwrNewTargetHoldTimeInv.get() < 1.0 && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 1.5 : 1.0))
  local targetType = @()
    styleText.__merge({
      watch = newTargetFontSizeMultRwr
      rendObj = ROBJ_TEXT
      pos = [pw(target.x * 100.0 * targetRadiusRel), ph(target.y * 100.0 * targetRadiusRel)]
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      fontSize = styleText.fontSize * objectStyle.fontScale * newTargetFontSizeMultRwr.get()
      text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    })

  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale
  let typeAirIconRadiusRel = iconRadiusRel * 0.8
  let typeShipIconRadiusRel = iconRadiusRel * 0.4

  local icon = null
  if (directionGroup != null)
    if (directionGroup?.type == ThreatType.AI || directionGroup?.type == ThreatType.SHIP)
      icon = @() {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
        color = color
        fillColor = 0
        commands = directionGroup?.type == ThreatType.AI ?
          [
            [ VECTOR_POLY,
              target.x * targetRadiusRel * 100.0 - typeAirIconRadiusRel * 100.0,
              target.y * targetRadiusRel * 100.0,
              target.x * targetRadiusRel * 100.0,
              target.y * targetRadiusRel * 100.0 - typeAirIconRadiusRel * 100.0,
              target.x * targetRadiusRel * 100.0 + typeAirIconRadiusRel * 100.0,
              target.y * targetRadiusRel * 100.0 ]
          ] :
          [
            [ VECTOR_LINE,
              target.x * targetRadiusRel * 100.0 -       typeShipIconRadiusRel * 100.0,
              target.y * targetRadiusRel * 100.0 + 0.8 * typeShipIconRadiusRel * 100.0,
              target.x * targetRadiusRel * 100.0 - 0.8 * typeShipIconRadiusRel * 100.0,
              target.y * targetRadiusRel * 100.0 +       typeShipIconRadiusRel * 100.0,
              target.x * targetRadiusRel * 100.0 + 0.8 * typeShipIconRadiusRel * 100.0,
              target.y * targetRadiusRel * 100.0 +       typeShipIconRadiusRel * 100.0,
              target.x * targetRadiusRel * 100.0 +       typeShipIconRadiusRel * 100.0,
              target.y * targetRadiusRel * 100.0 + 0.8 * typeShipIconRadiusRel * 100.0]
          ]
      }

  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local launch = null
  if (target.launch) {
    launch = @() {
      watch = attackOpacityRwr,
      rendObj = ROBJ_VECTOR_CANVAS,
      size = flex(),
      lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale,
      color = color,
      fillColor = 0,
      opacity = attackOpacityRwr.get(),
      commands = [
        [ VECTOR_ELLIPSE,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0,
          iconRadiusRel * 100.0,
          iconRadiusRel * 100.0]
       ]
    }
  }

  return @() {
    size = flex()
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        children = [
          icon,
          launch
        ]
      },
      targetType
    ]
  }
}

let rwrTargetsComponent = function(objectStyle) {
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
      createOuterGrid(style.grid),
      {
        pos = [pw(5), ph(5)],
        size = [pw(90), ph(90)],
        children = [
          createCompass(style.grid),
          {
            pos = [pw(5), ph(5)],
            size = [pw(90), ph(90)],
            children = [
              createInnerGrid(style.grid),
              rwrTargetsComponent(style.object),
              rwrPriorityTargetComponent(style.object)
            ]
          }
        ]
      },
      @()
        styleText.__merge({
          rendObj = ROBJ_TEXT
          pos = [pw(30), ph(-85)]
          size = flex()
          halign = ALIGN_RIGHT
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize * gridFontSizeMult
          text = "CHF"
        }),
      @()
        styleText.__merge({
          watch = ChaffsCount
          rendObj = ROBJ_TEXT
          pos = [pw(45), ph(-85)]
          size = flex()
          halign = ALIGN_RIGHT
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize * gridFontSizeMult
          text = format("%d", ChaffsCount.get())
        }),
      @()
        styleText.__merge({
          rendObj = ROBJ_TEXT
          pos = [pw(30), ph(-78)]
          size = flex()
          halign = ALIGN_RIGHT
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize * gridFontSizeMult
          text = "FLR"
        }),
      @()
        styleText.__merge({
          watch = FlaresCount
          rendObj = ROBJ_TEXT
          pos = [pw(45), ph(-78)]
          size = flex()
          halign = ALIGN_RIGHT
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize * gridFontSizeMult
          text = format("%d", FlaresCount.get())
        })
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
    children = scope(scale, style.__merge( {object = style.object.__merge({ scale = style.object.scale * 0.50, fontScale = style.object.fontScale * 0.75 }) }))
  }
}

return tws