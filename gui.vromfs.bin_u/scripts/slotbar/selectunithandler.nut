from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { canAssignInSlot, setUnit } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

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
  if (!::CrewTakeUnitProcess.safeInterrupt())
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
    unitsArray = ::all_units.filter(@(u) busyUnits.indexof(u.name) == null
      && u.canAssignToCrew(country)).values()
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

local class SelectUnitHandler extends ::gui_handlers.BaseGuiHandlerWT
{
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

  function initScreen()
  {
    country = ::g_crews_list.get()[countryId].country
    curOptionsMasks = []
    filterOptionsList = getFilterOptionsList()
    optionsMaskByUnits = {}
    legendData = []
    if (slotbarWeak)
      slotbarWeak = slotbarWeak.weakref() //we are miss weakref on assigning from params table

    this.guiScene.applyPendingChanges(false) //to apply slotbar scroll before calculating positions

    let tdObj = slotObj.getParent()
    let tdPos = tdObj.getPosRC()

    ::gui_handlers.ActionsList.removeActionsListFromObject(tdObj)

    let tdClone = tdObj.getClone(this.scene, slotbarWeak)
    tdClone.pos = tdPos[0] + ", " + tdPos[1]
    tdClone["class"] = "slotbarClone"
    curClonObj = tdClone

    // When menu opens on switching to country, slots are invisible due to animation
    if ((tdClone?["color-factor"] ?? "255") != "255")
      ::gui_bhv_deprecated.massTransparency.setTranspRecursive(tdClone, 255)

    let curUnitCloneObj = ::get_slot_obj(tdClone, countryId, idInCountry)
    ::fill_unit_item_timers(curUnitCloneObj, getCrewUnit())
    ::gui_handlers.ActionsList.switchActionsListVisibility(curUnitCloneObj)

    this.scene.findObject("tablePlace").pos = tdPos[0] + ", " + tdPos[1]

    let needEmptyCrewButton = initAvailableUnitsArray()

    curVisibleSlots = firstPageSlots

    this.showSceneBtn("btn_emptyCrew", needEmptyCrewButton)

    updateUnitsGroupText()
    initChooseUnitsOptions()
    fillChooseUnitsOptions()
    fillLegendData()
    fillLegend()
    fillUnitsList()
    updateUnitsList()
    ::move_mouse_on_obj(curUnitCloneObj)
    updateOptionShowUnsupportedForCustomList()
    this.showSceneBtn("choose_popup_menu", !isEmptyOptionsList || (needEmptyCrewButton && ::show_console_buttons) || hasGroupText())
  }

  function reinitScreen(params = {})
  {
    if (checkObj(curClonObj))
      curClonObj.getScene().destroyElement(curClonObj)
    this.setParams(params)
    initScreen()
    wasReinited = true
  }

  function fillLegendData()
  {
    legendData.clear()
    foreach (specType in ::g_crew_spec_type.types)
      if (specType != ::g_crew_spec_type.UNKNOWN)
        addLegendData(specType.specName, specType.trainedIcon, loc("crew/trained") + loc("ui/colon") + specType.getName())
    addLegendData("warningIcon", "#ui/gameuiskin#new_icon.svg", "#mainmenu/selectCrew/haveMoreQualified/tooltip")
  }

  function fillLegend()
  {
    let haveLegend = !isEmptyOptionsList && legendData.len() > 0
    let legendNest = this.showSceneBtn("legend_nest", haveLegend)
    if (!haveLegend)
      return

    let legendView = {
      header = loc("mainmenu/legend")
      haveLegend = legendData.len() > 0,
      legendData = legendData
    }
    let markup = ::handyman.renderCached("%gui/slotbar/legend_block", legendView)
    this.guiScene.replaceContentFromText(legendNest, markup, markup.len(), this)
  }

  function initAvailableUnitsArray()
  {
    unitsArray = sortUnitsList(unitsArray)

    unitsList = []
    if (slotbarWeak?.ownerWeak?.canShowShop && slotbarWeak.ownerWeak.canShowShop())
      unitsList.append(SEL_UNIT_BUTTON.SHOP)
    let needEmptyCrewButton = !isSelectByGroups && ((crew?.aircraft ?? "") != "")
      && (!hasDefaultUnitsInCountry(country) || busyUnitsCount >= MIN_NON_EMPTY_SLOTS_IN_COUNTRY)
    if (needEmptyCrewButton)
      unitsList.append(SEL_UNIT_BUTTON.EMPTY_CREW)
    unitsList.extend(unitsArray)
    unitsList.append(SEL_UNIT_BUTTON.SHOW_MORE)

    return needEmptyCrewButton
  }

  function sortUnitsList(units)
  {
    let ediff = getCurrentEdiff()
    let trained = getTblValue("trainedSpec", crew, {})
    let getSortSpecialization = @(unit) unit.name in trained ? trained[unit.name]
                                          : unit.trainCost ? -1
                                          : 0
    let selectedUnit = getCrewUnit()
    let groupIdByUnitName = config?.unitsGroupsByCountry[country].groupIdByUnitName
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

  function addLegendData(id, imagePath, locId)
  {
    foreach(data in legendData)
      if (id == data.id)
        return

    legendData.append({
      id = id,
      imagePath = imagePath,
      locId = locId
    })
  }

  function haveMoreQualifiedCrew(unit)
  {
    let bestIdx = ::g_crew.getBestTrainedCrewIdxForUnit(unit, false, crew)
    return bestIdx >= 0 && bestIdx != crew.idInCountry
  }

  getTextSlotMarkup = @(id, text) ::build_aircraft_item(id, null, { emptyText = text })

  function fillUnitsList()
  {
    let markupArr = []
    foreach(_idx, unit in unitsList)
    {
      local rowData = ""
      if (!::u.isInteger(unit))
        rowData = "unitCell {}"
      else if (unit == SEL_UNIT_BUTTON.SHOP)
        rowData = getTextSlotMarkup("shop_item", "#mainmenu/btnShop")
      else if (unit == SEL_UNIT_BUTTON.EMPTY_CREW)
        rowData = getTextSlotMarkup("empty_air", "#shop/emptyCrew")
      else if (unit == SEL_UNIT_BUTTON.SHOW_MORE)
        rowData = getTextSlotMarkup("show_more", "#mainmenu/showMore")
      markupArr.append(rowData)
    }

    let markup = "\n".join(markupArr)
    let tblObj = this.scene.findObject("airs_table")
    tblObj.alwaysShowBorder = "yes"
    this.guiScene.replaceContentFromText(tblObj, markup, markup.len(), this)

    showMoreObj = tblObj.findObject("td_show_more")
  }

  function onEmptyCrew()
  {
    trainSlotAircraft(null)
  }

  function onDoneSlotChoose(obj)
  {
    let row = obj.getValue()
    if (row < 0)
      return

    let unit = unitsList[row]
    if (unit == SEL_UNIT_BUTTON.SHOP)
      return goToShop()
    if (unit == SEL_UNIT_BUTTON.EMPTY_CREW)
      return trainSlotAircraft(null) //empty slot
    if (unit == SEL_UNIT_BUTTON.SHOW_MORE)
    {
      curVisibleSlots += slotsPerPage - 1 //need to all new slots be visible and current button also
      updateUnitsList()
      return
    }

    if (isSelectByGroups && ::u.isUnit(unit) && !canAssignInSlot(unit, config.unitsGroupsByCountry, country))
      return

    if (!hasChangeVehicle(unit))
      return this.goBack()

    if (!isSelectByGroups && haveMoreQualifiedCrew(unit))
      return ::gui_start_selecting_crew({
          unit = unit,
          unitObj = this.scene.findObject(unit.name),
          takeCrewIdInCountry = crew.idInCountry,
          messageText = loc("mainmenu/selectCrew/haveMoreQualified"),
          afterSuccessFunc = Callback(this.goBack, this)
          isSelectByGroups = isSelectByGroups
        })

    trainSlotAircraft(unit)
  }

  function goToShop()
  {
    this.goBack()
    if (slotbarWeak?.ownerWeak?.openShop)
    {
      let unit = getCrewUnit()
      slotbarWeak.ownerWeak.openShop(unit?.unitType)
    }
  }

  function trainSlotAircraft(unit)
  {
    let onFinishCb = Callback(onTakeProcessFinish, this)
    if (isSelectByGroups)
      setUnit({
        crew = crew
        unit = unit
        onFinishCb = onFinishCb
      })
    else
      ::CrewTakeUnitProcess(crew, unit, onFinishCb)
  }

  function onTakeProcessFinish(_isSuccess)
  {
    this.goBack()
  }

  function initChooseUnitsOptions()
  {
    curOptionsMasks.clear()
    optionsMaskByUnits.clear()

    foreach(slot in unitsList)
    {
      let unit = getSlotUnit(slot)
      if (!::u.isUnit(unit))
        continue

      let masks = []
      foreach (userOpt in filterOptionsList)
        masks.append(getOptionsMaskForUnit[userOpt](unit, crew, config))

      optionsMaskByUnits[unit.name] <- masks
      for (local i = 0; i < masks.len(); i++)
        if (curOptionsMasks.len() > i)
          curOptionsMasks[i] = curOptionsMasks[i] | masks[i]
        else
          curOptionsMasks.append(masks[i])
    }
  }

  function fillChooseUnitsOptions()
  {
    let locParams = {
      gameModeName = colorize("hotkeyColor", getGameModeNameFromParams(config))
      customListName = colorize("hotkeyColor", getCustomListNameFromParams(config))
    }

    let objOptionsNest = this.scene.findObject("choose_options_nest")
    if ( !checkObj(objOptionsNest) )
      return

    isEmptyOptionsList = true
    let view = { rows = [] }
    foreach (idx, userOpt in filterOptionsList)
    {
      let maskOption = ::get_option(userOpt)
      let singleOption = getTblValue("singleOption", maskOption, false)
      if (singleOption)
      {
        // All bits but first are set to 1.
        maskOption.value = maskOption.value | ~1
        ::set_option(userOpt, maskOption.value)
      }
      let maskStorage = getTblValue(idx, curOptionsMasks, 0)
      if ((maskOption.value & maskStorage) == 0)
      {
        maskOption.value = maskStorage
        ::set_option(userOpt, maskOption.value)
      }
      let hideTitle = getTblValue("hideTitle", maskOption, false)
      let row = {
        option_title = hideTitle ? "" : loc( maskOption.hint )
        option_id = maskOption.id
        option_idx = idx
        option_uid = userOpt
        option_value = maskOption.value
        nums = []
      }
      row.cb <- maskOption?.cb

      local countVisibleOptions = 0
      foreach (idxItem, text in maskOption.items)
      {
        let optionVisible = ( (1 << idxItem) & maskStorage ) != 0
        if (optionVisible)
          countVisibleOptions++
        local name = text
        if (::g_string.startsWith(name, "#"))
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
        isEmptyOptionsList = false
    }

    let markup = ::handyman.renderCached(("%gui/slotbar/choose_units_filter"), view)
    this.guiScene.replaceContentFromText(objOptionsNest, markup, markup.len(), this)

    objOptionsNest.show(!isEmptyOptionsList)
    this.showSceneBtn("choose_options_header", !isEmptyOptionsList)
    this.showSceneBtn("filtered_units_text", !isEmptyOptionsList)
    let objChoosePopupMenu = this.scene.findObject("choose_popup_menu")
    if ( !checkObj(objChoosePopupMenu) )
      return

    this.guiScene.setUpdatesEnabled(true, true)

    let sizeChoosePopupMenu = objChoosePopupMenu.getSize()
    let scrWidth = ::g_dagui_utils.toPixels(this.guiScene, "@bw + @rw")
    objChoosePopupMenu.side = ((objChoosePopupMenu.getPosRC()[0] + sizeChoosePopupMenu[0]) > scrWidth) ? "left" : "right"
  }

  function getGameModeNameFromParams(params)
  {
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

  function getCustomListNameFromParams(params)
  {
    return params?.customUnitsListName ?? ""
  }

  function getCurrentEdiff()
  {
    if (config?.getEdiffFunc)
      return config.getEdiffFunc()
    if (slotbarWeak)
      return slotbarWeak.getCurrentEdiff()
    return ::get_current_ediff()
  }

  function onSelectedOptionChooseUnsapportedUnit(obj)
  {
    onSelectedOptionChooseUnit(obj)
    updateOptionShowUnsupportedForCustomList()
  }

  function onSelectedOptionChooseUnit(obj)
  {
    if (!checkObj(obj) || !obj?.idx)
      return

    let maskOptions = getTblValue(obj.idx.tointeger(), curOptionsMasks, null)
    if (!maskOptions)
      return

    let oldOption = ::get_option((obj.uid).tointeger())
    let value = (oldOption.value.tointeger() & (~maskOptions)) | (obj.getValue() & maskOptions)
    ::set_option((obj.uid).tointeger(), value)
    curVisibleSlots = firstPageSlots
    updateUnitsList()
  }

  function updateOptionShowUnsupportedForCustomList()
  {
    let modeOption = ::get_option(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE)
    let customOption = ::get_option(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST)

    let customOptionObj = this.scene.findObject(customOption.id)
    if (!checkObj(customOptionObj))
      return

    let isModeOptionChecked = modeOption.value & 1
    if (!isModeOptionChecked)
    {
      let idx = filterOptionsList.indexof(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE)
      let maskOptions = curOptionsMasks?[idx]
      if (maskOptions)
        customOptionObj.setValue(modeOption.value - (modeOption.value & (~maskOptions)))
    }
    customOptionObj.show(isModeOptionChecked)
  }

  function showUnitSlot(objSlot, unit, isVisible)
  {
    objSlot.show(isVisible)
    objSlot.inactive = isVisible ? "no" : "yes"
    if (!isVisible || objSlot.childrenCount())
      return

    let isTrained = (unit.name in crew?.trainedSpec) || unit.trainCost == 0
    let isEnabled = ::is_unit_enabled_for_slotbar(unit, config)
    let canShowCrewSpec = hasFeature("CrewInfo")
    let isLockedUnit = isSelectByGroups && !canAssignInSlot(unit, config.unitsGroupsByCountry, country)

    let unitItemParams = {
      status = isLockedUnit ? "locked"
        : !isEnabled ? "disabled"
        : isTrained ? "mounted"
        : "canBuy"
      showWarningIcon = !isSelectByGroups && canShowCrewSpec && haveMoreQualifiedCrew(unit)
      showBR = hasFeature("SlotbarShowBattleRating")
      getEdiffFunc = getCurrentEdiff.bindenv(this)
      fullBlock = false
      isLocalState = !isSelectByGroups
      tooltipParams = { showLocalState = !isSelectByGroups }
    }

    if (!isTrained)
      unitItemParams.overlayPrice <- unit.trainCost

    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    if (canShowCrewSpec && specType != ::g_crew_spec_type.UNKNOWN)
      unitItemParams.specType <- specType

    let id = unit.name
    let markup = ::build_aircraft_item(id, unit, unitItemParams)
    this.guiScene.replaceContentFromText(objSlot, markup, markup.len(), this)
    objSlot.tooltipId = ::g_tooltip.getIdUnit(unit.name, unitItemParams.tooltipParams)
    ::fill_unit_item_timers(objSlot.findObject(id), unit, unitItemParams)
  }

  function updateUnitsList()
  {
    if (!checkObj(this.scene))
      return

    this.guiScene.setUpdatesEnabled(false, false)
    let optionMasks = []
    foreach (userOpt in filterOptionsList)
      optionMasks.append(::get_option(userOpt).value)

    let tblObj = this.scene.findObject("airs_table")
    let total = tblObj.childrenCount()
    let lenghtOptions = optionMasks.len()
    local selected = 0
    let crewUnitId = getTblValue("aircraft", crew, "")

    local visibleAmount = 0
    let isFirstPage = curVisibleSlots == firstPageSlots
    local firstHiddenUnit = null
    local firstHiddenUnitObj = null
    local needShowMoreButton = false

    for (local i = 0; i < total; i++)
    {
      let objSlot = tblObj.getChild(i)
      if (!objSlot)
        continue
      let slot = unitsList?[i]
      let unit = getSlotUnit(slot)
      if (!::u.isUnit(unit))
        continue

      let masksUnit = optionsMaskByUnits?[unit.name]
      local isVisible = true
      if (masksUnit)
        for (local j = 0; j < lenghtOptions; j++)
          if ( (masksUnit[j] & optionMasks[j]) == 0 )
            isVisible = false

      if (isVisible)
      {
        isVisible = ++visibleAmount <= curVisibleSlots
        if (!isVisible)
          if (visibleAmount == curVisibleSlots)
          {
            firstHiddenUnit = unit
            firstHiddenUnitObj = objSlot
          } else
            needShowMoreButton = true
      }

      showUnitSlot(objSlot, slot, isVisible)

      if (isVisible
        && (!isFirstPage || unit.name == crewUnitId)) //on not first page always select last visible unit
        selected = i
    }

    if (!needShowMoreButton && firstHiddenUnit)
      showUnitSlot(firstHiddenUnitObj, firstHiddenUnit, true)
    if (showMoreObj)
    {
      showMoreObj.show(needShowMoreButton)
      showMoreObj.inactive = needShowMoreButton ? "no" : "yes"
      if (!isFirstPage && needShowMoreButton)
        selected = total - 1
    }

    if (!isEmptyOptionsList)
      this.scene.findObject("filtered_units_text").setValue(
        loc("mainmenu/filteredUnits", {
          total = unitsArray.len()
          filtered = colorize("activeTextColor", visibleAmount)
        }))

    this.guiScene.setUpdatesEnabled(true, true)
    if (selected != 0)
      tblObj.setValue(selected)
  }

  function onEventSetInQueue(_params)
  {
    this.goBack()
  }

  function getCrewUnit()
  {
    return isSelectByGroups
      ? config?.countryPresets[country].units[idInCountry]
      : ::g_crew.getCrewUnit(crew)
  }

  function getSelectedGroup()
  {
    if (!isSelectByGroups)
      return null

    let unitsGroups = config.unitsGroupsByCountry?[country]
    let selectedUnit = getCrewUnit()
    if (unitsGroups == null || selectedUnit == null)
      return null

    let selectedGroupName = unitsGroups.groupIdByUnitName?[selectedUnit.name] ?? ""
    return unitsGroups.groups?[selectedGroupName]
  }

  hasChangeVehicle = @(unit) getCrewUnit() != unit
  getSlotUnit = @(slot) slot
  getFilterOptionsList = @() isSelectByGroups ? [] : defaultFilterOptions
  hasGroupText = @() isSelectByGroups

  function updateUnitsGroupText(unit = null)
  {
    let isVisibleGroupText = hasGroupText()
    let unitsGroupTextObj = this.showSceneBtn("units_group_text", isVisibleGroupText)
    if (!isVisibleGroupText)
      return

    let textArray = [loc("mainmenu/onlyShownUnitsByGroup", {
      groupName = loc(getSelectedGroup()?.name ?? "")
    })]
    if (::u.isUnit(unit) && !canAssignInSlot(unit, config.unitsGroupsByCountry, country))
      textArray.append(colorize("red", loc("worldwar/help/slotbar/unit_unavailable")))

    unitsGroupTextObj.setValue("\n".join(textArray, true))
  }

  function onSlotSelect(obj)
  {
    let row = obj.getValue()
    if (row < 0)
      return

    let unit = unitsList[row]
    updateUnitsGroupText(unit)
  }
}

::gui_handlers.SelectUnitHandler <- SelectUnitHandler

return {
  open = @(crew, slotbar) ::get_cur_gui_scene().performDelayed({},
    function() {

      let params = getParamsFromSlotbarConfig(crew, slotbar)
      if (params == null)
        return ::broadcastEvent("ModalWndDestroy")

      ::handlersManager.destroyPrevHandlerAndLoadNew(SelectUnitHandler, params)
    })
  getParamsFromSlotbarConfig = getParamsFromSlotbarConfig
}

