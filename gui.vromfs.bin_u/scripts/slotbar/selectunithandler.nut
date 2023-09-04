//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { toPixels } = require("%sqDagui/daguiUtil.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { CrewTakeUnitProcess } = require("%scripts/crew/crewTakeUnitProcess.nut")
let { canAssignInSlot, setUnit } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { startsWith } = require("%sqstd/string.nut")
let { hasDefaultUnitsInCountry } = require("%scripts/shop/shopUnitsInfo.nut")

global enum SEL_UNIT_BUTTON {
  EMPTY_CREW
  SHOP
  SHOW_MORE
}

let defaultFilterOptions = [
  ::USEROPT_BIT_CHOOSE_UNITS_TYPE,
  ::USEROPT_BIT_CHOOSE_UNITS_RANK,
  ::USEROPT_BIT_CHOOSE_UNITS_OTHER,
  ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE,
  ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST
]

let getOptionsMaskForUnit = {
  [::USEROPT_BIT_CHOOSE_UNITS_TYPE] = @(unit, _crew, _config) 1 << unit.esUnitType,
  [::USEROPT_BIT_CHOOSE_UNITS_RANK] = @(unit, _crew, _config) 1 << (unit.rank - 1),
  [::USEROPT_BIT_CHOOSE_UNITS_OTHER] =
    @(unit, crew, _config) (unit.name in (crew?.trainedSpec ?? {}) ? 0 : unit.trainCost) ? 2 : 1,
  [::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE] =
    @(unit, _crew, config) ::is_unit_enabled_for_slotbar(unit, config) ? 2 : 1,
  [::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST] =
    @(unit, _crew, config) ::isUnitInCustomList(unit, config) ? 2 : 1
}

const MIN_NON_EMPTY_SLOTS_IN_COUNTRY = 1

let function getParamsFromSlotbarConfig(crew, slotbar) {
  if (!::SessionLobby.canChangeCrewUnits())
    return null
  if (!CrewTakeUnitProcess.safeInterrupt())
    return null

  let slotbarObj = slotbar.scene
  let slotObj = ::get_slot_obj(slotbarObj, crew.idCountry, crew.idInCountry)
  if (!checkObj(slotObj))
    return null

  let isSelectByGroups = slotbar?.unitsGroupsByCountry != null
  let country = crew.country

  local busyUnitsCount = 0
  local unitsArray = []
  if (!isSelectByGroups) {
    let crewUnitId = ::g_crew.getCrewUnit(crew)?.name ?? ""
    let busyUnits = ::get_crews_list_by_country(country)
      .map(@(cc) cc?.aircraft ?? "").filter(@(id) id != "" && id != crewUnitId)
    busyUnitsCount = busyUnits.len()
    unitsArray = ::all_units.filter(@(unit) busyUnits.indexof(unit.name) == null
      && unit.canAssignToCrew(country)).values()
  }
  else {
    let unitsGroups = slotbar.unitsGroupsByCountry?[country]
    let crewUnit = slotbar?.countryPresets[country].units[crew.idInCountry]
    let selectedGroupName = unitsGroups?.groupIdByUnitName[crewUnit?.name] ?? ""
    unitsArray = unitsGroups?.groups[selectedGroupName].units.values() ?? []
  }
  if (unitsArray.len() == 0)
    return null

  return {
    countryId = crew.idCountry,
    idInCountry = crew.idInCountry,
    config = slotbar,
    slotObj = slotObj,
    slotbarWeak = slotbar,
    crew = crew
    isSelectByGroups
    busyUnitsCount
    unitsArray
  }
}

