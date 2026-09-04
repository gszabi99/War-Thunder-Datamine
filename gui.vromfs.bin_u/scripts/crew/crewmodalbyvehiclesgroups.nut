from "string" import format
from "%scripts/dagui_natives.nut" import get_crew_slot_cost
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { CrewHandler } = require("%scripts/crew/crewWndHandler.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let { getSlotItem, getCurPreset, setUnit } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let slotbarWidget = require("%scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let { setColoredDoubleTextToButton, warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { purchaseNewCrewSlot } = require("%scripts/crew/crew.nut")
let { purchaseConfirmation } = require("%scripts/purchase/purchaseConfirmationHandler.nut")

class CrewModalByVehiclesGroups (CrewHandler) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/crew/crewModalByVehiclesGroups.blk"

  slotbarActions = ["aircraft", "changeUnitsGroup", "repair"]

  getSlotbarParams = @() {
    curSlotIdInCountry = this.idInCountry
    showEmptySlot = true
    needPresetsPanel = false
  }

  createSlotbarHandler = @(params) slotbarWidget.create(params)

  onSlotDblClick = @(_slotCrew) null
  canUpgradeCrewSpec = @(_upgCrew) false

  function getCurCrewUnit(slotCrew) {
    let curPreset = getCurPreset()
    return curPreset?.countryPresets[slotCrew.country].units[slotCrew.idInCountry]
  }

  getSlotCrew = @() getSlotItem(this.countryId, this.idInCountry)

  function updateButtons() {
    let isRecrutedCrew = this.crew.id != -1
    this.scene.findObject("btn_apply").show(isRecrutedCrew)
    showObjById("not_recrute_crew_warning", !isRecrutedCrew, this.scene)
    showObjById("btn_recruit", !isRecrutedCrew, this.scene)
    if (!isRecrutedCrew) {
      let rawCost = get_crew_slot_cost(this.getCurCountryName())
      let cost = rawCost ? Cost(rawCost.cost, rawCost.costGold) : Cost()
      let text = "".concat(loc("shop/recruitCrew"),
        loc("ui/parentheses/space", { text = cost.getTextAccordingToBalance() }))
      setColoredDoubleTextToButton(this.scene, "btn_recruit", text)
    }
  }

  function onRecruitCrew() {
    let country = this.getCurCountryName()
    let rawCost = get_crew_slot_cost(country)
    let cost = rawCost ? Cost(rawCost.cost, rawCost.costGold) : Cost()
    if (!checkBalanceMsgBox(cost))
      return

    let unit = this.getCurCrewUnit(this.crew)
    let onTaskSuccess = Callback(function() {
      let crews = getCrewsListByCountry(country)
      if (!crews.len())
        return

      let newCrew = crews.top()
      setUnit({
        crew = newCrew
        unit = unit
        showNotification = false
      })
      this.openSelectedCrew()
      this.updatePage()
    }, this)
    if (cost > zero_money) {
      let text = warningIfGold(
        format(loc("shop/needMoneyQuestion_purchaseCrew"),
          cost.getTextAccordingToBalance()),
        cost)

      let callbackYes = @() purchaseNewCrewSlot(country, onTaskSuccess)
      purchaseConfirmation({ id = "need_money", text, callbackYes }, cost)
    }
    else
      onTaskSuccess()
  }

  function onEventPresetsByGroupsChanged(_params) {
    this.openSelectedCrew()
    this.updatePage()
  }
}

register_gui_handler("CrewModalByVehiclesGroups", CrewModalByVehiclesGroups)

return {
  open = function(params = {}) {
    if (hasFeature("CrewSkills"))
      handlersManager.loadHandler(CrewModalByVehiclesGroups, params)
    else
      showInfoMsgBox(loc("msgbox/notAvailbleYet"))
  }
}
