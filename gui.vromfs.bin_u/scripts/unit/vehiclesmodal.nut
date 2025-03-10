from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_time_msec } = require("dagor.time")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilterWidget.nut")
let { findChildIndex, getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { ceil } = require("%sqstd/math.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { isUnitGroup } = require("%scripts/unit/unitStatus.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { showAirExpWpBonus } = require("%scripts/bonusModule.nut")
let { showUnitDiscount } = require("%scripts/discounts/discountUtils.nut")

const OPEN_RCLICK_UNIT_MENU_AFTER_SELECT_TIME = 500 
                                                    

local handlerClass = class (gui_handlers.BaseGuiHandlerWT) {
  wndType              = handlerType.MODAL
  unitsFilter          = null
  units                = null
  filteredUnits        = null
  lastSelectedUnit     = null
  needSkipFocus        = false
  sceneTplName         = "%gui/unit/vehiclesModal.tpl"
  wndTitleLocId        = "itemTypes/vehicles"
  slotbarActions       = [ "research", "buy", "take", "add_to_wishlist", "go_to_wishlist", "sec_weapons", "weapons", "showroom", "testflight", "info", "repair" ]

  actionsListOpenTime  = 0
  maxSlotCountY = 6
  maxSlotCountX = 4

  filtersData = null

  function getSceneTplView() {
    this.collectUnitData()
    return {
      slotCountX = this.maxSlotCountX
      slotCountY = min(ceil(this.units.len().tofloat() / this.maxSlotCountX), this.maxSlotCountY)
      hasScrollBar = this.maxSlotCountX * this.maxSlotCountY < this.units.len()
      unitsList = this.getUnitsListData()

      wndTitle = this.getWndTitle()
      needCloseBtn = this.canQuitByGoBack
      navBar = this.getNavBarView()
    }
  }

  function initScreen() {
    let listObj = this.scene.findObject("units_list")
    this.restoreLastUnitSelection(listObj)
    this.initPopupFilter()
  }

  function initPopupFilter() {
    let nestObj = this.scene.findObject("filter_nest")
    openPopupFilter({
      scene = nestObj
      onChangeFn = this.onChangeFilterItem.bindenv(this)
      filterTypesFn = this.getFiltersView.bindenv(this)
    })
  }

  getWndTitle = @() loc(this.wndTitleLocId)
  getNavBarView = @() null
  updateButtons = @() null

  function collectUnitData() {
    if (this.filtersData == null)
      this.filtersData = {}

    this.units = []
    let countries = {}
    let unitsTypes = {}
    let ranks = {}

    foreach (unit in getAllUnits())
      if (!this.unitsFilter || this.unitsFilter(unit)) {
        this.units.append(unit)
        let country = unit.shopCountry
        let rank = unit.rank
        let unitTypeId = $"unittype_{unit.unitType.esUnitType}"

        if (!countries?[country])
          countries[country] <- {
            id = country
            objId = country
            idx = shopCountriesList.findindex(@(id) id == country) ?? -1
            image = getCountryIcon(country)
            text = loc(country)
            value = this.filtersData?["country"][country].value ?? false,
          }

        if (!unitsTypes?[unitTypeId]) {
          let image = unit.unitType.testFlightIcon
          let text = unit.unitType.getArmyLocName()
          unitsTypes[unitTypeId] <- {
            unitType = unit.unitType,
            image, text,
            value = this.filtersData?["unittype"][unitTypeId].value ?? false,
            id = unit.unitType.esUnitType
            objId = unitTypeId
            idx = unit.unitType.esUnitType
          }
        }

        let rankId = $"rank_{rank}"
        if (!ranks?[rankId])
          ranks[rankId] <- {
            id = rank
            objId = rankId
            idx   = rank
            value   = this.filtersData?["rank"][rankId].value ?? false
            text  = $"{loc("shop/age")} {get_roman_numeral(rank)}"
          }
      }
    this.filtersData["unittype"] <- unitsTypes
    this.filtersData["country"] <- countries
    this.filtersData["rank"] <- ranks
  }

  function onChangeFilterItem(objId, typeName, value) {
    let referenceArr = this.filtersData[typeName]
    if (objId == RESET_ID)
      foreach (inst in referenceArr)
        inst.value = false
    else
      referenceArr[objId].value = value
    this.fillUnitsList()
  }

  function getFiltersView() {
    let res = []
    foreach (tName in ["country", "unittype", "rank"]) {
      let isUnitType = tName == "unittype"
      let responceArr = this.filtersData[tName]

      let view = { checkbox = [] }
      foreach (inst in responceArr) {
        if (isUnitType && !inst.unitType.isAvailable())
          continue

        view.checkbox.append({
          id = inst.objId
          idx = inst.idx
          image = inst?.image
          text = inst.text
          value = inst.value
        })
      }

      view.checkbox.sort(@(a, b) a.idx <=> b.idx)

      if (view.checkbox.len() > 0)
        view.checkbox[view.checkbox.len() - 1].isLastCheckBox <- true

      res.append(view)
    }
    return res
  }

  function filterUnit(unit, params) {
    if (((params["country"].len() > 0) && params["country"]?[unit.shopCountry] == null)
      || ((params["unittype"].len() > 0) && params["unittype"]?[unit.unitType.esUnitType] == null)
      || ((params["rank"].len() > 0) && params["rank"]?[unit.rank] == null))
      return false
    return true
  }

  function filterUnits(units) {
    this.filteredUnits = []
    let params = {}
    foreach (tName in ["country", "unittype", "rank"]) {
      let oldFilter = this.filtersData[tName]
      let arr = {}
      foreach (v in oldFilter)
        if (v.value)
          arr[v.id] <- true
      params[tName] <- arr
    }

    foreach (unit in units)
      if (this.filterUnit(unit, params))
        this.filteredUnits.append(unit)
  }

  function getUnitsListData() {
    this.filterUnits(this.units)
    let data = []
    foreach (unit in this.filteredUnits)
      data.append(format("unitItemContainer{id:t='cont_%s' %s}", unit.name,
        buildUnitSlot(unit.name, unit, this.getUnitItemParams(unit))))

    return "".join(data)
  }

  function fillUnitsList() {
    let listObj = this.scene.findObject("units_list")
    if (!checkObj(listObj))
      return

    let data = this.getUnitsListData()
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)

    foreach (unit in this.units) {
      let placeObj = listObj.findObject($"cont_{unit.name}")
      if (!placeObj)
        continue

      this.updateAdditionalProp(unit, placeObj)
      ::updateAirAfterSwitchMod(unit)
    }

    this.restoreLastUnitSelection(listObj)
  }

  function selectCell() {
    let listObj = this.scene.findObject("units_list")
    if (!listObj?.isValid())
      return

    let idx = findChildIndex(listObj, @(c) c.isHovered())
    if (idx == -1 || idx == listObj.getValue())
      return

    listObj.setValue(idx)
  }

  function restoreLastUnitSelection(listObj) {
    local newIdx = -1
    if (this.lastSelectedUnit) {
      let unit = this.lastSelectedUnit
      newIdx = this.filteredUnits.findindex(@(u) u == unit) ?? -1
    }
    let total = listObj.childrenCount()
    if (newIdx == -1 && total)
      newIdx = 0

    this.needSkipFocus = true
    listObj.setValue(newIdx)
    this.needSkipFocus = false

    if (newIdx == -1) {
      this.lastSelectedUnit = null
      this.updateButtons()
    }
  }

  function getUnitItemParams(_unit) {
    return {
      hasActions         = true
      isInTable          = false
      fullBlock          = false
      showBR             = hasFeature("GlobalShowBattleRating")
      tooltipParams      = { needShopInfo = true }
    }
  }

  getParamsForActionsList = @() { setResearchManually  = true }

  function checkUnitItemAndUpdate(unit) {
    if (!unit)
      return

    this.updateUnitItem(unit, this.scene.findObject($"cont_{unit.name}"))
    ::updateAirAfterSwitchMod(unit)
  }

  function updateUnitItem(unit, placeObj) {
    if (!checkObj(placeObj))
      return

    let unitBlock = buildUnitSlot(unit.name, unit, this.getUnitItemParams(unit))
    this.guiScene.replaceContentFromText(placeObj, unitBlock, unitBlock.len(), this)
    this.updateAdditionalProp(unit, placeObj)
  }

  function updateAdditionalProp(unit, placeObj) {
    fillUnitSlotTimers(placeObj.findObject(unit.name), unit)
    showUnitDiscount(placeObj.findObject($"{unit.name}-discount"), unit)

    local bonusData = unit.name
    if (isUnitGroup(unit))
      bonusData = unit.airsGroup.map(@(unt) unt.name)
    showAirExpWpBonus(placeObj.findObject($"{unit.name}-bonus"), bonusData)
  }

  function getCurSlotObj() {
    let listObj = this.scene.findObject("units_list")
    let idx = getObjValidIndex(listObj)
    if (idx < 0)
      return null

    return listObj.getChild(idx).getChild(0)
  }

  function onUnitSelect(_obj) {
    this.lastSelectedUnit = null
    let slotObj = this.getCurSlotObj()
    if (checkObj(slotObj))
      this.lastSelectedUnit = getAircraftByName(slotObj.unit_name)

    this.updateButtons()
  }

  function onUnitAction(_obj) {
    this.selectCell()
    this.openUnitActionsList(this.getCurSlotObj())
  }

  function onUnitClick(obj) {
    this.actionsListOpenTime = get_time_msec()
    this.onUnitAction(obj)
  }

  function onUnitRightClick(obj) {
    if (get_time_msec() - this.actionsListOpenTime
        < OPEN_RCLICK_UNIT_MENU_AFTER_SELECT_TIME)
      return
    this.onUnitAction(obj)
  }

  function onEventUnitResearch(p) {
    let prevUnitName = p?.prevUnitName
    let unitName = p?.unitName

    if (prevUnitName && prevUnitName != unitName)
      this.checkUnitItemAndUpdate(getAircraftByName(prevUnitName))

    this.checkUnitItemAndUpdate(getAircraftByName(unitName))
  }

  function onEventUnitBought(p) {
    ::update_gamercards()
    this.checkUnitItemAndUpdate(getAircraftByName(p?.unitName))
  }

  function onEventFlushSquadronExp(_p) {
    this.fillUnitsList()
  }

  function onEventModificationPurchased(p) {
    this.checkUnitItemAndUpdate(p?.unit)
  }

  function onEventUnitRepaired(p) {
    this.checkUnitItemAndUpdate(p?.unit)
  }
}

gui_handlers.vehiclesModal <- handlerClass

return {
  handlerClass = handlerClass
  open = function(unitsFilter = null, params = {}) {
    let handlerParams = params.__merge({ unitsFilter = unitsFilter })
    handlersManager.loadHandler(handlerClass, handlerParams)
  }
}