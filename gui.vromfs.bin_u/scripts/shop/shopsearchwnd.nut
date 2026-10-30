import "%scripts/shop/shopSearchCore.nut" as shopSearchCore
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/unit/unitInfoRoles.nut" import getUnitRole
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/unit/unitInfo.nut" import getUnitName, getUnitCountry
from "%scripts/unit/unitShopInfo.nut" import canBuyUnit
from "%scripts/slotbar/slotbarView.nut" import buildUnitSlot, fillUnitSlotTimers
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/unit/unitInfoTexts.nut" import getUnitClassIco
from "%scripts/unit/availabilityBuyOnline.nut" import canBuyUnitOnline
from "string" import format
from "%sqstd/string.nut" import cutPrefix
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

let ShopSearchWnd = class (BaseGuiHandlerWT) {
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
      windowTitle = loc("ui/colon").concat(loc("shop/search/results"), this.searchString)
      countriesCount = countriesView.len()
      countriesTotal = shopCountriesList.len()
      countries = countriesView
    }
  }

  function initScreen() {
    if (this.isUseUnitPlates) {
      let contentObj = this.scene.findObject("contentBlock")
      foreach (u in this.units)
        fillUnitSlotTimers(contentObj.findObject(u.name), u)
    }
  }

  function prepareUnitsData() {
    let data = {}
    let ediff = this.getEdiffFunc()
    foreach (countryId in shopCountriesList) {
      let countryUnits = this.units.filter(@(unit) getUnitCountry(unit) == countryId)
      if (!countryUnits.len())
        continue

      data[countryId] <- {}
      foreach (unitType in unitTypes.types) {
        let armyUnits = countryUnits.filter(@(unit) unitType == unit.unitType)
        if (!armyUnits.len())
          continue

        armyUnits.sortby(@(a) a.getBattleRating(ediff))
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
        countryIcon = getCountryIcon(countryId)
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
          isTooltipByHold = showConsoleButtons.get()
        }

        foreach (u in unitsList) {
          if (this.isUseUnitPlates) {
            armyView.unitPlates.append({
              id = u.name
              plateMarkup = buildUnitSlot(u.name, u)
            })
          }
          else {
            armyView.units.append({
              id = u.name
              ico = getUnitClassIco(u)
              type = getUnitRole(u)
              tooltipId = getTooltipType("UNIT").getTooltipId(u.name)
              text = nbsp.concat(colorize("fadedTextColor", format("[%.1f]", u.getBattleRating(ediff))),
                getUnitName(u, true))
              isUsable = u.isUsable()
              canBuy   = canBuyUnit(u) || canBuyUnitOnline(u)
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
    this.unitToShowOnClose = cutPrefix(obj.id, "btn_") ?? ""
    this.goBack()
  }

  function afterModalDestroy() {
    this.cbOwnerShowUnit(this.unitToShowOnClose)
  }

  function getIsUseUnitPlates(unitsData) {
    let visibleHeight = to_pixels(
      "1@maxWindowHeightNoSrh -1@frameHeaderHeight -@cIco -6@blockInterval -0.02@sf)")
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
register_gui_handler("ShopSearchWnd", ShopSearchWnd)

return freeze({
  open = function(searchString, cbOwnerShowUnit, getEdiffFunc) {
    let units = shopSearchCore.findUnitsByLocName(searchString)
    if (!units.len())
      return false
    handlersManager.loadHandler(ShopSearchWnd, {
      searchString = searchString
      cbOwnerShowUnit = cbOwnerShowUnit
      getEdiffFunc = getEdiffFunc
      units = units
    })
    return true
  }
})
