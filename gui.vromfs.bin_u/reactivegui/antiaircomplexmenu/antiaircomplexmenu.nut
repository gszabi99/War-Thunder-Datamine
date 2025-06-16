from "%rGui/globals/ui_library.nut" import *
let string = require("string")
let { targets, TargetsTrigger, HasAzimuthScale, AzimuthMin,
  AzimuthRange, HasDistanceScale, DistanceMax, DistanceMin, Irst
} = require("%rGui/radarState.nut")
let { PI, floor, lerp } = require("%sqstd/math.nut")
let dasVerticalViewIndicator = load_das("%rGui/antiAirComplexMenu/verticalViewIndicator.das")
let dasRadarHud = load_das("%rGui/radar.das")
let { radarSwitchToTarget } = require("antiAirComplexMenuControls")
let { RadarTargetType, RadarTargetIconType } = require("guiRadar")
let { RADAR_TAGET_ICON_NONE, RADAR_TAGET_ICON_JET, RADAR_TAGET_ICON_HELICOPTER, RADAR_TAGET_ICON_ROCKET } = RadarTargetIconType
let { RADAR_TAGET_TYPE_OWN_WEAPON, RADAR_TAGET_TYPE_OWN_WEAPON_TARGET } = RadarTargetType
let { safeAreaSizeHud, bh, rh } = require("%rGui/style/screenState.nut")
let { needShowDmgIndicator, dmgIndicatorStates } = require("%rGui/hudState.nut")
let { setRenderCameraToHudTexture } = require("hudState")
let { logerr } = require("dagor.debug")
let { mkFrame, mkShortcutButton, mkShortcutText, shortcutButtonPadding, frameHeaderHeight
} = require("%rGui/antiAirComplexMenu/antiAirMenuBaseComps.nut")
let { antiAirMenuShortcutHeight } = require("%rGui/hints/shortcuts.nut")
let { actionBarSize } = require("%rGui/hud/actionBarState.nut")
let { actionBarTopPanelMarginBottom, actionBarTopPanelHeight
} = require("%rGui/hud/actionBarTopPanel.nut")

let radarColor = 0xFF00FF07
let radarColorInactive = 0x66006602
let multiplayerScoreHeightWithOffset = shHud(5)
let sizeDamageIndicatorFull = shHud(30)
let panelsGap = hdpx(8)
let targetRowHeight = evenPx(32)
let targetRowPadding = hdpx(8)
let sidePanelsWidth = hdpx(480)
let defRadarHeight = hdpx(716)
let defCameraRenderHeight = hdpx(400)
let verticalViewIndicatorHeight = hdpx(204)
let controlPanelHeight = frameHeaderHeight + 2*antiAirMenuShortcutHeight + 5*panelsGap
let occupiedCenterHeight = multiplayerScoreHeightWithOffset
  + controlPanelHeight + actionBarTopPanelHeight
  + actionBarTopPanelMarginBottom

let radarHeight = Computed(@()
  min(rh.get() - (actionBarSize.get()?[1] ?? 0) - occupiedCenterHeight, defRadarHeight))
let bottomMarginLeftPanel = Computed(@() !needShowDmgIndicator.get() ? sizeDamageIndicatorFull
  : sh(100) - (dmgIndicatorStates.get()?.pos[1] ?? 0) - bh.get())

let planeTargetPicture = Picture($"!ui/gameuiskin#voice_message_jet.svg")
let helicopterTargetPicture = Picture($"!ui/gameuiskin#voice_message_helicopter.svg")
let rocketTargetPicture = Picture($"!ui/gameuiskin#voice_message_missile.svg")

let verticalViewIndicator = {
  size = [sidePanelsWidth, verticalViewIndicatorHeight]
  rendObj = ROBJ_DAS_CANVAS
  script = dasVerticalViewIndicator
  drawFunc = "draw"
  setupFunc = "setup"
  font = Fonts.hud
  fontSize = hdpx(14)
  planeTargetPicture
  helicopterTargetPicture
  rocketTargetPicture
}

let verticalViewIndicatorFrame = @() {
  watch = bottomMarginLeftPanel
  margin = [0, 0, bottomMarginLeftPanel.get() + panelsGap, 0]
  vplace = ALIGN_BOTTOM
  children = mkFrame(verticalViewIndicator, loc("hud/elevation_azimuth_indicator"))
}

