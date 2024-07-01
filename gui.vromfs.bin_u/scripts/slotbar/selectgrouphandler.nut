from "%scripts/dagui_library.nut" import *
from "%scripts/slotbar/slotbarConsts.nut" import SEL_UNIT_BUTTON

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getGroupUnitMarkUp } = require("%scripts/unit/groupUnit.nut")
let { getParamsFromSlotbarConfig } = require("%scripts/slotbar/selectUnitHandler.nut")
let { USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE
} = require("%scripts/options/optionsExtNames.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { isUnitEnabledForSlotbar } = require("%scripts/slotbar/slotbarView.nut")

let class SelectGroupHandler (gui_handlers.SelectUnitHandler) {
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
    let isEnabled = isUnitEnabledForSlotbar(unit, this.config)
    let unitItemParams = {
      status = !isEnabled ? "disabled" : "mounted"
      fullBlock = false
      nameLoc = getUnitName(unit.name)
      bottomLineText = loc(
        slotbarPresets.getVehiclesGroupByUnit(unit, countryGroupsList)?.name ?? "")
    }

    let markup = getGroupUnitMarkUp(unit.name, unit, group, unitItemParams)
    this.guiScene.replaceContentFromText(objSlot, markup, markup.len(), this)
  }

  hasChangeVehicle = @(group) group?.id !=
    this.config.unitsGroupsByCountry?[this.country].groupIdByUnitName?[this.getCrewUnit()?.name ?? ""]

  getSlotUnit = @(slot) slot?.currentUnit ?? slot?.defaultUnit ?? slot
  getFilterOptionsList = @() [ USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE ]
  updateUnitsGroupText = @(_unit = null) null
  fillLegendData = @() null
  hasGroupText = @() false
}

gui_handlers.SelectGroupHandler <- SelectGroupHandler

return {
  open = function(crew, slotbar) {
    let params = getParamsFromSlotbarConfig(crew, slotbar)
    if (params == null)
      return broadcastEvent("ModalWndDestroy")

    handlersManager.destroyPrevHandlerAndLoadNew(SelectGroupHandler, params)
  }
}
