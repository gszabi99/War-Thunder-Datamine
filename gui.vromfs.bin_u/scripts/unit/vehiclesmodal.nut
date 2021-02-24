local popupFilter = require("scripts/popups/popupFilter.nut")

local MAX_SLOT_COUNT_X = 4
local MAX_SLOT_COUNT_Y = 6

const OPEN_RCLICK_UNIT_MENU_AFTER_SELECT_TIME = 500 // when select slot by right click button
                                                    // then menu vehilce opened and close

local handlerClass = class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType              = handlerType.MODAL
  unitsFilter          = null
  units                = null
  filteredUnits        = null
  countries            = null
  unitsTypes           = null
  lastSelectedUnit     = null
  needSkipFocus        = false
  sceneTplName         = "gui/unit/vehiclesModal"
  wndTitleLocId        = "itemTypes/vehicles"
  slotbarActions       = [ "research", "buy", "take", "sec_weapons", "weapons", "showroom", "testflight", "info", "repair" ]

  actionsListOpenTime  = 0

  function getSceneTplView()
  {
    collectUnitData()
    return {
      slotCountX = MAX_SLOT_COUNT_X
      slotCountY = min( units.len() / MAX_SLOT_COUNT_X + 1, MAX_SLOT_COUNT_Y)
      hasScrollBar = MAX_SLOT_COUNT_X * MAX_SLOT_COUNT_Y < units.len()
      unitsList = getUnitsListData()

      wndTitle = getWndTitle()
      needCloseBtn = canQuitByGoBack
      navBar = getNavBarView()
    }
  }

  function initScreen()
  {
    local listObj = scene.findObject("units_list")
    restoreLastUnitSelection(listObj)

    local nestObj = scene.findObject("filter_nest")
    local filter = popupFilter.open(nestObj, onChangeFilterItem.bindenv(this), getFiltersView())
    nestObj.setUserData(filter)
  }

  getWndTitle = @() ::loc(wndTitleLocId)
  getNavBarView = @() null
  updateButtons = @() null

  function collectUnitData()
  {
    units = []
    countries = {}
    unitsTypes = {}

    foreach(unit in ::all_units)
      if (!unitsFilter || unitsFilter(unit))
      {
        local country = unit.shopCountry
        local unitTypeStr = unit.unitType.esUnitType.tostring()
        units.append(unit)
        if (!(country in countries))
          countries[country] <- {
            id = country
            idx = ::shopCountriesList.findindex(@(id) id == country) ?? -1
            value = true
          }
        if (!(unitTypeStr in unitsTypes))
          unitsTypes[unitTypeStr] <- {unitType = unit.unitType, value = true}
      }
  }

  function onChangeFilterItem(objId, typeName, value)
  {
    local isTypeUnit = typeName == "unit"
    local referenceArr = isTypeUnit ? unitsTypes : countries
    if (objId == "all_items")
      foreach (inst in referenceArr)
        inst.value = value
    else
      referenceArr[isTypeUnit ? objId.split("_")[1] : objId].value = value
    fillUnitsList()
  }

  function getFiltersView()
  {
    local res = []
    foreach (tName in ["country", "unit"])
    {
      local isUnitType = tName == "unit"
      local responceArr = isUnitType ? unitsTypes : countries
      local cbView = {
        id = "all_items"
        idx = -1
        image = $"#ui/gameuiskin#{isUnitType ? "all_unit_types" : "flag_all_nations"}.svg"
        text = $"#all_{isUnitType ? "units" : "countries"}"
        value = true
      }
      local view = { checkbox = [cbView] }
      foreach(inst in responceArr)
      {
        if (isUnitType && !inst.unitType.isAvailable())
          continue

        view.checkbox.append({
          id = isUnitType ? $"unit_{inst.unitType.esUnitType}" : inst.id
          idx = isUnitType ? inst.unitType.esUnitType : inst.idx
          image = isUnitType ? inst.unitType.testFlightIcon : ::get_country_icon(inst.id)
          text = isUnitType ? inst.unitType.getArmyLocName() : $"#{inst.id}"
          value = inst.value
        })
      }

      view.checkbox.sort(@(a,b) a.idx <=> b.idx)

      if (view.checkbox.len() > 0)
        view.checkbox[view.checkbox.len()-1].isLastCheckBox <- true

      res.append(view)
    }
    return res
  }

  function getUnitsListData()
  {
    filteredUnits = []
    foreach(unit in units)
    {
      local country = unit.shopCountry
      if (!countries[country].value || !unitsTypes[unit.unitType.esUnitType.tostring()].value)
        continue
      filteredUnits.append(unit)
    }

    local data = ""
    foreach(unit in filteredUnits)
    {
      local country = unit.shopCountry
      if (!countries[country].value || !unitsTypes[unit.unitType.esUnitType.tostring()].value)
        continue

      data += ::format("unitItemContainer{id:t='cont_%s' %s}", unit.name,
        ::build_aircraft_item(unit.name, unit, getUnitItemParams(unit)))
    }
    return data
  }

  function fillUnitsList()
  {
    local listObj = scene.findObject("units_list")
    if (!::check_obj(listObj))
      return

    local data = getUnitsListData()
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    foreach(unit in units)
    {
      local placeObj = listObj.findObject("cont_" + unit.name)
      if (!placeObj)
        continue

      updateAdditionalProp(unit, placeObj)
      ::updateAirAfterSwitchMod(unit)
    }

    restoreLastUnitSelection(listObj)
  }

  function restoreLastUnitSelection(listObj)
  {
    local newIdx = -1
    if (lastSelectedUnit)
    {
      local unit = lastSelectedUnit
      newIdx = filteredUnits.findindex(@(u) u == unit) ?? -1
    }
    local total = listObj.childrenCount()
    if (newIdx == -1 && total)
      newIdx = 0

    needSkipFocus = true
    listObj.setValue(newIdx)
    needSkipFocus = false

    if (newIdx == -1)
    {
      lastSelectedUnit = null
      updateButtons()
    }
  }

  function getUnitItemParams(unit)
  {
    return {
      hasActions         = true
      isInTable          = false
      fullBlock          = false
      showBR             = ::has_feature("GlobalShowBattleRating")
      tooltipParams      = { needShopInfo = true }
    }
  }

  getParamsForActionsList = @() {setResearchManually  = true}

  function checkUnitItemAndUpdate(unit)
  {
    if (!unit)
      return

    updateUnitItem(unit, scene.findObject("cont_" + unit.name))
    ::updateAirAfterSwitchMod(unit)
  }

  function updateUnitItem(unit, placeObj)
  {
    if (!::check_obj(placeObj))
      return

    local unitBlock = ::build_aircraft_item(unit.name, unit, getUnitItemParams(unit))
    guiScene.replaceContentFromText(placeObj, unitBlock, unitBlock.len(), this)
    updateAdditionalProp(unit, placeObj)
  }

  function updateAdditionalProp(unit, placeObj)
  {
    ::fill_unit_item_timers(placeObj.findObject(unit.name), unit, getUnitItemParams(unit))
    ::showUnitDiscount(placeObj.findObject(unit.name+"-discount"), unit)

    local bonusData = unit.name
    if (::isUnitGroup(unit))
      bonusData = ::u.map(unit.airsGroup, function(unit) { return unit.name })
    ::showAirExpWpBonus(placeObj.findObject(unit.name+"-bonus"), bonusData)
  }

  function getCurSlotObj() {
    local listObj = scene.findObject("units_list")
    local idx = ::get_obj_valid_index(listObj)
    if (idx < 0)
      return null

    return listObj.getChild(idx).getChild(0)
  }

  function onUnitSelect(obj)
  {
    lastSelectedUnit = null
    local slotObj = getCurSlotObj()
    if (::check_obj(slotObj))
      lastSelectedUnit = ::getAircraftByName(slotObj.unit_name)

    updateButtons()
  }

  function onUnitAction(obj) {
    openUnitActionsList(getCurSlotObj())
  }

  function onUnitClick(obj) {
    actionsListOpenTime = ::dagor.getCurTime()
    onUnitAction(obj)
  }

  function onUnitRightClick(obj) {
    if (::dagor.getCurTime() - actionsListOpenTime
        < OPEN_RCLICK_UNIT_MENU_AFTER_SELECT_TIME)
      return
    onUnitAction(obj)
  }

  function onEventUnitResearch(p)
  {
    local prevUnitName = p?.prevUnitName ?? null
    local unitName = p?.unitName ?? null

    if (prevUnitName && prevUnitName != unitName)
      checkUnitItemAndUpdate(::getAircraftByName(prevUnitName))

    checkUnitItemAndUpdate(::getAircraftByName(unitName))
  }

  function onEventUnitBought(p)
  {
    ::update_gamercards()
    checkUnitItemAndUpdate(::getAircraftByName(p?.unitName ?? null))
  }

  function onEventFlushSquadronExp(p)
  {
    fillUnitsList()
  }

  function onEventModificationPurchased(p)
  {
    checkUnitItemAndUpdate(p?.unit ?? null)
  }

  function onEventUnitRepaired(p)
  {
    checkUnitItemAndUpdate(p?.unit ?? null)
  }
}

::gui_handlers.vehiclesModal <- handlerClass

return {
  handlerClass = handlerClass
  open = function(unitsFilter = null, params = {})
  {
    local handlerParams = params.__merge({ unitsFilter = unitsFilter })
    ::handlersManager.loadHandler(handlerClass, handlerParams)
  }
}
