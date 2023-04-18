//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

::gui_handlers.ShopSearchWnd <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopSearchWnd.tpl"

  searchString = ""
  units = []
  cbOwnerShowUnit = null
  getEdiffFunc = null

  isUseUnitPlates = false
  unitToShowOnClose = null

  function getSceneTplView() {
    let unitsData = this.prepareUnitsData()
    let countriesView = this.getCountriesView(unitsData)

    return {
      windowTitle = loc("shop/search/results") + loc("ui/colon") + this.searchString
      countriesCount = countriesView.len()
      countriesTotal = shopCountriesList.len()
      countries = countriesView
    }
  }

  function initScreen() {
    if (this.isUseUnitPlates) {
      let contentObj = this.scene.findObject("contentBlock")
      foreach (u in this.units)
        ::fill_unit_item_timers(contentObj.findObject(u.name), u)
    }
  }

  function prepareUnitsData() {
    let data = {}
    let ediff = this.getEdiffFunc()
    foreach (countryId in shopCountriesList) {
      let countryUnits = this.units.filter(@(unit) ::getUnitCountry(unit) == countryId)
      if (!countryUnits.len())
        continue

      data[countryId] <- {}
      foreach (unitType in unitTypes.types) {
        let armyUnits = countryUnits.filter(@(unit) unitType == unit.unitType)
        if (!armyUnits.len())
          continue

        armyUnits.sort(@(a, b) a.getBattleRating(ediff) <=> b.getBattleRating(ediff))
        data[countryId][unitType.armyId] <- armyUnits
      }
    }
    return data
  }

  function getCountriesView(unitsData) {
    let view = []
    let ediff = this.getEdiffFunc()
    this.isUseUnitPlates = this.getIsUseUnitPlates(unitsData)

    foreach (countryId in shopCountriesList) {
      if (!unitsData?[countryId])
        continue

      let countryView = {
        countryIcon = ::get_country_icon(countryId)
        armyTypes = []
      }

      foreach (unitType in unitTypes.types) {
        let unitsList = unitsData[countryId]?[unitType.armyId]
        if (!unitsList)
          continue

        let armyView = {
          armyName = colorize("fadedTextColor", unitType.getArmyLocName())
          unitPlates = this.isUseUnitPlates ? [] : null
          units      = this.isUseUnitPlates ? null : []
          isTooltipByHold = ::show_console_buttons
        }

        foreach (u in unitsList) {
          if (this.isUseUnitPlates) {
            armyView.unitPlates.append({
              id = u.name
              plateMarkup = ::build_aircraft_item(u.name, u)
            })
          }
          else {
            armyView.units.append({
              id = u.name
              ico = ::getUnitClassIco(u)
              type = getUnitRole(u)
              tooltipId = ::g_tooltip.getIdUnit(u.name)
              text = colorize("fadedTextColor", format("[%.1f]", u.getBattleRating(ediff))) +
                ::nbsp + ::getUnitName(u, true)
              isUsable = u.isUsable()
              canBuy   = ::canBuyUnit(u) || ::canBuyUnitOnline(u)
            })
          }
        }

        countryView.armyTypes.append(armyView)
      }

      if (countryView.armyTypes.len())
        view.append(countryView)
    }

    return view
  }

  function getCurrentEdiff() {
    return this.getEdiffFunc()
  }

  function onUnitClick(obj) {
    this.unitToShowOnClose = ::g_string.cutPrefix(obj.id, "btn_") ?? ""
    this.goBack()
  }

  function afterModalDestroy() {
    this.cbOwnerShowUnit(this.unitToShowOnClose)
  }

  function getIsUseUnitPlates(unitsData) {
    let visibleHeight = to_pixels("1@maxWindowHeightNoSrh -1@frameHeaderHeight " +
      "-@cIco -6@blockInterval -0.02@sf)")
    let slotHeight  = to_pixels("@slot_height + 2@slot_interval")
    local maxColumnHeight = 0
    foreach (countryUnits in unitsData) {
      local columnHeight = 0
      foreach (armyUnits in countryUnits)
        columnHeight += slotHeight * (0.5 + armyUnits.len())
      maxColumnHeight = max(maxColumnHeight, columnHeight)
    }
    return maxColumnHeight <= visibleHeight
  }
}

return {
  open = function(searchString, cbOwnerShowUnit, getEdiffFunc) {
    let units = shopSearchCore.findUnitsByLocName(searchString)
    if (!units.len())
      return false
    ::handlersManager.loadHandler(::gui_handlers.ShopSearchWnd, {
      searchString = searchString
      cbOwnerShowUnit = cbOwnerShowUnit
      getEdiffFunc = getEdiffFunc
      units = units
    })
    return true
  }
}
