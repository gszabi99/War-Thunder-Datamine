from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let selectGroupHandler = require("%scripts/slotbar/selectGroupHandler.nut")
let { setShowUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getShopVisibleCountries } = require("%scripts/shop/shopCountriesList.nut")
let { bit_unit_status } = require("%scripts/unit/unitInfo.nut")
let { getSlotObj } = require("%scripts/slotbar/slotbarView.nut")
let { selectCrew } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")

local handlerClass = class (gui_handlers.SlotbarWidget) {
  unitsGroupsByCountry = null
  countryPresets = null
  emptyText = "#mainmenu/changeUnitsGroup"

  function validateParams() {
    base.validateParams()
    this.validatePresetsParams()
  }

  function validatePresetsParams() {
    let curPreset = slotbarPresets.getCurPreset()
    this.unitsGroupsByCountry = curPreset.groupsList
    this.countryPresets = curPreset.countryPresets
  }

  function gatherVisibleCrewsConfig(onlyForCountryIdx = null) {
    let res = []
    let country = this.getForcedCountry()
    foreach (idx, coutryCrews in getCrewsList()) {
      if (onlyForCountryIdx != null && onlyForCountryIdx != idx)
        continue

      let visibleCountries = this.countriesToShow ?? getShopVisibleCountries()
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
      let unitsList = this.countryPresets?[listCountry]
      let realCrewsCount = crewsList.len()
      let groupsList = this.unitsGroupsByCountry?[listCountry].groups
      let isVisualDisabled = groupsList == null
      let crewsCount = max(realCrewsCount, this.showNewSlot ? (groupsList?.len() ?? 0) : 0)
      for (local i = 0; i < crewsCount; i++) {
        let crew = crewsList?[i] ?? this.getDefaultCrew(listCountry, idx, i)
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

  function applySlotSelection(obj, selSlot) {
    this.curSlotCountryId = selSlot.countryId
    this.curSlotIdInCountry = selSlot.crewIdInCountry

    if (this.slotbarOninit) {
      if (this.afterSlotbarSelect)
        this.afterSlotbarSelect()
      return
    }

    let crewList = getCrewsList()?[this.curSlotCountryId]
    let country = crewList?.country ?? ""
    let crew = crewList?.crews[this.curSlotIdInCountry]
      ?? this.getDefaultCrew(country, this.curSlotCountryId, this.curSlotIdInCountry)
    let groupsList = this.unitsGroupsByCountry?[country].groups
    let unit = this.getCurCrewUnit(crew)
    if (unit || groupsList == null)
      this.setCrewUnit(unit)
    else if (this.needActionsWithEmptyCrews)
      this.onSlotChangeGroup()

    if (this.hasActions) {
      let slotItem = getSlotObj(obj, this.curSlotCountryId, this.curSlotIdInCountry)
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

  function getCurSlotUnit() {
    return this.countryPresets?[this.getCurCountry()].units[this.curSlotIdInCountry]
  }

  function getCurCrewUnit(crew) {
    return this.countryPresets?[crew.country].units[crew.idInCountry]
  }

  function getHangarFallbackUnitParams() {
    return {
      country = this.getCurCountry()
      slotbarUnits = (this.countryPresets?[this.getCurCountry()].units ?? [])
        .filter(@(unit) unit != null)
    }
  }

  function onEventPresetsByGroupsChanged(p) {
    let newCrew = p?.crew
    let newUnit = p?.unit
    if (newCrew != null && newUnit != null) {
      selectCrew(newCrew.idCountry, newCrew.idInCountry)
      setShowUnit(newUnit)
    }
    this.validatePresetsParams()
    this.fullUpdate()
  }

  function getCurCrew() {
    return slotbarPresets.getSlotItem(this.curSlotCountryId, this.curSlotIdInCountry)
  }

  getParamsForActionsList = @() { hasSlotbarByUnitsGroups = true }
  function onSlotChangeGroup() {
    let crew = this.getCurCrew()
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
        crewData.unit, this.unitsGroupsByCountry?[crewData?.crew.country ?? ""])?.name ?? "")
  }

  getDefaultDblClickFunc = @() @(_crew) null
}

gui_handlers.slotbarWidgetByVehiclesGroups <- handlerClass

function create(params) {
  let nest = params?.scene
  if (!checkObj(nest))
    return null

  if (params?.shouldAppendToObject ?? true) { //we append to nav-bar by default
    let data = "slotbarDiv { id:t='nav-slotbar' }"
    nest.getScene().appendWithBlk(nest, data)
    params.scene = nest.findObject("nav-slotbar")
  }

  return handlersManager.loadHandler(handlerClass, params)
}

return {
  create = create
}