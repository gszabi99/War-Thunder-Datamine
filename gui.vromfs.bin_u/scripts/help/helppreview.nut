//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let helpTabs = require("%scripts/controls/help/controlsHelpTabs.nut")

::gui_handlers.helpPreviewHandler <- class extends ::gui_handlers.helpWndModalHandler {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/help/helpPreview.blk"
  contentSet = HELP_CONTENT_SET.CONTROLS
  tabsCreated = false

  initScreen = @() null

  afterModalDestroy = @() null

  function showPreview() {
    this.preset = ::g_controls_manager.getPreviewPreset()
    this.visibleTabs = helpTabs.getTabs(this.contentSet)
    if (!this.tabsCreated)
      this.fillTabs()
    else
      this.fillSubTabs()

    let subTabsObj = this.scene.findObject("sub_tabs_list")
    ::move_mouse_on_child_by_value(subTabsObj?.isVisible()
      ? subTabsObj
      : this.scene.findObject("tabs_list"))
  }
}

return {
  function getHelpPreviewHandler(params) {
    return ::handlersManager.loadHandler(::gui_handlers.helpPreviewHandler, params)
  }
}