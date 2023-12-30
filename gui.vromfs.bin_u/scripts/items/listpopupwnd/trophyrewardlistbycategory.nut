from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_obj, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

local class TrophyRewardListByCategory (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/items/trophyRewardListByCategory.tpl"

  chestItem = null
  currentCategoryId = null

  getSceneTplView = @() {
    contentData = "".join(this.chestItem.getContentMarkupForDescription({}))
    headerText = this.chestItem.getName(false)
  }

  function openCategory(categoryId) {
    let containerObj = this.scene.findObject("item_info_collapsable_prizes")
    if (!checkObj(containerObj))
      return
    let total = containerObj.childrenCount()
    local visible = false
    this.guiScene.setUpdatesEnabled(false, false)
    for (local i = 0; i < total; i++) {
      let childObj = containerObj.getChild(i)
      if (childObj.isCategory == "no") {
        childObj.enable(visible)
        childObj.show(visible)
        continue
      }
      if (childObj.categoryId == categoryId) {
        childObj.collapsed = childObj.collapsed == "no" ? "yes" : "no"
        visible = childObj.collapsed == "no"
        continue
      }
      childObj.collapsed = "yes"
      visible = false
    }
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function onPrizeCategoryClick(obj) {
    this.currentCategoryId = obj.categoryId
    this.openCategory(this.currentCategoryId)
    if (showConsoleButtons.value)
      move_mouse_on_obj(obj)
  }
}

gui_handlers.TrophyRewardListByCategory <- TrophyRewardListByCategory

return @(params) loadHandler(TrophyRewardListByCategory, params)
