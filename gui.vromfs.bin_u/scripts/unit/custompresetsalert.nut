from "%scripts/dagui_library.nut" import *
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isDataBlock } = require("%sqStdLibs/helpers/u.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getWeaponryCustomPresets } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

const SEEN_UNITS_WITH_CUSTOM_PRESETS = "seenUnitsWithCustomPresets"

local seenUnits = {}
local isInited = false

function initOnce() {
  if (isInited || !::g_login.isProfileReceived())
    return

  isInited = true

  let blk = loadLocalAccountSettings(SEEN_UNITS_WITH_CUSTOM_PRESETS, null)
  if (!isDataBlock(blk))
    return

  seenUnits = convertBlk(blk)
}

function getCurCountryUnits() {
  let units = []
  let countryId = profileCountrySq.value
  foreach (crew in ::get_crews_list_by_country(countryId))
    if ((crew?.aircraft ?? "") != "")
      units.append(getAircraftByName(crew.aircraft))
  return units
}

function checkShowCustomPresetsAlert(units = null) {
  initOnce()
  if (!isInited)
    return

  if (units == null)
    units = getCurCountryUnits()

  let unitNames = []
  foreach (unit in units) {
    if (!unit.hasWeaponSlots || (unit.name in seenUnits))
      continue

    let hasCustomPresets = getWeaponryCustomPresets(unit).len() > 0
    if (hasCustomPresets)
      continue

    unitNames.append(unit.name)
    seenUnits[unit.name] <- true
  }

  if (unitNames.len() == 0)
    return

  let msg = loc("msgbox/custom_presets_alert", {
    count = unitNames.len()
    unitNames = ", ".join(unitNames.map(@(n) colorize("activeTextColor", getUnitName(n))))
  })
  scene_msg_box("custom_presets_alert", null, msg, [["ok"]], "ok")
  saveLocalAccountSettings(SEEN_UNITS_WITH_CUSTOM_PRESETS, seenUnits)
}

addListenersWithoutEnv({
  function SignOut(_) {
    seenUnits.clear()
    isInited = false
  }
  function CrewTakeUnit(params) {
    let { unit } = params
    if (unit != null)
      checkShowCustomPresetsAlert([unit])
  }
})

return {
  checkShowCustomPresetsAlert
}