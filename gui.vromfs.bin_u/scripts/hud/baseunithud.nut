local { getHasCompassObservable } = require("hudCompassState")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")

class ::gui_handlers.BaseUnitHud extends ::gui_handlers.BaseGuiHandlerWT
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
    local multiplayerScoreObj = scene.findObject("hud_multiplayer_score")
    if (::check_obj(multiplayerScoreObj)) {
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
