local globalState = require("globalState.nut")
local widgetsState = require("widgetsState.nut")
local hudState = require("hudState.nut")
local hudUnitType = require("hudUnitType.nut")
local helicopterHud = require("helicopterHud.nut")
local shipHud = require("shipHud.nut")
local shipExHud = require("shipExHud.nut")
local tankExHud = require("tankExHud.nut")
local shipObstacleRf = require("shipObstacleRangefinder.nut")
local shipDeathTimer = require("shipDeathTimer.nut")
local scoreboard = require("hud/scoreboard/scoreboard.nut")
local screenState = require("style/screenState.nut")
local airHud = require("airHud.nut")
local tankHud = require("tankHud.nut")
local mfdHud = require("mfd.nut")
local planeMfd = require("planeMfd.nut")
local heliIlsHud = require("heliIls.nut")
local planeIls = require("planeIls.nut")
local changelog = require("changelog/changelog.ui.nut")

local widgetsMap = {
  [DargWidgets.HUD] = function() {
    if (!globalState.isInFlight.value)
      return null

    ::gui_scene.removePanel(0)
    ::gui_scene.removePanel(1)
    if (hudUnitType.isHelicopter()) {
      ::gui_scene.addPanel(0, mfdHud)
      ::gui_scene.addPanel(1, heliIlsHud)
      return helicopterHud
    }
    else if (hudUnitType.isAir()) {
      ::gui_scene.addPanel(0, planeMfd)
      ::gui_scene.addPanel(1, planeIls)
      return airHud
    }
    else if (hudUnitType.isTank())
      return tankHud.Root
    else if (hudUnitType.isShip() && !hudState.isPlayingReplay.value)
      return shipHud
    else if (hudUnitType.isSubmarine() && !hudState.isPlayingReplay.value)
      return shipExHud
    //



    else
      return null
  },

  [DargWidgets.SHIP_OBSTACLE_RF] = function () {
    return {
      size = flex()
      halign = ALIGN_CENTER
      children = [shipObstacleRf, shipDeathTimer]
    }
  },

  [DargWidgets.SCOREBOARD] = @ () {
    size = flex()
    halign = ALIGN_CENTER
    children = scoreboard
  },

  [DargWidgets.CHANGE_LOG] = @() {
    size = flex()
    children = changelog
  },

  [DargWidgets.DAMAGE_PANEL] = tankHud.tankDmgIndicator
}


local widgets = @() {
  watch = [
    globalState.isInFlight
    hudState.unitType
    hudState.isPlayingReplay
    widgetsState.widgets
    screenState.safeAreaSizeHud
  ]
  children = widgetsState.widgets.value.map(@(widget) {
    size = widget?.transform?.size ?? [sw(100), sh(100)]
    pos = widget?.transform?.pos ?? [0, 0]
    children = widgetsMap?[widget.widgetId]()
  })
}


return widgets