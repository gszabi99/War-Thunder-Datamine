//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { reloadDargUiScript } = require("reactiveGuiCommand")

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

let function applyRendererSettingsChange(shouldReloadScene = false, shouldDoItOnSceneSwitch = false, cb = null) {
  isRequestedReloadScene = shouldReloadScene
  isRequestedOnSceneSwitch = shouldDoItOnSceneSwitch
  cbFunc = cb

  ::on_renderer_settings_change()
}

/**
 * Called from client. Client calls this func every time when renderer settings changes are applied,
 * even if this action was NOT requested by scripts. Also, it can request the GUI Scene reload
 * by param forceReloadGuiScene.
 */

::on_renderer_settings_applied <- function on_renderer_settings_applied(forceReloadGuiScene) {
  ::handlersManager.updateSceneBgBlur(true)
  ::handlersManager.updateSceneVrParams()

  ::handlersManager.doDelayed(function() {
    isRequestedReloadScene = isRequestedReloadScene || forceReloadGuiScene

    if (isRequestedReloadScene) {
      reloadDargUiScript(false)
      let handler = isRequestedOnSceneSwitch ? null : ::handlersManager.getActiveBaseHandler()
      if (handler)
        handler.fullReloadScene()
      else
        ::handlersManager.markfullReloadOnSwitchScene()
    }

    cbFunc?()

    isRequestedReloadScene = false
    isRequestedOnSceneSwitch = false
    cbFunc = null
  })
}

return applyRendererSettingsChange
