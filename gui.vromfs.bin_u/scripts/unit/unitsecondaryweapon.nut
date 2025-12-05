from "%scripts/dagui_library.nut" import *
let { getWeaponryByPresetInfo } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { getWeaponItemViewParams } = require("%scripts/weaponry/weaponryVisual.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

function getSelectedPresetMarkup(unit) {
  let weaponryByPresetInfo = getWeaponryByPresetInfo(unit, null)
  let selectedPresetName = getLastWeapon(unit.name)

  local preset = weaponryByPresetInfo.presets.findvalue(@(w) w.name == selectedPresetName)
  if (preset == null)
    preset = weaponryByPresetInfo.presets[0]

  let weaponryItem = getWeaponItemViewParams($"item_0", unit, preset.weaponPreset, {}).__update({
    tiersView = preset.tiersView.map(@(t) {
      img = t?.img ?? ""
      tierTooltipId = t?.tierTooltipId
      isActive = t?.isActive || "img" in t
    })
  })

  return handyman.renderCached("%gui/unitInfo/weaponryPreset.tpl", { weaponryItem })
}

return {
  getSelectedPresetMarkup
}