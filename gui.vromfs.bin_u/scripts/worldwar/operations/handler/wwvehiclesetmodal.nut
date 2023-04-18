//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let getLockedCountryData = require("%scripts/worldWar/inOperation/wwGetSlotbarLockedCountryFunc.nut")
let { setCurPreset } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let slotbarWidget = require("%scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let seenWWOperationAvailable = require("%scripts/seen/seenList.nut").get(SEEN.WW_OPERATION_AVAILABLE)

const WW_VEHICLE_SET_OUT_OF_DATE_DAYS = 90

local handlerClass = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/worldWar/wwVehicleSetModal.blk"
  sceneTplTeamStrenght = "%gui/worldWar/wwOperationDescriptionSideStrenght.tpl"
  slotbarActions = [ "aircraft", "sec_weapons", "weapons", "crew", "info", "repair" ]

  map = null
  descHandlerWeak = null

  function initScreen() {
    this.updateWindow()
    seenWWOperationAvailable.markSeen(this.map.getId())
    seenWWOperationAvailable.setDaysToUnseen(WW_VEHICLE_SET_OUT_OF_DATE_DAYS)
  }

  function updateWindow() {
    this.updateTitle()
    this.updateDescription()
    this.updateSlotbar()
  }

  function updateTitle() {
    let ttlObj = this.scene.findObject("wnd_title")
    if (checkObj(ttlObj))
      ttlObj.setValue(this.map.getNameText())
  }

  function updateDescription() {
    let operationBgObj = this.scene.findObject("operation_background")
    if (checkObj(operationBgObj))
      operationBgObj["background-image"] = this.map.getBackground()
    ::g_world_war.updateConfigurableValues()
    this.updateTeamsInfo()
  }

  function updateTeamsInfo() {
    foreach (side in ::g_world_war.getCommonSidesOrder()) {
      let data = ::handyman.renderCached(
        this.sceneTplTeamStrenght, this.getUnitsListViewBySide(side, side == SIDE_2))
      this.guiScene.replaceContentFromText(
        this.scene.findObject($"team_{::ww_side_val_to_name(side)}_unit_info"),
        data, data.len(), this)
    }
  }

  function getUnitsListViewBySide(side, isInvert) {
    let unitsListView = this.map.getUnitsViewBySide(side)
    return unitsListView.len() == 0 ? {} : {
      sideName = ::ww_side_val_to_name(side)
      unitString = unitsListView
      invert = isInvert
    }
  }

  createSlotbarHandler = @(params) slotbarWidget.create(params)

  function updateSlotbar() {
    let countriesToShow = []
    foreach(idx, _ in this.map.getCountryToSideTbl())
      countriesToShow.append(idx)

    setCurPreset(this.map.getId(), this.map?.getUnitsGroupsByCountry())
    this.createSlotbar({
      countriesToShow
      availableUnits = ::all_units
      customUnitsList = null
      needPresetsPanel = false
      showRepairBox = false
      showEmptySlot = true
      showNewSlot = true
      shouldCheckCrewsReady = true
      hasExtraInfoBlock = true
      customUnitsListName = this.map.getNameText()
      getLockedCountryData
    },"nav-slotbar")
  }

  function onUnitClick(unitObj) {
    unitContextMenuState({
      unitObj = unitObj
      actionsNames = this.getSlotbarActions()
      curEdiff = ::g_world_war.defaultDiffCode
      isSlotbarEnabled = false
    }.__update(this.getUnitParamsFromObj(unitObj)))
  }

  function onEventWWGlobalStatusChanged(p) {
    if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.MAPS)
      this.updateWindow()
  }
}

::gui_handlers.wwVehicleSetModal <- handlerClass

return {
  open = @(p) ::handlersManager.loadHandler(handlerClass, p)
}
