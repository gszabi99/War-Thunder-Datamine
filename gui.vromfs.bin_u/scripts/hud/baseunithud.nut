from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getHasCompassObservable } = require("hudCompassState")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")

::gui_handlers.BaseUnitHud <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  scene = null
  wndType = handlerType.CUSTOM

  actionBar    = null
  isReinitDelayed = false

  function initScreen() {
    actionBar = null
    isReinitDelayed = false
  }

  function updatePosHudMultiplayerScore() {
    let multiplayerScoreObj = scene.findObject("hud_multiplayer_score")
    if (checkObj(multiplayerScoreObj)) {
      multiplayerScoreObj.setValue(stashBhvValueConfig([{
        watch = getHasCompassObservable()
        updateFunc = @(obj, value) obj.top = value ? "0.065@scrn_tgt" : "0.015@scrn_tgt"
      }]))
    }
  }

  function onEventControlsPresetChanged(p) {
    isReinitDelayed = true
  }
  function onEventControlsChangedShortcuts(p) {
    isReinitDelayed = true
  }
  function onEventControlsChangedAxes(p) {
    isReinitDelayed = true
  }

  function onEventShowHud(p) {
    if (isReinitDelayed)
    {
      actionBar?.reinit(true)
      isReinitDelayed = false
    }
  }
}
