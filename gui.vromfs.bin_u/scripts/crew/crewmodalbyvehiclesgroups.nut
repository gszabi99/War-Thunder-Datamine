local { getSlotItem, getCurPreset, setUnit } = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
local slotbarWidget = require("scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")

local class CrewModalByVehiclesGroups extends ::gui_handlers.CrewModalHandler
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
    local curPreset = getCurPreset()
    local curCountryGroups =  curPreset?.groupsList[getCurCountryName()]
    if (curCountryGroups == null)
      return

    local curUnit = getCrewUnit(crew)
    local curGoupName = curCountryGroups.groupIdByUnitName?[curUnit.name] ?? ""

    local sortData = [] // { unit, locname }
    foreach(unit in (curCountryGroups.groups?[curGoupName].units ?? []))
      if (unit.getCrewUnitType() == curCrewUnitType)
      {
        local isCurrent = curUnit.name == unit.name
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
    local curPreset = getCurPreset()
    return curPreset?.countryPresets[slotCrew.country].units[slotCrew.idInCountry]
  }

  getSlotCrew = @() getSlotItem(countryId, idInCountry)

  function updateButtons()
  {
    local isRecrutedCrew = crew.id != -1
    scene.findObject("btn_apply").show(isRecrutedCrew)
    showSceneBtn("not_recrute_crew_warning", !isRecrutedCrew)
    showSceneBtn("btn_recruit", !isRecrutedCrew)
    if (!isRecrutedCrew) {
      local rawCost = ::get_crew_slot_cost(getCurCountryName())
      local cost = rawCost? ::Cost(rawCost.cost, rawCost.costGold) : ::Cost()
      local text = "".concat(::loc("shop/recruitCrew"),
        ::loc("ui/parentheses/space", { text = cost.getTextAccordingToBalance() }))
      ::set_double_text_to_button(scene, "btn_recruit", text)
    }
  }

  function onRecruitCrew()
  {
    local country = getCurCountryName()
    local rawCost = ::get_crew_slot_cost(country)
    local cost = rawCost? ::Cost(rawCost.cost, rawCost.costGold) : ::Cost()
    if (!::check_balance_msgBox(cost))
      return

    local unit = getCrewUnit(crew)
    local onTaskSuccess = ::Callback(function() {
      local crews = ::get_crews_list_by_country(country)
      if (!crews.len())
        return

      local newCrew = crews.top()
      setUnit({
        crew = newCrew
        unit = unit
        showNotification = false
      })
      openSelectedCrew()
      updatePage()
    }, this)
    if (cost > ::zero_money) {
      local msgText = ::warningIfGold(
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
