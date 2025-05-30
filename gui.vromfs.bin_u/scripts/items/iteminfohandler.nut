from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { fillItemDescr } = require("%scripts/items/itemVisual.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getChestChancesData, fillChestChances } = require("%scripts/items/prizeChance.nut")

local class ItemInfoHandler (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/items/itemDesc.blk"

  currentItemId = null
  currentCategoryId = null
  currentGeneratorId = -1

  function updateHandlerData(item, shopDesc = false, preferMarkup = false, params = null) {
    this.scene.scrollToView(true)
    fillItemDescr(item, this.scene, this, shopDesc, preferMarkup, params)

    if (item == null) {
      this.currentItemId = null
      this.currentCategoryId = null
      return
    }

    this.currentGeneratorId = item?.generator.id ?? -1
    if (this.currentGeneratorId > -1 && item?.needShowTextChances()) {
      let chancesData = getChestChancesData(this.currentGeneratorId,
        Callback(this.fillChestChances, this))
      if (chancesData != null)
        this.fillChestChances(chancesData, this.currentGeneratorId)
    }

    if (item.id == this.currentItemId && this.currentCategoryId != null) {
      this.openCategory(this.currentCategoryId)
      return
    }
    this.currentItemId = item.id
    this.currentCategoryId = null
  }

  function fillChestChances(chancesData, generatorId) {
    if (this.currentGeneratorId != generatorId)
      return

    let itemsNest = this.scene.findObject("item_info_collapsable_prizes")
      ?? this.scene.findObject("item_desc_div")
    if (!itemsNest?.isValid())
      return
    fillChestChances(itemsNest, chancesData)
  }

  function setHandlerVisible(value) {
    this.scene.show(value)
    this.scene.enable(value)
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

gui_handlers.ItemInfoHandler <- ItemInfoHandler

return function(scene) {
  if (!checkObj(scene))
    return null
  return handlersManager.loadHandler(ItemInfoHandler, { scene = scene })
}