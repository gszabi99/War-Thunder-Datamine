//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let { getUnitListByUnlockId } = require("%scripts/unlocks/unlockMarkers.nut")
let { getUnlockTitle } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

let function getUnitsData(unlockId) {
  let data = {}
  let ediff = getShopDiffCode()
  let units = getUnitListByUnlockId(unlockId).filter(@(u) u.isVisibleInShop())
  foreach (countryId in shopCountriesList) {
    let countryUnits = units.filter(@(unit) ::getUnitCountry(unit) == countryId)
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
let getUnitRankText = @(u) ::get_roman_numeral(u.rank)

let function getCountriesView(unlockId) {
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
        isTooltipByHold = ::show_console_buttons
        units = unitsList.map(@(u) {
          id = u.name
          ico = ::getUnitClassIco(u)
          type = getUnitRole(u)
          tooltipId = ::g_tooltip.getIdUnit(u.name)
          text = ::nbsp.concat(
            colorize("fadedTextColor",
              $"[{getUnitRankText(u)},{::nbsp}{getUnitBrText(u, ediff)}]"),
            ::getUnitName(u, true))
          isUsable = u.isUsable()
          canBuy   = ::canBuyUnit(u) || ::canBuyUnitOnline(u)
        })
      })
    }

    if (armyTypes.len() > 0)
      view.append({
        countryIcon = ::get_country_icon(countryId)
        armyTypes
      })
  }

  return view
}

let function getWndTitle(unlockId) {
  let unlockBlk = getUnlockById(unlockId)
  let unlockCfg = ::build_conditions_config(unlockBlk)
  return loc("mainmenu/showVehiclesTitle", {
    taskName = getUnlockTitle(unlockCfg)
  })
}

let class UnlockUnitListWnd extends ::gui_handlers.BaseGuiHandlerWT {
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

::gui_handlers.UnlockUnitListWnd <- UnlockUnitListWnd

let function openUnlockUnitListWnd(unlockId, onUnitSelectCb) {
  ::handlersManager.loadHandler(UnlockUnitListWnd, {
    unlockId
    onUnitSelectCb
  })
}

return openUnlockUnitListWnd
