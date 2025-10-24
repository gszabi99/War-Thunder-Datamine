from "%rGui/globals/ui_library.nut" import *
let { fabs, sqrt } = require("%sqstd/math.nut")
let compass = require("%rGui/compass.nut")
let { HasCompass, CompassValue } = require("%rGui/compassState.nut")
let { hudFontHgt, fontOutlineFxFactor, greenColor, fontOutlineColor, fadeColor } = require("%rGui/style/airHudStyle.nut")
let { SelectedTargetBlinking, modeNames, azimuthMarkers, forestall, selectedTarget, IsRadarHudVisible,
  IsRadarEmitting, Irst, IsForestallVisible, ScanZoneWatched, LockZoneWatched, IsScanZoneAzimuthVisible,
  IsScanZoneElevationVisible, IsLockZoneVisible, AzimuthMarkersTrigger } = require("%rGui/radarState.nut")
let { getRadarTargetsIffFilterMask, RadarTargetsIffFilterMask } = require("radarGuiControls")

let deg = loc("measureUnits/deg")

let styleText = {
  color = greenColor
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

let maxMeasuresCompWidth = @()
  calc_comp_size(styleText.__merge({
    rendObj = ROBJ_TEXT
    text = $"360{deg}x360{deg}*"
  }))[0]

let getMaxLabelSize = @()
  calc_comp_size(styleText.__merge({
    rendObj = ROBJ_TEXT
    text = $"180{deg}"
  }))

let maxLabelWidth = getMaxLabelSize()[0]
let maxLabelHeight = getMaxLabelSize()[1]

let styleLineForeground = {
  color = greenColor
  lineWidth = hdpx(LINE_WIDTH)
}

let compassSize = [hdpx(500), hdpx(32)]
let compassStep = 5.0
let compassOneElementWidth = compassSize[1]

let getCompassStrikeWidth = @(oneElementWidth, step) 360.0 * oneElementWidth / step

let frameTrigger = {}
SelectedTargetBlinking.subscribe(@(v) v ? anim_start(frameTrigger) : anim_request_stop(frameTrigger))


function getRadarModeText(radarModeNameWatch, isRadarVisibleWatch) {
  let texts = []
  if (radarModeNameWatch.get() in modeNames)
    texts.append(loc(modeNames[radarModeNameWatch.get()]))
  else if (isRadarVisibleWatch.get())
    texts.append(Irst.get() ? loc("hud/irst") : loc("hud/radarEmitting"))
  return "".join(texts)
}

let forestallRadius = hdpx(15)

let forestallVisible = @(color) function() {
  return styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color
    size = [2 * forestallRadius, 2 * forestallRadius]
    lineWidth = hdpx(2 * LINE_WIDTH)
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = SelectedTargetBlinking.get(), loop = true, easing = InOutSine, trigger = frameTrigger }]
    fillColor = 0
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [forestall.x - forestallRadius, forestall.y - forestallRadius]
      }
    }
  })
}

let forestallComponent = @(color) function() {
  return {
    size = const [sw(100), sh(100)]
    children = IsForestallVisible.get() ? forestallVisible(color) : null
    watch = IsForestallVisible
  }
}

function scanZoneAzimuthComponent(color) {
  let width = sw(100)
  let height = sh(100)
  let mw = 100 / width
  let mh = 100 / height
  let lineWidth = hdpx(4)
  return function() {
    if (!IsScanZoneAzimuthVisible.get())
      return { watch = IsScanZoneAzimuthVisible }

    let { x0, y0, x1, y1 } = ScanZoneWatched.get()
    let _x0 = (x0 + x1) * 0.5
    let _y0 = (y0 + y1) * 0.5
    let px0 = (x0 - _x0) * mw
    let py0 = (y0 - _y0) * mh
    let px1 = (x1 - _x0) * mw
    let py1 = (y1 - _y0) * mh

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth
      watch = [ScanZoneWatched, IsScanZoneAzimuthVisible]
      opacity = 0.3
      fillColor = 0
      size = [width, height]
      color
      pos = [_x0, _y0]
      commands = [[ VECTOR_LINE, px0, py0, px1, py1 ]]
    }
  }
}

