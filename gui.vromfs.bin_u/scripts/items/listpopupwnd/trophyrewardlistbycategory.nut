from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_obj
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/dagui_library.nut" import *

let { getChestChancesData, fillChestChances } = require("%scripts/items/prizeChance.nut")

local class TrophyRewardListByCategory (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/items/trophyRewardListByCategory.tpl"

  chestItem = null
  currentCategoryId = null

  function initScreen() {
    base.initScreen()
    let generatorId = this.chestItem.getGenerator()?.id ?? -1
    if (generatorId >= 0 && this?.chestItem.needShowTextChances()) {
      let chancesData = getChestChancesData(generatorId,
        Callback(this.fillChestChances, this))
      if (chancesData != null)
        this.fillChestChances(chancesData)
    }
  }

  function fillChestChances(chancesData, _generatorId = -1) {
    let itemsNest = this.scene.findObject("item_info_collapsable_prizes")
    if (!itemsNest?.isValid())
      return
    fillChestChances(itemsNest, chancesData)
  }

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
    if (showConsoleButtons.get())
      move_mouse_on_obj(obj)
  }
}

register_gui_handler("TrophyRewardListByCategory", TrophyRewardListByCategory)

return @(params) loadHandler(TrophyRewardListByCategory, params)
