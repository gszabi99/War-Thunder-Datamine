from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { set_blk_value_by_path, get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")

::onUpdateProfile <- function onUpdateProfile(taskId, action, transactionType = ::EATT_UNKNOWN) //code callback on profile update
{
  if (!::g_login.isProfileReceived())
    ::g_login.onProfileReceived()

  ::broadcastEvent("ProfileUpdated", { taskId = taskId, action = action, transactionType = transactionType })

  if (!::g_login.isLoggedIn())
    return
  ::update_gamercards()
  penalties.showBannedStatusMsgBox(true)
}

//save/load settings by account. work only after local profile received from host.
::save_local_account_settings <- function save_local_account_settings(path, value)
{
  if (!::should_disable_menu() && !::g_login.isProfileReceived())
  {
    logerr("".concat("unsafe profile settings read: save_local_account_settings at login state ",
      ::g_login.getStateDebugStr()))
    return
  }

  let cdb = ::get_local_custom_settings_blk()
  if (set_blk_value_by_path(cdb, path, value))
    saveProfile()
}

::load_local_account_settings <- function load_local_account_settings(path, defValue = null)
{
  if (!::should_disable_menu() && !::g_login.isProfileReceived())
  {
    logerr("".concat("unsafe profile settings read: load_local_account_settings at login state ",
      ::g_login.getStateDebugStr()))
    return defValue
  }

  let cdb = ::get_local_custom_settings_blk()
  return get_blk_value_by_path(cdb, path, defValue)
}

//save/load setting to local profile, not depend on account, so can be usable before login.
::save_local_shared_settings <- function save_local_shared_settings(path, value)
{
  let blk = ::get_common_local_settings_blk()
  if (set_blk_value_by_path(blk, path, value))
    saveProfile()
}

::load_local_shared_settings <- function load_local_shared_settings(path, defValue = null)
{
  let blk = ::get_common_local_settings_blk()
  return get_blk_value_by_path(blk, path, defValue)
}

let getRootSizeText = @() "{0}x{1}".subst(::screen_width(), ::screen_height())

//save/load settings by account and by screenSize
::loadLocalByScreenSize <- function loadLocalByScreenSize(name, defValue=null)
{
  if (!::g_login.isProfileReceived())
    return defValue
  let rootName = getRootSizeText()
  let cdb = ::get_local_custom_settings_blk()
  if (cdb?[rootName][name])
    return cdb[rootName][name]
  return defValue
}

::saveLocalByScreenSize <- function saveLocalByScreenSize(name, value)
{
  if (!::g_login.isProfileReceived())
    return
  let rootName = getRootSizeText()
  let cdb = ::get_local_custom_settings_blk()
  if (cdb?[rootName] != null && typeof(cdb[rootName]) != "instance")
    cdb[rootName] = null
  if (cdb?[rootName] == null)
    cdb[rootName] = ::DataBlock()
  if (cdb?[rootName][name] == null)
    cdb[rootName][name] = value
  else
    if (cdb[rootName][name] == value)
      return  //no need save when no changes
    else
      cdb[rootName][name] = value
  saveProfile()
}

//remove all data by screen size from all size blocks
//also clear empty size blocks
::clear_local_by_screen_size <- function clear_local_by_screen_size(name)
{
  if (!::g_login.isProfileReceived())
    return
  let cdb = ::get_local_custom_settings_blk()
  local hasChanges = false
  for(local idx = cdb.blockCount() - 1; idx >= 0; idx--)
  {
    let blk = cdb.getBlock(idx)
    if (!(name in blk))
      continue

    hasChanges = true
    if (::u.isDataBlock(blk?[name]))
      blk.removeBlock(name)
    else
      blk.removeParam(name)

    if (!blk.blockCount() && !blk.paramCount())
      cdb.removeBlockById(idx)
  }
  if (hasChanges)
    saveProfile()
}

// Deprecated, for storing new data use load_local_account_settings() instead.
::loadLocalByAccount <- function loadLocalByAccount(path, defValue=null)
{
  if (!::should_disable_menu() && !::g_login.isProfileReceived())
  {
    logerr("".concat("unsafe profile settings read: loadLocalByAccount at login state ",
      ::g_login.getStateDebugStr()))
    return defValue
  }

  let cdb = ::get_local_custom_settings_blk()
  let id = ::my_user_id_str + "." + (::isProductionCircuit() ? "production" : ::get_cur_circuit_name())
  local profileBlk = cdb?.accounts?[id]
  if (profileBlk)
  {
    let value = get_blk_value_by_path(profileBlk, path)
    if (value != null)
      return value
  }
  profileBlk = cdb?.accounts?[::my_user_id_str]
  if (profileBlk)
  {
    let value = get_blk_value_by_path(profileBlk, path)
    if (value != null)
      return value
  }
  return defValue
}

// Deprecated, for storing new data use save_local_account_settings() instead.
::saveLocalByAccount <- function saveLocalByAccount(path, value, saveFunc = saveProfile)
{
  if (!::should_disable_menu() && !::g_login.isProfileReceived())
  {
    logerr("".concat("unsafe profile settings read: saveLocalByAccount at login state ",
      ::g_login.getStateDebugStr()))
    return
  }

  let cdb = ::get_local_custom_settings_blk()
  let id = ::my_user_id_str + "." + (::isProductionCircuit() ? "production" : ::get_cur_circuit_name())
  if (set_blk_value_by_path(cdb, "accounts/" + id + "/" + path, value))
    saveFunc()
}