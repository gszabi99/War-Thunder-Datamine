from "%rGui/globals/ui_library.nut" import *
let { setVirtualAxisValue } = require("controls")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let hints = require("%rGui/hints/hints.nut")
let { Irst, modeNames, RadarModeNameId, IsRadarVisible, HasHelmetTarget, MfdRadarOffsetX,
  IsRadarHudVisible, IsRadarHasFilters
} = require("%rGui/radarState.nut")
let { setTimeout, clearTimer, defer } = require("dagor.workcycle")
let { eventbus_subscribe } = require("eventbus")
let { RadarTargetsIffFilterMask, AirRadarGuiControlMode, getAirRadarGuiControlMode, getNextRadarTargetsIffFilterMask } = require("radarGuiControls")
let { AIR_RADAR_GUI_CONTROL_HIDDEN, AIR_RADAR_GUI_CONTROL_BUTTONAS_AND_SHORTCUTS } = AirRadarGuiControlMode
let { showConsoleButtons, cursorVisible } = require("%rGui/ctrlsState.nut")
let { isPlayingReplay, isUnitAlive, unitType } = require("%rGui/hudState.nut")
let { HudColor } = require("%rGui/airState.nut")
let { adjustColorBrightness } = require("%rGui/style/airHudStyle.nut")
let JB = require("%rGui/control/gui_buttons.nut")
let { register_command } = require("console")
let { isInFlight } = require("%rGui/globalState.nut")
let { mkImageCompByDargKey } = require("%rGui/components/gamepadImgByKey.nut")
let { IFFFilter, typeFilter, filterPresets, switchFilter, isFiltersExpanded } = require("%rGui/radarFilters.nut")
let { isAir } = require("%rGui/hudUnitType.nut")

const HELI_AXIS_CONTROL_PREFIX = "helicopter_"

const BUTTON_BG_DARK_FACTOR = 0.1
const BUTTON_BG_ALPHA = 0x4c
const BUTTON_DISABLED_BG_ALPHA = 0x26

const TOOLTIP_DELAY = 1
const TOOLTIP_BORDER_COLOR = 0xFF37454D
const TOOLTIP_BG_COLOR = 0xFF182029
const TOOLTIP_CONTAINER_KEY = "tooltip_container"

const TOOLTIP_ROOT_MARGIN = hdpx(25)
const BTN_ICON_SIZE = evenPx(26)
const BTN_SIZE = hdpx(45)
const FILTER_BTN_SIZE = hdpxi(30)

const HORIZONTAL_BUTTONS_OIFFSET_X = hdpx(20)

const BTN_CONTAINER_WITH_ALIGNED_HINTS_MAX_WIDTH = hdpx(80)

const WITHIN_VISUAL_RANGE_MODE_NAMES = ["ACM", "BST", "VSL"]

let selectedFilterBtnIndex = Watched(-1)
let airRadarGuiControlMode = Watched(getAirRadarGuiControlMode())
let isRadarGamepadNavEnabled = Watched(false)

let disableGamepadNavigation = @() isRadarGamepadNavEnabled.set(false)

eventbus_subscribe("air_radar_gui_control_mode_changed", function(params) {
  airRadarGuiControlMode.set(params.mode)
})

eventbus_subscribe("air_radar_gui_gamepad_nav_mode_toggle", function(_) {
  let shouldEnable = !isRadarGamepadNavEnabled.get()
  let isGamepadNavAvailable = IsRadarHudVisible.get() && !isPlayingReplay.get()
  if (shouldEnable && isGamepadNavAvailable)
    isRadarGamepadNavEnabled.set(true)
  else
    disableGamepadNavigation()
})

let isRadarButtonsVisible = Computed(@() IsRadarHudVisible.get()
  && !isPlayingReplay.get()
  && (airRadarGuiControlMode.get() != AIR_RADAR_GUI_CONTROL_HIDDEN || isRadarGamepadNavEnabled.get()))

let isRadarFiltersButtonsVisible = Computed(@() isRadarButtonsVisible.get()
  && IsRadarHasFilters.get() && IsRadarVisible.get()
  && (unitType.get() == "aircraft" || unitType.get() == "helicopter"))

let modeName = Computed(@() modeNames?[RadarModeNameId.get()] ?? "")
let isWvrMode = Computed(function() {
  foreach (wvrMode in WITHIN_VISUAL_RANGE_MODE_NAMES)
    if (modeName.get().contains(wvrMode))
      return true
  return false
})

