from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

::gui_handlers.ShopSearchWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "%gui/shop/shopSearchWnd"

  searchString = ""
  units = []
  cbOwnerShowUnit = null
  getEdiffFunc = null
  wndTitle = null

  isUseUnitPlates = false
  unitToShowOnClose = null

  function getSceneTplView()
  {
    let unitsData = prepareUnitsData()
    let countriesView = getCountriesView(unitsData)

    return {
      windowTitle = wndTitle ?? (loc("shop/search/results") + loc("ui/colon") + searchString)
      countriesCount = countriesView.len()
      countriesTotal = shopCountriesList.len()
      countries = countriesView
    }
  }

  function initScreen()
  {
    if (isUseUnitPlates)
    {
      let contentObj = scene.findObject("contentBlock")
      foreach (u in units)
        ::fill_unit_item_timers(contentObj.findObject(u.name), u)
    }
  }

  function prepareUnitsData()
  {
    let data = {}
    let ediff = getEdiffFunc()
    foreach (countryId in shopCountriesList)
    {
      let countryUnits = units.filter(@(unit) ::getUnitCountry(unit) == countryId)
      if (!countryUnits.len())
        continue

      data[countryId] <- {}
      foreach (unitType in unitTypes.types)
      {
        let armyUnits = countryUnits.filter(@(unit) unitType == unit.unitType)
        if (!armyUnits.len())
          continue

        armyUnits.sort(@(a, b) a.getBattleRating(ediff) <=> b.getBattleRating(ediff))
        data[countryId][unitType.armyId] <- armyUnits
      }
    }
    return data
  }

  function getCountriesView(unitsData)
  {
    let view = []
    let ediff = getEdiffFunc()
    isUseUnitPlates = getIsUseUnitPlates(unitsData)

    foreach (countryId in shopCountriesList)
    {
      if (!unitsData?[countryId])
        continue

      let countryView = {
        countryIcon = ::get_country_icon(countryId)
        armyTypes = []
      }

      foreach (unitType in unitTypes.types)
      {
        let unitsList = unitsData[countryId]?[unitType.armyId]
        if (!unitsList)
          continue

        let armyView = {
          armyName = colorize("fadedTextColor", unitType.getArmyLocName())
          unitPlates = isUseUnitPlates ? [] : null
          units      = isUseUnitPlates ? null : []
          isTooltipByHold = ::show_console_buttons
        }

        foreach (u in unitsList)
        {
          if (isUseUnitPlates)
          {
            armyView.unitPlates.append({
              id = u.name
              plateMarkup = ::build_aircraft_item(u.name, u)
            })
          }
          else
          {
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

  function getCurrentEdiff()
  {
    return getEdiffFunc()
  }

  function onUnitClick(obj)
  {
    unitToShowOnClose = ::g_string.cutPrefix(obj.id, "btn_") ?? ""
    goBack()
  }

  function afterModalDestroy() {
    cbOwnerShowUnit(unitToShowOnClose)
  }

  function getIsUseUnitPlates(unitsData)
  {
    let visibleHeight = to_pixels("1@maxWindowHeightNoSrh -1@frameHeaderHeight " +
      "-@cIco -6@blockInterval -0.02@sf)")
    let slotHeight  = to_pixels("@slot_height + 2@slot_interval")
    local maxColumnHeight = 0
    foreach (countryUnits in unitsData)
    {
      local columnHeight = 0
      foreach (armyUnits in countryUnits)
        columnHeight += slotHeight * (0.5 + armyUnits.len())
      maxColumnHeight = max(maxColumnHeight, columnHeight)
    }
    return maxColumnHeight <= visibleHeight
  }
}

return {
  open = function(searchString, cbOwnerShowUnit, getEdiffFunc, params = null)
  {
    let units = params?.units ?? shopSearchCore.findUnitsByLocName(searchString)
    if (!units.len())
      return false
    ::handlersManager.loadHandler(::gui_handlers.ShopSearchWnd, {
      searchString = searchString
      cbOwnerShowUnit = cbOwnerShowUnit
      getEdiffFunc = getEdiffFunc
      units = units
      wndTitle = params?.wndTitle
    })
    return true
  }
}