local class SelectUnitHandler extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/slotbar/slotbarChooseAircraft.blk"
  slotbarWeak = null

  countryId = -1
  idInCountry = -1
  crew = null

  config = null //same as slotbarParams in BaseGuiHandlerWT
  slotObj = null
  curClonObj = null

  unitsArray = null // array of units
  unitsList = null  // array of menu items
  busyUnitsCount = 0

  wasReinited = false

  filterOptionsList = null

  curOptionsMasks = null //[]
  optionsMaskByUnits = null //{}
  isEmptyOptionsList = true
  legendData = null //[]

  slotsPerPage = 9 //check css
  firstPageSlots = 20
  curVisibleSlots = 0

  showMoreObj = null
  country = ""

  isSelectByGroups = false

  function initScreen() {
    this.country = ::g_crews_list.get()[this.countryId].country
    this.curOptionsMasks = []
    this.filterOptionsList = this.getFilterOptionsList()
    this.optionsMaskByUnits = {}
    this.legendData = []
    if (this.slotbarWeak)
      this.slotbarWeak = this.slotbarWeak.weakref() //we are miss weakref on assigning from params table

    this.guiScene.applyPendingChanges(false) //to apply slotbar scroll before calculating positions

    let tdObj = this.slotObj.getParent()
    let tdPos = tdObj.getPosRC()

    ::gui_handlers.ActionsList.removeActionsListFromObject(tdObj)

    let tdClone = tdObj.getClone(this.scene, this.slotbarWeak)
    tdClone.pos = tdPos[0] + ", " + tdPos[1]
    tdClone["class"] = "slotbarClone"
    this.curClonObj = tdClone

    // When menu opens on switching to country, slots are invisible due to animation
    if ((tdClone?["color-factor"] ?? "255") != "255")
      ::gui_bhv_deprecated.massTransparency.setTranspRecursive(tdClone, 255)

    let curUnitCloneObj = ::get_slot_obj(tdClone, this.countryId, this.idInCountry)
    ::fill_unit_item_timers(curUnitCloneObj, this.getCrewUnit())
    ::gui_handlers.ActionsList.switchActionsListVisibility(curUnitCloneObj)

    this.scene.findObject("tablePlace").pos = tdPos[0] + ", " + tdPos[1]

    let needEmptyCrewButton = this.initAvailableUnitsArray()

    this.curVisibleSlots = this.firstPageSlots

    this.showSceneBtn("btn_emptyCrew", needEmptyCrewButton)

    this.updateUnitsGroupText()
    this.initChooseUnitsOptions()
    this.fillChooseUnitsOptions()
    this.fillLegendData()
    this.fillLegend()
    this.fillUnitsList()
    this.updateUnitsList()
    ::move_mouse_on_obj(curUnitCloneObj)
    this.updateOptionShowUnsupportedForCustomList()
    this.showSceneBtn("choose_popup_menu", !this.isEmptyOptionsList || (needEmptyCrewButton && ::show_console_buttons) || this.hasGroupText())
  }

  function reinitScreen(params = {}) {
    if (checkObj(this.curClonObj))
      this.curClonObj.getScene().destroyElement(this.curClonObj)
    this.setParams(params)
    this.initScreen()
    this.wasReinited = true
  }

  function fillLegendData() {
    this.legendData.clear()
    foreach (specType in ::g_crew_spec_type.types)
      if (specType != ::g_crew_spec_type.UNKNOWN)
        this.addLegendData(specType.specName, specType.trainedIcon, loc("crew/trained") + loc("ui/colon") + specType.getName())
    this.addLegendData("warningIcon", "#ui/gameuiskin#new_icon.svg", "#mainmenu/selectCrew/haveMoreQualified/tooltip")
  }

  function fillLegend() {
    let haveLegend = !this.isEmptyOptionsList && this.legendData.len() > 0
    let legendNest = this.showSceneBtn("legend_nest", haveLegend)
    if (!haveLegend)
      return

    let legendView = {
      header = loc("mainmenu/legend")
      haveLegend = this.legendData.len() > 0,
      legendData = this.legendData
    }
    let markup = handyman.renderCached("%gui/slotbar/legend_block.tpl", legendView)
    this.guiScene.replaceContentFromText(legendNest, markup, markup.len(), this)
  }

  function initAvailableUnitsArray() {
    this.unitsArray = this.sortUnitsList(this.unitsArray)

    this.unitsList = []
    if (this.slotbarWeak?.ownerWeak?.canShowShop && this.slotbarWeak.ownerWeak.canShowShop())
      this.unitsList.append(SEL_UNIT_BUTTON.SHOP)
    let needEmptyCrewButton = !this.isSelectByGroups && ((this.crew?.aircraft ?? "") != "")
      && (!hasDefaultUnitsInCountry(this.country) || this.busyUnitsCount >= MIN_NON_EMPTY_SLOTS_IN_COUNTRY)
    if (needEmptyCrewButton)
      this.unitsList.append(SEL_UNIT_BUTTON.EMPTY_CREW)
    this.unitsList.extend(this.unitsArray)
    this.unitsList.append(SEL_UNIT_BUTTON.SHOW_MORE)

    return needEmptyCrewButton
  }

  function sortUnitsList(units) {
    let ediff = this.getCurrentEdiff()
    let trained = getTblValue("trainedSpec", this.crew, {})
    let getSortSpecialization = @(unit) unit.name in trained ? trained[unit.name]
                                          : unit.trainCost ? -1
                                          : 0
    let selectedUnit = this.getCrewUnit()
    let groupIdByUnitName = this.config?.unitsGroupsByCountry[this.country].groupIdByUnitName
    let unitsSortArr = units.map(@(unit)
      {
        isCurrent = unit == selectedUnit
        groupId = groupIdByUnitName?[unit.name] ?? ""
        economicRank = unit.getEconomicRank(ediff)
        isDefaultAircraft = ::is_default_aircraft(unit.name)
        sortSpecialization = getSortSpecialization(unit)
        unit = unit
      }
    )

    unitsSortArr.sort(@(a, b)
         b.isCurrent <=> a.isCurrent
      || a.groupId <=> b.groupId
      || a.economicRank <=> b.economicRank
      || b.isDefaultAircraft <=> a.isDefaultAircraft
      || a.sortSpecialization <=> b.sortSpecialization
      || a.unit.rank <=> b.unit.rank
      || a.unit.name <=> b.unit.name
    )

    return unitsSortArr.map(@(unit) unit.unit)
  }

  function addLegendData(id, imagePath, locId) {
    foreach (data in this.legendData)
      if (id == data.id)
        return

    this.legendData.append({
      id = id,
      imagePath = imagePath,
      locId = locId
    })
  }

  function haveMoreQualifiedCrew(unit) {
    let bestIdx = ::g_crew.getBestTrainedCrewIdxForUnit(unit, false, this.crew)
    return bestIdx >= 0 && bestIdx != this.crew.idInCountry
  }

  getTextSlotMarkup = @(id, text) ::build_aircraft_item(id, null, { emptyText = text })

  function fillUnitsList() {
    let markupArr = []
    foreach (_idx, unit in this.unitsList) {
      local rowData = ""
      if (!u.isInteger(unit))
        rowData = "unitCell {}"
      else if (unit == SEL_UNIT_BUTTON.SHOP)
        rowData = this.getTextSlotMarkup("shop_item", "#mainmenu/btnShop")
      else if (unit == SEL_UNIT_BUTTON.EMPTY_CREW)
        rowData = this.getTextSlotMarkup("empty_air", "#shop/emptyCrew")
      else if (unit == SEL_UNIT_BUTTON.SHOW_MORE)
        rowData = this.getTextSlotMarkup("show_more", "#mainmenu/showMore")
      markupArr.append(rowData)
    }

    let markup = "\n".join(markupArr)
    let tblObj = this.scene.findObject("airs_table")
    tblObj.alwaysShowBorder = "yes"
    this.guiScene.replaceContentFromText(tblObj, markup, markup.len(), this)

    this.showMoreObj = tblObj.findObject("td_show_more")
  }

  function onEmptyCrew() {
    this.trainSlotAircraft(null)
  }

  function onDoneSlotChoose(obj) {
    let row = obj.getValue()
    if (row < 0)
      return

    let unit = this.unitsList[row]
    if (unit == SEL_UNIT_BUTTON.SHOP)
      return this.goToShop()
    if (unit == SEL_UNIT_BUTTON.EMPTY_CREW)
      return this.trainSlotAircraft(null) //empty slot
    if (unit == SEL_UNIT_BUTTON.SHOW_MORE) {
      this.curVisibleSlots += this.slotsPerPage - 1 //need to all new slots be visible and current button also
      this.updateUnitsList()
      return
    }

    if (this.isSelectByGroups && u.isUnit(unit) && !canAssignInSlot(unit, this.config.unitsGroupsByCountry, this.country))
      return

    if (!this.hasChangeVehicle(unit))
      return this.goBack()

    if (!this.isSelectByGroups && this.haveMoreQualifiedCrew(unit))
      return ::gui_start_selecting_crew({
          unit = unit,
          unitObj = this.scene.findObject(unit.name),
          takeCrewIdInCountry = this.crew.idInCountry,
          messageText = loc("mainmenu/selectCrew/haveMoreQualified"),
          afterSuccessFunc = Callback(this.goBack, this)
          isSelectByGroups = this.isSelectByGroups
        })

    this.trainSlotAircraft(unit)
  }

  function goToShop() {
    this.goBack()
    if (this.slotbarWeak?.ownerWeak?.openShop) {
      let unit = this.getCrewUnit()
      this.slotbarWeak.ownerWeak.openShop(unit?.unitType)
    }
  }

  function trainSlotAircraft(unit) {
    let onFinishCb = Callback(this.onTakeProcessFinish, this)
    if (this.isSelectByGroups)
      setUnit({
        crew = this.crew
        unit = unit
        onFinishCb = onFinishCb
      })
    else
      CrewTakeUnitProcess(this.crew, unit, onFinishCb)
  }

  function onTakeProcessFinish(_isSuccess) {
    this.goBack()
  }

  function initChooseUnitsOptions() {
    this.curOptionsMasks.clear()
    this.optionsMaskByUnits.clear()

    foreach (slot in this.unitsList) {
      let unit = this.getSlotUnit(slot)
      if (!u.isUnit(unit))
        continue

      let masks = []
      foreach (userOpt in this.filterOptionsList)
        masks.append(getOptionsMaskForUnit[userOpt](unit, this.crew, this.config))

      this.optionsMaskByUnits[unit.name] <- masks
      for (local i = 0; i < masks.len(); i++)
        if (this.curOptionsMasks.len() > i)
          this.curOptionsMasks[i] = this.curOptionsMasks[i] | masks[i]
        else
          this.curOptionsMasks.append(masks[i])
    }
  }

  function fillChooseUnitsOptions() {
    let locParams = {
      gameModeName = colorize("hotkeyColor", this.getGameModeNameFromParams(this.config))
      customListName = colorize("hotkeyColor", this.getCustomListNameFromParams(this.config))
    }

    let objOptionsNest = this.scene.findObject("choose_options_nest")
    if (!checkObj(objOptionsNest))
      return

    this.isEmptyOptionsList = true
    let view = { rows = [] }
    foreach (idx, userOpt in this.filterOptionsList) {
      let maskOption = ::get_option(userOpt)
      let singleOption = getTblValue("singleOption", maskOption, false)
      if (singleOption) {
        // All bits but first are set to 1.
        maskOption.value = maskOption.value | ~1
        ::set_option(userOpt, maskOption.value)
      }
      let maskStorage = getTblValue(idx, this.curOptionsMasks, 0)
      if ((maskOption.value & maskStorage) == 0) {
        maskOption.value = maskStorage
        ::set_option(userOpt, maskOption.value)
      }
      let hideTitle = getTblValue("hideTitle", maskOption, false)
      let row = {
        option_title = hideTitle ? "" : loc(maskOption.hint)
        option_id = maskOption.id
        option_idx = idx
        option_uid = userOpt
        option_value = maskOption.value
        nums = []
      }
      row.cb <- maskOption?.cb

      local countVisibleOptions = 0
      foreach (idxItem, text in maskOption.items) {
        let optionVisible = ((1 << idxItem) & maskStorage) != 0
        if (optionVisible)
          countVisibleOptions++
        local name = text
        if (startsWith(name, "#"))
          name = name.slice(1)
        name = loc(name, locParams)
        row.nums.append({
          option_name = name,
          visible = optionVisible && (!singleOption || idxItem == 0)
        })
      }
      if (countVisibleOptions > 1 || singleOption)
        view.rows.append(row)
      if (countVisibleOptions > 1)
        this.isEmptyOptionsList = false
    }

    let markup = handyman.renderCached(("%gui/slotbar/choose_units_filter.tpl"), view)
    this.guiScene.replaceContentFromText(objOptionsNest, markup, markup.len(), this)

    objOptionsNest.show(!this.isEmptyOptionsList)
    this.showSceneBtn("choose_options_header", !this.isEmptyOptionsList)
    this.showSceneBtn("filtered_units_text", !this.isEmptyOptionsList)
    let objChoosePopupMenu = this.scene.findObject("choose_popup_menu")
    if (!checkObj(objChoosePopupMenu))
      return

    this.guiScene.setUpdatesEnabled(true, true)

    let sizeChoosePopupMenu = objChoosePopupMenu.getSize()
    let scrWidth = toPixels(this.guiScene, "@bw + @rw")
    objChoosePopupMenu.side = ((objChoosePopupMenu.getPosRC()[0] + sizeChoosePopupMenu[0]) > scrWidth) ? "left" : "right"
  }

  function getGameModeNameFromParams(params) {
    //same order as in is_unit_enabled_for_slotbar
    local event = ::events.getEvent(params?.eventId)
    if (!event && params?.roomCreationContext)
      event = params.roomCreationContext.mGameMode
    if (event)
      return ::events.getEventNameText(event)

    if ((params?.gameModeName ?? "") != "")
      return params.gameModeName

    if (::SessionLobby.isInRoom())
      return ::SessionLobby.getMissionNameLoc()

    return getTblValue("text", ::game_mode_manager.getCurrentGameMode(), "")
  }

  function getCustomListNameFromParams(params) {
    return params?.customUnitsListName ?? ""
  }

  function getCurrentEdiff() {
    if (this.config?.getEdiffFunc)
      return this.config.getEdiffFunc()
    if (this.slotbarWeak)
      return this.slotbarWeak.getCurrentEdiff()
    return ::get_current_ediff()
  }

  function onSelectedOptionChooseUnsapportedUnit(obj) {
    this.onSelectedOptionChooseUnit(obj)
    this.updateOptionShowUnsupportedForCustomList()
  }

  function onSelectedOptionChooseUnit(obj) {
    if (!checkObj(obj) || !obj?.idx)
      return

    let maskOptions = getTblValue(obj.idx.tointeger(), this.curOptionsMasks, null)
    if (!maskOptions)
      return

    let oldOption = ::get_option((obj.uid).tointeger())
    let value = (oldOption.value.tointeger() & (~maskOptions)) | (obj.getValue() & maskOptions)
    ::set_option((obj.uid).tointeger(), value)
    this.curVisibleSlots = this.firstPageSlots
    this.updateUnitsList()
  }

  function updateOptionShowUnsupportedForCustomList() {
    let modeOption = ::get_option(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE)
    let customOption = ::get_option(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST)

    let customOptionObj = this.scene.findObject(customOption.id)
    if (!checkObj(customOptionObj))
      return

    let isModeOptionChecked = modeOption.value & 1
    if (!isModeOptionChecked) {
      let idx = this.filterOptionsList.indexof(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE)
      let maskOptions = this.curOptionsMasks?[idx]
      if (maskOptions)
        customOptionObj.setValue(modeOption.value - (modeOption.value & (~maskOptions)))
    }
    customOptionObj.show(isModeOptionChecked)
  }

  function showUnitSlot(objSlot, unit, isVisible) {
    objSlot.show(isVisible)
    objSlot.inactive = isVisible ? "no" : "yes"
    if (!isVisible || objSlot.childrenCount())
      return

    let isTrained = (unit.name in this.crew?.trainedSpec) || unit.trainCost == 0
    let isEnabled = ::is_unit_enabled_for_slotbar(unit, this.config)
    let isLockedUnit = this.isSelectByGroups && !canAssignInSlot(unit, this.config.unitsGroupsByCountry, this.country)

    let unitItemParams = {
      status = isLockedUnit ? "locked"
        : !isEnabled ? "disabled"
        : isTrained ? "mounted"
        : "canBuy"
      showWarningIcon = !this.isSelectByGroups && this.haveMoreQualifiedCrew(unit)
      showBR = hasFeature("SlotbarShowBattleRating")
      getEdiffFunc = this.getCurrentEdiff.bindenv(this)
      fullBlock = false
      isLocalState = !this.isSelectByGroups
      tooltipParams = { showLocalState = !this.isSelectByGroups }
    }

    if (!isTrained)
      unitItemParams.overlayPrice <- unit.trainCost

    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(this.crew, unit)
    if (specType != ::g_crew_spec_type.UNKNOWN)
      unitItemParams.specType <- specType

    let id = unit.name
    let markup = ::build_aircraft_item(id, unit, unitItemParams)
    this.guiScene.replaceContentFromText(objSlot, markup, markup.len(), this)
    objSlot.tooltipId = ::g_tooltip.getIdUnit(unit.name, unitItemParams.tooltipParams)
    ::fill_unit_item_timers(objSlot.findObject(id), unit, unitItemParams)
  }

  function updateUnitsList() {
    if (!checkObj(this.scene))
      return

    this.guiScene.setUpdatesEnabled(false, false)
    let optionMasks = []
    foreach (userOpt in this.filterOptionsList)
      optionMasks.append(::get_option(userOpt).value)

    let tblObj = this.scene.findObject("airs_table")
    let total = tblObj.childrenCount()
    let lenghtOptions = optionMasks.len()
    local selected = 0
    let crewUnitId = getTblValue("aircraft", this.crew, "")

    local visibleAmount = 0
    let isFirstPage = this.curVisibleSlots == this.firstPageSlots
    local firstHiddenUnit = null
    local firstHiddenUnitObj = null
    local needShowMoreButton = false

    for (local i = 0; i < total; i++) {
      let objSlot = tblObj.getChild(i)
      if (!objSlot)
        continue
      let slot = this.unitsList?[i]
      let unit = this.getSlotUnit(slot)
      if (!u.isUnit(unit))
        continue

      let masksUnit = this.optionsMaskByUnits?[unit.name]
      local isVisible = true
      if (masksUnit)
        for (local j = 0; j < lenghtOptions; j++)
          if ((masksUnit[j] & optionMasks[j]) == 0)
            isVisible = false

      if (isVisible) {
        isVisible = ++visibleAmount <= this.curVisibleSlots
        if (!isVisible)
          if (visibleAmount == this.curVisibleSlots) {
            firstHiddenUnit = unit
            firstHiddenUnitObj = objSlot
          }
          else
            needShowMoreButton = true
      }

      this.showUnitSlot(objSlot, slot, isVisible)

      if (isVisible
        && (!isFirstPage || unit.name == crewUnitId)) //on not first page always select last visible unit
        selected = i
    }

    if (!needShowMoreButton && firstHiddenUnit)
      this.showUnitSlot(firstHiddenUnitObj, firstHiddenUnit, true)
    if (this.showMoreObj) {
      this.showMoreObj.show(needShowMoreButton)
      this.showMoreObj.inactive = needShowMoreButton ? "no" : "yes"
      if (!isFirstPage && needShowMoreButton)
        selected = total - 1
    }

    if (!this.isEmptyOptionsList)
      this.scene.findObject("filtered_units_text").setValue(
        loc("mainmenu/filteredUnits", {
          total = this.unitsArray.len()
          filtered = colorize("activeTextColor", visibleAmount)
        }))

    this.guiScene.setUpdatesEnabled(true, true)
    if (selected != 0)
      tblObj.setValue(selected)
  }

  function onEventSetInQueue(_params) {
    this.goBack()
  }

  function getCrewUnit() {
    return this.isSelectByGroups
      ? this.config?.countryPresets[this.country].units[this.idInCountry]
      : ::g_crew.getCrewUnit(this.crew)
  }

  function getSelectedGroup() {
    if (!this.isSelectByGroups)
      return null

    let unitsGroups = this.config.unitsGroupsByCountry?[this.country]
    let selectedUnit = this.getCrewUnit()
    if (unitsGroups == null || selectedUnit == null)
      return null

    let selectedGroupName = unitsGroups.groupIdByUnitName?[selectedUnit.name] ?? ""
    return unitsGroups.groups?[selectedGroupName]
  }

  hasChangeVehicle = @(unit) this.getCrewUnit() != unit
  getSlotUnit = @(slot) slot
  getFilterOptionsList = @() this.isSelectByGroups ? [] : defaultFilterOptions
  hasGroupText = @() this.isSelectByGroups

  function updateUnitsGroupText(unit = null) {
    let isVisibleGroupText = this.hasGroupText()
    let unitsGroupTextObj = this.showSceneBtn("units_group_text", isVisibleGroupText)
    if (!isVisibleGroupText)
      return

    let textArray = [loc("mainmenu/onlyShownUnitsByGroup", {
      groupName = loc(this.getSelectedGroup()?.name ?? "")
    })]
    if (u.isUnit(unit) && !canAssignInSlot(unit, this.config.unitsGroupsByCountry, this.country))
      textArray.append(colorize("red", loc("worldwar/help/slotbar/unit_unavailable")))

    unitsGroupTextObj.setValue("\n".join(textArray, true))
  }

  function onSlotSelect(obj) {
    let row = obj.getValue()
    if (row < 0)
      return

    let unit = this.unitsList[row]
    this.updateUnitsGroupText(unit)
  }
}

::gui_handlers.SelectUnitHandler <- SelectUnitHandler

return {
  open = @(crew, slotbar) ::get_cur_gui_scene().performDelayed({},
    function() {

      let params = getParamsFromSlotbarConfig(crew, slotbar)
      if (params == null)
        return broadcastEvent("ModalWndDestroy")

      ::handlersManager.destroyPrevHandlerAndLoadNew(SelectUnitHandler, params)
    })
  getParamsFromSlotbarConfig = getParamsFromSlotbarConfig
}

