from "%appGlobals/hud/hudState.nut" import isAAComplexMenuActive
from "hudCompassState" import hasCompassObservable
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { stashBhvValueConfig } = require("%scripts/sqDagui/guiBhv/guiBhvValueConfig.nut")
let { isPlayerAlive } = require("%scripts/hud/hudState.nut")

function updatePosMultiplayerScore(obj, hasCompass, isInAntiAirMenu) {
  let top = hasCompass && !isInAntiAirMenu
    ? "1@multiplayerScoreTopPosUnderCompass"
    : "0.015@shHud"
  obj.top = top
}

let BaseUnitHud = class (BaseGuiHandlerWT) {
  scene = null
  wndType = handlerType.CUSTOM

  actionBarWeak   = null
  isReinitDelayed = false

  function initScreen() {
    this.actionBarWeak = null
    this.isReinitDelayed = false
  }

  function updatePosHudMultiplayerScore() {
    let multiplayerScoreObj = this.scene.findObject("hud_multiplayer_score")
    if (checkObj(multiplayerScoreObj)) {
      multiplayerScoreObj.setValue(stashBhvValueConfig([{
        watch = hasCompassObservable
        updateFunc = Callback(@(obj, value) updatePosMultiplayerScore(obj, value, isAAComplexMenuActive.get()), this)
      },
      {
        watch = isAAComplexMenuActive
        updateFunc = Callback(@(obj, value) updatePosMultiplayerScore(obj, hasCompassObservable.get(), value), this)
      },
      {
        watch = isPlayerAlive
        updateFunc = @(obj, value) obj.show(value)
      }]))
    }
  }

  function onEventControlsPresetChanged(_p) {
    this.isReinitDelayed = true
  }
  function onEventControlsChangedShortcuts(_p) {
    this.isReinitDelayed = true
  }
  function onEventControlsChangedAxes(_p) {
    this.isReinitDelayed = true
  }

  function onEventShowHud(_p) {
    if (this.isReinitDelayed) {
      this.actionBarWeak?.reinit()
      this.onControlsChanged()
      this.isReinitDelayed = false
    }
  }

  onControlsChanged = @() null
}
register_gui_handler("BaseUnitHud", BaseUnitHud)

return { BaseUnitHud }
