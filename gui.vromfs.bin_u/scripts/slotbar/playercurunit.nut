from "%scripts/dagui_library.nut" import *

let { get_player_unit_name } = require("unit")
let { hangar_get_current_unit_name, hangar_move_cam_to_unit_place } = require("hangar")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadModel } = require("%scripts/hangarModelLoadManager.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { profileCountrySq, switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { isUnitDefault } = require("%scripts/unit/unitStatus.nut")
let { isInFlight } = require("gameplayBinding")

local isFallbackUnitInHangar = null
let hangarDefaultUnits = {}

function getCountryHangarDefaultUnit(countryId, esUnitType) {
  if (hangarDefaultUnits?[countryId] == null) {
    hangarDefaultUnits[countryId] <- {}
    foreach (needReserveUnit in [ true, false ]) {
      foreach (u in getAllUnits())
        if (u.isVisibleInShop() && u.shopCountry == countryId
            && (!needReserveUnit || isUnitDefault(u))
            && hangarDefaultUnits[countryId]?[u.esUnitType] == null)
          hangarDefaultUnits[countryId][u.esUnitType] <- u
      if (hangarDefaultUnits[countryId].len() == unitTypes.types.len() - 1)
        break
    }
  }
  return hangarDefaultUnits[countryId]?[esUnitType]
    ?? hangarDefaultUnits[countryId].findvalue(@(_u) true)
}

function getFallbackUnitForHangar(params) {
  
  let countryId = params?.country ?? profileCountrySq.get()
  let curHangarUnit = getAircraftByName(hangar_get_current_unit_name())
  if (curHangarUnit?.shopCountry == countryId
      && (params?.slotbarUnits ?? []).indexof(curHangarUnit) != null)
    return curHangarUnit

  
  let esUnitType = curHangarUnit?.esUnitType ?? ES_UNIT_TYPE_AIRCRAFT
  foreach (needCheckUnitType in [ true, false ])
    foreach (unit in (params?.slotbarUnits ?? []))
      if (!needCheckUnitType || unit.esUnitType == esUnitType)
        return unit

  
  return getCountryHangarDefaultUnit(countryId, esUnitType)
}

let showedUnit = mkWatched(persist, "showedUnit", null)

let getShowedUnitName = @() showedUnit.get()?.name ??
  (isFallbackUnitInHangar ? "" : hangar_get_current_unit_name())

let getShowedUnit = @() showedUnit.get() ??
  (isFallbackUnitInHangar ? null : getAircraftByName(hangar_get_current_unit_name()))

function setShowUnit(unit, params = null) {
  showedUnit.set(unit)
  isFallbackUnitInHangar = unit == null
  if (unit?.name)
    loadModel(unit?.name)
  else {
    let countryId = params?.country ?? profileCountrySq.get()
    switchProfileCountry(countryId)
    hangar_move_cam_to_unit_place(getFallbackUnitForHangar(params)?.name ?? "")
  }
}

showedUnit.subscribe(function(_v) {
  broadcastEvent("ShowedUnitChanged")
})

function getPlayerCurUnit() {
  local unit = null
  if (isInFlight())
    unit = getAircraftByName(get_player_unit_name())
  if (!unit || unit.name == "dummy_plane")
    unit = showedUnit.get() ?? getAircraftByName(hangar_get_current_unit_name())
  return unit
}


return {
  showedUnit
  getShowedUnitName
  getShowedUnit
  setShowUnit
  getPlayerCurUnit
}


