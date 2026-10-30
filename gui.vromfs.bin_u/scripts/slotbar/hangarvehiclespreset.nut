from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/slotbar/slotbarStateData.nut" import getSelectedCrews
from "%scripts/slotbar/slotbarPresetsState.nut" import getCurrentPresetIdx
from "%scripts/slotbar/slotbarPresetsHelpers.nut" import getCurrentSlotbarPreset
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "hangar" import hangar_current_preset_changed
from "%scripts/dagui_library.nut" import *

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

local curSlotCountryId = -1
local curSlotIdInCountry = -1
local curPresetId = -1
local curUnitsCount = -1

function updateHangarPreset(forceUpdate = false) {
  if (!isInMenu.get() || !hasFullLoginState.get())
    return

  let country = profileCountrySq.get()
  let newSlotCountryId = shopCountriesList.findindex(@(cName) cName == country) ?? -1
  let newSlotIdInCountry = getSelectedCrews(country)
  let newPresetId = getCurrentPresetIdx(country)
  let newUnitsCount = getCurrentSlotbarPreset(country)?.units.len() ?? -1
  if (!forceUpdate && newPresetId == curPresetId
    && newSlotCountryId == curSlotCountryId && newSlotIdInCountry == curSlotIdInCountry
    && newUnitsCount == curUnitsCount)
    return

  curPresetId = newPresetId
  curSlotCountryId = newSlotCountryId
  curSlotIdInCountry = newSlotIdInCountry
  curUnitsCount = newUnitsCount
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

hasFullLoginState.subscribe(function(v) {
  if (v)
    updateHangarPreset(true)
})