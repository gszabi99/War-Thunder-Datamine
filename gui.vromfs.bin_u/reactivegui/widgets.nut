from "%rGui/globals/ui_library.nut" import *

let globalState = require("%rGui/globalState.nut")
let widgetsState = require("%rGui/widgetsState.nut")
let { isPlayingReplay, unitType } = require("%rGui/hudState.nut")
let hudUnitType = require("%rGui/hudUnitType.nut")
let shipHud = require("%rGui/shipHud.nut")
let shipHudTouch = require("%rGui/hud/shipHudTouch.nut")
let shipExHud = require("%rGui/shipExHud.nut")
let tankExHud = require("%rGui/tankExHud.nut")
let shipDeathTimer = require("%rGui/shipDeathTimer.nut")
let mkScoreboard = require("%rGui/hud/scoreboard/mkScoreboard.nut")
let { aircraftHud } = require("%rGui/aircraftHud.nut")
let { helicopterHud } = require("%rGui/helicopterHud.nut")
let tankHud = require("%rGui/tankHud.nut")
let { infantryHud } = require("%rGui/infantryHud.nut")
let infantryDroneHud = require("%rGui/infantryDroneHud.nut")
let changelog = require("%rGui/changelog/changelog.ui.nut")
let { cursorVisible } = require("%rGui/ctrlsState.nut")
let { isInSpectatorMode } = require("%rGui/respawnWndState.nut")
let { fullScreenBlurPanel } = require("%rGui/components/blurPanel.nut")
let tankSightPreview = require("%rGui/tankSightPreview.nut")
let wwMap = require("%rGui/wwMap/wwMap.nut")
let bulletsGraph = require("%rGui/weapons/bulletsGraphPanel.nut")


let widgetsMap = {
  [DargWidgets.HUD] = function() {
    if (!globalState.isInFlight.get())
      return null

    local unitHud = null
    if (hudUnitType.isHelicopter())
      unitHud = helicopterHud
    else if (hudUnitType.isAir())
      unitHud = aircraftHud
    else if (hudUnitType.isTank())
      unitHud = tankHud
    else if (hudUnitType.isShip())
      unitHud = shipHud
    else if (hudUnitType.isSubmarine() && !isPlayingReplay.get())
      unitHud = shipExHud
    else if (hudUnitType.isHuman())
      unitHud = infantryHud




    else if (hudUnitType.isHumanAirDrone())
      unitHud = infantryDroneHud
    else if (hudUnitType.isHumanHeliDrone())
      unitHud = infantryDroneHud

    return unitHud
  },

  [DargWidgets.HUD_TOUCH] = function() {
    if (!globalState.isInFlight.get())
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

  [DargWidgets.TANK_SIGHT_SETTINGS] = @() tankSightPreview,
  [DargWidgets.WORLDWAR_MAP] = wwMap,
  [DargWidgets.BULLETS_GRAPH] = @() bulletsGraph,
}


let stubInteractiveCursorForDaGUI = Cursor({})

let cursor = @() {
  watch = cursorVisible
  size = flex()
  cursor = cursorVisible.get() ? stubInteractiveCursorForDaGUI : null
}

let widgets = @() {
  watch = [
    globalState.isInFlight
    unitType
    isPlayingReplay
    widgetsState
  ]
  size = flex()
  children = widgetsState.get().map(@(widget) {
    size = widget?.transform.size ?? [sw(100), sh(100)]
    pos = widget?.transform.pos ?? [0, 0]
    children = widgetsMap?[widget.widgetId]()
  }).append(cursor)
}


return widgets