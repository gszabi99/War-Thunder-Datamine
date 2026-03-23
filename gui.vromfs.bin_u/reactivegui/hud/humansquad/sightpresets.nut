from "%rGui/globals/ui_library.nut" import *

let { humanCurGunInfo, humanCurGunModeInfo } = require("%rGui/hud/state/human_gun_info_es.nut")
let { canSightChange } = require("%appGlobals/hud/humanPhysState.nut")
let { hud } = require("%rGui/style/colors.nut")
let { infantryHudCommonColor, infantryHudInactiveColor } = hud

let sightPresetsData = Computed(@()
  humanCurGunModeInfo.get()?.modWeapon?.sightPresetsData
  ?? humanCurGunInfo.get()?.sightPresetsData
  ?? [])
let currentPresetIdx = Computed(@()
  humanCurGunModeInfo.get()?.modWeapon?.currentSightPreset
  ?? humanCurGunInfo.get()?.currentSightPreset
  ?? 0)

let presetGap = hdpxi(2)
let presetPadding = [hdpxi(1), hdpxi(6)]

function mkPresetItem(text, isCurrent) {
  if (isCurrent)
    return {
      rendObj = ROBJ_BOX
      borderWidth = hdpxi(1)
      borderColor = infantryHudCommonColor
      padding = presetPadding
      children = {
        rendObj = ROBJ_TEXT
        text
        color = infantryHudCommonColor
        font = Fonts.very_tiny_text_hud
      }
    }
  return {
    rendObj = ROBJ_TEXT
    text
    color = infantryHudInactiveColor
    font = Fonts.very_tiny_text_hud
    padding = presetPadding
  }
}

let sightPresetsPanel = @() {
  watch = [canSightChange, sightPresetsData, currentPresetIdx]
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  pos = [-shHud(12), 0]
  gap = presetGap
  children = canSightChange.get()
    ? sightPresetsData.get().map(@(l, idx) mkPresetItem(loc(l), idx == currentPresetIdx.get()))
    : null
}

return sightPresetsPanel
