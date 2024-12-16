from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getHasCompassObservable } = require("hudCompassState")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { isInKillerCamera } = require("%scripts/hud/hudState.nut")

gui_handlers.BaseUnitHud <- class (gui_handlers.BaseGuiHandlerWT) {
  scene = null
  wndType = handlerType.CUSTOM

  actionBar    = null
  isReinitDelayed = false

  function initScreen() {
    this.actionBar = null
    this.isReinitDelayed = false
  }

  function updatePosHudMultiplayerScore() {
    let multiplayerScoreObj = this.scene.findObject("hud_multiplayer_score")
    if (checkObj(multiplayerScoreObj)) {
      multiplayerScoreObj.setValue(stashBhvValueConfig([{
        watch = getHasCompassObservable()
        updateFunc = @(obj, value) obj.top = value ? "1@multiplayerScoreTopPosUnderCompass" : "0.015@shHud"
      },
      {
        watch = isInKillerCamera
        updateFunc = @(obj, value) obj.show(!value)
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
      this.actionBar?.reinit()
      this.isReinitDelayed = false
    }
  }
}
