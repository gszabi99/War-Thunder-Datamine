from "%rGui/globals/ui_library.nut" import *
let string = require("string")
let { targets, TargetsTrigger, HasAzimuthScale, AzimuthMin,
  AzimuthRange, HasDistanceScale, DistanceMax, DistanceMin
} = require("%rGui/radarState.nut")
let { deferOnce } = require("dagor.workcycle")
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
let { mkFrame, shortcutButtonPadding, frameHeaderHeight, borderWidth,
  makeTargetStatusEllementFactory, targetsSortFunction, targetSortFunctionWatched
} = require("%rGui/antiAirComplexMenu/antiAirMenuBaseComps.nut")
let { antiAirMenuShortcutHeight } = require("%rGui/hints/shortcuts.nut")
let { actionBarSize, isActionBarVisible, isActionBarCollapsed, actionBarActionsCount
} = require("%rGui/hud/actionBarState.nut")
let { actionBarTopPanelMarginBottom, actionBarTopPanelHeight
} = require("%rGui/hud/actionBarTopPanel.nut")
let { aaMenuCfg } = require("antiAirComplexMenuState.nut")
let { mkImageCompByDargKey } = require("%rGui/components/gamepadImgByKey.nut")
let { showConsoleButtons } = require("%rGui/ctrlsState.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let scrollbar = require("%rGui/components/scrollbar.nut")
let { mkZoomMinBtn, mkZoomMaxBtn, radarColor, mkSensorTypeSwitchBtn, mkSensorSwitchBtn,
  mkSensorScanPatternSwitchBtn, mkSensorRangeSwitchBtn, mkSensorTargetLockBtn,
  mkFireBtn, mkSpecialFireBtn, mkWeaponLockBtn, mkNightVisionBtn, zoomControlByMouseWheel
} = require("%rGui/antiAirComplexMenu/antiAirComplexControlsButtons.nut")
let { mkFilterTargetsBtn } = require("antiAirComplexMenuTargetsList.nut")

let scrollHandler = ScrollHandler()
let blockInterval = hdpx(6)

let multiplayerScoreHeightWithOffset = shHud(5)
let hudActionBarItemSize = shHud(6)
let hudActionBarItemOffset = shHud(0.5)
let sizeDamageIndicatorFull = shHud(30)
let panelsGap = hdpx(8)
let targetRowHeight = evenPx(32)
let targetRowPadding = hdpx(8)
let defLeftPanelsWidth = hdpx(480)
let defRightPanelsWidth = hdpx(520)
let defRadarHeight = hdpx(716)
let controlPanelHeight = frameHeaderHeight + 2*antiAirMenuShortcutHeight + 5*panelsGap
let occupiedCenterHeight = multiplayerScoreHeightWithOffset
  + controlPanelHeight + actionBarTopPanelHeight
  + actionBarTopPanelMarginBottom
let shortcutsBtnPadding = panelsGap - shortcutButtonPadding

let radarHeight = Computed(@()
  min(rh.get() - (actionBarSize.get()?[1] ?? 0) - occupiedCenterHeight, defRadarHeight))

let topDamageIndicator = Computed(@() !needShowDmgIndicator.get() ? sh(100) - sizeDamageIndicatorFull
  : dmgIndicatorStates.get()?.pos[1] ?? 0)

let planeTargetPicture = Picture($"!ui/gameuiskin#voice_message_jet.svg")
let helicopterTargetPicture = Picture($"!ui/gameuiskin#voice_message_helicopter.svg")
let rocketTargetPicture = Picture($"!ui/gameuiskin#voice_message_missile.svg")

let contentScale = Computed(function() {
  let safeAreaWidth = safeAreaSizeHud.get().size[0]
  let intersectsLeft = radarHeight.get() / 2 + defLeftPanelsWidth + panelsGap > safeAreaWidth / 2
  let shortcutButtonWidth = showConsoleButtons.get() ? 1.2 * targetRowHeight-targetRowPadding : 0
  let intersectsRight = radarHeight.get() / 2 + defRightPanelsWidth + panelsGap + shortcutButtonWidth > safeAreaWidth / 2
  let kLeft = intersectsLeft ? 0.95 * safeAreaWidth / (radarHeight.get() + 2 * defLeftPanelsWidth + panelsGap) : 1
  let kRight = intersectsRight ? 0.95 * safeAreaWidth / (radarHeight.get() + 2 * defRightPanelsWidth + panelsGap) : 1
  return min(kLeft, kRight)
})

function scrollTargetsListToTarget(index) {
  let scrollComp = scrollHandler.elem
  if (scrollComp == null)
    return

  let scrollCompHeight = scrollComp.getHeight()
  let scrollContentShift = scrollComp.getScrollOffsY()

  let isItemAboveViewport = index * targetRowHeight - scrollContentShift < 0
  if (isItemAboveViewport)
    scrollHandler.scrollToY(index * targetRowHeight)

  let isItemBelowViewport = (index + 1) * targetRowHeight - scrollContentShift > scrollCompHeight
  if (isItemBelowViewport)
    scrollHandler.scrollToY((index + 1) * targetRowHeight - scrollCompHeight)
}

let leftPanelsHeight = Computed(function() {
  let scaledRadarHeight = (radarHeight.get() + frameHeaderHeight) * contentScale.get()
  return min(topDamageIndicator.get() - bh.get() - multiplayerScoreHeightWithOffset - panelsGap, scaledRadarHeight)
})

let leftPanelsWidth = Computed(@() defLeftPanelsWidth * contentScale.get())
let rightPanelsWidth = Computed(@() defRightPanelsWidth * contentScale.get())

function mkVerticalViewIndicator() {
  let verticalViewIndicatorHeight = Computed(@() leftPanelsHeight.get() * 0.4 - panelsGap / 2 - frameHeaderHeight * contentScale.get() - 2 * borderWidth)
  return @() {
    watch = [aaMenuCfg, contentScale, verticalViewIndicatorHeight, leftPanelsWidth]
    size = [leftPanelsWidth.get(), verticalViewIndicatorHeight.get()]
    rendObj = ROBJ_DAS_CANVAS
    script = dasVerticalViewIndicator
    drawFunc = "draw"
    setupFunc = "setup"
    font = Fonts.hud
    fontSize = hdpx(14 * contentScale.get())
    planeTargetPicture
    helicopterTargetPicture
    rocketTargetPicture
    maxAltitude = aaMenuCfg.get()?["verticalViewMaxAltitude"]
  }
}

function mkVerticalViewIndicatorFrame() {
  let verticalViewIndicatorPos = Computed(@() leftPanelsHeight.get() * 0.6 + panelsGap / 2)
  return @() {
    watch = [verticalViewIndicatorPos, contentScale]
    pos = [0, verticalViewIndicatorPos.get()]
    children = mkFrame(mkVerticalViewIndicator(), { text = loc("hud/elevation_azimuth_indicator"), scale = contentScale.get() })
  }
}

function mkCameraRender() {
  let cameraRenderHeight = Computed(@() leftPanelsHeight.get() * 0.6 - panelsGap / 2 - frameHeaderHeight * contentScale.get() - 2 * borderWidth)
  return @() {
    watch = [cameraRenderHeight, leftPanelsWidth]
    size = [leftPanelsWidth.get(), cameraRenderHeight.get()]
    rendObj = ROBJ_TACTICAL_CAMERA_RENDER
    onAttach = @() setRenderCameraToHudTexture(true)
    onDetach = @() setRenderCameraToHudTexture(false)
    children = mkFrame({
      margin = shortcutsBtnPadding
      flow = FLOW_HORIZONTAL
      gap = shortcutsBtnPadding
      children = [mkZoomMinBtn(), mkZoomMaxBtn()]
    }, null, { vplace = ALIGN_BOTTOM, hplace = ALIGN_RIGHT, margin = panelsGap })
  }
}

let circularRadar = @() {
  watch = [radarHeight, contentScale]
  size = [radarHeight.get() * contentScale.get(), radarHeight.get() * contentScale.get()]
  rendObj = ROBJ_DAS_CANVAS
  script = dasRadarHud
  drawFunc = "draw_radar_hud"
  setupFunc = "setup_radar_data"
  font = Fonts.hud
  fontSize = hdpx(16 * contentScale.get())
  color = radarColor
  annotateTargets = true
  handleClicks = true
  isAAComplexMenuLayout = true
  vignetteColor = 0xFF304054
  planeTargetPicture
  helicopterTargetPicture
  rocketTargetPicture
  children = {
    margin = shortcutsBtnPadding
    vplace = ALIGN_BOTTOM
    children = mkSensorTypeSwitchBtn()
  }
}

let mkRadarControl = @() {
  padding = shortcutsBtnPadding
  gap = hdpx(20)
  flow = FLOW_HORIZONTAL
  children = [
    {
      gap = shortcutsBtnPadding
      flow = FLOW_VERTICAL
      children = [mkSensorSwitchBtn(), mkSensorScanPatternSwitchBtn()]
    }
    {
      gap = shortcutsBtnPadding
      flow = FLOW_VERTICAL
      children = [mkSensorRangeSwitchBtn(), mkSensorTargetLockBtn()]
    }
  ]
}

let mkFireControl = @() {
  padding = shortcutsBtnPadding
  gap = hdpx(20)
  flow = FLOW_HORIZONTAL
  children = [
    {
      gap = shortcutsBtnPadding
      flow = FLOW_VERTICAL
      children = [mkFireBtn(), mkSpecialFireBtn()]
    }
    mkWeaponLockBtn()
  ]
}

let mkCentralBlock = @() @() {
  watch = contentScale
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = panelsGap
  children = [
    mkFrame(circularRadar,{ text = loc("hud/plan_position_indicator"), scale = contentScale.get() },
      { opacity = 0.8 })
    {
      flow = FLOW_HORIZONTAL
      gap = panelsGap
      children = [
        mkFrame(mkRadarControl, { text = loc("hud/radar_control") })
        mkFrame(mkFireControl, { text = loc("hud/fire_control") })
      ]
    }
  ]
}

let selectTarget = @(target) radarSwitchToTarget(target.objectId)
let isVisibleTarget = @(target) target != null
  && target.targetType != RADAR_TAGET_TYPE_OWN_WEAPON_TARGET
  && target.targetType != RADAR_TAGET_TYPE_OWN_WEAPON

function findNewTarget(inc) {
  let visibleTargets = targets.filter(isVisibleTarget).sort(targetsSortFunction)
  let targetsCount = visibleTargets.len()
  if (targetsCount == 0)
    return null

  local curTargetIdx = visibleTargets.findindex(@(target) target?.isDetected)
  curTargetIdx = curTargetIdx ?? visibleTargets.findindex(@(target) target?.isSelected) 
  if (curTargetIdx == null)
    curTargetIdx = inc > 0 ? -1 : targetsCount
  return visibleTargets[clamp(curTargetIdx + inc, 0, targetsCount-1)]
}

function findAndSelectTarget(inc) {
  let target = findNewTarget(inc)
  if (target != null)
    selectTarget(target)
}

let selectPrevTarget = @() findAndSelectTarget(-1)
let selectNextTarget = @() findAndSelectTarget(1)

let targetTypeIconStatus = {
  construct_header = @(_) { size = [flex(4), flex()] }
  construct_ellement = function(target, _) {
    local icon = null
    let iconType = target.iconType
    if (iconType == RADAR_TAGET_ICON_NONE) {
      icon = null
    } else if (iconType == RADAR_TAGET_ICON_JET) {
      icon = planeTargetPicture
    } else if (iconType == RADAR_TAGET_ICON_HELICOPTER) {
      icon = helicopterTargetPicture
    } else if (iconType == RADAR_TAGET_ICON_ROCKET) {
      icon = rocketTargetPicture
    } else {
      logerr($"could not parse target type {iconType}")
    }
    return {
      size = [flex(4), flex()]
      rendObj = ROBJ_IMAGE
      image = icon
    }
  }
}

let targetStatusFactories = [
  {key = "index", ell = makeTargetStatusEllementFactory([flex(4), flex()], "#",
    @(target) target.persistentIndex,
    function(index, target){
      let indexStr = index.tostring()
      if (target.isAttacked){
        return "".concat(indexStr, "*")
      }
      return indexStr
    })}

  {key = "azimuth", ell = makeTargetStatusEllementFactory([flex(13), flex()], loc("hud/AAComplexMenu/azimuth"),
    @(target) target.azimuthRel,
    function(azimuth_rel, _) {
      let radToDeg = 180.0 / PI
      let azimuth = (AzimuthMin.get() + AzimuthRange.get() * azimuth_rel) * radToDeg
      let text = HasAzimuthScale.get() ? string.format("%d", floor(azimuth)) : "-"
      return text
    },
    { watch = [AzimuthMin, AzimuthRange, HasAzimuthScale] })}

  {key = "distance", ell = makeTargetStatusEllementFactory([flex(17), flex()], loc("hud/AAComplexMenu/distance"),
    @(target) target.distanceRel,
    function(dist_rel, _){
      let distance = lerp(0.0, 1.0, DistanceMin.get(), DistanceMax.get(), dist_rel)
      let text = HasDistanceScale.get() ? string.format("%.1f", distance) : "-"
      return text
    },
    { watch = [DistanceMin, DistanceMax, HasDistanceScale] })}

  {key = "height", ell = makeTargetStatusEllementFactory([flex(17), flex()], loc("hud/AAComplexMenu/height"),
    @(target) target.heightRel,
    @(height, _) string.format("%.1f", height * 0.001))}

  {key = "speed", ell = makeTargetStatusEllementFactory([flex(17), flex()], loc("hud/AAComplexMenu/speed"),
    @(target) target.radSpeed
    @(rad_speed, _) rad_speed > -3000.0 ? string.format("%.1f", rad_speed) : "-")}

  {key = "courseDist", ell = makeTargetStatusEllementFactory([flex(4), flex()], loc("hud/AAComplexMenu/courseDist"),
    @(target) target.courseDist
    @(course_dist, _) course_dist >= 0.0 ? string.format("%.1f", course_dist * 0.001) : loc("hud/AAComplexMenu/courseDistUnknown"))}

  {key = "typeIcon", ell = targetTypeIconStatus }

  {key = "typeText", ell = makeTargetStatusEllementFactory(flex(20), loc("hud/AAComplexMenu/type"),
    @(target) target.typeId,
    @(target_id, _) loc(target_id))}

  {key = "IFF", ell = makeTargetStatusEllementFactory([flex(10), flex()], loc("hud/AAComplexMenu/IFF/header"),
    @(target) target.isEnemy,
    @(is_enemy, _) is_enemy ? loc("hud/AAComplexMenu/IFF/enemy") : loc("hud/AAComplexMenu/IFF/ally"))}
]

function createTargetListElement(is_header, target, scale, isSelected = false, ovr = {}) {
  let fontSize = is_header ? hdpx(14 * scale) : hdpx(16 * scale)
  return @() {
    watch = aaMenuCfg
    size = [flex(), targetRowHeight]
    rendObj = ROBJ_SOLID
    color = isSelected ? 0x19191919 : 0
    padding = targetRowPadding

    children = [
      !isSelected || !showConsoleButtons.get() ? null
        : mkImageCompByDargKey("J:R.Thumb.v", 0, {
            pos = [-1.2*targetRowHeight-targetRowPadding, 0]
            height = 1.2*targetRowHeight
            vplace = ALIGN_CENTER
            zOrder = Layers.Tooltip
          })
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        children = targetStatusFactories.map(function(prot){
          let isPresent =  aaMenuCfg.get().targetList?[prot.key] ?? true

          if (isPresent){
            return is_header ? prot.ell.construct_header(fontSize) : prot.ell.construct_ellement(target, fontSize)
          }
          return null
        })
      }
    ]
  }.__update(ovr)
}