function scanZoneElevationComponent(color) {
  let width = sw(100)
  let height = sh(100)
  let mw = 100 / width
  let mh = 100 / height
  let size = [width, height]
  let lineWidth = hdpx(4)
  let watch = [ScanZoneWatched, IsScanZoneElevationVisible]
  return function() {
    if (!IsScanZoneElevationVisible.get())
      return { watch = [IsScanZoneElevationVisible] }

    let { x2, x3, y2, y3 } = ScanZoneWatched.get()
    let _x0 = (x2 + x3) * 0.5
    let _y0 = (y2 + y3) * 0.5
    let px2 = (x2 - _x0) * mw
    let py2 = (y2 - _y0) * mh
    let px3 = (x3 - _x0) * mw
    let py3 = (y3 - _y0) * mh

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      opacity = 0.3
      watch
      lineWidth
      color
      fillColor = 0
      size
      pos = [_x0, _y0]
      commands = [[ VECTOR_LINE, px2, py2, px3, py3 ]]
    }
  }
}

function lockZoneComponentCommon(IsCustomLockZoneVisible, color, animations) {
  return function() {
    let res =  { watch = [IsCustomLockZoneVisible, LockZoneWatched] }
    if (!IsCustomLockZoneVisible.get())
      return res.__update({ animations = animations })

    let width = sw(100)
    let height = sh(100)
    let mw = 100 / width
    let mh = 100 / height
    let corner = IsRadarEmitting.get() ? 0.1 : 0.02
    let lineWidth = hdpx(4)
    let size = const [sw(100), sh(100)]

    let { x0, x1, x2, x3, y0, y1, y2, y3 } = LockZoneWatched.get()
    let _x0 = (x0 + x1 + x2 + x3) * 0.25
    let _y0 = (y0 + y1 + y2 + y3) * 0.25

    let px0 = (x0 - _x0) * mw
    let py0 = (y0 - _y0) * mh
    let px1 = (x1 - _x0) * mw
    let py1 = (y1 - _y0) * mh
    let px2 = (x2 - _x0) * mw
    let py2 = (y2 - _y0) * mh
    let px3 = (x3 - _x0) * mw
    let py3 = (y3 - _y0) * mh

    let commands = [
      [ VECTOR_LINE, px0, py0, px0 + (px1 - px0) * corner, py0 + (py1 - py0) * corner ],
      [ VECTOR_LINE, px0, py0, px0 + (px3 - px0) * corner, py0 + (py3 - py0) * corner ],

      [ VECTOR_LINE, px1, py1, px1 + (px2 - px1) * corner, py1 + (py2 - py1) * corner ],
      [ VECTOR_LINE, px1, py1, px1 + (px0 - px1) * corner, py1 + (py0 - py1) * corner ],

      [ VECTOR_LINE, px2, py2, px2 + (px3 - px2) * corner, py2 + (py3 - py2) * corner ],
      [ VECTOR_LINE, px2, py2, px2 + (px1 - px2) * corner, py2 + (py1 - py2) * corner ],

      [ VECTOR_LINE, px3, py3, px3 + (px0 - px3) * corner, py3 + (py0 - py3) * corner ],
      [ VECTOR_LINE, px3, py3, px3 + (px2 - px3) * corner, py3 + (py2 - py3) * corner ]
    ]

    return res.__update({
      animations = animations
      pos = [_x0, _y0 ]
      rendObj = ROBJ_VECTOR_CANVAS
      color
      lineWidth
      fillcolor = color
      size
      commands
    })
  }
}

function lockZoneComponent(color) {
  let animations = [{ prop = AnimProp.opacity, from = 0.0, to = 1, duration = 0.25, play = true, loop = true, easing = InOutSine }]
  let IsActiveLockZoneVisibile = Computed(@() IsLockZoneVisible.get() && IsRadarEmitting.get())
  return lockZoneComponentCommon(IsActiveLockZoneVisibile, color, animations)
}

