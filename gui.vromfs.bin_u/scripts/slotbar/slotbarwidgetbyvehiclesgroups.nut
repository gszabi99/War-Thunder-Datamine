let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let selectGroupHandler = require("%scripts/slotbar/selectGroupHandler.nut")
let { setShowUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getShopVisibleCountries } = require("%scripts/shop/shopCountriesList.nut")

local handlerClass = class extends ::gui_handlers.SlotbarWidget
{
  unitsGroupsByCountry = null
  countryPresets = null
  emptyText = "#mainmenu/changeUnitsGroup"

  function validateParams()
  {
    base.validateParams()
    validatePresetsParams()
  }

  function validatePresetsParams()
  {
    let curPreset = slotbarPresets.getCurPreset()
    unitsGroupsByCountry = curPreset.groupsList
    countryPresets = curPreset.countryPresets
  }

  function gatherVisibleCrewsConfig(onlyForCountryIdx = null)
  {
    let res = []
    let country = getForcedCountry()
    foreach(idx, coutryCrews in ::g_crews_list.get())
    {
      if (onlyForCountryIdx != null && onlyForCountryIdx != idx)
        continue

      let visibleCountries = getShopVisibleCountries()
      let listCountry = coutryCrews.country
      if ((singleCountry != null && singleCountry != listCountry)
        || visibleCountries.indexof(listCountry) == null)
        continue

      let countryData = {
        country = listCountry
        id = idx
        isEnabled = (!country || country == listCountry)
        crews = []
      }
      res.append(countryData)

      if (!countryData.isEnabled)
        continue

      let crewsList = coutryCrews.crews
      let unitsList = countryPresets?[listCountry]
      let realCrewsCount = crewsList.len()
      let groupsList = unitsGroupsByCountry?[listCountry].groups
      let isVisualDisabled = groupsList == null
      let crewsCount = max(realCrewsCount, showNewSlot ? (groupsList?.len() ?? 0) : 0)
      for(local i = 0; i < crewsCount; i++)
      {
        let crew = crewsList?[i] ?? getDefaultCrew(listCountry, idx, i)
        let unit = unitsList?.units[i]
        let status = unit == null ? bit_unit_status.empty
          : isVisualDisabled || (unit != null && !(unit.name in availableUnits)) ? bit_unit_status.disabled
          : bit_unit_status.owned

        addCrewData(countryData.crews, {
          crew = crew,
          unit = unit,
          status = status,
          isSelectable = unit != null || groupsList == null
          isVisualDisabled = isVisualDisabled
          isLocalState = false
        })
      }
    }
    return res
  }

  function applySlotSelection(obj, selSlot)
  {
    curSlotCountryId = selSlot.countryId
    curSlotIdInCountry = selSlot.crewIdInCountry

    if (slotbarOninit)
    {
      if (afterSlotbarSelect)
        afterSlotbarSelect()
      return
    }

    let crewList = ::g_crews_list.get()?[curSlotCountryId]
    let country = crewList?.country ?? ""
    let crew = crewList?.crews[curSlotIdInCountry]
      ?? getDefaultCrew(country, curSlotCountryId, curSlotIdInCountry)
    let groupsList = unitsGroupsByCountry?[country].groups
    let unit = getCrewUnit(crew)
    if (unit || groupsList == null)
      setCrewUnit(unit)
    else if (needActionsWithEmptyCrews)
      onSlotChangeGroup()

    if (hasActions)
    {
      let slotItem = ::get_slot_obj(obj, curSlotCountryId, curSlotIdInCountry)
      openUnitActionsList(slotItem)
    }

    if (afterSlotbarSelect)
      afterSlotbarSelect()
  }

  getDefaultCrew = @(country, idCountry, idInCountry) {
    country = country
    idCountry = idCountry
    idInCountry = idInCountry
    id = -1
  }

  function getCurSlotUnit()
  {
    return countryPresets?[getCurCountry()].units[curSlotIdInCountry]
  }

  function getCrewUnit(crew)
  {
    return countryPresets?[crew.country].units[crew.idInCountry]
  }

  function getHangarFallbackUnitParams()
  {
    return {
      country = getCurCountry()
      slotbarUnits = (countryPresets?[getCurCountry()].units ?? [])
        .filter(@(unit) unit != null)
    }
  }

  function onEventPresetsByGroupsChanged(p)
  {
    let newCrew = p?.crew
    let newUnit = p?.unit
    if (newCrew != null && newUnit != null)
    {
      ::select_crew(newCrew.idCountry, newCrew.idInCountry)
      setShowUnit(newUnit)
    }
    validatePresetsParams()
    fullUpdate()
  }

  function getCurCrew()
  {
    return slotbarPresets.getSlotItem(curSlotCountryId, curSlotIdInCountry)
  }

  getParamsForActionsList = @() { hasSlotbarByUnitsGroups = true }
  function onSlotChangeGroup()
  {
    let crew = getCurCrew()
    if (!crew)
      return

    let slotbar = this
    ignoreCheckSlotbar = true
    checkedCrewAirChange(function() {
        ignoreCheckSlotbar = false
        selectGroupHandler.open(crew, slotbar)
      },
      function() {
        ignoreCheckSlotbar = false
        checkSlotbar()
      }
    )
  }

  getCrewDataParams = @(crewData) {
    bottomLineText = ::loc(
      slotbarPresets.getVehiclesGroupByUnit(
        crewData.unit, unitsGroupsByCountry?[crewData?.crew.country ?? ""])?.name ?? "")
  }

  getDefaultDblClickFunc = @() @(crew) null
}

::gui_handlers.slotbarWidgetByVehiclesGroups <- handlerClass

let function create(params)
{
  let nest = params?.scene
  if (!::check_obj(nest))
    return null

  if (params?.shouldAppendToObject ?? true) //we append to nav-bar by default
  {
    let data = "slotbarDiv { id:t='nav-slotbar' }"
    nest.getScene().appendWithBlk(nest, data)
    params.scene = nest.findObject("nav-slotbar")
  }

  return ::handlersManager.loadHandler(handlerClass, params)
}

return {
  create = create
}