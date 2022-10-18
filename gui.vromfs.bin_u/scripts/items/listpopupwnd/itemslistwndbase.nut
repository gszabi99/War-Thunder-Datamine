from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.ItemsListWndBase <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/items/universalSpareApplyWnd"

  itemsList = null
  alignObj = null
  align = ALIGN.BOTTOM

  curItem = null

  function getSceneTplView()
  {
    return {
      items = ::handyman.renderCached("%gui/items/item", { items = ::u.map(itemsList, @(i) i.getViewData()) })
      columns = stdMath.calc_golden_ratio_columns(itemsList.len())

      align = align
      position = "50%pw-50%w, 50%ph-50%h"
      hasPopupMenuArrow = checkObj(alignObj)
    }
  }

  function initScreen()
  {
    setCurItem(itemsList[0])
    updateWndAlign()
    this.guiScene.performDelayed(this, @() this.guiScene.performDelayed(this, function() {
      if (this.scene.isValid())
        ::move_mouse_on_child_by_value(this.scene.findObject("items_list"))
    }))
  }

  function updateWndAlign()
  {
    if (checkObj(alignObj))
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, this.scene.findObject("frame_obj"))
  }

  function setCurItem(item)
  {
    curItem = item
    this.scene.findObject("header_text").setValue(curItem.getName())
  }

  function onItemSelect(obj)
  {
    let value = obj.getValue()
    if (value in itemsList)
      setCurItem(itemsList[value])
  }

  function onActivate() {}
  function onButtonMax() {}

  function afterModalDestroy() {
    ::move_mouse_on_obj(alignObj)
  }
}
