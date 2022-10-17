let { format } = require("string")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let { findChildIndex } = require("%sqDagui/daguiUtil.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { ceil } = require("%sqstd/math.nut")

let MAX_SLOT_COUNT_X = 4

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
  sceneTplName         = "%gui/unit/vehiclesModal"
  wndTitleLocId        = "itemTypes/vehicles"
  slotbarActions       = [ "research", "buy", "take", "sec_weapons", "weapons", "showroom", "testflight", "info", "repair" ]

  actionsListOpenTime  = 0
  maxSlotCountY = 6

  function getSceneTplView()
  {
    collectUnitData()
    return {
      slotCountX = MAX_SLOT_COUNT_X
      slotCountY = min(ceil(units.len().tofloat() / MAX_SLOT_COUNT_X), maxSlotCountY)
      hasScrollBar = MAX_SLOT_COUNT_X * maxSlotCountY < units.len()
      unitsList = getUnitsListData()

      wndTitle = getWndTitle()
      needCloseBtn = canQuitByGoBack
      navBar = getNavBarView()
    }
  }

  function initScreen()
  {
    let listObj = scene.findObject("units_list")
    restoreLastUnitSelection(listObj)
    initPopupFilter()
  }

  function initPopupFilter() {
    let nestObj = scene.findObject("filter_nest")
    openPopupFilter({
      scene = nestObj
      onChangeFn = onChangeFilterItem.bindenv(this)
      filterTypes = getFiltersView()
    })
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
        let country = unit.shopCountry
        let unitTypeStr = unit.unitType.esUnitType.tostring()
        units.append(unit)
        if (!(country in countries))
          countries[country] <- {
            id = country
            idx = shopCountriesList.findindex(@(id) id == country) ?? -1
            value = false
          }
        if (!(unitTypeStr in unitsTypes))
          unitsTypes[unitTypeStr] <- {unitType = unit.unitType, value = false}
      }
  }

  function onChangeFilterItem(objId, typeName, value)
  {
    let isTypeUnit = typeName == "unit"
    let referenceArr = isTypeUnit ? unitsTypes : countries
    if (objId == RESET_ID)
      foreach (inst in referenceArr)
        inst.value = false
    else
      referenceArr[isTypeUnit ? objId.split("_")[1] : objId].value = value
    fillUnitsList()
  }

  function getFiltersView()
  {
    let res = []
    foreach (tName in ["country", "unit"])
    {
      let isUnitType = tName == "unit"
      let responceArr = isUnitType ? unitsTypes : countries
      let view = { checkbox = [] }
      foreach(inst in responceArr)
      {
        if (isUnitType && !inst.unitType.isAvailable())
          continue

        view.checkbox.append({
          id = isUnitType ? $"unit_{inst.unitType.esUnitType}" : inst.id
          idx = isUnitType ? inst.unitType.esUnitType : inst.idx
          image = isUnitType ? inst.unitType.testFlightIcon : ::get_country_icon(inst.id)
          text = isUnitType ? inst.unitType.getArmyLocName() : ::loc(inst.id)
          value = false
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
    let isEmptyCountryFilter  = countries.findindex(@(t) t.value) == null
    let isEmptyUnitFilter = unitsTypes.findindex(@(t) t.value) == null
    foreach(unit in units)
    {
      let country = unit.shopCountry
      // Show all items if filters list is empty
      if ((!isEmptyCountryFilter && !countries[country].value)
        || (!isEmptyUnitFilter && !unitsTypes[unit.unitType.esUnitType.tostring()].value))
        continue
      filteredUnits.append(unit)
    }

    local data = ""
    foreach(unit in filteredUnits)
      data += format("unitItemContainer{id:t='cont_%s' %s}", unit.name,
        ::build_aircraft_item(unit.name, unit, getUnitItemParams(unit)))

    return data
  }

  function fillUnitsList()
  {
    let listObj = scene.findObject("units_list")
    if (!::check_obj(listObj))
      return

    let data = getUnitsListData()
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    foreach(unit in units)
    {
      let placeObj = listObj.findObject("cont_" + unit.name)
      if (!placeObj)
        continue

      updateAdditionalProp(unit, placeObj)
      ::updateAirAfterSwitchMod(unit)
    }

    restoreLastUnitSelection(listObj)
  }

  function selectCell()
  {
    let listObj = scene.findObject("units_list")
    if (!listObj?.isValid())
      return

    let idx = findChildIndex(listObj, @(c) c.isHovered())
    if (idx == -1 || idx == listObj.getValue())
      return

    listObj.setValue(idx)
  }

  function restoreLastUnitSelection(listObj)
  {
    local newIdx = -1
    if (lastSelectedUnit)
    {
      let unit = lastSelectedUnit
      newIdx = filteredUnits.findindex(@(u) u == unit) ?? -1
    }
    let total = listObj.childrenCount()
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

    let unitBlock = ::build_aircraft_item(unit.name, unit, getUnitItemParams(unit))
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
    let listObj = scene.findObject("units_list")
    let idx = ::get_obj_valid_index(listObj)
    if (idx < 0)
      return null

    return listObj.getChild(idx).getChild(0)
  }

  function onUnitSelect(obj)
  {
    lastSelectedUnit = null
    let slotObj = getCurSlotObj()
    if (::check_obj(slotObj))
      lastSelectedUnit = ::getAircraftByName(slotObj.unit_name)

    updateButtons()
  }

  function onUnitAction(obj) {
    selectCell()
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
    let prevUnitName = p?.prevUnitName
    let unitName = p?.unitName

    if (prevUnitName && prevUnitName != unitName)
      checkUnitItemAndUpdate(::getAircraftByName(prevUnitName))

    checkUnitItemAndUpdate(::getAircraftByName(unitName))
  }

  function onEventUnitBought(p)
  {
    ::update_gamercards()
    checkUnitItemAndUpdate(::getAircraftByName(p?.unitName))
  }

  function onEventFlushSquadronExp(p)
  {
    fillUnitsList()
  }

  function onEventModificationPurchased(p)
  {
    checkUnitItemAndUpdate(p?.unit)
  }

  function onEventUnitRepaired(p)
  {
    checkUnitItemAndUpdate(p?.unit)
  }
}

::gui_handlers.vehiclesModal <- handlerClass

return {
  handlerClass = handlerClass
  open = function(unitsFilter = null, params = {})
  {
    let handlerParams = params.__merge({ unitsFilter = unitsFilter })
    ::handlersManager.loadHandler(handlerClass, handlerParams)
  }
}
