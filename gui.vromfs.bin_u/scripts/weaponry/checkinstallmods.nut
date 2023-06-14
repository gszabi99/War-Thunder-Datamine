from "%scripts/dagui_library.nut" import *
let { getModificationName } = require("%scripts/weaponry/bulletsInfo.nut")
let { getWeaponDisabledMods } = require("%scripts/weaponry/weaponryInfo.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

let needReqModInstall = @(unit, weapon) getWeaponDisabledMods(unit, weapon).len() > 0

let function installMods(unit, disabledMods) {
  let onSuccess = function() {
    disabledMods.each(@(modName) ::updateAirAfterSwitchMod(unit, modName))
    broadcastEvent("ModificationChanged")
  }
  let taskId = ::enable_modifications(unit.name, disabledMods, true)
  ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
}

let function promptReqModInstall(unit, weapon) {
  let disabledMods = getWeaponDisabledMods(unit, weapon)
  if (disabledMods.len() == 0)
    return true

  let modNames = disabledMods.map(
    @(modName) colorize("userlogColoredText", getModificationName(unit, modName)))
  let text = loc("weaponry/require_mod_install", {
    modNames = loc("ui/colon").join(modNames)
    numMods = disabledMods.len()
  })
  let onOk = @() installMods(unit, disabledMods)
  ::scene_msg_box("activate_wager_message_box", null, text, [["yes", onOk], ["no"]], "yes")
  return false
}

return {
  needReqModInstall
  promptReqModInstall
}