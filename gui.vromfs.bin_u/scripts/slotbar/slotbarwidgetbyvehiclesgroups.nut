from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

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
    let country = this.getForcedCountry()
    foreach(idx, coutryCrews in ::g_crews_list.get())
    {
      if (onlyForCountryIdx != null && onlyForCountryIdx != idx)
        continue

      let visibleCountries = getShopVisibleCountries()
      let listCountry = coutryCrews.country
      if ((this.singleCountry != null && this.singleCountry != listCountry)
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
      let crewsCount = max(realCrewsCount, this.showNewSlot ? (groupsList?.len() ?? 0) : 0)
      for(local i = 0; i < crewsCount; i++)
      {
        let crew = crewsList?[i] ?? getDefaultCrew(listCountry, idx, i)
        let unit = unitsList?.units[i]
        let status = unit == null ? bit_unit_status.empty
          : isVisualDisabled || (unit != null && !(unit.name in this.availableUnits)) ? bit_unit_status.disabled
          : bit_unit_status.owned

        this.addCrewData(countryData.crews, {
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
    this.curSlotCountryId = selSlot.countryId
    this.curSlotIdInCountry = selSlot.crewIdInCountry

    if (this.slotbarOninit)
    {
      if (this.afterSlotbarSelect)
        this.afterSlotbarSelect()
      return
    }

    let crewList = ::g_crews_list.get()?[this.curSlotCountryId]
    let country = crewList?.country ?? ""
    let crew = crewList?.crews[this.curSlotIdInCountry]
      ?? getDefaultCrew(country, this.curSlotCountryId, this.curSlotIdInCountry)
    let groupsList = unitsGroupsByCountry?[country].groups
    let unit = getCrewUnit(crew)
    if (unit || groupsList == null)
      this.setCrewUnit(unit)
    else if (this.needActionsWithEmptyCrews)
      onSlotChangeGroup()

    if (this.hasActions)
    {
      let slotItem = ::get_slot_obj(obj, this.curSlotCountryId, this.curSlotIdInCountry)
      this.openUnitActionsList(slotItem)
    }

    if (this.afterSlotbarSelect)
      this.afterSlotbarSelect()
  }

  getDefaultCrew = @(country, idCountry, idInCountry) {
    country = country
    idCountry = idCountry
    idInCountry = idInCountry
    id = -1
  }

  function getCurSlotUnit()
  {
    return countryPresets?[this.getCurCountry()].units[this.curSlotIdInCountry]
  }

  function getCrewUnit(crew)
  {
    return countryPresets?[crew.country].units[crew.idInCountry]
  }

  function getHangarFallbackUnitParams()
  {
    return {
      country = this.getCurCountry()
      slotbarUnits = (countryPresets?[this.getCurCountry()].units ?? [])
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
    this.fullUpdate()
  }

  function getCurCrew()
  {
    return slotbarPresets.getSlotItem(this.curSlotCountryId, this.curSlotIdInCountry)
  }

  getParamsForActionsList = @() { hasSlotbarByUnitsGroups = true }
  function onSlotChangeGroup()
  {
    let crew = getCurCrew()
    if (!crew)
      return

    let slotbar = this
    this.ignoreCheckSlotbar = true
    this.checkedCrewAirChange(function() {
        this.ignoreCheckSlotbar = false
        selectGroupHandler.open(crew, slotbar)
      },
      function() {
        this.ignoreCheckSlotbar = false
        this.checkSlotbar()
      }
    )
  }

  getCrewDataParams = @(crewData) {
    bottomLineText = loc(
      slotbarPresets.getVehiclesGroupByUnit(
        crewData.unit, unitsGroupsByCountry?[crewData?.crew.country ?? ""])?.name ?? "")
  }

  getDefaultDblClickFunc = @() @(_crew) null
}

::gui_handlers.slotbarWidgetByVehiclesGroups <- handlerClass

let function create(params)
{
  let nest = params?.scene
  if (!checkObj(nest))
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