let targetLock = @() toggleShortcut("ID_SENSOR_TARGET_LOCK_TANK")

function createTargetDist(index, target, scale, isShowConsoleButtons) {
  let ovr = {
    behavior = Behaviors.Button
    onClick = @() selectTarget(target)
    function onDoubleClick() {
      selectTarget(target)
      deferOnce(targetLock)
    }
  }

  let targetElement = createTargetListElement(false, target, scale, target.isDetected, ovr)

  if (target.isDetected && isShowConsoleButtons)
    scrollTargetsListToTarget(index)

  return targetElement
}

let targetList = @() {
  watch = [TargetsTrigger, contentScale, targetSortFunctionWatched]
  size = flex()
  flow = FLOW_VERTICAL
  children = scrollbar.makeSideScroll({
    size = FLEX_H
    margin = [0, blockInterval]
    flow = FLOW_VERTICAL
    children = targets
      .filter(isVisibleTarget)
      .sort(targetsSortFunction)
      .map(@(t, i) createTargetDist(i, t, contentScale.get(), showConsoleButtons.get()))
    },
    {
      scrollHandler = scrollHandler
      joystickScroll = false
    })
}

let targetListMain = @() {
  watch = [radarHeight, rightPanelsWidth, contentScale]
  size = [rightPanelsWidth.get(), radarHeight.get() * contentScale.get()]
  flow = FLOW_VERTICAL
  hotkeys = [["^J:R.Thumb.Up", @() selectPrevTarget()],
    ["^J:R.Thumb.Down", @() selectNextTarget()]]
  children = [
    createTargetListElement(true, null, contentScale.get(), false),
    targetList
  ]
}

