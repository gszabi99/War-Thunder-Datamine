local { loadModel } = require("scripts/hangarModelLoadManager.nut")

local showedUnit = persist("showedUnit", @() ::Watched(null))

local getShowedUnitName = @() showedUnit.value?.name ?? ::hangar_get_current_unit_name()

local getShowedUnit = @() showedUnit.value ?? ::getAircraftByName(::hangar_get_current_unit_name())

local function setShowUnit(unit) {
  if (!unit)
    return
  showedUnit(unit)
  loadModel(unit.name)
}

local function getPlayerCurUnit() {
  local unit = null
  if (::is_in_flight())
    unit = ::getAircraftByName(::get_player_unit_name())
  if (!unit || unit.name == "dummy_plane")
    unit = showedUnit.value
  return unit
}


return {
  showedUnit
  getShowedUnitName
  getShowedUnit
  setShowUnit
  getPlayerCurUnit
}