function mkCameraRender() {
  let occupiedHeight = multiplayerScoreHeightWithOffset
    + verticalViewIndicatorHeight + 2 * frameHeaderHeight + 3 * panelsGap
  let cameraRenderHeight = Computed(@()
    min(rh.get() - bottomMarginLeftPanel.get() - occupiedHeight,
      defCameraRenderHeight))
  return @() {
    watch = cameraRenderHeight
    size = [sidePanelsWidth, cameraRenderHeight.get()]
    rendObj = ROBJ_TACTICAL_CAMERA_RENDER
    onAttach = @() setRenderCameraToHudTexture(true)
    onDetach = @() setRenderCameraToHudTexture(false)
  }
}

let circularRadarModeText = {
  flow = FLOW_HORIZONTAL
  gap = hdpx(2)
  children = [
    @() {
      watch = Irst
      rendObj = ROBJ_TEXT
      color = Irst.get() ? radarColorInactive : radarColor
      font = Fonts.very_tiny_text_hud
      text = loc("hud/radar")
    }
    {
      rendObj = ROBJ_TEXT
      color = radarColorInactive
      font = Fonts.very_tiny_text_hud
      text = "/"
    }
    @() {
      watch = Irst
      rendObj = ROBJ_TEXT
      color = Irst.get() ? radarColor : radarColorInactive
      font = Fonts.very_tiny_text_hud
      text = loc("hud/irst")
    }
  ]
}

let circularRadar = @() {
  watch = radarHeight
  size = [radarHeight.get(), radarHeight.get()]
  rendObj = ROBJ_DAS_CANVAS
  script = dasRadarHud
  drawFunc = "draw_radar_hud"
  setupFunc = "setup_radar_data"
  font = Fonts.hud
  fontSize = hdpx(16)
  color = radarColor
  annotateTargets = true
  handleClicks = true
  isAAComplexMenuLayout = true
  vignetteColor = 0xFF304054
  planeTargetPicture
  helicopterTargetPicture
  rocketTargetPicture
  children = {
    margin = panelsGap - shortcutButtonPadding
    vplace = ALIGN_BOTTOM
    children = mkShortcutButton("ID_SENSOR_TYPE_SWITCH_TANK",
      circularRadarModeText)
  }
}

let mkRadarControl = @() {
  padding = panelsGap - shortcutButtonPadding
  gap = hdpx(20)
  flow = FLOW_HORIZONTAL
  children = [
    {
      gap = panelsGap - shortcutButtonPadding
      flow = FLOW_VERTICAL
      children = [
        mkShortcutButton("ID_SENSOR_SWITCH_TANK", mkShortcutText(loc("radar_selector/search")))
        mkShortcutButton("ID_SENSOR_SCAN_PATTERN_SWITCH_TANK", mkShortcutText(loc("hud/search_mode")))
      ]
    }
    {
      gap = panelsGap - shortcutButtonPadding
      flow = FLOW_VERTICAL
      children = [
        mkShortcutButton("ID_SENSOR_RANGE_SWITCH_TANK", mkShortcutText(loc("hud/scope_scale")))
        mkShortcutButton("ID_SENSOR_TARGET_LOCK_TANK", mkShortcutText(loc("actionBarItem/weapon_lock")))
      ]
    }
  ]
}

let mkFireControl = @() {
  padding = panelsGap - shortcutButtonPadding
  gap = hdpx(20)
  flow = FLOW_HORIZONTAL
  children = [
    {
      gap = panelsGap - shortcutButtonPadding
      flow = FLOW_VERTICAL
      children = [
        mkShortcutButton("ID_FIRE_GM", mkShortcutText(loc("hotkeys/ID_FIRE_GM")))
        mkShortcutButton("ID_FIRE_GM_SPECIAL_GUN",
          mkShortcutText(loc("hotkeys/ID_FIRE_GM_SPECIAL_GUN")))
      ]
    }
    mkShortcutButton("ID_WEAPON_LOCK_TANK", mkShortcutText(loc("hud/guidanceState")))
  ]
}

let mkCentralBlock = @() {
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = panelsGap
  children = [
    mkFrame(circularRadar, loc("hud/plan_position_indicator"), { opacity = 0.8 })
    {
      flow = FLOW_HORIZONTAL
      gap = panelsGap
      children = [
        mkFrame(mkRadarControl, loc("hud/radar_control"))
        mkFrame(mkFireControl, loc("hud/fire_control"))
      ]
    }
  ]
}

let mkTargetCell = @(size, fontSize, text) {
  size
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  rendObj = ROBJ_TEXT
  fontSize
  text
}

