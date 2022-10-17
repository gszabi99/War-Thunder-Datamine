let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

local curSlotCountryId = -1
local curSlotIdInCountry = -1
local curPresetId = -1

let function updateHangarPreset(forceUpdate = false) {
  if (!::isInMenu())
    return

  let country = ::get_profile_country_sq()
  let newSlotCountryId = shopCountriesList.findindex(@(cName) cName == country) ?? -1
  let newSlotIdInCountry = ::selected_crews?[newSlotCountryId] ?? -1
  let newPresetId = ::slotbarPresets.getCurrent()
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