let verticalButtonsAir = [
  {
    id = "ID_SENSOR_TYPE_SWITCH"
    img = Computed(@() Irst.get() ? "ui/gameuiskin#radar_controls_irst_mode.svg"
      : "ui/gameuiskin#radar_controls_radar_mode.svg")
    focusOnGamepadNav = true
    shHintAlign = ALIGN_RIGHT
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH"
    img = "ui/gameuiskin#radar_controls_search_sector.svg"
    shHintAlign = ALIGN_RIGHT
  }
  {
    id = "ID_SENSOR_ACM_SWITCH"
    img = Computed(@() HasHelmetTarget.get() ? "ui/gameuiskin#radar_controls_hmd_mode.svg"
      : isWvrMode.get() ? "ui/gameuiskin#radar_controls_wvr_mode.svg"
      : "ui/gameuiskin#radar_controls_bvr_mode.svg")
    shHintAlign = ALIGN_RIGHT

  }
  {
    id = "ID_SENSOR_MODE_SWITCH"
    img = "ui/gameuiskin#radar_controls_search_modes.svg"
    isActive = Computed(@() !Irst.get())
    shHintAlign = ALIGN_RIGHT
  }
]

let horizontalButtonsAir = [
  {
    id = "sensor_cue_z_rangeMax"
    img = "ui/gameuiskin#radar_controls_elevation_up.svg"
    axisControl = {
      onHoldValue = 1
      axisId = "sensor_cue_z"
    }
  }
  {
    id = "sensor_cue_z_rangeMin"
    img = "ui/gameuiskin#radar_controls_elevation_down.svg"
    axisControl = {
      onHoldValue = -1
      axisId = "sensor_cue_z"
    }
  }
  {
    id = "ID_SENSOR_DIRECTION_AXES_RESET"
    img = "ui/gameuiskin#radar_controls_elevation_reset.svg"
  }
  {
    id = "ID_SENSOR_RANGE_SWITCH"
    img = "ui/gameuiskin#radar_controls_scale.svg"
    isActive = Computed(@() !Irst.get())
  }
  {
    id = "ID_SENSOR_SWITCH"
    img = "ui/gameuiskin#radar_controls_power.svg"
    isAlwaysVisible = true
  }
]

let IFFFilterConfigs = [
  {
    img = "ui/gameuiskin#radar_controls_friend_foe.svg"
    valueMask = RadarTargetsIffFilterMask.ALLY | RadarTargetsIffFilterMask.ENEMY
    tooltipOverride = "hud/AAComplexMenu/IFF/all"
  }
  {
    img = "ui/gameuiskin#radar_controls_friend.svg"
    valueMask = RadarTargetsIffFilterMask.ALLY
    tooltipOverride = "hud/AAComplexMenu/IFF/ally"
  }
  {
    img = "ui/gameuiskin#radar_controls_foe.svg"
    valueMask = RadarTargetsIffFilterMask.ENEMY
    tooltipOverride = "hud/AAComplexMenu/IFF/enemy"
  }
]

let mapAirToHeliBtn = @(btn, ovr = {}) btn?.axisControl != null
  ? btn.__merge({
      id = $"{HELI_AXIS_CONTROL_PREFIX}{btn.id}"
      axisControl = btn.axisControl.__merge({ axisId = $"{HELI_AXIS_CONTROL_PREFIX}{btn.axisControl.axisId}" })
    }, ovr)
  : btn.__merge({ id = $"{btn.id}_HELICOPTER" }, ovr)

let verticalButtonsHeli = verticalButtonsAir.map(@(btn)
  mapAirToHeliBtn(btn, { shHintAlign = ALIGN_LEFT }))
let horizontalButtonsHeli = horizontalButtonsAir.map(@(btn )mapAirToHeliBtn(btn))

let mkTooltipText = @(text) {
  maxWidth = sh(30)
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  font = Fonts.tiny_text_hud
  fontSize = hdpxi(16)
  text
}

let tooltipState = Watched(null)
let tooltipContainerPos = [0, 0]
local tooltipTimer = null

function tooltipCleanup() {
  clearTimer(tooltipTimer)
  tooltipTimer = null
  tooltipState.set(null)
}

function cleanupTooltipOnCursorHide(isCursorVisible) {
  if (!isCursorVisible)
    tooltipCleanup()
}