function createTargetListElement(index, azimuth, distance, height, speed, typeIcon, typeId, fontSize, isDetected = false, onClick = null){
  return {
    size = [flex(), targetRowHeight]
    rendObj = ROBJ_SOLID
    color = isDetected ? 0x19191919 : 0
    padding = targetRowPadding
    flow = FLOW_HORIZONTAL
    behavior = onClick != null ? Behaviors.Button : null
    onClick = onClick

    children = [
      mkTargetCell([pw(4), flex()], fontSize, index)
      mkTargetCell([pw(13), flex()], fontSize, azimuth)
      mkTargetCell([pw(17), flex()], fontSize, distance)
      mkTargetCell([pw(17), flex()], fontSize, height)
      mkTargetCell([pw(17), flex()], fontSize, speed)
      {
        rendObj = ROBJ_IMAGE
        size = [pw(4), flex()]
        image = typeIcon
      }
      mkTargetCell(flex(), fontSize, typeId)
    ]
  }
}

function createTargetDist(index, hasAzimuthScale, azimuthMin, azimuthRange, hasDistanceScale, distanceMin, distanceMax) {
  let target = targets[index]

  if (target.targetType == RADAR_TAGET_TYPE_OWN_WEAPON_TARGET || target.targetType == RADAR_TAGET_TYPE_OWN_WEAPON){
    return null
  }

  let radToDeg = 180.0 / PI
  let azimuth = (azimuthMin + azimuthRange * target.azimuthRel) * radToDeg
  let azimuthText = hasAzimuthScale ? string.format("%d", floor(azimuth)) : "-"

  let distance = lerp(0.0, 1.0, distanceMin, distanceMax, target.distanceRel)
  let distanceText = hasDistanceScale ? string.format("%.1f", distance) : "-"

  let heightText = string.format("%.1f", target.heightRel * 0.001)

  let speedText = target.radSpeed > -3000.0 ? string.format("%.1f", target.radSpeed) : "-"

  let typeIdText = loc(target.typeId)

  local icon = null
  let iconType = target.iconType
  if (iconType == RADAR_TAGET_ICON_NONE){
    icon = null
  } else if (iconType == RADAR_TAGET_ICON_JET){
    icon = planeTargetPicture
  } else if (iconType == RADAR_TAGET_ICON_HELICOPTER){
    icon = helicopterTargetPicture
  } else if (iconType == RADAR_TAGET_ICON_ROCKET){
    icon = rocketTargetPicture
  } else {
    logerr($"could not parse target type {iconType}")
  }

  local onClick = function() {
    radarSwitchToTarget(target.objectId)
  }
  return createTargetListElement(target.persistentIndex, azimuthText, distanceText, heightText, speedText, icon, typeIdText, hdpx(16), target.isDetected, onClick)
}

let targetList = @() {
  watch = [TargetsTrigger, HasAzimuthScale, AzimuthMin, AzimuthRange, HasDistanceScale, DistanceMin, DistanceMax]
  size = flex()
  flow = FLOW_VERTICAL
  children = targets.map(function(t, i) {
    if (t == null)
      throw null
    return createTargetDist(i, HasAzimuthScale.get(), AzimuthMin.get(), AzimuthRange.get(), HasDistanceScale.get(), DistanceMin.get(), DistanceMax.get())
  })
}

let targetListMain = @() {
  watch = radarHeight
  size = [sidePanelsWidth, min(hdpx(624), radarHeight.get())]
  flow = FLOW_VERTICAL
  children = [
    createTargetListElement("#", loc("hud/AAComplexMenu/azimuth"),
      loc("hud/AAComplexMenu/distance"), loc("hud/AAComplexMenu/height"),
      loc("hud/AAComplexMenu/speed"), null, loc("hud/AAComplexMenu/type"), hdpx(14)),
    targetList
  ]
}

let aaComplexMenu = {
  size = flex()
  rendObj = ROBJ_SOLID
  color = 0xDD101010

  children = @() {
    watch = safeAreaSizeHud
    size = flex()
    margin = safeAreaSizeHud.get().borders
    padding = [multiplayerScoreHeightWithOffset, 0, 0, 0]

    children = [
      verticalViewIndicatorFrame
      mkCentralBlock()
      mkFrame(targetListMain, loc("hud/target_list"), { hplace = ALIGN_RIGHT })
      mkFrame(mkCameraRender(), loc("hud/sight_view"))
    ]
  }
}

return { aaComplexMenu }
