from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryPresets.nut" import MIN_TIERS_COUNT

let { getSinglePresetView } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { getWeaponItemViewParams } = require("%scripts/weaponry/weaponryVisual.nut")
let { getLastWeapon, getPresetsList } = require("%scripts/weaponry/weaponryInfo.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

function getSelectedPresetMarkup(unit) {
  let selectedPresetName = getLastWeapon(unit.name)
  local preset = getSinglePresetView(unit, selectedPresetName)
  if (preset == null) {
    let defaultPresetName = getPresetsList(unit, null)?[0].name
    if (defaultPresetName)
      preset = getSinglePresetView(unit, defaultPresetName)
    if (preset == null)
      return null
  }

  let weaponryItem = getWeaponItemViewParams($"item_0", unit, preset.weaponPreset, {}).__update({
    tiersView = preset.tiersView.map(@(t) {
      img = t?.img ?? ""
      tierTooltipId = t?.tierTooltipId
      isActive = t?.isActive || "img" in t
    })
  })

  let tiersCount = max(weaponryItem.tiersView.len(), MIN_TIERS_COUNT)
  let slotScale = tiersCount <= MIN_TIERS_COUNT ? 1
    : MIN_TIERS_COUNT.tofloat() / tiersCount

  return handyman.renderCached("%gui/unitInfo/weaponryPreset.tpl",
    { weaponryItem, tiersCount, slotScale, isTooltipByHold = showConsoleButtons.get() })
}

return {
  getSelectedPresetMarkup
}