let invisibleAction = {
  size = [hudActionBarItemSize, hudActionBarItemSize]
  margin = [0, hudActionBarItemOffset]
  gap = hudActionBarItemOffset
  behavior = Behaviors.Button 
}

function fakeActionBar() { 
  let res = { watch = [isActionBarVisible, isActionBarCollapsed, actionBarActionsCount] }
  if (!isActionBarVisible.get() || isActionBarCollapsed.get())
    return res
  return res.__update({
    hplace = ALIGN_CENTER
    vplace = ALIGN_BOTTOM
    flow = FLOW_HORIZONTAL
    children = array(actionBarActionsCount.get(), null)
      .map(@(_) clone invisibleAction)
  })
}

let aaComplexMenu = {
  size = flex()
  rendObj = ROBJ_SOLID
  color = 0xDD101010

  children = @() {
    watch = [safeAreaSizeHud, aaMenuCfg, contentScale]
    size = flex()
    margin = safeAreaSizeHud.get().borders
    padding = [multiplayerScoreHeightWithOffset, 0, 0, 0]

    children = [
      zoomControlByMouseWheel
      aaMenuCfg.get()?["hasVerticalView"] ? mkVerticalViewIndicatorFrame() : null
      mkCentralBlock()
      aaMenuCfg.get()?["hasTargetList"]
        ? mkFrame(targetListMain,
          { text = loc("hud/target_list"), scale = contentScale.get(),
            rightBlock = mkFilterTargetsBtn(contentScale.get()) },
          { hplace = ALIGN_RIGHT })
        : null
      aaMenuCfg.get()?["hasTurretView"]
        ? mkFrame(mkCameraRender(), {
            text = loc("hud/sight_view"),
            scale = contentScale.get(),
            rightBlock = mkNightVisionBtn(contentScale.get())
          })
        : null
      fakeActionBar
    ]
  }
}

return { aaComplexMenu }