function standbyLockZoneComponent(color) {
  let IsStandbyLockZoneVisibile = Computed(@() IsLockZoneVisible.get() && !IsRadarEmitting.get())
  return lockZoneComponentCommon(IsStandbyLockZoneVisibile, color, null)
}

function getForestallTargetLineCoords() {
  let p1 = {
    x = forestall.x
    y = forestall.y
  }
  let p2 = {
    x = selectedTarget.x
    y = selectedTarget.y
  }

  let resPoint1 = {
    x = 0
    y = 0
  }
  let resPoint2 = {
    x = 0
    y = 0
  }

  let dx = p1.x - p2.x
  let dy = p1.y - p2.y
  let absDx = fabs(dx)
  let absDy = fabs(dy)

  if (absDy >= absDx) {
    resPoint2.x = p2.x
    resPoint2.y = p2.y + (dy > 0 ? 0.5 : -0.5) * hdpx(50)
  }
  else {
    resPoint2.y = p2.y
    resPoint2.x = p2.x + (dx > 0 ? 0.5 : -0.5) * hdpx(50)
  }

  let vecDx = p1.x - resPoint2.x
  let vecDy = p1.y - resPoint2.y
  let vecLength = sqrt(vecDx * vecDx + vecDy * vecDy)
  let vecNorm = {
    x = vecLength > 0 ? vecDx / vecLength : 0
    y = vecLength > 0 ? vecDy / vecLength : 0
  }

  resPoint1.x = resPoint2.x + vecNorm.x * (vecLength - forestallRadius)
  resPoint1.y = resPoint2.y + vecNorm.y * (vecLength - forestallRadius)

  return [resPoint2, resPoint1]
}


function forestallTgtLine(color) {
  let w = sw(100)
  let h = sh(100)

  return styleLineForeground.__merge({
    color
    rendObj = ROBJ_VECTOR_CANVAS
    size = [w, h]
    lineWidth = hdpx(LINE_WIDTH)
    opacity = 0.8
    behavior = Behaviors.RtPropUpdate
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.5, play = SelectedTargetBlinking.get(), loop = true, easing = InOutSine, trigger = frameTrigger }]
    update = function() {
      let resLine = getForestallTargetLineCoords()

      return {
        commands = [
          [VECTOR_LINE, resLine[0].x * 100.0 / w, resLine[0].y * 100.0 / h, resLine[1].x * 100.0 / w, resLine[1].y * 100.0 / h]
        ]
      }
    }
  })
}

let forestallTargetLine = @(color) function() {
  return !IsForestallVisible.get() ? { watch = IsForestallVisible }
  : {
    watch = IsForestallVisible
    size = const [sw(100), sh(100)]
    children = forestallTgtLine(color)
  }
}

function compassComponent(color) {
  let compassInstance = compass(compassSize, color)
  return function() {
    return {
      watch = HasCompass
      pos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
      children = HasCompass.get() ? compassInstance : null
    }
  }
}

let createAzimuthMark = @(size, is_selected, is_detected, is_enemy, color)
  function() {

    local frame = null

    let frameSizeW = size[0] * 1.5
    let frameSizeH = size[1] * 1.5
    let commands = []

    if (is_selected)
      commands.append(
        [VECTOR_LINE, 0, 0, 100, 0],
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 100, 100, 0, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      )
    else if (is_detected)
      commands.append(
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      )
    if (!is_enemy) {
      let yOffset = is_selected ? 110 : 95
      let xOffset = is_selected ? 0 : 10
      commands.append([VECTOR_LINE, xOffset, yOffset, 100.0 - xOffset, yOffset])
    }

    frame = {
      size = [frameSizeW, frameSizeH]
      pos = [(size[0] - frameSizeW) * 0.5, (size[1] - frameSizeH) * 0.5 ]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(2)
      color
      fillColor = 0
      commands
    }

    return {
      size
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(3)
      color
      fillColor = 0
      commands = [
        [VECTOR_LINE, 0, 100, 50, 0],
        [VECTOR_LINE, 50, 0, 100, 100],
        [VECTOR_LINE, 100, 100, 0, 100]
      ]
      children = frame
    }
  }

