from "%scripts/dagui_library.nut" import *

from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let isGroupItem = @(id) id.indexof("/") == null
let isCategoryItem = @(id) id.indexof("/") != null
let getItemIdParts = @(id) id.split("/")
let getGroupId = @(id) id.split("/")?[0] ?? ""

local DecoratorGroupsTreeHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType          = handlerType.CUSTOM
  sceneBlkName     = "%gui/skins/decoratorGroupsTree.blk"
  treeObj = null
  treeData = null
  selectCallback = null
  prevSelected = ""
  prevInvokedId = null
  allowGroupSelection = false

  function initScreen() {
    this.treeObj = this.scene.findObject("list")
    move_mouse_on_child_by_value(this.treeObj)
    this.fillTree()
  }

  function fillTree() {
    if (this.treeData == null)
      return
    this.treeData = this.treeData.map(function(data) {
      if (data?.isCollapsable ?? false)
        data.onCollapseFunc <- "onCollapseGroup"
      return data
    })

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", { items = this.treeData })
    this.guiScene.replaceContentFromText(this.treeObj, data, data.len(), this)
    this.selectItemById(this.prevSelected)
  }

  function findFirstVisibleCategoryIndexInGroup(group) {
    return this.treeData.findindex(@(v) getGroupId(v.id) == group && isCategoryItem(v.id) && !v.hidden)
  }

  function findGroupIndex(group) {
    return this.treeData.findindex(@(v) v.id == group && !v.hidden)
  }

  function findFirstVisibleGroup() {
    return this.treeData.findvalue(@(v) isGroupItem(v.id) && !v.hidden)?.id
  }

  function isElementVisible(elementId) {
    return this.treeData.findindex(@(v) v.id == elementId && !v.hidden) != null
  }

  function getIndexForSelection(itemId) {
    let [ group = "", category = "" ] = getItemIdParts(itemId)
    if (group == "" || !this.isElementVisible(group)) {
      let openedGroup = this.findFirstVisibleGroup()
      let index = this.allowGroupSelection ? this.findGroupIndex(openedGroup)
        : this.findFirstVisibleCategoryIndexInGroup(openedGroup)
      return { openedGroup, index }
    }

    if (category == "" || !this.isElementVisible($"{group}/{category}")) {
      let index = (this.allowGroupSelection || this.hasNoGroups(group)) ? this.findGroupIndex(group) : this.findFirstVisibleCategoryIndexInGroup(group)
      return { openedGroup = group, index }
    }

    let index = this.treeData.findindex(@(v) v.id == $"{group}/{category}")
    return { openedGroup = group, index = index }
  }

  function selectItemById(itemId) {
    let { openedGroup, index } = this.getIndexForSelection(itemId)

    local visible = false
    let total = this.treeObj.childrenCount()
    for (local i = 0; i < total; ++i) {
      let itemObj = this.treeObj.getChild(i)

      let isHidden = !this.isElementVisible(itemObj.id)

      if (isCategoryItem(itemObj.id)) {
        itemObj.enable(visible && !isHidden)
        itemObj.show(visible && !isHidden)
        continue
      }
      else {
        itemObj.enable(!isHidden)
        itemObj.show(!isHidden)
      }

      if ("collapsed" not in itemObj || isHidden)
        continue

      itemObj.collapsed = itemObj.id == openedGroup ? "no" : "yes"
      visible = itemObj.collapsed == "no"
    }

    if (index == null)
      return

    if (this.treeObj.getValue() == index) {
      this.invokeCallback(this.prevSelected)
      return
    }

    this.treeObj.setValue(index)
  }

  function onCollapseGroup(obj) {
    let id = obj.id
    if (id.len() > 4 && id.slice(0, 4) == "btn_")
      this.doSelectElement(id.slice(4))
  }

  function onElementSelect(obj) {
    local value = obj.getValue()
    let item = obj.getChild(value)
    this.prevSelected = item.id
    this.doSelectElement(item.id)
  }

  function doSelectElement(id) {
    this.selectItemById(id)
    this.invokeCallback(id)
  }

  function invokeCallback(id) {
    if (this.prevInvokedId == id)
      return
    this.prevInvokedId = id

    let needInvokeCallback = this.allowGroupSelection || this.hasNoGroups(id) || isCategoryItem(id)
    if (this.selectCallback != null && needInvokeCallback)
      this.selectCallback(id)
  }

  function hasNoGroups(groupId) {
    return this.treeData.findvalue(@(v) v.id == groupId)?.isNoGroups ?? false
  }

  function update(data) {
    if (data == null)
      return
    this.prevInvokedId = ""
    this.treeData.each(@(item) item.hidden = !data.contains(item.id))
    this.selectItemById(this.prevSelected)
  }

  getTreeObject = @() this.treeObj
}

gui_handlers.DecoratorGroupsTreeHandler <- DecoratorGroupsTreeHandler

return {
  initTree = @(params = {}) handlersManager.loadHandler(DecoratorGroupsTreeHandler, params)
}