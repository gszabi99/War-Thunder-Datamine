from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/dagui_library.nut" import *

let hardPersist = mkHardPersist("slotbar.slotbarPresetsState")
let slotbarPresetsByCountry = hardPersist("slotbarPresetsByCountry", {})
let slotbarPresetsSeletected = hardPersist("slotbarPresetsSeletected", {})
let slotbarPresetsVersion = hardPersist("slotbarPresetsVersion", { ver = 0 })

let isSlotbarPresetsLoading = Watched(false)

function getCurrentPresetIdx(country = null, defValue = -1) {
  country = country ?? profileCountrySq.get()
  return (country in slotbarPresetsSeletected) ? slotbarPresetsSeletected[country] : defValue
}

return {
  slotbarPresetsByCountry
  slotbarPresetsSeletected
  slotbarPresetsVersion
  getCurrentPresetIdx
  isSlotbarPresetsLoading
}