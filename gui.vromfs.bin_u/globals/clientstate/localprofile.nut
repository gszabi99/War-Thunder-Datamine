from "%globalScripts/dataBlockExt.nut" import setBlkValueByPath, getBlkValueByPath
from "%appGlobals/login/loginState.nut" import isProfileReceived, getStateDebugStr
from "%globalScripts/clientState/initialState.nut" import shouldDisableMenu
from "eventbus" import eventbus_send
from "dagor.debug" import debug_dump_stack, logerr
from "blkGetters" import get_local_custom_settings_blk, get_common_local_settings_blk, get_local_unit_settings_blk

const NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED = "need_show_msg_graphic_aa_settings_was_modified"


let saveProfile = @() eventbus_send("saveProfile", {})


function saveLocalAccountSettings(path, value) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings write: saveLocalAccountSettings at login state ",
      getStateDebugStr()))
    return
  }

  let cdb = get_local_custom_settings_blk()
  if (setBlkValueByPath(cdb, path, value))
    saveProfile()
}

function loadLocalAccountSettings(path, defValue = null) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: loadLocalAccountSettings at login state ",
      getStateDebugStr()))
    return defValue
  }

  let cdb = get_local_custom_settings_blk()
  return getBlkValueByPath(cdb, path, defValue)
}

let getRandUnitOptPath = @(unitName, optName, groupIndex = null) "".concat(
  unitName
  "/paramsForRandomUnit/"
  optName
  groupIndex == null ? "" : groupIndex
)

function saveLocalUnitSettings(path, value) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings write: saveLocalUnitSettings at login state ",
      getStateDebugStr()))
    return
  }

  let cdb = get_local_unit_settings_blk()
  if (setBlkValueByPath(cdb, path, value))
    saveProfile()
}

function loadLocalUnitSettings(path, defValue = null) {
  if (!shouldDisableMenu && !isProfileReceived.get()) {
    debug_dump_stack()
    logerr("".concat("unsafe profile settings read: loadLocalUnitSettings at login state ",
      getStateDebugStr()))
    return defValue
  }

  let cdb = get_local_unit_settings_blk()
  return getBlkValueByPath(cdb, path, defValue)
}


function saveLocalSharedSettings(path, value) {
  let blk = get_common_local_settings_blk()
  if (setBlkValueByPath(blk, path, value))
    saveProfile()
}

function loadLocalSharedSettings(path, defValue = null) {
  let blk = get_common_local_settings_blk()
  return getBlkValueByPath(blk, path, defValue)
}

return freeze({
  NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED
  getRandUnitOptPath
  saveLocalSharedSettings
  loadLocalSharedSettings
  saveLocalAccountSettings
  loadLocalAccountSettings
  loadLocalUnitSettings
  saveLocalUnitSettings
})
