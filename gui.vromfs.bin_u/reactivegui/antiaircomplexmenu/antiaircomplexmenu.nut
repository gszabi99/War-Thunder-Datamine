from "%rGui/globals/ui_library.nut" import *

let { hasSpecialWeapon, hasManySensorScanPattern, hasTargetTrack, hasWeaponLock } = require("vehicleModel")
let string = require("string")
let { targets, TargetsTrigger, HasAzimuthScale, AzimuthMin,
  AzimuthRange, HasDistanceScale, DistanceMax, DistanceMin,
  CueVisible, CueReferenceTurretAzimuth, CueAzimuth, CueAzimuthHalfWidthRel, CueDistWidthRel, CueDist
  TargetRadarAzimuthWidth, TargetRadarDist
} = require("%rGui/radarState.nut")
let { deferOnce, setTimeout, clearTimer } = require("dagor.workcycle")
let { PI, floor, lerp, fabs } = require("%sqstd/math.nut")
let { norm_s_ang } = require("dagor.math")
let { radarSwitchToTarget } = require("radarGuiControls")
let { RadarTargetType, RadarTargetIconType } = require("guiRadar")
let { RADAR_TAGET_ICON_NONE, RADAR_TAGET_ICON_JET, RADAR_TAGET_ICON_HELICOPTER, RADAR_TAGET_ICON_ROCKET } = RadarTargetIconType
let { RADAR_TAGET_TYPE_OWN_WEAPON, RADAR_TAGET_TYPE_OWN_WEAPON_TARGET } = RadarTargetType
let { safeAreaSizeHud, bh, rh } = require("%rGui/style/screenState.nut")
let { needShowDmgIndicator, dmgIndicatorStates } = require("%rGui/hudState.nut")
let { setRenderCameraToHudTexture } = require("hudState")
let { logerr } = require("dagor.debug")
let { mkFrame, shortcutButtonPadding, frameHeaderHeight, borderWidth,
  makeTargetStatusEllementFactory, targetsSortFunction, targetSortFunctionWatched,
  frameBorderColor, frameBackgroundColor } = require("%rGui/antiAirComplexMenu/antiAirMenuBaseComps.nut")
