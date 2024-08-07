from "%scripts/dagui_library.nut" import *
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getCrewById } = require("%scripts/slotbar/slotbarState.nut")

let class SwapCrewsHandler (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/slotbar/swapCrews.blk"

  draggedObj = null
  airsTableSource = null

  draggedClone = null
  draggedCrewCountry = null

  fixedPositions = null
  items = null
  holeIndex = -1
  isSaved = false
  draggedCloneTop = 0

  function initScreen() {
    this.fixedPositions = []
    this.items = []

    let tableBounds = this.getTableBounds()
    let itemsHolder = this.scene.findObject("itemsHolder")
    itemsHolder.pos = $"{tableBounds.left}, {tableBounds.top}"
    itemsHolder.size = $"{tableBounds.width}, {tableBounds.height}"

    this.showOriginalSlotbar(false)

    this.draggedCrewCountry = getCrewById(this.draggedObj.crewId.tointeger()).country
    this.cloneSlotbarTable()

    let objPos = this.draggedObj.getPosRC()
    let objSize = this.draggedObj.getSize()

    gui_handlers.ActionsList.removeActionsListFromObject(this.draggedObj) //close unit context menu
    this.draggedClone = this.draggedObj.getClone(this.scene.findObject("itemsNest"), this)
    this.draggedClone.pos = ", ".join(objPos)
    this.draggedClone["class"] = "swapCrewsDnD"
    this.draggedClone["bounds"] = ",".join([tableBounds.left, objPos[1], tableBounds.right, objPos[1] + objSize[1]])
    this.draggedClone.dragging = "yes"
    this.draggedCloneTop = objPos[1]
  }

  function onCloseSwapCrews() {
    this.showOriginalSlotbar(true)
    this.goBack()
  }

  function onCrewDrop(_obj) {
    if(this.isSaved)
      return

    ::slotbarPresets.replaceCrewsInCurrentPreset(this.draggedCrewCountry, this.getCrewsOrder())

    this.draggedClone.dragging = "no"
    let pos = this.draggedClone.getPosRC()
    this.draggedClone.pos = null
    this.draggedClone.left = pos[0]
    this.draggedClone["left-base"] = pos[0]
    this.draggedClone["left-end"] = this.fixedPositions[this.holeIndex]
    this.draggedClone.top = pos[1]
    this.draggedClone["top-base"] = pos[1]
    this.draggedClone["top-end"] = this.draggedCloneTop
    this.draggedClone["dropFinished"] = "yes"

    this.isSaved = true
  }

  function onCrewDropFinish(_obj) {
    this.onCloseSwapCrews()
  }

  function getTableBounds() {
    let pos = this.airsTableSource.getParent().getPosRC()
    let size = this.airsTableSource.getParent().getSize()
    let padding = to_pixels("@slot_interval + @slotScrollButtonWidth")
    return {
      left = pos[0] + padding,
      top = pos[1],
      right = pos[0] + size[0] - padding,
      bottom = pos[1] + size[1],
      width = size[0] - 2 * padding,
      height = size[1]
    }
  }

  function isItemInBounds(item, bounds) {
    let itemPos = item.getPosRC()
    let itemSize = item.getPosRC()
    if(itemPos[0] < bounds.left || itemPos[0] + itemSize[0] > bounds.right)
      return false
    return true
  }

  function cloneSlotbarTable() {
    let itemsCount = this.airsTableSource.childrenCount()

    for (local i = 0; i < itemsCount - 1; i++) {
      let originalItem = this.airsTableSource.getChild(i)
      let originalItemPos = originalItem.getPosRC()
      this.fixedPositions.append(originalItemPos[0])
      if (originalItem.id == this.draggedObj.id) {
        this.holeIndex = i
        continue
      }

      gui_handlers.ActionsList.removeActionsListFromObject(originalItem)

      let item = originalItem.getClone(this.scene.findObject("itemsNest"), this)
      item["class"] = "swapCrewsDnD"
      item.left = originalItemPos[0].tostring()
      item["left-base"] = originalItemPos[0].tostring()
      item["left-end"] = originalItemPos[0].tostring()
      item.top = originalItemPos[1].tostring()
      item["top-base"] = originalItemPos[1].tostring()
      item["top-end"] = originalItemPos[1].tostring()
      item["swapable"] = "yes"
      this.items.append(item)
    }
  }

  function showOriginalSlotbar(value) {
    let itemsCount = this.airsTableSource.childrenCount()
    for (local i = 0; i < itemsCount; i++) {
      let item = this.airsTableSource.getChild(i)
      item["class"] = value ? "" : "slotbarCloneSource"
    }
 }

  function onCrewMove(_obj) {
    let draggedCloneCenter = this.draggedClone.getPosRC()[0] + this.draggedClone.getSize()[0] / 2

    let index = this.findIndexPosition(draggedCloneCenter)
    if(this.holeIndex == index)
      return
    this.holeIndex = index
    this.rearrangeItems()
  }

  function rearrangeItems() {
    let holeIndex = this.holeIndex
    let allowedPositions = this.fixedPositions.filter(@(_p, i) i != holeIndex)
    for (local i = 0; i < allowedPositions.len(); i++) {
      let item = this.items[i]
      this.setNewPosition(item, allowedPositions[i])
    }
  }

  getCrewsOrder = @() this.items.map(@(item) item.crewId.tointeger())
    .insert(this.holeIndex, this.draggedClone.crewId.tointeger())

  function findIndexPosition(value) {
    for (local i = 0; i < this.fixedPositions.len() - 1; i++)
      if(value >= this.fixedPositions[i] && value < this.fixedPositions[i + 1])
        return i
    if(value >= this.fixedPositions[this.fixedPositions.len() - 1])
      return this.fixedPositions.len() - 1
    return 0
  }

  function setNewPosition(item, left) {
    if(item.left == left.tostring())
      return
    item["left-end"] = left
  }

  onUnitCellDragStart = @ (_obj) null
  onCrewDragStart = @ (_obj) null
  onSlotChangeAircraft = @ () null
  onOpenCrewWindow = @ (_obj) null
  onSwapCrews = @ (_obj) null
  onOpenCrewPopup = @(_obj) null
  onSlotbarSelect = @(_obj) null
  onSlotbarActivate = @(_obj) null
  onSlotbarDblClick = @(_obj) null
  onUnitCellDrop = @(_obj) null
  onUnitCellMove = @(_obj) null
  onCrewBlockHover = @(_obj) null
}

gui_handlers.SwapCrewsHandler <- SwapCrewsHandler

return @(draggedObj, airsTableSource) handlersManager.loadHandler(SwapCrewsHandler, { draggedObj, airsTableSource })
