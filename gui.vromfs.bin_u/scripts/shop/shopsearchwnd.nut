local shopSearchCore = require("scripts/shop/shopSearchCore.nut")
local { getUnitRole } = require("scripts/unit/unitInfoTexts.nut")

class ::gui_handlers.ShopSearchWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/shop/shopSearchWnd"

  searchString = ""
  units = []
  cbOwnerShowUnit = null
  getEdiffFunc = null

  isUseUnitPlates = false

  function getSceneTplView()
  {
    local unitsData = prepareUnitsData()
    local countriesView = getCountriesView(unitsData)

    return {
      windowTitle = ::loc("shop/search/results") + ::loc("ui/colon") + searchString
      countriesCount = countriesView.len()
      countriesTotal = ::shopCountriesList.len()
      countries = countriesView
    }
  }

  function initScreen()
  {
    if (isUseUnitPlates)
    {
      local contentObj = scene.findObject("contentBlock")
      foreach (u in units)
        ::fill_unit_item_timers(contentObj.findObject(u.name), u)
    }
  }

  function prepareUnitsData()
  {
    local data = {}
    local ediff = getEdiffFunc()
    foreach (countryId in ::shopCountriesList)
    {
      local countryUnits = units.filter(@(unit) ::getUnitCountry(unit) == countryId)
      if (!countryUnits.len())
        continue

      data[countryId] <- {}
      foreach (unitType in ::g_unit_type.types)
      {
        local armyUnits = countryUnits.filter(@(unit) unitType == unit.unitType)
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
    local view = []
    local ediff = getEdiffFunc()
    isUseUnitPlates = getIsUseUnitPlates(unitsData)

    foreach (countryId in ::shopCountriesList)
    {
      if (!unitsData?[countryId])
        continue

      local countryView = {
        countryIcon = ::get_country_icon(countryId)
        armyTypes = []
      }

      foreach (unitType in ::g_unit_type.types)
      {
        local unitsList = unitsData[countryId]?[unitType.armyId]
        if (!unitsList)
          continue

        local armyView = {
          armyName = ::colorize("fadedTextColor", unitType.getArmyLocName())
          unitPlates = isUseUnitPlates ? [] : null
          units      = isUseUnitPlates ? null : []
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
              text = ::colorize("fadedTextColor", ::format("[%.1f]", u.getBattleRating(ediff))) +
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
    local unitId = ::g_string.cutPrefix(obj.id, "btn_") ?? ""
    cbOwnerShowUnit(unitId)
    goBack()
  }

  function getIsUseUnitPlates(unitsData)
  {
    local visibleHeight = ::to_pixels("1@maxWindowHeightNoSrh -1@frameHeaderHeight " +
      "-@cIco -6@blockInterval -0.02@sf)")
    local slotHeight  = ::to_pixels("@slot_height + 2@slot_interval")
    local maxColumnHeight = 0
    foreach (countryUnits in unitsData)
    {
      local columnHeight = 0
      foreach (armyUnits in countryUnits)
        columnHeight += slotHeight * (0.5 + armyUnits.len())
      maxColumnHeight = ::max(maxColumnHeight, columnHeight)
    }
    return maxColumnHeight <= visibleHeight
  }
}

return {
  open = function(searchString, cbOwnerShowUnit, getEdiffFunc)
  {
    local units = shopSearchCore.findUnitsByLocName(searchString)
    if (!units.len())
      return
    ::handlersManager.loadHandler(::gui_handlers.ShopSearchWnd, {
      searchString = searchString
      cbOwnerShowUnit = cbOwnerShowUnit
      getEdiffFunc = getEdiffFunc
      units = units
    })
  }
}
