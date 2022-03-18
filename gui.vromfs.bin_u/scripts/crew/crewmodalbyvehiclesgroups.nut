let { getSlotItem, getCurPreset, setUnit } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let slotbarWidget = require("%scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")

let class CrewModalByVehiclesGroups extends ::gui_handlers.CrewModalHandler
{
  slotbarActions = ["aircraft", "changeUnitsGroup", "repair"]

  getSlotbarParams = @() {
    curSlotIdInCountry = idInCountry
    showEmptySlot = true
    needPresetsPanel = false
  }

  createSlotbarHandler = @(params) slotbarWidget.create(params)

  function updateAirList()
  {
    airList = []
    let curPreset = getCurPreset()
    let curCountryGroups =  curPreset?.groupsList[getCurCountryName()]
    if (curCountryGroups == null)
      return

    let curUnit = getCrewUnit(crew)
    let curGroupName = curCountryGroups.groupIdByUnitName?[curUnit?.name] ?? ""

    let sortData = [] // { unit, locname }
    foreach(unit in (curCountryGroups.groups?[curGroupName].units ?? []))
      if (unit.getCrewUnitType() == curCrewUnitType)
      {
        let isCurrent = curUnit?.name == unit.name
        if (isCurrent)
          airList.append(unit)
        else
        {
          sortData.append({
            unit = unit
            locname = ::g_string.utf8ToLower(::getUnitName(unit))
          })
        }
      }

    sortData.sort(@(a,b) a.locname <=> b.locname)
    airList.extend(sortData.map(@(a) a.unit))
  }

  onSlotDblClick = @(slotCrew) null
  canUpgradeCrewSpec = @(upgCrew) false

  function getCrewUnit(slotCrew)
  {
    let curPreset = getCurPreset()
    return curPreset?.countryPresets[slotCrew.country].units[slotCrew.idInCountry]
  }

  getSlotCrew = @() getSlotItem(countryId, idInCountry)

  function updateButtons()
  {
    let isRecrutedCrew = crew.id != -1
    scene.findObject("btn_apply").show(isRecrutedCrew)
    showSceneBtn("not_recrute_crew_warning", !isRecrutedCrew)
    showSceneBtn("btn_recruit", !isRecrutedCrew)
    if (!isRecrutedCrew) {
      let rawCost = ::get_crew_slot_cost(getCurCountryName())
      let cost = rawCost? ::Cost(rawCost.cost, rawCost.costGold) : ::Cost()
      let text = "".concat(::loc("shop/recruitCrew"),
        ::loc("ui/parentheses/space", { text = cost.getTextAccordingToBalance() }))
      setColoredDoubleTextToButton(scene, "btn_recruit", text)
    }
  }

  function onRecruitCrew()
  {
    let country = getCurCountryName()
    let rawCost = ::get_crew_slot_cost(country)
    let cost = rawCost? ::Cost(rawCost.cost, rawCost.costGold) : ::Cost()
    if (!::check_balance_msgBox(cost))
      return

    let unit = getCrewUnit(crew)
    let onTaskSuccess = ::Callback(function() {
      let crews = ::get_crews_list_by_country(country)
      if (!crews.len())
        return

      let newCrew = crews.top()
      setUnit({
        crew = newCrew
        unit = unit
        showNotification = false
      })
      openSelectedCrew()
      updatePage()
    }, this)
    if (cost > ::zero_money) {
      let msgText = ::warningIfGold(
        format(::loc("shop/needMoneyQuestion_purchaseCrew"),
          cost.getTextAccordingToBalance()),
        cost)
      msgBox("need_money", msgText,
        [ ["ok", @() ::g_crew.purchaseNewSlot(country, onTaskSuccess) ],
          ["cancel", @() null ]
        ], "ok")
    }
    else
      onTaskSuccess()
  }

  function onEventPresetsByGroupsChanged(params)
  {
    openSelectedCrew()
    updatePage()
  }
}

::gui_handlers.CrewModalByVehiclesGroups <- CrewModalByVehiclesGroups

return {
  open = function(params = {}) {
    if (::has_feature("CrewSkills"))
      ::handlersManager.loadHandler(CrewModalByVehiclesGroups, params)
    else
      ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))
  }
}