function tooltip() {
  let tipState = tooltipState.get()

  let onAttach = @() defer(function() {
    let {l = 0, t = 0} = gui_scene.getCompAABBbyKey(TOOLTIP_CONTAINER_KEY)
    tooltipContainerPos[0] = l
    tooltipContainerPos[1] = t
  })

  if (!tipState?.tipRootElemAabb)
    return { key = TOOLTIP_CONTAINER_KEY, watch = tooltipState, onAttach }

  let tooltipComp = mkTooltipText(tipState.text)

  let {l, t, r} = tipState.tipRootElemAabb
  let rootelemW = r - l
  let [contX, contY] = tooltipContainerPos
  let [tipW, tipH] = calc_comp_size(tooltipComp)

  let desiredX = (l + rootelemW * 0.5) - tipW * 0.5 - contX
  let minX = -contX + TOOLTIP_ROOT_MARGIN
  let maxX = sw(100) - contX - tipW - TOOLTIP_ROOT_MARGIN

  let desiredY = t - tipH - contY
  let minY = -contY + TOOLTIP_ROOT_MARGIN
  let maxY = sh(100) - contY - tipH - TOOLTIP_ROOT_MARGIN

  let pos = [clamp(desiredX, minX, maxX), clamp(desiredY, minY, maxY)]

  return {
    key = TOOLTIP_CONTAINER_KEY
    watch = tooltipState
    pos
    padding = const [hdpx(6), hdpx(8)]
    zOrder = Layers.Tooltip
    rendObj = ROBJ_BOX
    fillColor = TOOLTIP_BG_COLOR
    borderColor = TOOLTIP_BORDER_COLOR
    borderWidth = dp(1)

    children = tooltipComp
    onAttach
  }
}

let cachedFiltersBtns = []

function onCollapseFiltersBtn() {
  cachedFiltersBtns.clear()
  tooltipCleanup()
  isFiltersExpanded.set(!isFiltersExpanded.get())
}

function getFilterButtonsConfig() {
  if (cachedFiltersBtns.len() > 0)
    return cachedFiltersBtns
  let preset = filterPresets.findvalue(@(p) p.filter == typeFilter)
  if (preset == null)
    return cachedFiltersBtns

  let isBtnsExpanded = isFiltersExpanded.get()
  let collapseFiltersIconSize = hdpxi(18)
  let collapseBtn = { isSelected = isFiltersExpanded, iconSize = collapseFiltersIconSize,
    getText = @() isBtnsExpanded ? loc("mainmenu/btnCollapse") : loc("mainmenu/btnExpand"),
    onClick = onCollapseFiltersBtn, icon = Picture($"ui/gameuiskin#filter_icon.svg:{collapseFiltersIconSize}:P") }
  cachedFiltersBtns.append(collapseBtn)

  let iconSize = hdpxi(24)
  let { filter, valuesList } = preset
  foreach (valueData in valuesList) {
    if (!isBtnsExpanded) {
      cachedFiltersBtns.append({isVisible = false})
      continue
    }
    let valueMask = valueData.valueMask
    cachedFiltersBtns.append(
      { icon = valueData?.getImage(iconSize), iconSize, isSelected = valueData?.isSelected,
        onClick = @() switchFilter(filter, valueMask), text = valueData.locText
      })
  }
  return cachedFiltersBtns
}

function mkButtonIconComp(srcValueOrWatched) {
  let iconSrcW = type(srcValueOrWatched) == "string" ? Watched(srcValueOrWatched)
    : srcValueOrWatched

  return @() {
    watch = [HudColor, iconSrcW]
    rendObj = ROBJ_IMAGE
    size = const [BTN_ICON_SIZE, BTN_ICON_SIZE]
    color =  HudColor.get()
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = Picture($"{iconSrcW.get()}:{BTN_ICON_SIZE}:{BTN_ICON_SIZE}:P")
  }
}

let mkShortcutText = @(text, showConsoleBtnsV) hints(text, {
  place = "actionItem"
  font = Fonts.tiny_text_hud
  shortCombination = !showConsoleBtnsV
  fontSize = getFontDefHt("tiny_text_hud")
})

let buttonFillColor = Computed(@() adjustColorBrightness(HudColor.get(), BUTTON_BG_DARK_FACTOR, BUTTON_BG_ALPHA))
let buttonDisabledFillColor = Computed(@() adjustColorBrightness(HudColor.get(), BUTTON_BG_DARK_FACTOR, BUTTON_DISABLED_BG_ALPHA))
let buttonBorderColor = Computed(@() adjustColorBrightness(HudColor.get(), 0.4))


