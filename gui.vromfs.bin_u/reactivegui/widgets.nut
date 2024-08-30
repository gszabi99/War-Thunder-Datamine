from "%rGui/globals/ui_library.nut" import *

let globalState = require("globalState.nut")
let widgetsState = require("widgetsState.nut")
let { isPlayingReplay, unitType } = require("hudState.nut")
let hudUnitType = require("hudUnitType.nut")
let shipHud = require("shipHud.nut")
let shipHudTouch = require("%rGui/hud/shipHudTouch.nut")
let shipExHud = require("shipExHud.nut")
let tankExHud = require("tankExHud.nut")
let shipDeathTimer = require("shipDeathTimer.nut")
let mkScoreboard = require("hud/scoreboard/mkScoreboard.nut")
let aircraftHud = require("aircraftHud.nut")
let helicopterHud = require("helicopterHud.nut")
let tankHud = require("tankHud.nut")
let xrayIndicator = require("hud/xrayIndicator.nut")
let changelog = require("changelog/changelog.ui.nut")
let { cursorVisible } = require("%rGui/ctrlsState.nut")
let { isInSpectatorMode } = require("%rGui/respawnWndState.nut")
let { fullScreenBlurPanel } = require("%rGui/components/blurPanel.nut")
let tankSightPreview = require("%rGui/tankSightPreview.nut")

let widgetsMap = {
  [DargWidgets.HUD] = function() {
    if (!globalState.isInFlight.value)
      return null

    if (hudUnitType.isHelicopter())
      return helicopterHud
    else if (hudUnitType.isAir())
      return aircraftHud
    else if (hudUnitType.isTank())
      return tankHud
    else if (hudUnitType.isShip() && !isPlayingReplay.value)
      return shipHud
    else if (hudUnitType.isSubmarine() && !isPlayingReplay.value)
      return shipExHud
    else if (hudUnitType.isHuman())
      return tankHud
    //



    else
      return null
  },

  [DargWidgets.HUD_TOUCH] = function() {
    if (!globalState.isInFlight.value)
      return null

    if (hudUnitType.isShip())
      return shipHudTouch
    else
      return this[DargWidgets.HUD]()
  },

  [DargWidgets.SHIP_OBSTACLE_RF] = function () {
    return {
      size = flex()
      halign = ALIGN_CENTER
      children = shipDeathTimer
    }
  },

  [DargWidgets.SCOREBOARD] = @ () {
    size = flex()
    halign = ALIGN_CENTER
    children = mkScoreboard()
  },

  [DargWidgets.CHANGE_LOG] = @() {
    size = flex()
    children = changelog
  },

  [DargWidgets.DAMAGE_PANEL] = @() xrayIndicator,

  [DargWidgets.RESPAWN] = @() @() {
    watch = isInSpectatorMode
    size = flex()
    children = [
      isInSpectatorMode.get()
        ? null
        : fullScreenBlurPanel
      mkScoreboard()
    ]
  },

  [DargWidgets.TANK_SIGHT_SETTINGS] = @() tankSightPreview
}

// A stub to enable hover functionality
let stubInteractiveCursorForDaGUI = Cursor({})

let cursor = @() {
  watch = cursorVisible
  size = flex()
  cursor = cursorVisible.value ? stubInteractiveCursorForDaGUI : null
}

let widgets = @() {
  watch = [
    globalState.isInFlight
    unitType
    isPlayingReplay
    widgetsState
  ]
  children = widgetsState.value.map(@(widget) {
    size = widget?.transform?.size ?? [sw(100), sh(100)]
    pos = widget?.transform?.pos ?? [0, 0]
    children = widgetsMap?[widget.widgetId]()
  }).append(cursor)
}


return widgets