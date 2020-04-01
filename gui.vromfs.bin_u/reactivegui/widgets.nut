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
local radarComponent = require("radarComponent.nut")

local widgetsMap = {
  [DargWidgets.HUD] = function() {
    if (!globalState.isInFlight.value)
      return null

    ::gui_scene.removePanel(0)
    if (hudUnitType.isHelicopter())
    {
      ::gui_scene.addPanel(0, mfdHud)
      return helicopterHud
    }
    else if (hudUnitType.isAir())
    {
      ::gui_scene.addPanel(0, radarComponent.radar(true, sh(6), sh(6)))
      return airHud
    }
    else if (hudUnitType.isTank())
      return tankHud
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
  }
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