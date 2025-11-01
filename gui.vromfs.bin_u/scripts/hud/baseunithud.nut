from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getHasCompassObservable } = require("hudCompassState")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { isPlayerAlive } = require("%scripts/hud/hudState.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")

function updatePosMultiplayerScore(obj, hasCompass, isInAntiAirMenu) {
  let top = hasCompass && !isInAntiAirMenu
    ? "1@multiplayerScoreTopPosUnderCompass"
    : "0.015@shHud"
  obj.top = top
}

gui_handlers.BaseUnitHud <- class (gui_handlers.BaseGuiHandlerWT) {
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
        watch = getHasCompassObservable()
        updateFunc = @(obj, value) updatePosMultiplayerScore(
          obj, value, isAAComplexMenuActive.get())
      },
      {
        watch = isAAComplexMenuActive
        updateFunc = @(obj, value) updatePosMultiplayerScore(
          obj, getHasCompassObservable().get(), value)
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
