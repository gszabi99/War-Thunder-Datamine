from "%rGui/globals/ui_library.nut" import *
let { toggleShortcut, setVirtualAxisValue } = require("%globalScripts/controls/shortcutActions.nut")
let hints = require("%rGui/hints/hints.nut")
let { Irst, modeNames, RadarModeNameId, IsRadarVisible, HasHelmetTarget,
  IsRadarHudVisible } = require("%rGui/radarState.nut")
let { setTimeout, clearTimer, defer } = require("dagor.workcycle")
let { eventbus_subscribe } = require("eventbus")
let { AIR_RADAR_GUI_CONTROL_HIDDEN, AIR_RADAR_GUI_CONTROL_BUTTONAS_AND_SHORTCUTS,
} = require("radarGuiControls").AirRadarGuiControlMode
let { getAirRadarGuiControlMode } = require("radarGuiControls")
let { showConsoleButtons, cursorVisible } = require("%rGui/ctrlsState.nut")
let { isPlayingReplay } = require("%rGui/hudState.nut")
let { HudColor } = require("%rGui/airState.nut")
let { adjustColorBrightness } = require("%rGui/style/airHudStyle.nut")

const BUTTON_BG_DARK_FACTOR = 0.1
const BUTTON_BG_ALPHA = 0x4c

const TOOLTIP_DELAY = 1
const TOOLTIP_BORDER_COLOR = 0xFF37454D
const TOOLTIP_BG_COLOR = 0xFF182029
const TOOLTIP_CONTAINER_KEY = "tooltip_container"

let TOOLTIP_ROOT_MARGIN = hdpx(25)
let BTN_ICON_SIZE = evenPx(26)

let WITHIN_VISUAL_RANGE_MODE_NAMES = freeze(["ACM", "BST", "VSL"])

let airRadarGuiControlMode = Watched(getAirRadarGuiControlMode())

eventbus_subscribe("air_radar_gui_control_mode_changed", function(params) {
  airRadarGuiControlMode.set(params.mode)
})

let isRadarButtonsVisible = Computed(@() IsRadarHudVisible.get()
  && airRadarGuiControlMode.get() != AIR_RADAR_GUI_CONTROL_HIDDEN
  && !isPlayingReplay.get())

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
  }
  {
    id = "ID_SENSOR_SCAN_PATTERN_SWITCH"
    img = "ui/gameuiskin#radar_controls_search_sector.svg"
  }
  {
    id = "ID_SENSOR_ACM_SWITCH"
    img = Computed(@() HasHelmetTarget.get() ? "ui/gameuiskin#radar_controls_hmd_mode.svg"
      : isWvrMode.get() ? "ui/gameuiskin#radar_controls_wvr_mode.svg"
      : "ui/gameuiskin#radar_controls_bvr_mode.svg")

  }
  {
    id = "ID_SENSOR_MODE_SWITCH"
    img = "ui/gameuiskin#radar_controls_search_modes.svg"
    isActive = Computed(@() !Irst.get())
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

let mapAirToHeliBtn = @(btn) btn.__merge({
  id = btn.id.startswith("sensor_cue_z") ? $"helicopter_{btn.id}" : $"{btn.id}_HELICOPTER"
})

let verticalButtonsHeli = verticalButtonsAir.map(mapAirToHeliBtn)
let horizontalButtonsHeli = horizontalButtonsAir.map(mapAirToHeliBtn)

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
    padding = static [hdpx(6), hdpx(8)]
    zOrder = Layers.Tooltip
    rendObj = ROBJ_BOX
    fillColor = TOOLTIP_BG_COLOR
    borderColor = TOOLTIP_BORDER_COLOR
    borderWidth = dp(1)

    children = tooltipComp
    onAttach
  }
}

