from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/hud/dargHudLayers.nut" import getDargLayerWidgets
from "%scripts/dagui_library.nut" import *

let BaseUnitHud = class (BaseGuiHandlerWT) {
  scene = null
  wndType = handlerType.CUSTOM

  actionBarWeak   = null
  isReinitDelayed = false
  killFeedPlace   = null
  hasMpScore      = false

  function initScreen() {
    this.actionBarWeak = null
    this.isReinitDelayed = false
  }

  function getWidgetsList() {
    let layers = getDargLayerWidgets(this)
    return base.getWidgetsList().extend(layers)
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

return freeze({ BaseUnitHud })