let { antiAirMenuShortcutHeight } = require("%rGui/hints/shortcuts.nut")
let { actionBarSize, isActionBarVisible, isActionBarCollapsed, actionBarActionsCount
} = require("%rGui/hud/actionBarState.nut")
let { actionBarTopPanelMarginBottom, actionBarTopPanelHeight
} = require("%rGui/hud/actionBarTopPanel.nut")
let { aaMenuCfg } = require("%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut")
let { mkImageCompByDargKey } = require("%rGui/components/gamepadImgByKey.nut")
let { showConsoleButtons } = require("%rGui/ctrlsState.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { scrollbarWidth, makeSideScroll } = require("%rGui/components/scrollbar.nut")
let { mkZoomMinBtn, mkZoomMaxBtn, radarColor, mkSensorTypeSwitchBtn, mkSensorSwitchBtn,
  mkSensorScanPatternSwitchBtn, mkSensorRangeSwitchBtn, mkSensorTargetLockBtn,
  mkFireBtn, mkSpecialFireBtn, mkWeaponLockBtn, mkNightVisionBtn, zoomControlByMouseWheel
} = require("%rGui/antiAirComplexMenu/antiAirComplexControlsButtons.nut")
let { mkFilterTargetsBtn, planeTargetPicture, helicopterTargetPicture, rocketTargetPicture
} = require("%rGui/antiAirComplexMenu/antiAirComplexMenuTargetsList.nut")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")
let { radarCanvas } = require("%rGui/radar.nut")
local tooltipTimer = null

let headerToopltipLocs = {
  azimuth = "hud/AAComplexMenu/azimuth/tooltip"
  distance = "hud/AAComplexMenu/distance/tooltip"
  height = "hud/AAComplexMenu/height/tooltip"
  speed = "hud/AAComplexMenu/speed/tooltip"
  courseDist = "hud/AAComplexMenu/courseDist/tooltip"
  typeText = "hud/AAComplexMenu/type/tooltip"
  IFF = "hud/AAComplexMenu/IFF/tooltip"
}

let headerTooltipData = Watched({ id = null, pos = [0, 0] })

let scrollHandler = ScrollHandler()
let blockInterval = hdpx(6)

let multiplayerScoreHeightWithOffset = shHud(5)
let hudActionBarItemSize = shHud(6)
let hudActionBarItemOffset = shHud(0.5)
let sizeDamageIndicatorFull = shHud(30)
let panelsGap = hdpx(8)
let targetRowHeight = evenPx(32)
let targetsListPadding = hdpx(4)
let defLeftPanelsWidth = hdpx(480)
let defRightPanelsWidth = hdpx(560)
let defRadarHeight = hdpx(716)
let targetTypeIconHeight = evenPx(24)
let targetTypeIconSize = [targetTypeIconHeight, targetTypeIconHeight]
let controlPanelHeight = frameHeaderHeight + 2*antiAirMenuShortcutHeight + 5*panelsGap
let occupiedCenterHeight = multiplayerScoreHeightWithOffset
  + controlPanelHeight + actionBarTopPanelHeight
  + actionBarTopPanelMarginBottom
let shortcutsBtnPadding = panelsGap - shortcutButtonPadding

let radarHeight = Computed(@()
  min(rh.get() - (actionBarSize.get()?[1] ?? 0) - occupiedCenterHeight, defRadarHeight))

let topDamageIndicator = Computed(@() !needShowDmgIndicator.get() ? sh(100) - sizeDamageIndicatorFull
  : dmgIndicatorStates.get()?.pos[1] ?? 0)

let imageByTargetIconType = {
  [RADAR_TAGET_ICON_JET] = planeTargetPicture,
  [RADAR_TAGET_ICON_HELICOPTER] = helicopterTargetPicture,
  [RADAR_TAGET_ICON_ROCKET] = rocketTargetPicture,
}

let contentScale = Computed(function() {
  let safeAreaWidth = safeAreaSizeHud.get().size[0]
  let intersectsLeft = radarHeight.get() / 2 + defLeftPanelsWidth + panelsGap > safeAreaWidth / 2
  let shortcutButtonWidth = showConsoleButtons.get() ? 1.2 * targetRowHeight-targetsListPadding : 0
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
    script = getDasScriptByPath("%rGui/antiAirComplexMenu/verticalViewIndicator.das")
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

let circularRadar = @() radarCanvas(null, {
  watch = [radarHeight, contentScale]
  size = [radarHeight.get() * contentScale.get(), radarHeight.get() * contentScale.get()]
  font = Fonts.hud
  fontSize = hdpx(16 * contentScale.get())
  color = radarColor
  annotateTargets = true
  isAAComplexMenuLayout = true
  vignetteColor = 0xFF304054
  planeTargetPicture
  helicopterTargetPicture
  rocketTargetPicture
  screenHeight = sh(100)
  children = {
    margin = shortcutsBtnPadding
    vplace = ALIGN_BOTTOM
    children = mkSensorTypeSwitchBtn()
  }
}, true)()

let mkRadarControl = @() {
  padding = shortcutsBtnPadding
  gap = hdpx(20)
  flow = FLOW_HORIZONTAL
  children = [
    {
      gap = shortcutsBtnPadding
      flow = FLOW_VERTICAL
      children = [mkSensorSwitchBtn(), hasManySensorScanPattern() ? mkSensorScanPatternSwitchBtn() : null]
    }
    {
      gap = shortcutsBtnPadding
      flow = FLOW_VERTICAL
      children = [mkSensorRangeSwitchBtn(), hasTargetTrack() ? mkSensorTargetLockBtn() : null]
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
      children = [mkFireBtn(), hasSpecialWeapon() ? mkSpecialFireBtn() : null]
    }
    hasWeaponLock() ? mkWeaponLockBtn() : null
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

function isTargetInLockZone(target, az_min, az_range, turret_az, az_width, max_dist) {
  let turretAzimuth = az_min + az_range * turret_az
  let targetAz = az_min + az_range * target.azimuthRel
  let targetDelta = norm_s_ang(targetAz - turretAzimuth)
  let azimuthCheck = fabs(targetDelta) <= az_width

  let distanceCheck = target.distanceRel <= max_dist
  return azimuthCheck && distanceCheck
}

let hasSelectedTarget = Computed(function() {
  let trigger = TargetsTrigger.get()  
  return targets.findindex(@(target) target?.isSelected) != null
})

function findNewTarget(inc) {
  let isTargetAccessible = @(target) isVisibleTarget(target) && (!hasSelectedTarget.get()
    || isTargetInLockZone(target, AzimuthMin.get(), AzimuthRange.get(), CueReferenceTurretAzimuth.get(), TargetRadarAzimuthWidth.get(), TargetRadarDist.get()))
  let visibleTargets = targets.filter(isTargetAccessible).sort(targetsSortFunction)
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
  construct_header = @(_, __) { size = targetTypeIconSize }
  construct_ellement = function(target, _) {
    let iconType = target.iconType
    let icon = imageByTargetIconType?[iconType]
    if (icon == null && iconType != RADAR_TAGET_ICON_NONE)
      logerr($"could not parse target type {iconType}")

    return {
      size = targetTypeIconSize
      rendObj = ROBJ_IMAGE
      image = icon
    }
  }
}

function getTargetStatusIndexText(target){
  let indexStr = target.persistentIndex.tostring()
  if (target.isAttacked){
    return "".concat(indexStr, "*")
  }
  return indexStr
}

function onHoverHeader(on, rect, id) {
  clearTimer(tooltipTimer)
  if (!on) {
    headerTooltipData.set({ id = null })
    return
  }
  let pos = [rect.l, rect.b + blockInterval]
  tooltipTimer = setTimeout(1, @() headerTooltipData.set({ id, pos }))
}

let mkTooltipText = @(text) {
  maxWidth = sh(30)
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  font = Fonts.tiny_text_hud
  text
}

function mkTooltipHeader() {
  let { id, pos = [0, 0] } = headerTooltipData.get()
  if (id == null || id not in headerToopltipLocs)
    return { watch = headerTooltipData }

  let tooltipText = mkTooltipText(loc(headerToopltipLocs?[id]))
  let tooltipWidth = calc_comp_size(tooltipText)[0] + 2 * hdpx(7)

  return {
    rendObj = ROBJ_BOX
    watch = [ headerTooltipData ]
    pos = [min(pos[0], sw(100) - tooltipWidth), pos[1]]
    zOrder = Layers.Tooltip
    fillColor = frameBackgroundColor
    borderColor = frameBorderColor
    borderWidth = dp(1)
    padding = static [hdpx(7), hdpx(10)]
    children = tooltipText
  }
}

let targetStatusFactories = [
  {key = "index", ell = makeTargetStatusEllementFactory([flex(7), flex()], "#",
    @(target) target.persistentIndex,
    @(_, target) getTargetStatusIndexText(target),
    function(target) {
      local upd = {}
      if (target.isSelectedTargetOfInterest)
        upd = {
          children = {
            size = flex()
            rendObj = ROBJ_BOX
            borderColor = 0xFFAAAAAA
            borderWidth = hdpx(1)
          }
        }
      return upd
    })}

  {key = "azimuth", ell = makeTargetStatusEllementFactory([flex(11), flex()], loc("hud/AAComplexMenu/azimuth"),
    @(target) target.azimuthRel,
    function(azimuth_rel, _) {
      let radToDeg = 180.0 / PI
      let azimuth = (AzimuthMin.get() + AzimuthRange.get() * azimuth_rel) * radToDeg
      let text = HasAzimuthScale.get() ? string.format("%d", floor(azimuth)) : "-"
      return text
    },
    { watch = [AzimuthMin, AzimuthRange, HasAzimuthScale] })}

  {key = "distance", ell = makeTargetStatusEllementFactory([flex(15), flex()], loc("hud/AAComplexMenu/distance"),
    @(target) target.distanceRel,
    function(dist_rel, _){
      let distance = lerp(0.0, 1.0, DistanceMin.get(), DistanceMax.get(), dist_rel)
      let text = HasDistanceScale.get() ? string.format("%.1f", distance) : "-"
      return text
    },
    { watch = [DistanceMin, DistanceMax, HasDistanceScale] })}

  {key = "height", ell = makeTargetStatusEllementFactory([flex(16), flex()], loc("hud/AAComplexMenu/height"),
    @(target) target.heightRel,
    @(height, _) string.format("%.1f", height * 0.001))}

  {key = "speed", ell = makeTargetStatusEllementFactory([flex(15), flex()], loc("hud/AAComplexMenu/speed"),
    @(target) target.radSpeed
    @(rad_speed, _) rad_speed > -3000.0 ? string.format("%.1f", rad_speed) : "-")}

  {key = "courseDist", ell = makeTargetStatusEllementFactory([flex(4), flex()], loc("hud/AAComplexMenu/courseDist"),
    @(target) target.courseDist
    @(course_dist, _) course_dist >= 0.0 ? string.format("%.1f", course_dist * 0.001) : loc("hud/AAComplexMenu/courseDistUnknown"))}

  {key = "typeIcon", ell = targetTypeIconStatus }

  {key = "typeText", ell = makeTargetStatusEllementFactory(flex(18), loc("hud/AAComplexMenu/type"),
    @(target) target.typeId,
    @(target_id, _) loc(target_id))}

  {key = "IFF", ell = makeTargetStatusEllementFactory([flex(9), flex()], loc("hud/AAComplexMenu/IFF/header"),
    @(target) target.isEnemy,
    @(is_enemy, _) is_enemy ? loc("hud/AAComplexMenu/IFF/enemy") : loc("hud/AAComplexMenu/IFF/ally"))}
]

let targetLock = @() toggleShortcut("ID_SENSOR_TARGET_LOCK_TANK")

function isTargetInCueZone(target, azimuthMin, azimuthRange, cueReferenceTurretAzimuth, targetRadarAzimuthWidth, cueAzimuthHalfWidthRel, cueAzimuthRel,
  cueDistWidthRel, cueDist, targetRadarDist) {
  let turretAzimuth = azimuthMin + azimuthRange * cueReferenceTurretAzimuth

  let targetAz = azimuthMin + azimuthRange * target.azimuthRel
  let targetDelta = norm_s_ang(targetAz - turretAzimuth)

  let cueAzimuth = cueAzimuthRel * max(targetRadarAzimuthWidth - cueAzimuthHalfWidthRel * azimuthRange, 0.0)
  let cueAzimuthMin = cueAzimuth - cueAzimuthHalfWidthRel * azimuthRange
  let cueAzimuthMax = cueAzimuth + cueAzimuthHalfWidthRel * azimuthRange

  let isInCueAzimuth = cueAzimuthMin <= targetDelta && targetDelta <= cueAzimuthMax

  let distRel = 0.5 * cueDistWidthRel + cueDist * targetRadarDist * (1.0 - cueDistWidthRel)
  let halfDistGateWidthRel = 0.5 * cueDistWidthRel
  let radiusMin = distRel - halfDistGateWidthRel
  let radiusMax = distRel + halfDistGateWidthRel

  let isInCueDist = radiusMin <= target.distanceRel && target.distanceRel <= radiusMax

  return isInCueAzimuth && isInCueDist
}

function createTargetListElement(is_header, target, scale, isSelected = false) {
  let fontSize = is_header ? hdpx(14 * scale) : hdpx(16 * scale)

  let isThisTargetInLockZone = Computed(@() target != null && isTargetInLockZone(target,
    AzimuthMin.get(), AzimuthRange.get(), CueReferenceTurretAzimuth.get(),
    TargetRadarAzimuthWidth.get(), TargetRadarDist.get()))

  return @() {
    watch = [aaMenuCfg, isThisTargetInLockZone, hasSelectedTarget]

    behavior = !is_header ? Behaviors.Button : null
    function onClick(){
     if (isThisTargetInLockZone.get() || !hasSelectedTarget.get())
      selectTarget(target)
    }
    function onDoubleClick() {
      if (hasSelectedTarget.get()) {
        targetLock()
        deferOnce(@() selectTarget(target))
      }
      else {
        selectTarget(target)

        let isSelectedByCue = !CueVisible.get() ? target.isDetected : isTargetInCueZone(target, AzimuthMin.get(),
          AzimuthRange.get(), CueReferenceTurretAzimuth.get(), TargetRadarAzimuthWidth.get(), CueAzimuthHalfWidthRel.get(),
          CueAzimuth.get(), CueDistWidthRel.get(), CueDist.get(), TargetRadarDist.get())
        if (isSelectedByCue)
          targetLock()
      }
    }

    size = [flex(), targetRowHeight]

    children = [
      !isSelected || !showConsoleButtons.get() ? null
        : mkImageCompByDargKey("J:R.Thumb.v", 0, {
            pos = [-1.2*targetRowHeight-targetsListPadding, 0]
            height = 1.2*targetRowHeight
            vplace = ALIGN_CENTER
            zOrder = Layers.Tooltip
          })
      @() {
        watch = [hasSelectedTarget, isThisTargetInLockZone]
        rendObj = ROBJ_SOLID
        size = flex()
        color = is_header ? 0
        : isSelected ? 0x19191919
        : isThisTargetInLockZone.get() ? 0
        : hasSelectedTarget.get() ? 0x19190000 : 0x09090000
      }
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        children = targetStatusFactories.map(function(prot){
          let isPresent =  aaMenuCfg.get().targetList?[prot.key] ?? true

          if (isPresent){
            return is_header ? prot.ell.construct_header(fontSize, @(on, rect) onHoverHeader(on, rect, prot.key)) : prot.ell.construct_ellement(target, fontSize)
          }
          return null
        })
      }
    ]
  }
}

function createTargetDist(index, target, scale, isShowConsoleButtons) {
  let targetElement = createTargetListElement(false, target, scale, target.isDetected)

  if (target.isDetected && isShowConsoleButtons)
    scrollTargetsListToTarget(index)

  return targetElement
}

let targetList = @() {
  watch = [TargetsTrigger, contentScale, targetSortFunctionWatched]
  size = flex()
  flow = FLOW_VERTICAL
  children = makeSideScroll({
    margin = [0, targetsListPadding, 0, 0]
    size = FLEX_H
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
  padding = targetsListPadding
  flow = FLOW_VERTICAL
  hotkeys = [["^J:R.Thumb.Up", @() selectPrevTarget()],
    ["^J:R.Thumb.Down", @() selectNextTarget()]]
  children = [
    {
      size = FLEX_H
      padding = [0, scrollbarWidth + targetsListPadding, 0, 0]
      children = createTargetListElement(true, null, contentScale.get(), false),
    }
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

  children = [
    @() {
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
    mkTooltipHeader
  ]
}

return { aaComplexMenu }