function updateButtonTooltip(stateFlag, key, text) {
  if (stateFlag.get() & S_HOVER) {
    clearTimer(tooltipTimer)
    tooltipTimer = setTimeout(TOOLTIP_DELAY, function scheduleTooltipDisplay() {
      if (!(stateFlag.get() & S_HOVER))
        return
      let tipRootElemAabb = gui_scene.getCompAABBbyKey(key)
      if (!tipRootElemAabb)
        return
      tooltipState.set({
        tipRootElemAabb
        text
      })
    })
  } else
    tooltipCleanup()
}

function mkButtonBase(btn, ovr = {}) {
  let { id = "", img, axisControl = null, shHintAlign = ALIGN_CENTER, tooltipOverride = null } = btn
  let stateFlag = Watched(0)
  let isActive = btn?.isActive ?? Watched(true)
  let isHovered = Computed(@() (stateFlag.get() & S_HOVER) != 0)
  let maxContainerWidth = shHintAlign != ALIGN_CENTER ? BTN_CONTAINER_WITH_ALIGNED_HINTS_MAX_WIDTH : null

  let shHintOvr = shHintAlign != ALIGN_CENTER ? {
    minWidth = pw(100)
    hplace = shHintAlign
    halign = ALIGN_CENTER
  } : {}

  let shHintComp = @() {
    watch = [airRadarGuiControlMode, showConsoleButtons, isActive]
    children = airRadarGuiControlMode.get() == AIR_RADAR_GUI_CONTROL_BUTTONAS_AND_SHORTCUTS
      && isActive.get() ? mkShortcutText(id.concat("{{", "}}"), showConsoleButtons.get()) : null
  }.__update(shHintOvr)

  return @() {
    key = id
    watch = isActive
    minWidth = hdpx(52)
    maxWidth = maxContainerWidth
    minHeight = hdpx(67)
    vplace = ALIGN_BOTTOM
    opacity = isActive.get() ? 1 : 0.4

    behavior = Behaviors.Button
    onClick = !axisControl ? @() toggleShortcut(id) : null
    function onElemState(sf) {
      stateFlag.set(sf)
      let text = tooltipOverride != null ? loc(tooltipOverride)
        : isActive.get() ? loc($"hotkeys/{id}")
        : loc("guiHints/not_available_in_current_mode")
      updateButtonTooltip(stateFlag, id, text)
      if (!axisControl)
        return

      let isBtnHold = (sf & (S_MOUSE_ACTIVE | S_JOYSTICK_ACTIVE)) != 0
      let axisVal = isBtnHold ? axisControl.onHoldValue : 0
      setVirtualAxisValue(axisControl.axisId, axisVal)
    }
    flow = FLOW_VERTICAL
    valign = ALIGN_BOTTOM
    halign = ALIGN_CENTER
    children = [
      shHintComp
      @() {
        watch = [isHovered, HudColor, isActive, buttonFillColor, buttonBorderColor]
        size = const [BTN_SIZE, BTN_SIZE]
        rendObj = ROBJ_BOX
        fillColor = buttonFillColor.get()
        borderColor = isActive.get() && isHovered.get()
          ? HudColor.get()
          : buttonBorderColor.get()
        borderWidth = dp(2)
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        children = mkButtonIconComp(img)
      }
    ]

    onDetach = axisControl ? @() setVirtualAxisValue(axisControl.axisId, 0) : null
  }.__update(ovr)
}

let mkButton = @(btnCfg) mkButtonBase(btnCfg)

let filtersUpdated = Watched(0)
eventbus_subscribe("hud.radar.filtersUpdated", @(_) filtersUpdated.trigger())

function mkIFFFilterButton() {
  let currentFilter = IFFFilter.getFilterValue()
  let config = IFFFilterConfigs[currentFilter]

  return {
    watch = filtersUpdated
    children = mkButtonBase(config, {
      onClick = function(){
        let nextFilter = getNextRadarTargetsIffFilterMask(currentFilter)
        IFFFilter.setFilterValue(nextFilter, true)
      }
    })
  }
}

let mkHorizontalButtons = @(buttonsCfg, ovr = {}) @() {
  watch = IsRadarVisible
  size = const [pw(90), SIZE_TO_CONTENT]
  pos = const [HORIZONTAL_BUTTONS_OIFFSET_X, hdpx(70)]
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  flow = FLOW_HORIZONTAL
  gap = const { size = flex() }
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  children = IsRadarVisible.get() ? buttonsCfg.map(mkButton)
    : buttonsCfg.filter(@(btn) btn?.isAlwaysVisible).map(mkButton)
}.__update(ovr)

