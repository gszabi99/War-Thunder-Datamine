local curSlotCountryId = -1
local curSlotIdInCountry = -1
local curPresetId = -1

local function updateHangarPreset(forceUpdate = false) {
  if (!::isInMenu())
    return

  local country = ::get_profile_country_sq()
  local newSlotCountryId = ::shopCountriesList.findindex(@(cName) cName == country) ?? -1
  local newSlotIdInCountry = ::selected_crews?[newSlotCountryId] ?? -1
  local newPresetId = ::slotbarPresets.getCurrent()
  if (!forceUpdate && newPresetId == curPresetId
    && newSlotCountryId == curSlotCountryId && newSlotIdInCountry == curSlotIdInCountry)
    return

  curPresetId = newPresetId
  curSlotCountryId = newSlotCountryId
  curSlotIdInCountry = newSlotIdInCountry
  ::hangar_current_preset_changed(curSlotCountryId, curSlotIdInCountry, curPresetId)
}

addListenersWithoutEnv({
  CrewsListChanged      = @(p) updateHangarPreset()
  CrewChanged           = @(p) updateHangarPreset()
  CountryChanged        = @(p) updateHangarPreset()
  LoadingStateChange    = @(p) updateHangarPreset(true)
})