function mkButtonIconComp(srcValueOrWatched) {
  let iconSrcW = type(srcValueOrWatched) == "string" ? Watched(srcValueOrWatched)
    : srcValueOrWatched

  return @() {
    watch = [HudColor, iconSrcW]
    rendObj = ROBJ_IMAGE
    size = static [BTN_ICON_SIZE, BTN_ICON_SIZE]
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
let buttonBorderColor = Computed(@() adjustColorBrightness(HudColor.get(), 0.4))

function mkButton(btn) {
  let { id, img, axisControl = null } = btn
  let stateFlag = Watched(0)
  let isActive = btn?.isActive ?? Watched(true)

  return @() {
    key = id
    watch = isActive
    minWidth = hdpx(52)
    minHeight = hdpx(67)
    vplace = ALIGN_BOTTOM
    valign = ALIGN_BOTTOM
    halign = ALIGN_CENTER
    opacity = isActive.get() ? 1 : 0.4

    behavior = Behaviors.Button
    onClick = !axisControl ? @() toggleShortcut(id) : null
    function onElemState(sf) {
      stateFlag.set(sf)
      if (sf & S_HOVER) {
        clearTimer(tooltipTimer)
        tooltipTimer = setTimeout(TOOLTIP_DELAY, function scheduleTooltipDisplay() {
          if (!(stateFlag.get() & S_HOVER))
            return
          let tipRootElemAabb = gui_scene.getCompAABBbyKey(id)
          if (!tipRootElemAabb)
            return

          tooltipState.set({
            tipRootElemAabb
            text = isActive.get() ? loc($"hotkeys/{id}")
              : loc("guiHints/not_available_in_current_mode")
          })
        })
      } else {
        tooltipCleanup()
      }

      if (axisControl) {
        let isBtnHold = (sf & (S_MOUSE_ACTIVE | S_JOYSTICK_ACTIVE)) != 0
        let axisVal = isBtnHold ? axisControl.onHoldValue : 0
        setVirtualAxisValue(axisControl.axisId, axisVal)
      }
    }

    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = [airRadarGuiControlMode, showConsoleButtons, isActive]
        children = airRadarGuiControlMode.get() == AIR_RADAR_GUI_CONTROL_BUTTONAS_AND_SHORTCUTS
          && isActive.get() ? mkShortcutText(id.concat("{{", "}}"), showConsoleButtons.get()) : null
      }
      @() {
        watch = [buttonFillColor, buttonBorderColor]
        size = static [hdpx(45), hdpx(45)]
        rendObj = ROBJ_BOX
        fillColor = buttonFillColor.get()
        borderColor = buttonBorderColor.get()
        borderWidth = dp(2)
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        children = mkButtonIconComp(img)
      }
    ]

    onDetach = axisControl ? @() setVirtualAxisValue(axisControl.axisId, 0) : null
  }
}

let mkHorizontalButtons = @(buttonsCfg) @() {
  watch = IsRadarVisible
  size = static [pw(90), SIZE_TO_CONTENT]
  pos = static [hdpx(20), hdpx(70)]
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  flow = FLOW_HORIZONTAL
  gap = static { size = flex() }
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  children = IsRadarVisible.get() ? buttonsCfg.map(mkButton)
    : buttonsCfg.filter(@(btn) btn?.isAlwaysVisible).map(mkButton)
}

let mkVerticalButtons = @(buttonsCfg) @() {
  watch = IsRadarVisible
  pos = static [hdpx(-53), hdpx(-15)]
  vplace = ALIGN_BOTTOM
  flow = FLOW_VERTICAL
  gap = hdpx(5)
  halign = ALIGN_CENTER
  children = IsRadarVisible.get() ? buttonsCfg.map(mkButton) : null
}

let mkRadarButtons = @(vButtonsCfg, hButtonsCfg) {
  size = flex()
  children = [
    mkVerticalButtons(vButtonsCfg),
    mkHorizontalButtons(hButtonsCfg),
    tooltip
  ]

  onAttach = @() cursorVisible.subscribe(cleanupTooltipOnCursorHide)
  onDetach = function() {
    tooltipCleanup()
    cursorVisible.unsubscribe(cleanupTooltipOnCursorHide)
  }
}

return {
  isRadarButtonsVisible
  radarButtonsAir = mkRadarButtons(verticalButtonsAir, horizontalButtonsAir)
  radarButtonsHeli = mkRadarButtons(verticalButtonsHeli, horizontalButtonsHeli)
}