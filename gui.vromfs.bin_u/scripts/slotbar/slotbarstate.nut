//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { getShowedUnitName } = require("%scripts/slotbar/playerCurUnit.nut")

let function isCountrySlotbarHasUnits(countryId) {
  return ::get_crews_list_by_country(countryId).findvalue(@(crew) ::g_crew.getCrewUnit(crew) != null) != null
}

let function getAvailableCrewId(countryId) {
  local id = -1
  let curUnitId = getShowedUnitName()
  foreach (idx, crew in (::g_crews_list.get()?[countryId].crews ?? [])) {
    if (("aircraft" not in crew) || crew.aircraft == "")
      continue

    if (crew.aircraft == curUnitId) {
      id = idx
      break
    }
    if (id < 0)
      id = idx
  }
  return id
}

let function selectAvailableCrew(countryId) {
  local isAnyUnitInSlotbar = false
  if ((countryId in ::g_crews_list.get()) && (countryId in ::selected_crews)) {
    local id = getAvailableCrewId(countryId)
    isAnyUnitInSlotbar = id >= 0
    ::selected_crews[countryId] = max(0, id)
  }
  return isAnyUnitInSlotbar
}

let function getSelSlotsData() {
  ::init_selected_crews()
  let data = { slots = {}, units = {} }
  foreach (cIdx, country in ::g_crews_list.get()) {
    local unit = ::g_crew.getCrewUnit(country.crews?[::selected_crews[cIdx]])
    if (unit == null && isCountrySlotbarHasUnits(country.country)) {
      selectAvailableCrew(cIdx)
      unit = ::g_crew.getCrewUnit(country.crews?[::selected_crews[cIdx]])
    }
    data.slots[country.country] <- ::selected_crews[cIdx]
    data.units[country.country] <- unit?.name ?? ""
  }
  return data
}

return {
  isCountrySlotbarHasUnits
  getSelSlotsData
  selectAvailableCrew
}
