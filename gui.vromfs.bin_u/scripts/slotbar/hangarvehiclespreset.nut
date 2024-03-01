from "%scripts/dagui_natives.nut" import hangar_current_preset_changed
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getSelectedCrews } = require("%scripts/slotbar/slotbarState.nut")

local curSlotCountryId = -1
local curSlotIdInCountry = -1
local curPresetId = -1

function updateHangarPreset(forceUpdate = false) {
  if (!isInMenu())
    return

  let country = profileCountrySq.value
  let newSlotCountryId = shopCountriesList.findindex(@(cName) cName == country) ?? -1
  let newSlotIdInCountry = getSelectedCrews(newSlotCountryId)
  let newPresetId = ::slotbarPresets.getCurrent()
  if (!forceUpdate && newPresetId == curPresetId
    && newSlotCountryId == curSlotCountryId && newSlotIdInCountry == curSlotIdInCountry)
    return

  curPresetId = newPresetId
  curSlotCountryId = newSlotCountryId
  curSlotIdInCountry = newSlotIdInCountry
  hangar_current_preset_changed(curSlotCountryId, curSlotIdInCountry, curPresetId)
}

addListenersWithoutEnv({
  CrewsListChanged      = @(_p) updateHangarPreset()
  CrewChanged           = @(_p) updateHangarPreset()
  CountryChanged        = @(_p) updateHangarPreset()
  LoadingStateChange    = @(_p) updateHangarPreset(true)
})
