from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import get_crew_count
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { CrewTakeUnitProcess } = require("%scripts/crew/crewTakeUnitProcess.nut")
let { getCrewById } = require("%scripts/slotbar/crewsList.nut")
let { hasDefaultUnitsInCountry } = require("%scripts/shop/shopUnitsInfo.nut")
let fillSlotbarLegend = require("%scripts/slotbar/fillSlotbarLegend.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresets.nut")

let slotbarBaseCfg = require("%scripts/slotbar/selectCrewSlotbarBaseCfg.nut")

let class SlotbarUnitDnD (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/slotbar/slotbarUnitDnDControls.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  trashBin = null
  country = null
  draggedObj = null
  draggedObjParent = null
  crew = null
  unit = null
  hoveredSlotbarCrew = null
  hoveredSlotbarCrewId = -1

  function initScreen() {
    let canSendToVacation = slotbarPresets.getCurrentPreset(this.country).units.len() > 1 || !hasDefaultUnitsInCountry(this.country)

    this.trashBin = this.scene.findObject("unitTrashBin")

    this.trashBin["class"] = canSendToVacation ? "" : "disabled"

    if(!canSendToVacation)
      this.trashBin.findObject("trashBinText").setValue(loc("slotbar/noRemoveVehicle"))

    let draggedObjSize = this.draggedObj.getSize()
    this.trashBin.size = ", ".join([1.2 * draggedObjSize[0],
      draggedObjSize[1] * (canSendToVacation ? 1.3 : 1.45)])

    this.crew = getCrewById(this.draggedObj.crew_id.tointeger())

    this.createSlotbar(
      slotbarBaseCfg.__merge({
        singleCountry = this.country
        unitForSpecType = this.unit
        selectOnHover = true
        hasCrewHint = false
        applySlotSelectionOverride = @(_, __) this.onSlotSelection()
      }),"take-aircraft-slotbar")
    this.guiScene.performDelayed(this, @() this.slotbarWeak.selectCrew(-1))

    this.draggedObjParent = this.draggedObj.getParent()
    let tdPos = this.draggedObjParent.getPosRC()
    let draggedClone = this.draggedObjParent.getClone(this.scene, this)
    draggedClone.pos = ", ".join(tdPos)

    draggedClone["class"] = "slotbarClone"
    this.draggedObjParent["class"] = "slotbarCloneSource"

    let shopItemObj = draggedClone.getChild()
    shopItemObj.dragging = "yes"

    fillSlotbarLegend(this.scene.findObject("qualification_legend"), this.unit, this)
  }

  function onSlotSelection() {
    this.hoveredSlotbarCrew = this.getCurCrew()
    this.hoveredSlotbarCrewId = this.slotbarWeak.curSlotIdInCountry == -1
      ? -1
      : this.hoveredSlotbarCrew?.idInCountry ?? get_crew_count(this.country)
    this.updateTakeCrewText()
  }

  function updateTakeCrewText() {
    if (this.hoveredSlotbarCrewId != -1) {
      let cost = CrewTakeUnitProcess.getProcessCost(this.hoveredSlotbarCrew, this.unit)
      placePriceTextToButton(this.scene, "set_air_dnd_title", loc("mainmenu/btnTakeAircraft"), cost)
    }
    else
      this.scene.findObject("set_air_dnd_title_text").setValue("")
  }

  onTakeCancel = @() this.goBack()

  function onUnitCellDrop(obj) {
    if(this.isUnitIntersectsWithBin(obj))
      CrewTakeUnitProcess(this.crew)
    if(this.hoveredSlotbarCrewId != -1)
      CrewTakeUnitProcess(this.getCurCrew(), this.unit)
    this.goBack()
  }

  onUnitCellMove = @(obj) this.trashBin.active = this.isUnitIntersectsWithBin(obj) ? "yes" : "no"

  function isUnitIntersectsWithBin(obj) {
    let unitPos = obj.getPosRC()
    let unitSize = obj.getSize()

    let trashPos = this.trashBin.getPosRC()
    let trashSize = this.trashBin.getSize()

    return trashPos[0] < unitPos[0] + unitSize[0] && trashPos[0] + trashSize[0] > unitPos[0] &&
      trashPos[1] < unitPos[1] + unitSize[1] && trashPos[1] + trashSize[1] > unitPos[1]
  }

  function onDestroy() {
    if(this.draggedObjParent.isValid())
      this.draggedObjParent["class"] = ""
  }

  onUnitCellDragStart = @ (_obj) null
  onSlotChangeAircraft = @ () null
  onOpenCrewWindow = @ (_obj) null
  onSwapCrews = @ (_obj) null
  onCrewSlotClick = @(_obj) null
  onCrewDragStart = @ (_obj) null
  onCrewDropFinish = @ (_obj) null
  onCrewDrop = @(_obj) null
  onCrewMove = @(_obj) null
  onCrewBlockHover = @(_obj) null
}

gui_handlers.SlotbarUnitDnD <- SlotbarUnitDnD

return {
  startSlotbarUnitDnD = @(params) handlersManager.loadHandler(SlotbarUnitDnD, params)
}
