local slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
local { getGroupUnitMarkUp } = require("scripts/unit/groupUnit.nut")
local { getParamsFromSlotbarConfig } = require("scripts/slotbar/selectUnitHandler.nut")

local class SelectGroupHandler extends ::gui_handlers.SelectUnitHandler
{
  function getSortedGroupsArray()
  {
    local selectedGroup = getSelectedGroup()
    local groupsArray = config.unitsGroupsByCountry?[country].groups.values() ?? []

    local curPreset = slotbarPresets.getCurPreset()
    local curCountryPreset = curPreset.countryPresets?[country]
    local countryGroupsList = curPreset.groupsList?[country]
    local groupIdByUnitName = countryGroupsList?.groupIdByUnitName

    groupsArray = groupsArray.map(function(group) {
      group.isCurrent <- selectedGroup?.id == group.id
      group.currentUnit <- curCountryPreset?.units.findvalue(
        @(v) groupIdByUnitName?[v?.name ?? ""] == group.id)
      return group
    })
    groupsArray.sort(@(a, b) b.isCurrent <=> a.isCurrent || a.id <=> b.id)
    return groupsArray
  }

  function initAvailableUnitsArray()
  {
    unitsList = getSortedGroupsArray()
    unitsList.append(SEL_UNIT_BUTTON.SHOW_MORE)
    return false //for needEmptyCrewButton parameter
  }

  function trainSlotAircraft(unit)
  {
    slotbarPresets.setGroup({
      crew = crew
      group = unit
      onFinishCb = ::Callback(onTakeProcessFinish, this)
    })
  }

  function showUnitSlot(objSlot, group, isVisible)
  {
    objSlot.show(isVisible)
    objSlot.inactive = isVisible ? "no" : "yes"
    if (!isVisible || objSlot.childrenCount())
      return

    local countryGroupsList = slotbarPresets.getCurPreset().groupsList?[country]
    local unit = getSlotUnit(group)
    local isEnabled = ::is_unit_enabled_for_slotbar(unit, config)
    local unitItemParams = {
      status = !isEnabled ? "disabled" : "mounted"
      fullBlock = false
      nameLoc = ::getUnitName(unit.name)
      bottomLineText = ::loc(
        slotbarPresets.getVehiclesGroupByUnit(unit, countryGroupsList)?.name ?? "")
    }

    local markup = getGroupUnitMarkUp(unit.name, unit, group, unitItemParams)
    guiScene.replaceContentFromText(objSlot, markup, markup.len(), this)
  }

  hasChangeVehicle = @(group) group?.id !=
    config.unitsGroupsByCountry?[country].groupIdByUnitName?[getCrewUnit()?.name ?? ""]

  getSlotUnit = @(slot) slot?.currentUnit ?? slot?.defaultUnit ?? slot
  getFilterOptionsList = @() [ ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE ]
  updateUnitsGroupText = @(unit = null) null
  fillLegendData = @() null
  hasGroupText = @() false
}

::gui_handlers.SelectGroupHandler <- SelectGroupHandler

return {
  open = function(crew, slotbar) {
    local params = getParamsFromSlotbarConfig(crew, slotbar)
    if (params == null)
      return

    ::handlersManager.destroyPrevHandlerAndLoadNew(SelectGroupHandler, params)
  }
}
