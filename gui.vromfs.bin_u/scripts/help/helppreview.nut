import "%scripts/controls/help/controlsHelpTabs.nut" as helpTabs
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/help/helpWnd.nut" import helpWndModalHandler
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child_by_value
from "%scripts/controls/controlsState.nut" import getPreviewControlsPreset
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import HELP_CONTENT_SET

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

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

return freeze({
  function getHelpPreviewHandler(params) {
    return handlersManager.loadHandler(helpPreviewHandler, params)
  }
})