from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import HELP_CONTENT_SET

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { helpWndModalHandler } = require("%scripts/help/helpWnd.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value } = require("%scripts/sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let helpTabs = require("%scripts/controls/help/controlsHelpTabs.nut")
let { getPreviewControlsPreset } = require("%scripts/controls/controlsState.nut")

let helpPreviewHandler = class (helpWndModalHandler) {
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
register_gui_handler("helpPreviewHandler", helpPreviewHandler)

return {
  function getHelpPreviewHandler(params) {
    return handlersManager.loadHandler(helpPreviewHandler, params)
  }
}