from "%scripts/dagui_natives.nut" import hangar_current_preset_changed
from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { getSelectedCrews } = require("%scripts/slotbar/slotbarStateData.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

local curSlotCountryId = -1
local curSlotIdInCountry = -1
local curPresetId = -1

function updateHangarPreset(forceUpdate = false) {
  if (!isInMenu.get() || !isLoggedIn.get())
    return

  let country = profileCountrySq.get()
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
})

isInMenu.subscribe(function(v) {
  if (v)
    updateHangarPreset(true)
})

isLoggedIn.subscribe(function(v) {
  if (v)
    updateHangarPreset(true)
})