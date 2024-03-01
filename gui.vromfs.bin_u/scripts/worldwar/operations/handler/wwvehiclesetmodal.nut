from "%scripts/dagui_natives.nut" import get_profile_country, ww_side_val_to_name
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let getLockedCountryData = require("%scripts/worldWar/inOperation/wwGetSlotbarLockedCountryFunc.nut")
let { setCurPreset, getCurPreset, getWarningTextTbl, getBestAvailableUnitByGroup,
  getCurPresetUnitNames } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { getBestPresetData, generatePreset } = require("%scripts/slotbar/generatePreset.nut")
let slotbarWidget = require("%scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let seenWWOperationAvailable = require("%scripts/seen/seenList.nut").get(SEEN.WW_OPERATION_AVAILABLE)
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")

const WW_VEHICLE_SET_OUT_OF_DATE_DAYS = 90

function getAvailableUnits(map, country) {
  let res = {}
  let curPreset = getCurPreset()
  let countryGroups = map.getUnitsGroupsByCountry()?[country]
  let curSlotbarUnits = curPreset?.countryPresets[country].units ?? []
  foreach (unit in curSlotbarUnits) {
    if (!unit)
      continue

    let groupName = countryGroups?.groupIdByUnitName[unit.name] ?? ""
    let curGroup = countryGroups?.groups[groupName]
    let groupUnits = curGroup?.units
    if (groupUnits == null)
      res[unit.name] <- 1
    else {
      let bestAvailableUnit = getBestAvailableUnitByGroup(
        curSlotbarUnits, groupUnits, curPreset.groupsList, country)
      //curGroup cannot be null cause of groupUnits is not null here
      res[(bestAvailableUnit?.unit.name ?? curGroup.defaultUnit.name)] <- 1// warning disable: -access-potentially-nulled
    }
  }

  return res
}

local handlerClass = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/worldWar/wwVehicleSetModal.blk"
  sceneTplTeamStrenght = "%gui/worldWar/wwOperationDescriptionSideStrenght.tpl"
  slotbarActions = [ "aircraft", "sec_weapons", "weapons", "crew", "info", "repair" ]

  map = null

  function initScreen() {
    this.updateWindow()
    seenWWOperationAvailable.markSeen(this.map.getId())
    seenWWOperationAvailable.setDaysToUnseen(WW_VEHICLE_SET_OUT_OF_DATE_DAYS)
  }

  function updateWindow() {
    this.updateTitle()
    this.updateDescription()
    this.updateSlotbar()
    this.updateButtons()
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
      let data = handyman.renderCached(
        this.sceneTplTeamStrenght, this.getUnitsListViewBySide(side, side == SIDE_2))
      this.guiScene.replaceContentFromText(
        this.scene.findObject($"team_{ww_side_val_to_name(side)}_unit_info"),
        data, data.len(), this)
    }
  }

  function getUnitsListViewBySide(side, isInvert) {
    let unitsListView = this.map.getUnitsViewBySide(side)
    return unitsListView.len() == 0 ? {} : {
      sideName = ww_side_val_to_name(side)
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
      availableUnits = getAllUnits()
      customUnitsList = null
      needPresetsPanel = false
      showRepairBox = false
      showEmptySlot = true
      showNewSlot = true
      shouldCheckCrewsReady = true
      hasExtraInfoBlock = true
      customUnitsListName = this.map.getNameText()
      getLockedCountryData
      onCountryChanged = @() broadcastEvent(
        "PresetsByGroupsCountryChanged", {unitNames = getCurPresetUnitNames()})
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

  function onRunAutoPreset(_obj) {
    let cb = Callback(this.generateAutoPreset, this)
    ::queues.checkAndStart(
      Callback(function() {
        checkSquadUnreadyAndDo(cb, @() null, true)
      }, this),
      @() null,
      "isCanModifyCrew"
    )
  }

  function generateAutoPreset() {
    let country = get_profile_country()
    generatePreset(getAvailableUnits(this.map, country), country, true)
  }

  function updateButtons() {
    let country = get_profile_country()
    let availableUnits = getAvailableUnits(this.map, country)
    let wData = getWarningTextTbl(
      availableUnits, getCurPreset().countryPresets?[country].units, true)
    let isVisibleBtnAutoPreset = wData.needMsgBox
    let btnAutoPreset = showObjById("btn_auto_preset", isVisibleBtnAutoPreset, this.scene)
    if (isVisibleBtnAutoPreset) {
      let bestPresetData = getBestPresetData(availableUnits, country, true)
      let hasChangeInPreset = bestPresetData?.hasChangeInPreset ?? false
      btnAutoPreset.inactiveColor = hasChangeInPreset ? "no" : "yes"
      btnAutoPreset.hasUnseenIcon = hasChangeInPreset ? "yes" : "no"
      showObjById("auto_preset_warning_icon", hasChangeInPreset, btnAutoPreset)
    }
    let warningTextObj = showObjById("cant_join_reason_txt", wData.warningText != "", this.scene)
    warningTextObj.setValue(wData.warningText)

    let warningIconObj = showObjById("warning_icon", wData.fullWarningText != "", this.scene)
    warningIconObj.tooltip = wData.fullWarningText
  }

  function onEventWWGlobalStatusChanged(p) {
    if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.MAPS)
      this.updateWindow()
  }

  function onEventPresetsByGroupsChanged(_) {
    this.updateButtons()
  }

  function onEventCrewTakeUnit(_) {
    this.updateButtons()
  }

  function onEventSlotbarPresetLoaded(_) {
    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.updateButtons()
    })
  }

}

gui_handlers.wwVehicleSetModal <- handlerClass

return {
  open = @(p) handlersManager.loadHandler(handlerClass, p)
}
