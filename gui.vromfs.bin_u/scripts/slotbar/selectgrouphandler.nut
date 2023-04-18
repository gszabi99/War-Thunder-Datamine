//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { getGroupUnitMarkUp } = require("%scripts/unit/groupUnit.nut")
let { getParamsFromSlotbarConfig } = require("%scripts/slotbar/selectUnitHandler.nut")

let class SelectGroupHandler extends ::gui_handlers.SelectUnitHandler {
  function getSortedGroupsArray() {
    let selectedGroup = this.getSelectedGroup()
    local groupsArray = this.config.unitsGroupsByCountry?[this.country].groups.values() ?? []

    let curPreset = slotbarPresets.getCurPreset()
    let curCountryPreset = curPreset.countryPresets?[this.country]
    let countryGroupsList = curPreset.groupsList?[this.country]
    let groupIdByUnitName = countryGroupsList?.groupIdByUnitName

    groupsArray = groupsArray.map(function(group) {
      group.isCurrent <- selectedGroup?.id == group.id
      group.currentUnit <- curCountryPreset?.units.findvalue(
        @(v) groupIdByUnitName?[v?.name ?? ""] == group.id)
      return group
    })
    groupsArray.sort(@(a, b) b.isCurrent <=> a.isCurrent || a.id <=> b.id)
    return groupsArray
  }

  function initAvailableUnitsArray() {
    this.unitsList = this.getSortedGroupsArray()
    this.unitsList.append(SEL_UNIT_BUTTON.SHOW_MORE)
    return false //for needEmptyCrewButton parameter
  }

  function trainSlotAircraft(unit) {
    slotbarPresets.setGroup({
      crew = this.crew
      group = unit
      onFinishCb = Callback(this.onTakeProcessFinish, this)
    })
  }

  function showUnitSlot(objSlot, group, isVisible) {
    objSlot.show(isVisible)
    objSlot.inactive = isVisible ? "no" : "yes"
    if (!isVisible || objSlot.childrenCount())
      return

    let countryGroupsList = slotbarPresets.getCurPreset().groupsList?[this.country]
    let unit = this.getSlotUnit(group)
    let isEnabled = ::is_unit_enabled_for_slotbar(unit, this.config)
    let unitItemParams = {
      status = !isEnabled ? "disabled" : "mounted"
      fullBlock = false
      nameLoc = ::getUnitName(unit.name)
      bottomLineText = loc(
        slotbarPresets.getVehiclesGroupByUnit(unit, countryGroupsList)?.name ?? "")
    }

    let markup = getGroupUnitMarkUp(unit.name, unit, group, unitItemParams)
    this.guiScene.replaceContentFromText(objSlot, markup, markup.len(), this)
  }

  hasChangeVehicle = @(group) group?.id !=
    this.config.unitsGroupsByCountry?[this.country].groupIdByUnitName?[this.getCrewUnit()?.name ?? ""]

  getSlotUnit = @(slot) slot?.currentUnit ?? slot?.defaultUnit ?? slot
  getFilterOptionsList = @() [ ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE ]
  updateUnitsGroupText = @(_unit = null) null
  fillLegendData = @() null
  hasGroupText = @() false
}

::gui_handlers.SelectGroupHandler <- SelectGroupHandler

return {
  open = function(crew, slotbar) {
    let params = getParamsFromSlotbarConfig(crew, slotbar)
    if (params == null)
      return ::broadcastEvent("ModalWndDestroy")

    ::handlersManager.destroyPrevHandlerAndLoadNew(SelectGroupHandler, params)
  }
}
