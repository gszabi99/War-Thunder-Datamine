from "%scripts/dagui_library.nut" import *
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { CrewTakeUnitProcess } = require("%scripts/crew/crewTakeUnitProcess.nut")
let { getCrewById } = require("%scripts/slotbar/slotbarState.nut")
let { hasDefaultUnitsInCountry } = require("%scripts/shop/shopUnitsInfo.nut")

let class VacationBin (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/vacation/vacationBin.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  trashBin = null
  country = null
  draggedObj = null
  draggedObjParent = null
  crew = null

  function initScreen() {

    let canSendToVacation = ::slotbarPresets.getCurrentPreset(this.country).units.len() > 1 || !hasDefaultUnitsInCountry(this.country)

    this.guiScene.setCursor("drag-n-drop", true)
    this.trashBin = this.scene.findObject("unitTrashBin")

    this.trashBin["class"] = canSendToVacation ? "" : "disabled"

    if(!canSendToVacation)
      this.trashBin.findObject("trashBinText").setValue(loc("slotbar/noRemoveVehicle"))

    let draggedObjSize = this.draggedObj.getSize()
    this.trashBin.size = ", ".join([1.2 * draggedObjSize[0],
      draggedObjSize[1] * (canSendToVacation ? 1.3 : 1.45)])

    this.crew = getCrewById(this.draggedObj.crew_id.tointeger())

    this.draggedObjParent = this.draggedObj.getParent()
    let tdPos = this.draggedObjParent.getPosRC()
    tdPos[1] += to_pixels("@slotExtraInfoHeight")
    let draggedClone = this.draggedObjParent.getClone(this.scene, this)
    draggedClone.pos = ", ".join(tdPos)

    draggedClone["class"] = "slotbarClone"
    this.draggedObjParent["class"] = "slotbarCloneSource"

    let shopItemObj = draggedClone.getChild()
    shopItemObj.dragging = "yes"
  }

  function onTakeCancel() {
    this.draggedObjParent["class"] = ""
    this.guiScene.setCursor("normal", true)
    this.goBack()
  }

  function onUnitCellDrop(obj) {
    this.draggedObjParent["class"] = ""
    this.guiScene.setCursor("normal", true)
    if(this.isIntersect(obj))
      CrewTakeUnitProcess(this.crew)
    this.goBack()
  }

  onUnitCellMove = @(obj) this.trashBin.active = this.isIntersect(obj) ? "yes" : "no"

  function isIntersect(obj) {
    let unitPos = obj.getPosRC()
    let unitSize = obj.getSize()

    let trashPos = this.trashBin.getPosRC()
    let trashSize = this.trashBin.getSize()

    if(trashPos[0] < unitPos[0] + unitSize[0] && trashPos[0] + trashSize[0] > unitPos[0] &&
      trashPos[1] < unitPos[1] + unitSize[1] && trashPos[1] + trashSize[1] > unitPos[1])
      return true
    return false
  }

  onUnitCellDragStart = @ (_obj) null
  onSlotChangeAircraft = @ () null
  onOpenCrewWindow = @ (_obj) null
  onSwapCrews = @ (_obj) null
  onOpenCrewPopup = @(_obj) null
  hideAllPopups = @(_obj) null
}

gui_handlers.VacationBin <- VacationBin

return {
  vacationBinOpen = @(draggedObj, country) handlersManager.loadHandler(VacationBin, { draggedObj, country })
}
