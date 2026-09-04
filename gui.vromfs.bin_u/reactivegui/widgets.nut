import "%rGui/widgetsState.nut" as widgetsState
import "%rGui/shipHud.nut" as shipHud
import "%rGui/hud/shipHudTouch.nut" as shipHudTouch
import "%rGui/tankExHud.nut" as tankExHud
import "%rGui/shipDeathTimer.nut" as shipDeathTimer
import "%rGui/hud/scoreboard/mkScoreboard.nut" as mkScoreboard
import "%rGui/tankHud.nut" as tankHud
import "%rGui/infantryDroneHud.nut" as infantryDroneHud
import "%rGui/wwMap/wwMap.nut" as wwMap
import "%rGui/weapons/bulletsGraphPanel.nut" as bulletsGraph
import "%rGui/weapons/bulletsPenetrationGraphPanel.nut" as bulletsPenetrationGraph
from "%rGui/hudState.nut" import isPlayingReplay, unitType
from "%rGui/helicopterHud.nut" import helicopterHud
from "%rGui/infantryHud.nut" import infantryHud
from "%rGui/ctrlsState.nut" import cursorVisible
from "%rGui/respawnWndState.nut" import isInSpectatorMode
from "%rGui/globals/ui_library.nut" import *

let globalState = require("%rGui/globalState.nut")
let hudUnitType = require("%rGui/hudUnitType.nut")
let shipExHud = require("%rGui/shipExHud.nut")
let { aircraftHud } = require("%rGui/aircraftHud.nut")
let changelog = require("%rGui/changelog/changelog.ui.nut")
let { fullScreenBlurPanel } = require("%rGui/components/blurPanel.nut")
let tankSightPreview = require("%rGui/tankSightPreview.nut")


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
      size = FLEX
      halign = ALIGN_CENTER
      children = shipDeathTimer
    }
  },

  [DargWidgets.SCOREBOARD] = @ () {
    size = FLEX
    halign = ALIGN_CENTER
    children = mkScoreboard()
  },

  [DargWidgets.CHANGE_LOG] = @() {
    size = FLEX
    children = changelog
  },

  [DargWidgets.RESPAWN] = @() @() {
    watch = isInSpectatorMode
    size = FLEX
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
  [DargWidgets.BULLETS_PENETRATION] = @() bulletsPenetrationGraph,
}


let stubInteractiveCursorForDaGUI = Cursor({})

let cursor = @() {
  watch = cursorVisible
  size = FLEX
  cursor = cursorVisible.get() ? stubInteractiveCursorForDaGUI : null
}

let widgets = @() {
  watch = [
    globalState.isInFlight
    unitType
    isPlayingReplay
    widgetsState
  ]
  size = FLEX
  children = widgetsState.get().map(@(widget) {
    size = widget?.transform.size ?? [sw(100), sh(100)]
    pos = widget?.transform.pos ?? [0, 0]
    children = widgetsMap?[widget.widgetId]()
  }).append(cursor)
}


return widgets