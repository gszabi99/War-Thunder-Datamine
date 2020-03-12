local penalties = require("scripts/penitentiary/penalties.nut")

const PS4_SAVE_PROFILE_DELAY_MSEC = 60000

{
  local lastSaveTime = -PS4_SAVE_PROFILE_DELAY_MSEC
  ::save_profile_offline_limited <- function save_profile_offline_limited(isForced = false)
  {
    if (!isForced && ::is_platform_ps4
      && ::dagor.getCurTime() - lastSaveTime < PS4_SAVE_PROFILE_DELAY_MSEC)
      return

    lastSaveTime = ::dagor.getCurTime()
    if (::g_login.isProfileReceived())
      ::save_profile(false)
    else
      ::save_common_local_settings()
  }
}

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
::save_local_account_settings <- function save_local_account_settings(path, value, forceSave = false)
{
  if (!::should_disable_menu() && !::g_login.isProfileReceived())
  {
    ::script_net_assert_once("unsafe profile settings write",
      "save_local_account_settings at login state {0}".subst(::g_login.getStateDebugStr()))
    return
  }

  local cdb = ::get_local_custom_settings_blk()
  if (::set_blk_value_by_path(cdb, path, value))
    ::save_profile_offline_limited(forceSave)
}

::load_local_account_settings <- function load_local_account_settings(path, defValue = null)
{
  if (!::should_disable_menu() && !::g_login.isProfileReceived())
  {
    ::script_net_assert_once("unsafe profile settings read",
      "load_local_account_settings at login state {0}".subst(::g_login.getStateDebugStr()))
    return defValue
  }

  local cdb = ::get_local_custom_settings_blk()
  return ::get_blk_value_by_path(cdb, path, defValue)
}

//save/load setting to local profile, not depend on account, so can be usable before login.
::save_local_shared_settings <- function save_local_shared_settings(path, value, isForced = false)
{
  local blk = ::get_common_local_settings_blk()
  if (::set_blk_value_by_path(blk, path, value))
    ::save_profile_offline_limited(isForced)
}

::load_local_shared_settings <- function load_local_shared_settings(path, defValue = null)
{
  local blk = ::get_common_local_settings_blk()
  return ::get_blk_value_by_path(blk, path, defValue)
}

local getRootSizeText = @() "{0}x{1}".subst(::screen_width(), ::screen_height())

//save/load settings by account and by screenSize
::loadLocalByScreenSize <- function loadLocalByScreenSize(name, defValue=null)
{
  if (!::g_login.isProfileReceived())
    return defValue
  local rootName = getRootSizeText()
  local cdb = ::get_local_custom_settings_blk()
  if (cdb?[rootName][name])
    return cdb[rootName][name]
  return defValue
}

::saveLocalByScreenSize <- function saveLocalByScreenSize(name, value)
{
  if (!::g_login.isProfileReceived())
    return
  local rootName = getRootSizeText()
  local cdb = ::get_local_custom_settings_blk()
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
  ::save_profile_offline_limited()
}

//remove all data by screen size from all size blocks
//also clear empty size blocks
::clear_local_by_screen_size <- function clear_local_by_screen_size(name)
{
  if (!::g_login.isProfileReceived())
    return
  local cdb = ::get_local_custom_settings_blk()
  local hasChanges = false
  for(local idx = cdb.blockCount() - 1; idx >= 0; idx--)
  {
    local blk = cdb.getBlock(idx)
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
    ::save_profile_offline_limited()
}

// Deprecated, for storing new data use load_local_account_settings() instead.
::loadLocalByAccount <- function loadLocalByAccount(path, defValue=null)
{
  if (!::should_disable_menu() && !::g_login.isProfileReceived())
  {
    ::script_net_assert_once("unsafe profile settings read",
      "loadLocalByAccount at login state {0}".subst(::g_login.getStateDebugStr()))
    return defValue
  }

  local cdb = ::get_local_custom_settings_blk()
  local id = ::my_user_id_str + "." + (::isProductionCircuit() ? "production" : ::get_cur_circuit_name())
  local profileBlk = cdb?.accounts?[id]
  if (profileBlk)
  {
    local value = ::get_blk_value_by_path(profileBlk, path)
    if (value != null)
      return value
  }
  profileBlk = cdb?.accounts?[::my_user_id_str]
  if (profileBlk)
  {
    local value = ::get_blk_value_by_path(profileBlk, path)
    if (value != null)
      return value
  }
  return defValue
}

// Deprecated, for storing new data use save_local_account_settings() instead.
::saveLocalByAccount <- function saveLocalByAccount(path, value, forceSave = false, shouldSaveProfile = true)
{
  if (!::should_disable_menu() && !::g_login.isProfileReceived())
  {
    ::script_net_assert_once("unsafe profile settings read",
      "saveLocalByAccount at login state {0}".subst(::g_login.getStateDebugStr()))
    return
  }

  local cdb = ::get_local_custom_settings_blk()
  local id = ::my_user_id_str + "." + (::isProductionCircuit() ? "production" : ::get_cur_circuit_name())
  if (::set_blk_value_by_path(cdb, "accounts/" + id + "/" + path, value) && shouldSaveProfile)
    ::save_profile_offline_limited(forceSave)
}