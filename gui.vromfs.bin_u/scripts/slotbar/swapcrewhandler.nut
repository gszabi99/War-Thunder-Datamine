from "%scripts/dagui_natives.nut" import is_default_aircraft
from "%scripts/dagui_library.nut" import *
from "%scripts/slotbar/slotbarConsts.nut" import SEL_UNIT_BUTTON

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getSlotObj } = require("%scripts/slotbar/slotbarView.nut")
let { getCrew } = require("%scripts/crew/crew.nut")
let { abs } = require("math")

local class SwapCrewHandler (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/slotbar/slotbarSwapCrew.blk"
  slotbarWeak = null

  countryId = -1
  crewIdInCountry = -1
  crew = null
  airsTableSource = null

  curClonObjId = null
  slotsCrews = []

  tableInitPosX = 0
  itemToScroll = null

  function initScreen() {
    this.countryId = this.crew.idCountry;
    this.crewIdInCountry = this.crew.idInCountry
    if (this.slotbarWeak)
      this.slotbarWeak = this.slotbarWeak.weakref()

    let slotObj = getSlotObj(this.slotbarWeak.scene, this.countryId, this.crewIdInCountry)
    let tdObj = slotObj.getParent()

    gui_handlers.ActionsList.removeActionsListFromObject(tdObj)

    this.curClonObjId = tdObj.id

    let airsTablePos = this.airsTableSource.getParent().getPosRC()
    this.tableInitPosX = airsTablePos[0] + to_pixels("@slot_interval + 1@slotScrollButtonWidth")
    this.scene.findObject("tablePlace").left = airsTablePos[0]

    this.fillSlots()
  }

  function fillSlots() {
    let itemsHolder = this.scene.findObject("airs_table")
    let itemsCount = this.airsTableSource.childrenCount()
    this.slotsCrews.clear()
    this.itemToScroll = null
    local swappedItem = null

    for (local i = 0; i < itemsCount; i++) {
      let item = this.airsTableSource.getChild(i)
      gui_handlers.ActionsList.removeActionsListFromObject(item)

      let idParts = item.id.split("td_slot_")[1].split("_").map(@(part) part.tointeger())
      let slotCountryId = idParts[0]
      let slotIdInCountry = idParts[1]
      let crew = getCrew(slotCountryId, slotIdInCountry)

      let isEmpty = crew?.aircraft == null

      let itemClone = item.getClone(itemsHolder, this)
      itemClone["class"] = "slotbarClone"
      itemClone["swapCrews"] = "yes"

      if(this.curClonObjId == item.id) {
        itemClone["swappedItem"] = "yes"
        swappedItem = itemClone
      }

      if(isEmpty) {
        let topTextId = $"{itemClone.id.split("td_")[1]}_txt"
        itemClone.findObject(topTextId).show(false)
      }

      if(this.approxEqual(item.getPosRC()[0], this.tableInitPosX, 3)) {
        this.itemToScroll = itemClone
      }

      if(crew?.id == null)
        itemClone["fakeItem"] = "yes"

      this.slotsCrews.append(crew?.id)
    }

    this.guiScene.applyPendingChanges(false)
    this.itemToScroll?.scrollToView(true)

    swappedItem.setMouseCursorOnObject()
  }

  function onSlotSelect(obj) {
    let row = obj.getValue()
    if (row < 0)
      return

    if(this.slotsCrews[row] == null)
      return

    let swapedCrews = {}
    swapedCrews[this.slotsCrews[row]] <- this.crew.id
    swapedCrews[this.crew.id] <- this.slotsCrews[row]
    ::slotbarPresets.swapCrewsInCurrentPreset(swapedCrews)
    this.slotbarWeak.fullUpdate()
    this.goBack()
  }

  approxEqual = @(val1, val2, delta = 5) abs(val1 - val2) <= delta
  onEventSetInQueue = @(_params) this.goBack()
  onSwapCrews = @(_obj) null
  onOpenCrewWindow = @(_obj) null
  onSlotChangeAircraft = @(_obj) null
  onUnitCellDragStart = @(_obj) null
  onUnitCellDrop = @(_obj) null
  onUnitCellMove = @(_obj) null
  onOpenCrewPopup = @(_obj) null
  hideAllPopups = @(_obj) null
  onCrewDragStart = @ (_obj) null
  onCrewDropFinish = @ (_obj) null
}

gui_handlers.SwapCrewHandler <- SwapCrewHandler

return {
  open = @(crew, airsTableSource, slotbarWeak) handlersManager.loadHandler(SwapCrewHandler, { crew, airsTableSource, slotbarWeak })
}