let mkVerticalButtons = @(buttonsCfg) @() {
  watch = IsRadarVisible
  pos = const [hdpx(-53), hdpx(-15)]
  vplace = ALIGN_BOTTOM
  flow = FLOW_VERTICAL
  gap = hdpx(5)
  halign = ALIGN_CENTER
  children = IsRadarVisible.get() ? buttonsCfg.map(mkButton) : null
}

let cornerButton = @() {
  watch = IsRadarVisible
  pos = const [hdpx(-53), hdpx(70)]
  hplace = ALIGN_LEFT
  vplace = ALIGN_BOTTOM
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  children = IsRadarVisible.get() ? mkIFFFilterButton : null
}

local moveMouseTimer = null
function moveMouseOnGamepadNavEnabled(isNavEnabled, btnIdsToTryFocus) {
  if (!isNavEnabled)
    return
  clearTimer(moveMouseTimer)
  moveMouseTimer = setTimeout(0.1, function() { 
    foreach (id in btnIdsToTryFocus) {
      let isSuccess = move_mouse_cursor(id, false)
      if (isSuccess)
        break
    }
  })
}

function mkExitGamepadNavBtn() {
  let isHighlighted = Watched(false)
  return @() !isRadarGamepadNavEnabled.get()
    ? { watch = isRadarGamepadNavEnabled }
    : {
        watch = [isRadarGamepadNavEnabled, isHighlighted, buttonBorderColor, HudColor, buttonFillColor]
        size = const [hdpx(280), hdpx(38)]
        pos = const [HORIZONTAL_BUTTONS_OIFFSET_X, hdpx(138)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_BOTTOM
        padding = const [hdpx(8), hdpx(4)]

        rendObj = ROBJ_BOX
        fillColor = buttonFillColor.get()
        borderColor = isHighlighted.get() ? HudColor.get() : buttonBorderColor.get()
        borderWidth = dp(1)

        behavior = Behaviors.Button
        onClick = @() disableGamepadNavigation()
        onElemState = @(sf) isHighlighted.set((sf & (S_HOTKEY_ACTIVE | S_HOVER)) != 0)
        hotkeys = [ [$"^{JB.B} | J:R.Thumb"] ]

        halign = ALIGN_CENTER
        children = [
          mkImageCompByDargKey(JB.B, null, {
            pos = const [0, hdpx(-30)]
            height = hdpx(36)
          })
          @() {
            watch = HudColor
            size = FLEX_H
            vplace = ALIGN_CENTER
            rendObj = ROBJ_TEXTAREA
            behavior = Behaviors.TextArea
            color = HudColor.get()
            text = loc("hud/radarButtons/exitGamepadNav")
            halign = ALIGN_CENTER
          }
        ]
      }
    }

function mkFilterButton(btnData, idx) {
  let stateFlag = Watched(0)
  let isHovered = Computed(@() (stateFlag.get() & S_HOVER) != 0 || idx == selectedFilterBtnIndex.get())
  let filterValueWatch = btnData?.isSelected ?? Watched(false)

  return @() {
    key = $"filterbtn_{idx}"
    watch = [filterValueWatch, isHovered, HudColor, buttonFillColor, buttonDisabledFillColor]
    size = FILTER_BTN_SIZE
    rendObj = ROBJ_BOX
    fillColor = filterValueWatch.get() ? buttonFillColor.get() :  buttonDisabledFillColor.get()
    borderColor = isHovered.get()
      ? HudColor.get()
      : 0x00000000
    borderWidth = dp(2)
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    behavior = Behaviors.Button
    function onElemState(sf) {
      stateFlag.set(sf)
      updateButtonTooltip(stateFlag, $"filterbtn_{idx}", btnData?.getText() ?? btnData.text)
    }
    onClick = btnData.onClick
    children = btnData?.icon ? [
      {
        size = btnData.iconSize
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        rendObj = ROBJ_IMAGE
        image = btnData.icon
        color = filterValueWatch.get() ? HudColor.get() : buttonFillColor.get()
      }
    ] : null
  }
}

function onFilterBtnsNavigationShortcut() {
  let nextIndex = selectedFilterBtnIndex.get() + 1
  if (nextIndex > 0 && !isFiltersExpanded.get())
    return
  let btnsConfig = getFilterButtonsConfig().filter(@(btn) (btn?.isVisible ?? true))
  let btnsCount = btnsConfig.len()
  selectedFilterBtnIndex.set(nextIndex < btnsCount ? nextIndex : 0)
}

function onFilterBtnsApplyShortcut() {
  let btnsConfig = getFilterButtonsConfig().filter(@(btn) (btn?.isVisible ?? true))
  let btnsCount = btnsConfig.len()
  let index = selectedFilterBtnIndex.get()
  if (index < 0 || btnsCount <= index)
    return
  btnsConfig[index]?.onClick()
}

let filtersButtons = @(offsets) function() {
  let btnsConfig = getFilterButtonsConfig()
  let children = btnsConfig.filter(@(btnData) (btnData?.isVisible ?? true)).map(@(btnData, idx) mkFilterButton(btnData, idx))
  let navShortcut = isAir() ? ["@ID_TOGGLE_AIR_RADAR_NCTR_NAVIGATION"] : ["@ID_TOGGLE_AIR_RADAR_NCTR_NAVIGATION_HELICOPTER"]
  let applyShortcut= isAir() ? ["@ID_TOGGLE_AIR_RADAR_NCTR_APPLY"] : ["@ID_TOGGLE_AIR_RADAR_NCTR_APPLY_HELICOPTER"]

  let filtersBtnsPadding = Computed(function() {
    return [0, 0, 0,
      MfdRadarOffsetX.get() + offsets.get()[0]]
  })

  children.append(
    { behavior = Behaviors.Button
      onClick = onFilterBtnsNavigationShortcut
      hotkeys = [navShortcut]
    },
    {
      behavior = Behaviors.Button
      onClick = onFilterBtnsApplyShortcut
      hotkeys = [applyShortcut]
    }
  )

  const gapSize = hdpx(6)
  let totalHeight = (gapSize + FILTER_BTN_SIZE) * btnsConfig.len() - gapSize

  return {
    watch = [isFiltersExpanded, filtersBtnsPadding]
    flow = FLOW_VERTICAL
    padding = filtersBtnsPadding.get()
    pos = [pw(100), 0]
    size = [SIZE_TO_CONTENT, totalHeight + hdpx(15)]
    vplace = ALIGN_BOTTOM
    gap = gapSize
    children
  }
}

function mkRadarButtons(vButtonsCfg, hButtonsCfg, hButtonsSectionOvr = {}) {
  let btnIdsToTryFocus = []
  foreach (btn in [].extend(vButtonsCfg, hButtonsCfg))
    if (btn?.focusOnGamepadNav || btn?.isAlwaysVisible)
      btnIdsToTryFocus.append(btn.id)

  let handleGamepadNavChange = @(isEnabled) moveMouseOnGamepadNavEnabled(isEnabled, btnIdsToTryFocus)
  return {
    key = {}
    size = flex()
    children = [
      mkVerticalButtons(vButtonsCfg)
      mkHorizontalButtons(hButtonsCfg, hButtonsSectionOvr)
      cornerButton
      tooltip
      mkExitGamepadNavBtn()
    ]

    function onAttach() {
      moveMouseOnGamepadNavEnabled(isRadarGamepadNavEnabled.get(), btnIdsToTryFocus) 

      cursorVisible.subscribe(cleanupTooltipOnCursorHide)
      isRadarGamepadNavEnabled.subscribe(handleGamepadNavChange)
    }
    function onDetach() {
      tooltipCleanup()
      clearTimer(moveMouseTimer)
      cursorVisible.unsubscribe(cleanupTooltipOnCursorHide)
      isRadarGamepadNavEnabled.unsubscribe(handleGamepadNavChange)
    }
  }
}

isInFlight.subscribe(@(v) !v ? disableGamepadNavigation() : null)

function onUnitAliveChange(v) {
  if (v)
    return
  disableGamepadNavigation()
  cachedFiltersBtns.clear()
}

isUnitAlive.subscribe(onUnitAliveChange)

register_command(@() isRadarGamepadNavEnabled.set(!isRadarGamepadNavEnabled.get()), "ui.toggle_radar_nav")

return {
  isRadarButtonsVisible
  radarButtonsAir = mkRadarButtons(verticalButtonsAir, horizontalButtonsAir)
  radarButtonsHeli = mkRadarButtons(verticalButtonsHeli, horizontalButtonsHeli, { halign = ALIGN_LEFT, gap = hdpx(5) })
  isRadarGamepadNavEnabled
  isRadarFiltersButtonsVisible
  filtersButtons
}