let createAzimuthMarkWithOffset = @(size, total_width, angle, is_selected, is_detected, age_rel, is_enemy, isSecondRound, color) function() {
  let offset = (isSecondRound ? total_width : 0) +
    total_width * angle / 360.0 + 0.5 * size[0]
  return {
    size = SIZE_TO_CONTENT
    pos = [offset, 0]
    children = createAzimuthMark(size, is_selected, is_detected, is_enemy, color)
    opacity = 1.0 - age_rel
  }
}

let createAzimuthMarkStrike = @(total_width, height, markerWidth, color) function() {

  let markers = []
  let curValueMask = getRadarTargetsIffFilterMask()
  foreach (_id, azimuthMarker in azimuthMarkers) {
    if (!azimuthMarker)
      continue
    else if (azimuthMarker.ageRel > 1.0)
      continue
    let markerValueMask = azimuthMarker.isEnemy ? RadarTargetsIffFilterMask.ENEMY : RadarTargetsIffFilterMask.ALLY
    let needToShow = curValueMask == 0 ? true : (markerValueMask & curValueMask) != 0
    if (!needToShow)
      continue
    markers.append(createAzimuthMarkWithOffset([markerWidth, height], total_width,
      azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.ageRel, azimuthMarker.isEnemy, false, color))
    markers.append(createAzimuthMarkWithOffset([markerWidth, height], total_width,
      azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.ageRel, azimuthMarker.isEnemy, true, color))
  }

  return {
    watch = AzimuthMarkersTrigger
    size = [total_width * 2.0, height]
    pos = [0, height * 0.5]
    children = markers
  }
}

let createAzimuthMarkStrikeComponent = @(size, total_width, styleColor) function() {

  let markerWidth = hdpx(20)
  let offsetW =  0.5 * (size[0] - compassOneElementWidth)
    + CompassValue.get() * compassOneElementWidth * 2.0 / compassStep
    - total_width

  return {
    watch = CompassValue
    size = [size[0], size[1] * 2.0]
    clipChildren = true
    children = @() {
      children = createAzimuthMarkStrike(total_width, size[1], markerWidth, styleColor)
      pos = [offsetW, 0]
    }
  }
}

function azimuthMarkStrike(styleColor) {
  let width = compassSize[0] * 1.5
  let totalWidth = 2.0 * getCompassStrikeWidth(compassOneElementWidth, compassStep)

  return {
    pos = [sw(50) - 0.5 * width, sh(17)]
    children = [
      createAzimuthMarkStrikeComponent([width, hdpx(30)], totalWidth, styleColor)
    ]
  }
}

function mkRadar(isAir = false, radar_color_watch = Watched(Color(0, 255, 0, 255))) {
  return function() {
    let res = { watch = [IsRadarHudVisible, radar_color_watch] }

    if (!IsRadarHudVisible.get())
      return res

    let color = fadeColor(radar_color_watch.get(), 255);

    let radarHudVisibleChildren = !isAir ?
    [
      forestallComponent(color)
      forestallTargetLine(color)
      scanZoneAzimuthComponent(color)
      lockZoneComponent(color)
      standbyLockZoneComponent(color)
      compassComponent(color)
      azimuthMarkStrike(color)
    ] :
    [
      scanZoneAzimuthComponent(color)
      scanZoneElevationComponent(color)
      lockZoneComponent(color)
      standbyLockZoneComponent(color)
    ]

    return res.__update({
      halign = ALIGN_LEFT
      valign = ALIGN_TOP
      size = const [sw(100), sh(100)]
      children = radarHudVisibleChildren
    })
  }
}

return {
  mkRadar
  mode = getRadarModeText
  maxLabelWidth
  maxLabelHeight
  maxMeasuresCompWidth
}