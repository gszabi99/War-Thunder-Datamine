//checked for plus_string
from "%scripts/dagui_natives.nut" import get_crew_slot_cost
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { getSlotItem, getCurPreset, setUnit } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let slotbarWidget = require("%scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let { setColoredDoubleTextToButton, warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")

let class CrewModalByVehiclesGroups (gui_handlers.CrewModalHandler) {
  slotbarActions = ["aircraft", "changeUnitsGroup", "repair"]

  getSlotbarParams = @() {
    curSlotIdInCountry = this.idInCountry
    showEmptySlot = true
    needPresetsPanel = false
  }

  createSlotbarHandler = @(params) slotbarWidget.create(params)

  function updateAirList() {
    this.airList = []
    let curPreset = getCurPreset()
    let curCountryGroups =  curPreset?.groupsList[this.getCurCountryName()]
    if (curCountryGroups == null)
      return

    let curUnit = this.getCrewUnit(this.crew)
    let curGroupName = curCountryGroups.groupIdByUnitName?[curUnit?.name] ?? ""

    let sortData = [] // { unit, locname }
    foreach (unit in (curCountryGroups.groups?[curGroupName].units ?? []))
      if (unit.getCrewUnitType() == this.curCrewUnitType) {
        let isCurrent = curUnit?.name == unit.name
        if (isCurrent)
          this.airList.append(unit)
        else {
          sortData.append({
            unit = unit
            locname = utf8ToLower(getUnitName(unit))
          })
        }
      }

    sortData.sort(@(a, b) a.locname <=> b.locname)
    this.airList.extend(sortData.map(@(a) a.unit))
  }

  onSlotDblClick = @(_slotCrew) null
  canUpgradeCrewSpec = @(_upgCrew) false

  function getCrewUnit(slotCrew) {
    let curPreset = getCurPreset()
    return curPreset?.countryPresets[slotCrew.country].units[slotCrew.idInCountry]
  }

  getSlotCrew = @() getSlotItem(this.countryId, this.idInCountry)

  function updateButtons() {
    let isRecrutedCrew = this.crew.id != -1
    this.scene.findObject("btn_apply").show(isRecrutedCrew)
    this.showSceneBtn("not_recrute_crew_warning", !isRecrutedCrew)
    this.showSceneBtn("btn_recruit", !isRecrutedCrew)
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

    let unit = this.getCrewUnit(this.crew)
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
    if (cost > ::zero_money) {
      let msgText = warningIfGold(
        format(loc("shop/needMoneyQuestion_purchaseCrew"),
          cost.getTextAccordingToBalance()),
        cost)
      this.msgBox("need_money", msgText,
        [ ["ok", @() ::g_crew.purchaseNewSlot(country, onTaskSuccess) ],
          ["cancel", @() null ]
        ], "ok")
    }
    else
      onTaskSuccess()
  }

  function onEventPresetsByGroupsChanged(_params) {
    this.openSelectedCrew()
    this.updatePage()
  }
}

gui_handlers.CrewModalByVehiclesGroups <- CrewModalByVehiclesGroups

return {
  open = function(params = {}) {
    if (hasFeature("CrewSkills"))
      handlersManager.loadHandler(CrewModalByVehiclesGroups, params)
    else
      showInfoMsgBox(loc("msgbox/notAvailbleYet"))
  }
}
