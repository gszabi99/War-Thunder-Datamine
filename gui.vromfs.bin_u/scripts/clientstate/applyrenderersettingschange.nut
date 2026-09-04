from "reactiveGuiCommand" import reloadDargUiScript
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *
from "graphicsOptions" import onRendererSettingsChange

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

local isRequestedReloadScene = false
local isRequestedOnSceneSwitch = false
local cbFunc = null













function applyRendererSettingsChange(shouldReloadScene = false, shouldDoItOnSceneSwitch = false, cb = null) {
  isRequestedReloadScene = shouldReloadScene
  isRequestedOnSceneSwitch = shouldDoItOnSceneSwitch
  cbFunc = cb

  onRendererSettingsChange()
}







eventbus_subscribe("on_renderer_settings_applied", function onRendererSettingsApplied(evt) {
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
