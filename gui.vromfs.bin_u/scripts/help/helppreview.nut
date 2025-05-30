from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let helpTabs = require("%scripts/controls/help/controlsHelpTabs.nut")
let { getPreviewControlsPreset } = require("%scripts/controls/controlsState.nut")

gui_handlers.helpPreviewHandler <- class (gui_handlers.helpWndModalHandler) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/help/helpPreview.blk"
  contentSet = HELP_CONTENT_SET.CONTROLS
  tabsCreated = false

  initScreen = @() null

  afterModalDestroy = @() null

  function showPreview() {
    this.preset = getPreviewControlsPreset()
    this.visibleTabs = helpTabs.getTabs(this.contentSet)
    if (!this.tabsCreated)
      this.fillTabs()
    else
      this.fillSubTabs()

    let subTabsObj = this.scene.findObject("sub_tabs_list")
    move_mouse_on_child_by_value(subTabsObj?.isVisible()
      ? subTabsObj
      : this.scene.findObject("tabs_list"))
  }
}

return {
  function getHelpPreviewHandler(params) {
    return handlersManager.loadHandler(gui_handlers.helpPreviewHandler, params)
  }
}