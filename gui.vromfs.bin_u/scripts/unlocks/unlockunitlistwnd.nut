from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/shop/shopDifficulty.nut" import getShopDiffCode
from "%scripts/unlocks/unlockMarkers.nut" import getUnitListByUnlockId
from "%scripts/unlocks/unlocksState.nut" import buildConditionsConfig
from "%scripts/unlocks/unlocksViewModule.nut" import getUnlockTitle
from "%scripts/unit/unitInfoRoles.nut" import getUnitRole
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/unit/unitInfo.nut" import getUnitName, getUnitCountry
from "%scripts/unit/unitShopInfo.nut" import canBuyUnit
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/unit/unitInfoTexts.nut" import getUnitClassIco
from "%scripts/unit/availabilityBuyOnline.nut" import canBuyUnitOnline
from "string" import format
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

function getUnitsData(unlockId) {
  let data = {}
  let ediff = getShopDiffCode()
  let units = getUnitListByUnlockId(unlockId).filter(@(u) u.isVisibleInShop())
  foreach (countryId in shopCountriesList) {
    let countryUnits = units.filter(@(unit) getUnitCountry(unit) == countryId)
    if (!countryUnits.len())
      continue

    data[countryId] <- {}
    foreach (unitType in unitTypes.types) {
      let armyUnits = countryUnits.filter(@(unit) unitType == unit.unitType)
      if (!armyUnits.len())
        continue

      armyUnits.sort(@(a, b) a.rank <=> b.rank
        || a.getBattleRating(ediff) <=> b.getBattleRating(ediff))
      data[countryId][unitType.armyId] <- armyUnits
    }
  }
  return data
}

let getUnitBrText = @(u, ediff) format("%.1f", u.getBattleRating(ediff))
let getUnitRankText = @(u) get_roman_numeral(u.rank)

function getCountriesView(unlockId) {
  let ediff = getShopDiffCode()
  let unitsData = getUnitsData(unlockId)
  let view = []
  foreach (countryId in shopCountriesList) {
    if (!unitsData?[countryId])
      continue

    let armyTypes = []
    foreach (unitType in unitTypes.types) {
      let unitsList = unitsData[countryId]?[unitType.armyId]
      if (!unitsList)
        continue

      armyTypes.append({
        armyName = colorize("fadedTextColor", unitType.getArmyLocName())
        isTooltipByHold = showConsoleButtons.get()
        units = unitsList.map(@(u) {
          id = u.name
          ico = getUnitClassIco(u)
          type = getUnitRole(u)
          tooltipId = getTooltipType("UNIT").getTooltipId(u.name)
          text = nbsp.concat(
            colorize("fadedTextColor",
              $"[{getUnitRankText(u)},{nbsp}{getUnitBrText(u, ediff)}]"),
            getUnitName(u, true))
          isUsable = u.isUsable()
          canBuy   = canBuyUnit(u) || canBuyUnitOnline(u)
        })
      })
    }

    if (armyTypes.len() > 0)
      view.append({
        countryIcon = getCountryIcon(countryId)
        armyTypes
      })
  }

  return view
}

function getWndTitle(unlockId) {
  let unlockBlk = getUnlockById(unlockId)
  let unlockCfg = buildConditionsConfig(unlockBlk)
  return loc("mainmenu/showVehiclesTitle", {
    taskName = getUnlockTitle(unlockCfg)
  })
}

class UnlockUnitListWnd (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopSearchWnd.tpl"

  onUnitSelectCb = null
  selectedUnitId = null
  unlockId = null

  function getSceneTplView() {
    let countriesView = getCountriesView(this.unlockId)
    return {
      windowTitle = getWndTitle(this.unlockId)
      countriesCount = countriesView.len()
      countriesTotal = shopCountriesList.len()
      countries = countriesView
    }
  }

  function onUnitClick(obj) {
    this.selectedUnitId = obj.holderId
    this.goBack()
  }

  function afterModalDestroy() {
    this.onUnitSelectCb(this.selectedUnitId)
  }
}

register_gui_handler("UnlockUnitListWnd", UnlockUnitListWnd)

function openUnlockUnitListWnd(unlockId, onUnitSelectCb) {
  handlersManager.loadHandler(UnlockUnitListWnd, {
    unlockId
    onUnitSelectCb
  })
}

return openUnlockUnitListWnd
