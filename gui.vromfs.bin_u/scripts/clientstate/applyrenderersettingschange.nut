from "%scripts/dagui_natives.nut" import on_renderer_settings_change
from "%scripts/dagui_library.nut" import *

let { reloadDargUiScript } = require("reactiveGuiCommand")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { eventbus_subscribe } = require("eventbus")

local isRequestedReloadScene = false
local isRequestedOnSceneSwitch = false
local cbFunc = null

/**
 * Calls client func Renderer::onSettingsChanged(), to apply the modified graphics settings
 * from config.blk. Renderer applies all changes from config.blk on the next frame.
 * @param {bool} shouldReloadScene - Pass true to reload the GUI Scene after renderer settings applied.
 *     Please note, that renderer can request the GUI Scene reload too, via on_renderer_settings_applied()
 *     func param.
 * @param {bool} shouldDoItOnSceneSwitch - If true, GUI Scene will be reloaded on next scene switch.
 *     If false, GUI Scene  will be reloaded on the next frame.
 * @param {function|null} cb - Callback func, which will be called on next frame (when changes to the
 *     renderer settings have already been applied).
 */

function applyRendererSettingsChange(shouldReloadScene = false, shouldDoItOnSceneSwitch = false, cb = null) {
  isRequestedReloadScene = shouldReloadScene
  isRequestedOnSceneSwitch = shouldDoItOnSceneSwitch
  cbFunc = cb

  on_renderer_settings_change()
}

/**
 * Called from client. Client calls this func every time when renderer settings changes are applied,
 * even if this action was NOT requested by scripts. Also, it can request the GUI Scene reload
 * by param forceReloadGuiScene.
 */

eventbus_subscribe("on_renderer_settings_applied", function on_renderer_settings_applied(evt) {
  let forceReloadGuiScene = evt.need_reload
  handlersManager.updateSceneBgBlur(true)
  handlersManager.updateSceneVrParams()

  handlersManager.doDelayed(function() {
    isRequestedReloadScene = isRequestedReloadScene || forceReloadGuiScene

    if (isRequestedReloadScene) {
      reloadDargUiScript(false)
      let handler = isRequestedOnSceneSwitch ? null : handlersManager.getActiveBaseHandler()
      if (handler)
        handler.fullReloadScene()
      else
        handlersManager.markfullReloadOnSwitchScene()
    }

    cbFunc?()

    isRequestedReloadScene = false
    isRequestedOnSceneSwitch = false
    cbFunc = null
  })
})

return applyRendererSettingsChange
