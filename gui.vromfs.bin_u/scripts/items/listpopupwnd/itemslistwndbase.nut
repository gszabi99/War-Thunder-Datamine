//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { move_mouse_on_child_by_value, move_mouse_on_obj } = require("%scripts/baseGuiHandlerManagerWT.nut")
let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let ItemsListWndBase = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/items/universalSpareApplyWnd.tpl"

  itemsList = null
  alignObj = null
  align = ALIGN.BOTTOM

  curItem = null
  showAmount = true

  function getSceneTplView() {
    let showAmount = this.showAmount
    return {
      items = handyman.renderCached("%gui/items/item.tpl", {
        items = this.itemsList.map(@(i) i.getViewData({ showAmount }))
      })
      columns = stdMath.calc_golden_ratio_columns(this.itemsList.len())

      align = this.align
      position = "50%pw-50%w, 50%ph-50%h"
      hasPopupMenuArrow = checkObj(this.alignObj)
    }
  }

  function initScreen() {
    this.setCurItem(this.itemsList[0])
    this.updateWndAlign()
    this.guiScene.performDelayed(this, @() this.guiScene.performDelayed(this, function() {
      if (this.scene.isValid())
        move_mouse_on_child_by_value(this.scene.findObject("items_list"))
    }))

    if (this.itemsList.findindex(@(i) i.hasTimer()) != null)
      this.scene.findObject("update_timer")?.setUserData(this)
  }

  function updateWndAlign() {
    if (checkObj(this.alignObj))
      this.align = setPopupMenuPosAndAlign(this.alignObj, this.align, this.scene.findObject("frame_obj"))
  }

  function setCurItem(item) {
    this.curItem = item
    this.scene.findObject("header_text").setValue(this.curItem.getName())
    this.scene.findObject("buttonActivate").enable(!this.curItem.isExpired())
  }

  function onTimer(_obj, _dt) {
    let listObj = this.scene.findObject("items_list")
    if (!listObj?.isValid())
      return

    for (local i = 0; i < this.itemsList.len(); ++i) {
      let item = this.itemsList[i]
      if (!item.hasTimer())
        continue

      let itemObj = listObj.getChild(i)
      let timeTxtObj = itemObj.findObject("expire_time")
      timeTxtObj.setValue(item.getTimeLeftText())
    }

    this.scene.findObject("buttonActivate").enable(!this.curItem.isExpired())
  }

  function onItemSelect(obj) {
    let value = obj.getValue()
    if (value in this.itemsList)
      this.setCurItem(this.itemsList[value])
  }

  function onActivate() {}
  function onButtonMax() {}

  function afterModalDestroy() {
    move_mouse_on_obj(this.alignObj)
  }
}

gui_handlers.ItemsListWndBase <- ItemsListWndBase

return {
  ItemsListWndBase
}