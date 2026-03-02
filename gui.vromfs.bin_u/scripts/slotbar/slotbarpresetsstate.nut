from "%scripts/dagui_library.nut" import *

let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

let slotbarPresetsByCountry = persist("slotbarPresetsByCountry", @() {})
let slotbarPresetsSeletected = persist("slotbarPresetsSeletected", @() {})
let slotbarPresetsVersion = persist("slotbarPresetsVersion", @() {ver=0})

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