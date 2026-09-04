from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "console" import register_command
from "%scripts/dagui_library.nut" import *

let { setDebugPresetsOverride, clearDebugPresetsOverride, invalidateUnitCache } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { searchAndRepairInvalidPresets, DBG_REPAIR_PRESET_MODE } = require("%scripts/weaponry/weaponryPresetsRepair.nut")



local dbgOverrideUnitName = null

let testPresets = {
  saab_f35_wdns = [
    {
      customNameText = "Custom preset #1"
      tiers = {
        "9" : { presetId = "aim_9n", slot = 9 }
        "1" :  { presetId = "aim_9n", slot = 1 }
      }
    },
    {
      customNameText = "Custom preset #2"
      tiers = {
        "8": { presetId = "lau_5003b", slot = 8 }
        "7": { presetId = "lau3a", slot = 7 }
        "5": { presetId = "mk82_center", slot = 5 }
        "3": { presetId = "lau3a", slot = 3 }
        "9": { presetId = "mk82", slot = 9 }
        "1": { presetId = "mk82sn", slot = 1 }
        "2": { presetId = "lau_5003b", slot = 2 }
      }
    }
  ]
  su_17m4 = [
    {
      customNameText = "Custom preset #1"
      tiers = {
        "5" :  { presetId = "ptb_right", slot = 5 }
        "6" : { presetId = "delta_ng", slot = 6 }
        "7" : { presetId = "wing_right_single_r_60", slot = 7 }
        "8" :  { presetId = "ptb_right1", slot = 8 }
      }
    }
    {
      customNameText = "Custom preset #2"
      tiers = {
        "8" :  { presetId = "bombs_small_group_x5", slot = 8 }
        "6" : { presetId = "delta_ng", slot = 6 }
      }
    }
  ]
}

function startDebugRepaiPresets(unitName, dbgRepairPresetModeInt) {
  if (unitName in testPresets && dbgRepairPresetModeInt == DBG_REPAIR_PRESET_MODE.brokenTiers) {
    setDebugPresetsOverride(unitName, testPresets[unitName])
    dbgOverrideUnitName = unitName
  }
  else
    clearDebugPresetsOverride(unitName)

  invalidateUnitCache(getAircraftByName(unitName))
  searchAndRepairInvalidPresets([unitName], dbgRepairPresetModeInt)
}

register_command(startDebugRepaiPresets, "debug.repair_presets")

addListenersWithoutEnv({
  WeaponryPresetsRepairFinished = function(_p) {
    if (dbgOverrideUnitName != null) {
      clearDebugPresetsOverride(dbgOverrideUnitName)
      dbgOverrideUnitName = null
    }
  }
})